import '../../domain/entities/upload_item.dart';
import '../local/app_database.dart';

extension UploadRecordMapper on UploadRecord {
  UploadItem toEntity() => UploadItem(
        id: id,
        batchId: batchId,
        path: path,
        sizeBytes: sizeBytes,
        status: status,
        attempts: attempts,
        progress: progress,
        createdAt: createdAt,
      );
}
