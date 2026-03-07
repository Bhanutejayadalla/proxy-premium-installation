import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Represents a Proxi user discovered via BLE advertisement.
class BleDiscoveredUser {
  final String uid;       // Firebase UID extracted from manufacturer data
  final int rssi;         // Signal strength
  final double distanceM; // Estimated distance in meters

  BleDiscoveredUser({
    required this.uid,
    required this.rssi,
    required this.distanceM,
  });

  @override
  String toString() => 'BleDiscoveredUser(uid: ${uid.substring(0, min(8, uid.length))}…, rssi: $rssi, dist: ${distanceM.toStringAsFixed(1)}m)';
}

class BleService {
  /// Maximum RSSI threshold — devices weaker than this are ignored.
  /// -80 dBm ≈ ~30-50 meters in open space (BLE practical range).
  static const int rssiThreshold = -80;

  /// Manufacturer company ID used by Proxi (must match native Kotlin code).
  static const int proxiCompanyId = 0xFF01;

  /// Approximate distance (meters) from RSSI using log-distance model.
  /// txPower = -59 dBm (typical at 1 meter), n = 2.0 (path-loss exponent).
  static double estimateDistanceMeters(int rssi, {int txPower = -59, double n = 2.0}) {
    if (rssi == 0) return -1;
    return pow(10, (txPower - rssi) / (10 * n)).toDouble();
  }

  static void _log(String msg) => debugPrint('[BLE-Scanner] $msg');

  /// Check if the Bluetooth adapter is on and permissions are granted.
  Future<bool> init() async {
    _log('Requesting BLE permissions…');
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    if (results[Permission.bluetoothScan]?.isDenied == true ||
        results[Permission.bluetoothConnect]?.isDenied == true ||
        results[Permission.location]?.isDenied == true) {
      _log('Permissions denied: scan=${results[Permission.bluetoothScan]}, connect=${results[Permission.bluetoothConnect]}, loc=${results[Permission.location]}');
      return false;
    }

    try {
      final adapterState = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.unknown);
      if (adapterState != BluetoothAdapterState.on) {
        _log('Bluetooth adapter not ON (state: $adapterState)');
        return false;
      }
    } catch (e) {
      _log('Adapter state check failed: $e');
      return false;
    }
    _log('BLE init OK — permissions granted, adapter ON');
    return true;
  }

  /// Check if the Bluetooth adapter is currently on.
  Future<bool> isBluetoothOn() async {
    try {
      final state = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.unknown);
      _log('Adapter state: $state');
      return state == BluetoothAdapterState.on;
    } catch (e) {
      _log('isBluetoothOn check failed: $e');
      return false;
    }
  }

  /// Scan for Proxi users specifically — filters BLE advertisements that
  /// contain our custom manufacturer data (company ID 0xFF01 + UID bytes).
  ///
  /// Returns a list of [BleDiscoveredUser] with UID and estimated distance.
  /// This works fully OFFLINE — no internet needed.
  Future<List<BleDiscoveredUser>> scanForProxiUsers({
    int minRssi = rssiThreshold,
    int durationSeconds = 8,
  }) async {
    _log('Starting Proxi scan (duration: ${durationSeconds}s, minRssi: $minRssi)');
    final Map<String, BleDiscoveredUser> discoveredUsers = {};

    // Stop any previous scan cleanly
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    // Small delay to ensure adapter resets between scans
    await Future.delayed(const Duration(milliseconds: 500));

    // Subscribe to results BEFORE starting scan to avoid missing early results
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.rssi < minRssi) continue;

        // Check manufacturer data for Proxi company ID
        final uid = _extractProxiUid(r);
        if (uid != null && uid.isNotEmpty) {
          final distance = estimateDistanceMeters(r.rssi);
          _log('Found Proxi user: uid=${uid.substring(0, min(8, uid.length))}… rssi=${r.rssi} dist=${distance.toStringAsFixed(1)}m');
          // Keep the strongest signal per user
          if (!discoveredUsers.containsKey(uid) ||
              r.rssi > discoveredUsers[uid]!.rssi) {
            discoveredUsers[uid] = BleDiscoveredUser(
              uid: uid,
              rssi: r.rssi,
              distanceM: distance,
            );
          }
        }
      }
    }, onError: (e) { _log('Scan stream error: $e'); });

    // Start scan after listener is active
    try {
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: durationSeconds),
        androidUsesFineLocation: true,
      );
      _log('Scan started successfully');
    } catch (e) {
      _log('startScan failed: $e');
      await sub.cancel();
      return [];
    }

    // Wait for the full scan window + buffer
    await Future.delayed(Duration(seconds: durationSeconds + 1));

    await sub.cancel();
    try { await FlutterBluePlus.stopScan(); } catch (_) {}

    final sorted = discoveredUsers.values.toList()
      ..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    _log('Proxi scan complete: ${sorted.length} users found, ${discoveredUsers.length} unique UIDs');
    return sorted;
  }

  /// Extract a Proxi UID from a scan result's manufacturer data.
  /// Returns null if this is not a Proxi advertisement.
  String? _extractProxiUid(ScanResult result) {
    final mfData = result.advertisementData.manufacturerData;
    if (mfData.isEmpty) return null;

    // Check for our company ID (0xFF01 = 65281)
    if (mfData.containsKey(proxiCompanyId)) {
      final bytes = mfData[proxiCompanyId]!;
      if (bytes.isEmpty) return null;
      try {
        return utf8.decode(bytes).trim();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Perform a general BLE scan (includes all devices, not just Proxi).
  /// Returns total device count for diagnostics.
  Future<List<ScanResult>> scanAndCollect({
    int minRssi = rssiThreshold,
    int durationSeconds = 8,
  }) async {
    final Map<String, ScanResult> bestResults = {};

    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.rssi >= minRssi) {
          final id = r.device.remoteId.str.toUpperCase();
          if (!bestResults.containsKey(id) || r.rssi > bestResults[id]!.rssi) {
            bestResults[id] = r;
          }
        }
      }
    }, onError: (_) { /* ignore scan errors */ });

    try {
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: durationSeconds),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      await sub.cancel();
      return [];
    }

    await Future.delayed(Duration(seconds: durationSeconds + 1));

    await sub.cancel();
    try { await FlutterBluePlus.stopScan(); } catch (_) {}

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
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
  }
}
