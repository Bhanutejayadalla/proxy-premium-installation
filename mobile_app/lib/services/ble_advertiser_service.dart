import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper for native Android BLE advertising via MethodChannel.
///
/// Each Proxi user advertises a custom service UUID + their UID so
/// other Proxi phones can discover them offline via BLE scan.
class BleAdvertiserService {
  static const _channel = MethodChannel('com.proxi.ble_advertiser');

  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  static void _log(String msg) => debugPrint('[BLE-Advertiser] $msg');

  /// Check if this device supports BLE advertising (peripheral mode).
  Future<bool> isSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAdvertisingSupported');
      _log('isSupported: ${result ?? false}');
      return result ?? false;
    } catch (e) {
      _log('isSupported check failed: $e');
      return false;
    }
  }

  /// Start advertising the current user's UID via BLE.
  /// Other Proxi phones scanning nearby will pick this up.
  Future<bool> startAdvertising(String uid) async {
    if (_isAdvertising) {
      _log('Already advertising');
      return true;
    }
    try {
      _log('Starting advertising for uid=${uid.substring(0, uid.length > 8 ? 8 : uid.length)}…');
      final result = await _channel.invokeMethod<bool>(
        'startAdvertising',
        {'uid': uid},
      );
      _isAdvertising = result ?? false;
      _log('Advertising ${_isAdvertising ? "STARTED" : "FAILED"}');
      return _isAdvertising;
    } on PlatformException catch (e) {
      _isAdvertising = false;
      _log('Advertising PlatformException: ${e.code} — ${e.message}');
      throw Exception('BLE advertising failed: ${e.message}');
    }
  }

  /// Stop BLE advertising.
  Future<void> stopAdvertising() async {
    _log('Stopping advertising');
    try {
      await _channel.invokeMethod('stopAdvertising');
      _log('Advertising STOPPED');
    } catch (e) {
      _log('stopAdvertising error: $e');
    }
    _isAdvertising = false;
  }
}
