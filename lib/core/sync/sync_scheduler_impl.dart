import '../../features/upload_queue/domain/services/sync_scheduler.dart';
import 'background_sync.dart';
import 'sync_coordinator.dart';

class SyncSchedulerImpl implements SyncScheduler {
  SyncSchedulerImpl(this._coordinator);

  final SyncCoordinator _coordinator;

  @override
  Future<void> requestSync() async {
    try {
      await BackgroundSync.scheduleOneOff();
    } catch (_) {
      // The foreground coordinator and the periodic task still cover this.
      // Never let scheduling problems make a successful enqueue look failed.
    }
    _coordinator.kick();
  }
}
