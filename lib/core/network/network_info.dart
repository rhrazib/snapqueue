import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class NetworkInfo {
  Future<bool> get isOnline;
  Stream<bool> get onStatusChange;
}

class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasNetwork(List<ConnectivityResult> r) =>
      !r.contains(ConnectivityResult.none);

  @override
  Future<bool> get isOnline async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();
}
