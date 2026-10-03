import '../entities/upload_item.dart';

/// The remote side. Implementations throw a `Failure` on error.
abstract interface class UploadGateway {
  Future<void> upload(
    UploadItem item, {
    required void Function(double progress) onProgress,
  });
}
