import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/failures.dart';
import '../../domain/entities/upload_item.dart';
import '../../domain/repositories/upload_queue_repository.dart';
import '../local/app_database.dart';
import '../local/photo_storage.dart';
import '../local/upload_local_data_source.dart';
import '../mappers/upload_record_mapper.dart';

class UploadQueueRepositoryImpl implements UploadQueueRepository {
  UploadQueueRepositoryImpl(this._local, this._storage);

  final UploadLocalDataSource _local;
  final PhotoStorage _storage;

  @override
  Stream<List<UploadItem>> watchQueue() => _local
      .watchAll()
      .map((rows) => rows.map((r) => r.toEntity()).toList());

  @override
  Future<List<UploadItem>> uploadable() async =>
      (await _local.uploadable()).map((r) => r.toEntity()).toList();

  @override
  Future<void> enqueueBatch(List<String> photoPaths) async {
    final now = DateTime.now();
    final batchId = '${now.millisecondsSinceEpoch}';

    var stored = const <StoredPhoto>[];
    try {
      stored = await _storage.moveIntoBatch(batchId, photoPaths);
      await _local.insertAll([
        for (final photo in stored)
          UploadRecordsCompanion.insert(
            id: p.basenameWithoutExtension(photo.path),
            batchId: batchId,
            path: photo.path,
            sizeBytes: photo.sizeBytes,
            status: UploadStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
      ]);
    } catch (_) {
      // Put the photos back so the user can simply try again.
      await _storage.restore(stored);
      throw const StorageFailure();
    }
  }

  @override
  Future<bool> claim(String id) => _local.claim(id);

  @override
  Future<void> reportProgress(String id, double progress) =>
      _local.setProgress(id, progress);

  @override
  Future<void> markSynced(String id) async {
    final path = await _local.pathOf(id);
    await _local.markSynced(id);
    // The photo is on the server now; free the space right away.
    if (path != null) {
      try {
        await _storage.deleteAll([path]);
      } on FileSystemException {
        // the row is already synced, a leftover file is harmless
      }
    }
  }

  @override
  Future<void> markAttemptFailed(String id, {required bool exhausted}) =>
      _local.markAttemptFailed(id, exhausted: exhausted);

  @override
  Future<void> release(String id, {bool resetAttempts = false}) =>
      _local.release(id, resetAttempts: resetAttempts);

  @override
  Future<void> releaseStale() => _local.releaseStale();

  @override
  Future<bool> hasUploading() => _local.hasUploading();

  @override
  Future<void> retryFailed() => _local.retryFailed();

  @override
  Future<void> clearSynced() async {
    final paths = await _local.deleteSynced();
    await _storage.deleteAll(paths);
  }
}
