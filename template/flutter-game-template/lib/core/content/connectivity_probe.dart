import 'package:connectivity_plus/connectivity_plus.dart';

import '../../engine/engine.dart';

/// Which kind of connection the device has now. The only file that imports `connectivity_plus`.
abstract interface class ConnectivityProbe {
  Future<ConnectionKind> current();
}

class PluginConnectivityProbe implements ConnectivityProbe {
  @override
  Future<ConnectionKind> current() async {
    try {
      final r = await Connectivity().checkConnectivity();
      if (r.contains(ConnectivityResult.wifi) ||
          r.contains(ConnectivityResult.ethernet)) {
        return ConnectionKind.wifi;
      }
      if (r.contains(ConnectivityResult.mobile) ||
          r.contains(ConnectivityResult.vpn) ||
          r.contains(ConnectivityResult.other)) {
        return ConnectionKind.mobile;
      }
      return ConnectionKind.offline;
    } on Object {
      return ConnectionKind.mobile; // unknown: take the careful path
    }
  }
}

/// Fixed answer for tests.
class FakeConnectivityProbe implements ConnectivityProbe {
  FakeConnectivityProbe([this.kind = ConnectionKind.wifi]);
  ConnectionKind kind;
  @override
  Future<ConnectionKind> current() async => kind;
}
