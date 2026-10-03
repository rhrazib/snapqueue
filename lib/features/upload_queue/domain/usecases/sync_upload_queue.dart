import 'dart:async';

import '../../../../core/error/failures.dart';
import '../repositories/upload_gateway.dart';
import '../repositories/upload_queue_repository.dart';

enum SyncOutcome {
  /// Nothing left that is worth retrying.
  complete,

  /// Something failed (or we are offline); try again later.
  retryLater,
}

/// Drains the queue. Runs in the UI isolate (SyncCoordinator) and in the
/// WorkManager isolate, so correctness relies on the repository's atomic
/// `claim`, not on in-memory state.
///
/// Retry policy:
/// * offline / low bandwidth are transient: the item stays queued and is
///   retried in rounds of [maxAttempts] (the caller backs off), it never
///   becomes `failed`;
/// * a missing file is permanent and fails immediately;
/// * any other failure gives up after [maxAttempts].
class SyncUploadQueue {
  const SyncUploadQueue(this._repository, this._gateway);

  static const maxAttempts = 5;

  /// Progress is persisted in steps, not on every callback.
  static const _progressStep = 0.09;

  final UploadQueueRepository _repository;
  final UploadGateway _gateway;

  Future<SyncOutcome> call() async {
    await _repository.releaseStale();

    // Items are re-read after every pass so batches queued while this run is
    // in flight are picked up too. `attempted` stops a failing item from being
    // retried in a tight loop within one run.
    final attempted = <String>{};
    var retryLater = false;

    while (true) {
      final queue = (await _repository.uploadable())
          .where((i) => !attempted.contains(i.id))
          .toList();
      if (queue.isEmpty) break;

      for (final item in queue) {
        attempted.add(item.id);
        if (!await _repository.claim(item.id)) continue;

        var lastReported = 0.0;
        try {
          await _gateway.upload(item, onProgress: (value) {
            if (value - lastReported >= _progressStep) {
              lastReported = value;
              unawaited(
                _repository.reportProgress(item.id, value).catchError((_) {}),
              );
            }
          });
          await _repository.markSynced(item.id);
        } on NoInternetFailure {
          // Being offline is not the photo's fault, so it keeps its attempts.
          await _repository.release(item.id);
          return SyncOutcome.retryLater;
        } on FileMissingFailure {
          await _repository.markAttemptFailed(item.id, exhausted: true);
        } on LowBandwidthFailure {
          // Transient, so never terminal. Attempts are shown as n/5; after the
          // fifth the item goes back to waiting with a fresh counter and the
          // caller's growing backoff spaces the next round out.
          if (item.attempts + 1 >= maxAttempts) {
            await _repository.release(item.id, resetAttempts: true);
          } else {
            await _repository.markAttemptFailed(item.id, exhausted: false);
          }
          retryLater = true;
        } on Failure {
          if (await _failAttempt(item.id, item.attempts)) retryLater = true;
        } catch (_) {
          // Unexpected error: do not leave the row stuck in "uploading" and do
          // not abort the rest of the queue.
          if (await _failAttempt(item.id, item.attempts)) retryLater = true;
        }
      }
    }

    // Rows still "uploading" belong to another isolate or to a process that
    // died; they are released once stale, so come back to check on them.
    if (await _repository.hasUploading()) retryLater = true;

    return retryLater ? SyncOutcome.retryLater : SyncOutcome.complete;
  }

  /// Returns true when the item will be retried.
  Future<bool> _failAttempt(String id, int attempts) async {
    final exhausted = attempts + 1 >= maxAttempts;
    await _repository.markAttemptFailed(id, exhausted: exhausted);
    return !exhausted;
  }
}
