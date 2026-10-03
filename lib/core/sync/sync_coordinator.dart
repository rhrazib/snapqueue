import 'dart:async';
import 'dart:math' as math;

import '../../features/upload_queue/domain/usecases/sync_upload_queue.dart';
import '../network/network_info.dart';

/// Keeps the queue moving while the app is open: syncs when connectivity
/// comes back and retries with a growing delay after a failure. WorkManager
/// covers the app-closed case.
class SyncCoordinator {
  SyncCoordinator(this._syncQueue, this._network);

  static const _baseDelay = Duration(seconds: 20);
  static const _maxDelay = Duration(minutes: 5);

  final SyncUploadQueue _syncQueue;
  final NetworkInfo _network;

  StreamSubscription<bool>? _subscription;
  Timer? _retryTimer;
  bool _running = false;

  /// Set when a sync is requested while one is already running.
  bool _rerun = false;
  int _retryCount = 0;

  void start() {
    _subscription = _network.onStatusChange.listen((online) {
      if (online) {
        _retryCount = 0;
        kick();
      } else {
        _retryTimer?.cancel();
      }
    });
    kick();
  }

  Future<void> kick() async {
    if (_running) {
      // New work may have arrived after the running pass read the queue.
      _rerun = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerun = false;
        _retryTimer?.cancel();

        // Offline: nothing to do. The connectivity stream calls kick() when
        // the network is back, so there is no need to poll.
        if (!await _network.isOnline) break;

        final outcome = await _syncQueue();
        if (outcome == SyncOutcome.retryLater) {
          _scheduleRetry();
        } else {
          _retryCount = 0;
        }
      } while (_rerun);
    } catch (_) {
      _scheduleRetry();
    } finally {
      _running = false;
    }
  }

  void _scheduleRetry() {
    final seconds = math.min(
      _maxDelay.inSeconds,
      _baseDelay.inSeconds * (1 << math.min(_retryCount, 4)),
    );
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), kick);
  }

  void dispose() {
    _subscription?.cancel();
    _retryTimer?.cancel();
  }
}
