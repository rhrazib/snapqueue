import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/entities/upload_item.dart';
import 'upload_records.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [UploadRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  /// `shareAcrossIsolates` lets the WorkManager isolate and the UI isolate
  /// talk to one database server, so `watch()` streams in the UI update when
  /// the background worker writes progress.
  static QueryExecutor _openConnection() => driftDatabase(
        name: 'snapqueue',
        native: const DriftNativeOptions(shareAcrossIsolates: true),
      );
}
