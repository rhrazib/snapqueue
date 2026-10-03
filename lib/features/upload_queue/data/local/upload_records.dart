import 'package:drift/drift.dart';

import '../../domain/entities/upload_item.dart';

@DataClassName('UploadRecord')
class UploadRecords extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text()();
  TextColumn get path => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get status => textEnum<UploadStatus>()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  RealColumn get progress => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
