import '../repositories/upload_queue_repository.dart';
import '../services/sync_scheduler.dart';

class RetryFailedUploads {
  const RetryFailedUploads(this._repository, this._scheduler);

  final UploadQueueRepository _repository;
  final SyncScheduler _scheduler;

  Future<void> call() async {
    await _repository.retryFailed();
    await _scheduler.requestSync();
  }
}
