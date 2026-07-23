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
    String? ip;
    // Only the device's own IP — no SSID/BSSID, so no location permission is
    // needed (SSID read would require ACCESS_FINE_LOCATION, which we don't want).
    if (results.contains(ConnectivityResult.wifi)) {
      try {
        ip = await NetworkInfo().getWifiIP();
      } catch (_) {}
    }
    return ConnectivitySnapshot(
      wifi: results.contains(ConnectivityResult.wifi),
      mobile: results.contains(ConnectivityResult.mobile),
      bluetooth: results.contains(ConnectivityResult.bluetooth),
      vpn: results.contains(ConnectivityResult.vpn),
      wifiName: null,
      ip: ip,
    );
  }
}
