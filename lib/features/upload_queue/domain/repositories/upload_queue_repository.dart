import '../entities/upload_item.dart';

abstract interface class UploadQueueRepository {
  Stream<List<UploadItem>> watchQueue();

  /// Items waiting for their (next) upload attempt, oldest first.
  Future<List<UploadItem>> uploadable();

  /// Moves the photos into app storage and queues them as one batch.
  Future<void> enqueueBatch(List<String> photoPaths);

  /// Atomically takes ownership of an item. False if someone else has it.
  Future<bool> claim(String id);

  Future<void> reportProgress(String id, double progress);
  Future<void> markSynced(String id);
  Future<void> markAttemptFailed(String id, {required bool exhausted});

  /// Returns an item to the queue without counting an attempt.
  /// [resetAttempts] starts a fresh round of retries.
  Future<void> release(String id, {bool resetAttempts = false});

  /// Frees items left "uploading" by a process that died mid-upload.
  Future<void> releaseStale();

  /// True while some item is claimed by an uploader.
  Future<bool> hasUploading();

  Future<void> retryFailed();
  Future<void> clearSynced();
}
