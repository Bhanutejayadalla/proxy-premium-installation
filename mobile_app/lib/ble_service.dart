import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Represents a Proxi user discovered via BLE advertisement.
class BleDiscoveredUser {
  final String uid;         // Firebase UID extracted from manufacturer data
  final String username;    // Username from scan response (may be empty)
  final String deviceId;    // Device identifier from scan response (may be empty)
  final int rssi;           // Signal strength
  final double distanceM;   // Estimated distance in meters

  BleDiscoveredUser({
    required this.uid,
    this.username = '',
    this.deviceId = '',
    required this.rssi,
    required this.distanceM,
  });

  @override
  String toString() => 'BleDiscoveredUser(uid: ${uid.substring(0, min(8, uid.length))}…, '
      'username: ${username.isNotEmpty ? username : "?"}, '
      'rssi: $rssi, dist: ${distanceM.toStringAsFixed(1)}m)';
}

class BleService {
  /// RSSI threshold — devices weaker than this are ignored.
  /// -90 dBm covers the full 30-50m BLE range reliably.
  static const int rssiThreshold = -90;

  /// Manufacturer company ID used by Proxi (must match native Kotlin code).
  static const int proxiCompanyId = 0xFF01;

  /// Proxi service UUID used for scan-response username data.
  /// Must match PROXI_SERVICE_UUID in MainActivity.kt.
  static const String proxiServiceUuid = '0000ff01-0000-1000-8000-00805f9b34fb';

  // ── Continuous scan state ────────────────────────────────────────────────
  final StreamController<Map<String, BleDiscoveredUser>> _discoveryCtrl =
      StreamController<Map<String, BleDiscoveredUser>>.broadcast();

  /// Stream that emits the current map of discovered users whenever it changes.
  /// Key = uid string, value = BleDiscoveredUser.
  Stream<Map<String, BleDiscoveredUser>> get discoveredUsersStream =>
      _discoveryCtrl.stream;

  final Map<String, BleDiscoveredUser> _discovered = {};
  final Map<String, DateTime> _discoveredAt = {};
  Timer? _scanRestartTimer;
  StreamSubscription<List<ScanResult>>? _continuousScanSub;
  bool _continuousRunning = false;
  bool _scanCycleInProgress = false; // Guard: prevents overlapping scan cycles
  String? _myUid; // Filter our own advertisement out of results

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

    final scanOk = results[Permission.bluetoothScan]?.isGranted == true;
    final connectOk = results[Permission.bluetoothConnect]?.isGranted == true;
    final advertiseOk = results[Permission.bluetoothAdvertise]?.isGranted == true;
    final locationOk = results[Permission.location]?.isGranted == true;
    _log('Permissions — scan: $scanOk, connect: $connectOk, advertise: $advertiseOk, location: $locationOk');

    if (!scanOk || !connectOk) {
      _log('CRITICAL: bluetoothScan or bluetoothConnect denied — cannot scan');
      return false;
    }
    if (!advertiseOk) {
      _log('WARNING: bluetoothAdvertise denied — device will NOT be visible to others');
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

  // ── Continuous scan API ──────────────────────────────────────────────────

  /// Start a continuous BLE scan that:
  /// • Emits updates via [discoveredUsersStream] whenever a new Proxi device
  ///   is found or signal strength changes.
  /// • Restarts the hardware scan every 10 seconds to defeat Android scan
  ///   throttling (Android limits apps to 5 start-scan calls per 30 seconds).
  ///
  /// [myUid] — filter the local device's own advertisement out of results.
  Future<void> startContinuousScan({
    String? myUid,
    int minRssi = rssiThreshold,
  }) async {
    if (_continuousRunning) {
      _log('Continuous scan already running — updating myUid if changed');
      if (myUid != null) _myUid = myUid;
      return;
    }
    _myUid = myUid;
    _discovered.clear();
    _discoveredAt.clear();
    _continuousRunning = true;
    _scanCycleInProgress = false;
    _log('Starting continuous scan (restart every 10s, minRssi: $minRssi)');

    // Run first cycle immediately, then restart on timer.
    await _runScanCycle(minRssi);
    _scanRestartTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_continuousRunning) await _runScanCycle(minRssi);
    });
  }

  /// Stop continuous scanning and release all resources.
  Future<void> stopContinuousScan() async {
    if (!_continuousRunning) return;
    _continuousRunning = false;
    _scanCycleInProgress = false;
    _scanRestartTimer?.cancel();
    _scanRestartTimer = null;
    _continuousScanSub?.cancel();
    _continuousScanSub = null;
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 100));
    _discovered.clear();
    _discoveredAt.clear();
    _log('Continuous scan stopped');
  }

  /// Run one 8-second scan cycle, updating [_discovered] and pushing to the
  /// stream. Called by [startContinuousScan] and its restart timer.
  Future<void> _runScanCycle(int minRssi) async {
    // Guard: skip if a previous cycle is still finishing up.
    if (_scanCycleInProgress) {
      _log('Scan cycle already in progress — skipping overlap');
      return;
    }
    _scanCycleInProgress = true;
    _log('Scan cycle starting…');

    try {
    // Remove devices not seen in the last 30 seconds (out of range).
    final expiry = DateTime.now().subtract(const Duration(seconds: 30));
    final stale = _discoveredAt.entries
        .where((e) => e.value.isBefore(expiry))
        .map((e) => e.key)
        .toList();
    if (stale.isNotEmpty) {
      for (final uid in stale) {
        _discovered.remove(uid);
        _discoveredAt.remove(uid);
      }
      if (!_discoveryCtrl.isClosed) {
        _discoveryCtrl.add(Map.from(_discovered));
      }
      _log('Removed ${stale.length} stale device(s)');
    }

    // Cancel previous listener before restarting hardware scan.
    _continuousScanSub?.cancel();
    _continuousScanSub = null;
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    // Increase delay to 350 ms — older/MIUI devices need longer to release the
    // previous scan before a new one can start without a "start too frequently" error.
    await Future.delayed(const Duration(milliseconds: 350));

    if (!_continuousRunning) { _scanCycleInProgress = false; return; }

    // Subscribe to results BEFORE starting scan to catch early packets.
    _continuousScanSub = FlutterBluePlus.scanResults.listen((results) {
      bool changed = false;
      for (final r in results) {
        if (r.rssi < minRssi) continue;
        final parsed = _parseProxiAdvertisement(r);
        if (parsed == null) continue;
        // Skip our own advertisement.
        if (_myUid != null && parsed.uid.startsWith(_myUid!.substring(0, min(12, _myUid!.length)))) continue;
        final existing = _discovered[parsed.uid];
        if (existing == null || r.rssi > existing.rssi ||
            (parsed.username.isNotEmpty && existing.username.isEmpty)) {
          _discovered[parsed.uid] = parsed;
          _discoveredAt[parsed.uid] = DateTime.now();
          changed = true;
          _log('  → Discovered: ${parsed.uid.substring(0, min(8, parsed.uid.length))}… '
              'username="${parsed.username}" rssi=${parsed.rssi} dist=${parsed.distanceM.toStringAsFixed(1)}m');
        }
      }
      if (changed && !_discoveryCtrl.isClosed) {
        _discoveryCtrl.add(Map.from(_discovered));
      }
    }, onError: (e) { _log('Scan stream error: $e'); });

    // Try LOW_LATENCY first; fall back to BALANCED on devices that reject it
    // (common on battery-saver MIUI / OxygenOS builds and older chipsets).
    bool scanStarted = false;
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidUsesFineLocation: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
      scanStarted = true;
      _log('Scan cycle started — LOW_LATENCY, 8s window');
    } catch (e) {
      _log('startScan (lowLatency) failed: $e — retrying with BALANCED mode');
    }
    if (!scanStarted && _continuousRunning) {
      // Brief pause so the OS can release any held scan lock.
      await Future.delayed(const Duration(milliseconds: 600));
      try {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 8),
          androidUsesFineLocation: true,
          androidScanMode: AndroidScanMode.balanced,
        );
        _log('Scan cycle started — BALANCED (fallback), 8s window');
      } catch (e2) {
        _log('startScan (balanced) also failed: $e2');
      }
    }
    } finally {
      _scanCycleInProgress = false;
    }
  }

  /// Parse a BLE advertisement and extract Proxi user data.
  /// Returns null if this is not a Proxi advertisement.
  ///
  /// Manufacturer data (company ID 0xFF01): UID bytes (up to 20 chars).
  /// Service data (UUID 0000ff01-...): username bytes (up to 12 chars).
  BleDiscoveredUser? _parseProxiAdvertisement(ScanResult result) {
    final mfData = result.advertisementData.manufacturerData;
    final serviceData = result.advertisementData.serviceData;
    final deviceMac = result.device.remoteId.str;

    // Must have our manufacturer data to be a Proxi device.
    if (!mfData.containsKey(proxiCompanyId)) return null;

    final uidBytes = mfData[proxiCompanyId]!;
    if (uidBytes.isEmpty) {
      _log('  ✓ Proxi device $deviceMac: empty UID bytes');
      return null;
    }

    String uid;
    try {
      uid = utf8.decode(uidBytes).trim();
    } catch (e) {
      _log('  ✗ UID decode failed for $deviceMac: $e');
      return null;
    }

    // Extract username from scan response service data (if present).
    String username = '';
    String deviceId = '';
    final proxiUuid = Guid(proxiServiceUuid);
    if (serviceData.containsKey(proxiUuid)) {
      final sdBytes = serviceData[proxiUuid]!;
      // Format: username\x00deviceId  (null-delimited, username max 8 bytes, deviceId max 4 bytes)
      try {
        final decoded = utf8.decode(sdBytes).trim();
        final parts = decoded.split('\x00');
        username = parts.isNotEmpty ? parts[0] : '';
        deviceId = parts.length > 1 ? parts[1] : deviceMac;
      } catch (_) {
        deviceId = deviceMac;
      }
    } else {
      // Fall back to device MAC as identifier when no scan response.
      deviceId = deviceMac;
    }

    final dist = estimateDistanceMeters(result.rssi);
    _log('  ✓ Proxi: uid=${uid.substring(0, min(8, uid.length))}… '
        'user="${username.isNotEmpty ? username : "?"}" '
        'deviceId=$deviceId rssi=${result.rssi} dist=${dist.toStringAsFixed(1)}m');

    return BleDiscoveredUser(
      uid: uid,
      username: username,
      deviceId: deviceId,
      rssi: result.rssi,
      distanceM: dist,
    );
  }

  /// One-shot scan (kept for compatibility with existing call sites).
  /// Prefer [startContinuousScan] for the Nearby screen.
  Future<List<BleDiscoveredUser>> scanForProxiUsers({
    int minRssi = rssiThreshold,
    int durationSeconds = 8,
  }) async {
    _log('One-shot Proxi scan (${durationSeconds}s, minRssi: $minRssi)');
    final Map<String, BleDiscoveredUser> found = {};

    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 400));

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.rssi < minRssi) continue;
        final parsed = _parseProxiAdvertisement(r);
        if (parsed == null) continue;
        if (!found.containsKey(parsed.uid) || r.rssi > found[parsed.uid]!.rssi) {
          found[parsed.uid] = parsed;
        }
      }
    }, onError: (e) { _log('Scan error: $e'); });

    try {
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: durationSeconds),
        androidUsesFineLocation: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      _log('startScan failed: $e');
      await sub.cancel();
      return [];
    }

    await Future.delayed(Duration(seconds: durationSeconds + 1));
    await sub.cancel();
    try { await FlutterBluePlus.stopScan(); } catch (_) {}

    final sorted = found.values.toList()
      ..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    _log('One-shot scan complete: ${sorted.length} Proxi users found');
    return sorted;
  }

  /// Perform a general BLE scan — returns all visible devices for diagnostics.
  Future<List<ScanResult>> scanAndCollect({
    int minRssi = rssiThreshold,
    int durationSeconds = 5,
  }) async {
    final Map<String, ScanResult> best = {};
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.rssi >= minRssi) {
          final id = r.device.remoteId.str.toUpperCase();
          if (!best.containsKey(id) || r.rssi > best[id]!.rssi) best[id] = r;
        }
      }
    }, onError: (_) {});

    try {
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: durationSeconds),
        androidUsesFineLocation: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      await sub.cancel();
      return [];
    }

    await Future.delayed(Duration(seconds: durationSeconds + 1));
    await sub.cancel();
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    return best.values.toList();
  }

  /// Stop any ongoing scan.
  Future<void> stopScan() async {
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
  }

  /// Legacy stream-based scan (kept for compatibility).
  Stream<List<ScanResult>> scan({int minRssi = rssiThreshold}) {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    return FlutterBluePlus.scanResults.map((results) =>
      results.where((r) => r.rssi >= minRssi).toList()
    );
  }
}
