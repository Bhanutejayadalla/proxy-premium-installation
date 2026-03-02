import 'dart:async';
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

  /// Check if the Bluetooth adapter is on and permissions are granted.
  Future<bool> init() async {
    // Request permissions required for Bluetooth scanning
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    // Check if any critical permission was denied
    if (results[Permission.bluetoothScan]?.isDenied == true ||
        results[Permission.bluetoothConnect]?.isDenied == true ||
        results[Permission.location]?.isDenied == true) {
      return false;
    }

    // Check hardware status
    try {
      final adapterState = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.unknown);
      if (adapterState != BluetoothAdapterState.on) {
        return false;
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  /// Check if the Bluetooth adapter is currently on.
  Future<bool> isBluetoothOn() async {
    try {
      final state = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.unknown);
      return state == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  /// Perform a BLE scan for [duration] seconds and return ALL discovered
  /// devices that meet the RSSI threshold. Accumulates results over the
  /// full scan window instead of just taking the first emission.
  Future<List<ScanResult>> scanAndCollect({
    int minRssi = rssiThreshold,
    int durationSeconds = 8,
  }) async {
    final Map<String, ScanResult> bestResults = {};

    // Stop any previous scan
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    // Start a fresh scan
    final completer = Completer<List<ScanResult>>();

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.rssi >= minRssi) {
          final id = r.device.remoteId.str.toUpperCase();
          // Keep the strongest signal for each device
          if (!bestResults.containsKey(id) || r.rssi > bestResults[id]!.rssi) {
            bestResults[id] = r;
          }
        }
      }
    });

    // Start scan with timeout
    await FlutterBluePlus.startScan(timeout: Duration(seconds: durationSeconds));

    // Wait for scan to complete
    await Future.delayed(Duration(seconds: durationSeconds + 1));

    await sub.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    if (!completer.isCompleted) {
      completer.complete(bestResults.values.toList());
    }

    return bestResults.values.toList();
  }

  /// Legacy stream-based scan (kept for compatibility).
  Stream<List<ScanResult>> scan({int minRssi = rssiThreshold}) {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    return FlutterBluePlus.scanResults.map((results) =>
      results.where((r) => r.rssi >= minRssi).toList()
    );
  }

  /// Stop any ongoing scan.
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }
}