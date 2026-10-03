import '../repositories/upload_queue_repository.dart';

class ClearSyncedUploads {
  const ClearSyncedUploads(this._repository);

  final UploadQueueRepository _repository;

  Future<void> call() => _repository.clearSynced();
}
