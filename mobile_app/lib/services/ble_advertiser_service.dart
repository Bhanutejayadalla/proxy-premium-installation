import 'package:flutter/services.dart';

/// Dart wrapper for native Android BLE advertising via MethodChannel.
///
/// Each Proxi user advertises a custom service UUID + their UID so
/// other Proxi phones can discover them offline via BLE scan.
class BleAdvertiserService {
  static const _channel = MethodChannel('com.proxi.ble_advertiser');

  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  /// Check if this device supports BLE advertising (peripheral mode).
  Future<bool> isSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAdvertisingSupported');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Start advertising the current user's UID via BLE.
  /// Other Proxi phones scanning nearby will pick this up.
  Future<bool> startAdvertising(String uid) async {
    if (_isAdvertising) return true;
    try {
      final result = await _channel.invokeMethod<bool>(
        'startAdvertising',
        {'uid': uid},
      );
      _isAdvertising = result ?? false;
      return _isAdvertising;
    } on PlatformException catch (e) {
      _isAdvertising = false;
      throw Exception('BLE advertising failed: ${e.message}');
    }
  }

  /// Stop BLE advertising.
  Future<void> stopAdvertising() async {
    try {
      await _channel.invokeMethod('stopAdvertising');
    } catch (_) {
      // Ignore errors during stop
    }
    _isAdvertising = false;
  }
}
