import 'dart:io';
import 'dart:math';

import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/upload_item.dart';
import '../../domain/repositories/upload_gateway.dart';

/// Stand-in for the real backend (none was provided for the assessment).
/// Refuses when offline and randomly drops some uploads half way, to
/// exercise the retry logic the way a weak connection would.
class MockUploadGateway implements UploadGateway {
  MockUploadGateway(this._network, {this.failureRate = 0.3, Random? random})
      : _random = random ?? Random();

  final NetworkInfo _network;
  final double failureRate;
  final Random _random;

  @override
  Future<void> upload(
    UploadItem item, {
    required void Function(double progress) onProgress,
  }) async {
    if (!File(item.path).existsSync()) throw const FileMissingFailure();
    if (!await _network.isOnline) throw const NoInternetFailure();

    final shouldFail = _random.nextDouble() < failureRate;
    final failAtStep = 3 + _random.nextInt(6);

    for (var step = 1; step <= 10; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (shouldFail && step == failAtStep) throw const LowBandwidthFailure();
      onProgress(step / 10);
    }
  }
}

// ---------------------------------------------------------------------------
// Real implementation, to enable once a backend exists (needs `http` in
// pubspec). Same contract: map transport errors to Failures.
//
// class HttpUploadGateway implements UploadGateway {
//   HttpUploadGateway(this._client, this._baseUrl);
//   final http.Client _client;
//   final String _baseUrl;
//
//   @override
//   Future<void> upload(UploadItem item,
//       {required void Function(double) onProgress}) async {
//     final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/upload'))
//       ..files.add(await http.MultipartFile.fromPath('image', item.path));
//     try {
//       final response =
//           await _client.send(request).timeout(const Duration(seconds: 30));
//       if (response.statusCode >= 500) throw const LowBandwidthFailure();
//       onProgress(1);
//     } on SocketException {
//       throw const NoInternetFailure();
//     } on TimeoutException {
//       throw const LowBandwidthFailure();
//     }
//   }
// }
// ---------------------------------------------------------------------------
