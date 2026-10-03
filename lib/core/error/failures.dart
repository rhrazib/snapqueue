/// Failures that cross layer boundaries. Data sources translate platform
/// exceptions into these so the domain and presentation never see them.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => message;
}

class NoInternetFailure extends Failure {
  const NoInternetFailure() : super('No internet connection');
}

class LowBandwidthFailure extends Failure {
  const LowBandwidthFailure() : super('Connection too slow, upload timed out');
}

class FileMissingFailure extends Failure {
  const FileMissingFailure() : super('The photo is no longer on the device');
}

class StorageFailure extends Failure {
  const StorageFailure() : super('Could not write to device storage');
}

class EmptyBatchFailure extends Failure {
  const EmptyBatchFailure() : super('There are no photos in this batch');
}
