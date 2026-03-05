import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Timer? _updateTimer;
  Position? lastPosition;

  /// Check and request location permissions using Geolocator's own API.
  /// Returns true only if permission is granted (or already granted).
  Future<bool> requestPermission() async {
    // Check if location service is enabled first
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Get the current GPS position.
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 15));
      lastPosition = pos;
      return pos;
    } catch (_) {
      // Timeout or error — try last known position as fallback
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          lastPosition = last;
          return last;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Start periodic location updates (30s) — call only when nearby screen is active.
  void startUpdates(Function(double lat, double lng) onUpdate) {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        final pos = await getCurrentPosition();
        if (pos != null) {
          onUpdate(pos.latitude, pos.longitude);
        }
      },
    );
    // Fire immediately too
    getCurrentPosition().then((pos) {
      if (pos != null) onUpdate(pos.latitude, pos.longitude);
    });
  }

  /// Stop periodic updates when leaving screen.
  void stopUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Calculate distance in km between two points (Haversine).
  static double distanceBetween(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }
}
