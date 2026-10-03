import '../../../../core/error/failures.dart';
import '../repositories/upload_queue_repository.dart';
import '../services/sync_scheduler.dart';

class EnqueueBatch {
  const EnqueueBatch(this._repository, this._scheduler);

  final UploadQueueRepository _repository;
  final SyncScheduler _scheduler;

  Future<void> call(List<String> photoPaths) async {
    if (photoPaths.isEmpty) throw const EmptyBatchFailure();
    await _repository.enqueueBatch(photoPaths);
    await _scheduler.requestSync();
  }
}
