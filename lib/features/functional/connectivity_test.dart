import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class ConnectivitySnapshot {
  final bool wifi;
  final bool mobile;
  final bool bluetooth;
  final bool vpn;
  final String? wifiName;
  final String? ip;

  const ConnectivitySnapshot({
    required this.wifi,
    required this.mobile,
    required this.bluetooth,
    required this.vpn,
    this.wifiName,
    this.ip,
  });
}

class ConnectivityTest {
  static Future<ConnectivitySnapshot> read() async {
    final results = await Connectivity().checkConnectivity();
    String? wifiName;
    String? ip;
    if (results.contains(ConnectivityResult.wifi)) {
      try {
        final info = NetworkInfo();
        wifiName = await info.getWifiName();
        ip = await info.getWifiIP();
      } catch (_) {}
    }
    return ConnectivitySnapshot(
      wifi: results.contains(ConnectivityResult.wifi),
      mobile: results.contains(ConnectivityResult.mobile),
      bluetooth: results.contains(ConnectivityResult.bluetooth),
      vpn: results.contains(ConnectivityResult.vpn),
      wifiName: wifiName,
      ip: ip,
    );
  }
}
