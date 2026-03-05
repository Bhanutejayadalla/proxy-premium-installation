import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Routing result from either OSRM (road-based) or Haversine (straight-line).
class RouteResult {
  /// Distance in meters.
  final double distanceMeters;

  /// Duration in seconds (only meaningful for road-based routes).
  final double durationSeconds;

  /// Polyline coordinates to draw on the map.
  /// Empty if straight-line fallback was used.
  final List<LatLng> polyline;

  /// Whether this result came from OSRM (true) or straight-line fallback (false).
  final bool isRoadBased;

  const RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    required this.isRoadBased,
  });

  /// Friendly distance string: "1.2 km" or "850 m"
  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  /// Friendly walking time: "~14 min" (assumes 5 km/h walking speed)
  String get walkingTimeText {
    final minutes = isRoadBased
        ? (durationSeconds / 60).ceil()
        : (distanceMeters / (5000 / 60)).ceil(); // 5 km/h
    if (minutes < 1) return '< 1 min';
    return '~$minutes min walk';
  }
}

/// Free routing service backed by OSRM demo server (OpenStreetMap).
/// Falls back to Haversine straight-line when OSRM is unavailable.
class RoutingService {
  static const _osrmBase = 'https://router.project-osrm.org';

  /// Get a walking route between two points.
  /// Uses OSRM foot profile with fallback to straight-line.
  static Future<RouteResult> getRoute(LatLng from, LatLng to) async {
    try {
      final url = '$_osrmBase/route/v1/foot/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson&steps=false';

      final resp = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 8),
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (json['code'] == 'Ok') {
          final route = (json['routes'] as List).first as Map<String, dynamic>;
          final distance = (route['distance'] as num).toDouble();
          final duration = (route['duration'] as num).toDouble();

          // Parse GeoJSON LineString → List<LatLng>
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coords = geometry['coordinates'] as List;
          final polyline = coords
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();

          return RouteResult(
            distanceMeters: distance,
            durationSeconds: duration,
            polyline: polyline,
            isRoadBased: true,
          );
        }
      }
    } catch (_) {
      // Fall through to straight-line
    }

    // ── Fallback: Haversine straight-line ──
    return _straightLine(from, to);
  }

  /// Haversine straight-line distance.
  static RouteResult _straightLine(LatLng a, LatLng b) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) *
            cos(_rad(b.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final dist = 2 * R * asin(sqrt(h));

    return RouteResult(
      distanceMeters: dist,
      durationSeconds: dist / (5000 / 3600), // 5 km/h walking
      polyline: [a, b], // Just a straight line
      isRoadBased: false,
    );
  }

  static double _rad(double deg) => deg * pi / 180;
}
