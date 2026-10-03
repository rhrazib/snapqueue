import 'package:drift/drift.dart';

import '../../domain/entities/upload_item.dart';
import 'app_database.dart';

class UploadLocalDataSource {
  UploadLocalDataSource(this._db);

  static const _staleAfter = Duration(minutes: 2);

  final AppDatabase _db;

  Stream<List<UploadRecord>> watchAll() {
    final query = _db.select(_db.uploadRecords)
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return query.watch();
  }

  Future<List<UploadRecord>> uploadable() {
    final query = _db.select(_db.uploadRecords)
      ..where((t) => t.status
          .isInValues(const [UploadStatus.pending, UploadStatus.retrying]))
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return query.get();
  }

  Future<void> insertAll(List<UploadRecordsCompanion> rows) =>
      _db.batch((b) => b.insertAll(_db.uploadRecords, rows));

  Future<bool> claim(String id) async {
    final changed = await (_db.update(_db.uploadRecords)
          ..where((t) =>
              t.id.equals(id) &
              t.status.isInValues(
                  const [UploadStatus.pending, UploadStatus.retrying])))
        .write(UploadRecordsCompanion(
      status: const Value(UploadStatus.uploading),
      progress: const Value(0),
      updatedAt: Value(DateTime.now()),
    ));
    return changed == 1;
  }

  Future<String?> pathOf(String id) async {
    final row = await (_db.select(_db.uploadRecords)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.path;
  }

  Future<bool> hasUploading() async {
    final rows = await (_db.select(_db.uploadRecords)
          ..where((t) => t.status.equalsValue(UploadStatus.uploading))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  Future<void> setProgress(String id, double progress) =>
      (_db.update(_db.uploadRecords)
            ..where((t) =>
                t.id.equals(id) & t.status.equalsValue(UploadStatus.uploading)))
          .write(UploadRecordsCompanion(
        progress: Value(progress),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> markSynced(String id) => (_db.update(_db.uploadRecords)
        ..where((t) => t.id.equals(id)))
      .write(UploadRecordsCompanion(
    status: const Value(UploadStatus.synced),
    progress: const Value(1),
    updatedAt: Value(DateTime.now()),
  ));

  Future<void> markAttemptFailed(String id, {required bool exhausted}) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.uploadRecords)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;

      await (_db.update(_db.uploadRecords)..where((t) => t.id.equals(id)))
          .write(UploadRecordsCompanion(
        status: Value(exhausted ? UploadStatus.failed : UploadStatus.retrying),
        attempts: Value(row.attempts + 1),
        progress: const Value(0),
        updatedAt: Value(DateTime.now()),
      ));
    });
  }

  Future<void> release(String id, {bool resetAttempts = false}) =>
      (_db.update(_db.uploadRecords)..where((t) => t.id.equals(id)))
          .write(UploadRecordsCompanion(
    status: const Value(UploadStatus.pending),
    attempts: resetAttempts ? const Value(0) : const Value.absent(),
    progress: const Value(0),
    updatedAt: Value(DateTime.now()),
  ));

  Future<void> releaseStale() {
    final cutoff = DateTime.now().subtract(_staleAfter);
    return (_db.update(_db.uploadRecords)
          ..where((t) =>
              t.status.equalsValue(UploadStatus.uploading) &
              t.updatedAt.isSmallerThanValue(cutoff)))
        .write(UploadRecordsCompanion(
      status: const Value(UploadStatus.retrying),
      progress: const Value(0),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> retryFailed() => (_db.update(_db.uploadRecords)
        ..where((t) => t.status.equalsValue(UploadStatus.failed)))
      .write(UploadRecordsCompanion(
    status: const Value(UploadStatus.pending),
    attempts: const Value(0),
    updatedAt: Value(DateTime.now()),
  ));

  /// Deletes synced rows and returns their file paths for cleanup.
  Future<List<String>> deleteSynced() {
    return _db.transaction(() async {
      final synced = _db.select(_db.uploadRecords)
        ..where((t) => t.status.equalsValue(UploadStatus.synced));
      final paths = (await synced.get()).map((r) => r.path).toList();
      await (_db.delete(_db.uploadRecords)
            ..where((t) => t.status.equalsValue(UploadStatus.synced)))
          .go();
      return paths;
    });
  }
}
