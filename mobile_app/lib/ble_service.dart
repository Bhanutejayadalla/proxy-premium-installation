import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  /// Maximum RSSI threshold — devices weaker than this are ignored.
  /// -80 dBm ≈ ~30-50 meters in open space (BLE practical range).
  static const int rssiThreshold = -80;

  /// Approximate distance (meters) from RSSI using log-distance model.
  /// txPower = -59 dBm (typical at 1 meter), n = 2.0 (path-loss exponent).
  static double estimateDistanceMeters(int rssi, {int txPower = -59, double n = 2.0}) {
    if (rssi == 0) return -1;
    return pow(10, (txPower - rssi) / (10 * n)).toDouble();
  }

  Future<bool> init() async {
    // Request permissions required for Bluetooth scanning
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    // Check hardware status
    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
      return false;
    }
    return true;
  }

  /// Scan for BLE devices and return results filtered by RSSI proximity.
  Stream<List<ScanResult>> scan({int minRssi = rssiThreshold}) {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    return FlutterBluePlus.scanResults.map((results) =>
      results.where((r) => r.rssi >= minRssi).toList()
    );
  }
}