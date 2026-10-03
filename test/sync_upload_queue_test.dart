import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapqueue/core/error/failures.dart';
import 'package:snapqueue/features/upload_queue/domain/entities/upload_item.dart';
import 'package:snapqueue/features/upload_queue/domain/repositories/upload_gateway.dart';
import 'package:snapqueue/features/upload_queue/domain/repositories/upload_queue_repository.dart';
import 'package:snapqueue/features/upload_queue/domain/usecases/sync_upload_queue.dart';

class FakeRepository implements UploadQueueRepository {
  FakeRepository(List<UploadItem> items) : items = {for (final i in items) i.id: i};

  final Map<String, UploadItem> items;

  void _set(String id, {UploadStatus? status, int? attempts, double? progress}) {
    final o = items[id]!;
    items[id] = UploadItem(
      id: o.id,
      batchId: o.batchId,
      path: o.path,
      sizeBytes: o.sizeBytes,
      status: status ?? o.status,
      attempts: attempts ?? o.attempts,
      progress: progress ?? o.progress,
      createdAt: o.createdAt,
    );
  }

  @override
  Future<List<UploadItem>> uploadable() async => items.values
      .where((i) =>
          i.status == UploadStatus.pending || i.status == UploadStatus.retrying)
      .toList();

  @override
  Future<bool> claim(String id) async {
    final s = items[id]!.status;
    if (s != UploadStatus.pending && s != UploadStatus.retrying) return false;
    _set(id, status: UploadStatus.uploading);
    return true;
  }

  @override
  Future<void> markSynced(String id) async =>
      _set(id, status: UploadStatus.synced, progress: 1);

  @override
  Future<void> markAttemptFailed(String id, {required bool exhausted}) async =>
      _set(id,
          status: exhausted ? UploadStatus.failed : UploadStatus.retrying,
          attempts: items[id]!.attempts + 1);

  @override
  Future<void> release(String id, {bool resetAttempts = false}) async => _set(
      id,
      status: UploadStatus.pending,
      attempts: resetAttempts ? 0 : null);

  @override
  Future<void> reportProgress(String id, double progress) async =>
      _set(id, progress: progress);

  @override
  Future<void> releaseStale() async {}

  @override
  Future<bool> hasUploading() async =>
      items.values.any((i) => i.status == UploadStatus.uploading);

  @override
  Stream<List<UploadItem>> watchQueue() => const Stream.empty();

  @override
  Future<void> enqueueBatch(List<String> photoPaths) async {}

  @override
  Future<void> retryFailed() async {}

  @override
  Future<void> clearSynced() async {}
}

class FakeGateway implements UploadGateway {
  FakeGateway(this.behaviour);

  final FutureOr<void> Function(UploadItem item) behaviour;

  @override
  Future<void> upload(UploadItem item,
      {required void Function(double) onProgress}) async {
    await behaviour(item);
    onProgress(1);
  }
}

UploadItem item({
  String id = 'a',
  int attempts = 0,
  UploadStatus status = UploadStatus.pending,
}) =>
    UploadItem(
      id: id,
      batchId: 'b',
      path: '/tmp/$id.jpg',
      sizeBytes: 10,
      status: status,
      attempts: attempts,
      progress: 0,
      createdAt: DateTime(2026),
    );

void main() {
  test('marks the item synced when the upload succeeds', () async {
    final repo = FakeRepository([item()]);
    final outcome = await SyncUploadQueue(repo, FakeGateway((_) {}))();

    expect(repo.items['a']!.status, UploadStatus.synced);
    expect(outcome, SyncOutcome.complete);
  });

  test('low bandwidth keeps the item queued and asks for a retry', () async {
    final repo = FakeRepository([item()]);
    final gateway = FakeGateway((_) => throw const LowBandwidthFailure());
    final outcome = await SyncUploadQueue(repo, gateway)();

    expect(repo.items['a']!.status, UploadStatus.retrying);
    expect(repo.items['a']!.attempts, 1);
    expect(outcome, SyncOutcome.retryLater);
  });

  test('after a full round of low-bandwidth attempts the item starts a new '
      'round instead of failing', () async {
    final repo =
        FakeRepository([item(attempts: SyncUploadQueue.maxAttempts - 1)]);
    final gateway = FakeGateway((_) => throw const LowBandwidthFailure());
    final outcome = await SyncUploadQueue(repo, gateway)();

    expect(repo.items['a']!.status, UploadStatus.pending);
    expect(repo.items['a']!.attempts, 0);
    expect(outcome, SyncOutcome.retryLater);
  });

  test('being offline keeps the attempt count untouched', () async {
    final repo = FakeRepository([item(attempts: 2)]);
    final gateway = FakeGateway((_) => throw const NoInternetFailure());
    final outcome = await SyncUploadQueue(repo, gateway)();

    expect(repo.items['a']!.status, UploadStatus.pending);
    expect(repo.items['a']!.attempts, 2);
    expect(outcome, SyncOutcome.retryLater);
  });

  test('other failures give up after the last allowed attempt', () async {
    final repo =
        FakeRepository([item(attempts: SyncUploadQueue.maxAttempts - 1)]);
    final gateway = FakeGateway((_) => throw const StorageFailure());
    final outcome = await SyncUploadQueue(repo, gateway)();

    expect(repo.items['a']!.status, UploadStatus.failed);
    expect(outcome, SyncOutcome.complete);
  });

  test('a missing file fails immediately', () async {
    final repo = FakeRepository([item()]);
    final gateway = FakeGateway((_) => throw const FileMissingFailure());
    await SyncUploadQueue(repo, gateway)();

    expect(repo.items['a']!.status, UploadStatus.failed);
  });

  test('an unexpected error does not abort the rest of the queue', () async {
    final repo = FakeRepository([item(id: 'a'), item(id: 'b')]);
    final gateway = FakeGateway((i) {
      if (i.id == 'a') throw StateError('boom');
    });
    final outcome = await SyncUploadQueue(repo, gateway)();

    expect(repo.items['a']!.status, UploadStatus.retrying);
    expect(repo.items['b']!.status, UploadStatus.synced);
    expect(outcome, SyncOutcome.retryLater);
  });

  test('items queued while a run is in flight are uploaded in the same run',
      () async {
    final repo = FakeRepository([item(id: 'a')]);
    final gateway = FakeGateway((i) {
      if (i.id == 'a') repo.items['b'] = item(id: 'b');
    });
    final outcome = await SyncUploadQueue(repo, gateway)();

    expect(repo.items['a']!.status, UploadStatus.synced);
    expect(repo.items['b']!.status, UploadStatus.synced);
    expect(outcome, SyncOutcome.complete);
  });

  test('rows still uploading elsewhere make the run ask for a re-check',
      () async {
    final repo = FakeRepository([item(status: UploadStatus.uploading)]);
    final outcome = await SyncUploadQueue(repo, FakeGateway((_) {}))();

    expect(outcome, SyncOutcome.retryLater);
  });
}
