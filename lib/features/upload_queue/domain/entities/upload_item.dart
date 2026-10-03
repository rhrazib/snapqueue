import 'package:equatable/equatable.dart';

enum UploadStatus { pending, uploading, retrying, synced, failed }

class UploadItem extends Equatable {
  const UploadItem({
    required this.id,
    required this.batchId,
    required this.path,
    required this.sizeBytes,
    required this.status,
    required this.attempts,
    required this.progress,
    required this.createdAt,
  });

  final String id;
  final String batchId;
  final String path;
  final int sizeBytes;
  final UploadStatus status;
  final int attempts;
  final double progress;
  final DateTime createdAt;

  String get fileName => path.split(RegExp(r'[\\/]')).last;

  @override
  List<Object?> get props =>
      [id, batchId, path, sizeBytes, status, attempts, progress, createdAt];
}
