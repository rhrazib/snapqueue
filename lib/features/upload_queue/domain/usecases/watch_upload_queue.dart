import '../entities/upload_item.dart';
import '../repositories/upload_queue_repository.dart';

class WatchUploadQueue {
  const WatchUploadQueue(this._repository);

  final UploadQueueRepository _repository;

  Stream<List<UploadItem>> call() => _repository.watchQueue();
}
