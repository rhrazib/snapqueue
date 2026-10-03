/// Asks the platform to make sure the queue gets drained soon.
abstract interface class SyncScheduler {
  Future<void> requestSync();
}
