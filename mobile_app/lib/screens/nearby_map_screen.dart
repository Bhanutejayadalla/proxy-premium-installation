import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import 'user_detail_screen.dart';

/// Map-like view showing nearby users as positioned dots.
/// A real Google Maps integration would use google_maps_flutter.
/// This provides a visual radar-style overlay for now.
class NearbyMapScreen extends StatelessWidget {
  const NearbyMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final users = state.nearbyUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Map"),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.list),
            tooltip: "List View",
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: users.isEmpty
          ? const Center(child: Text("No nearby users found.\nTry scanning first."))
          : LayoutBuilder(
              builder: (context, constraints) {
                final centerX = constraints.maxWidth / 2;
                final centerY = constraints.maxHeight / 2;
                final maxRadius = centerX * 0.85;

                return Stack(
                  children: [
                    // Radar rings
                    ..._buildRadarRings(centerX, centerY, maxRadius),

                    // Center dot (you)
                    Positioned(
                      left: centerX - 8,
                      top: centerY - 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2)
                          ],
                        ),
                      ),
                    ),

                    // User dots
                    ...users.asMap().entries.map((entry) {
                      final i = entry.key;
                      final user = entry.value;
                      final dist = user.distanceKm ?? 5.0;
                      final maxDist = users
                          .map((u) => u.distanceKm ?? 10)
                          .reduce((a, b) => a > b ? a : b);
                      final normalized = (dist / maxDist).clamp(0.1, 1.0);
                      final angle = (i * 2.39996) + 0.5; // golden angle spread
                      final r = normalized * maxRadius;
                      final x = centerX + r * _cos(angle) - 20;
                      final y = centerY + r * _sin(angle) - 20;

                      return Positioned(
                        left: x,
                        top: y,
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    UserDetailScreen(user: user)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage:
                                    user.getAvatar(state.isFormal).isNotEmpty
                                        ? NetworkImage(
                                            user.getAvatar(state.isFormal))
                                        : null,
                                child:
                                    user.getAvatar(state.isFormal).isEmpty
                                        ? Text(user.username[0].toUpperCase())
                                        : null,
                              ),
                              Text(
                                user.username,
                                style: const TextStyle(fontSize: 9),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (dist > 0)
                                Text("${dist.toStringAsFixed(1)}km",
                                    style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Label
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text("${users.length} people nearby",
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  List<Widget> _buildRadarRings(
      double cx, double cy, double maxR) {
    return [0.33, 0.66, 1.0].map((f) {
      final r = maxR * f;
      return Positioned(
        left: cx - r,
        top: cy - r,
        child: Container(
          width: r * 2,
          height: r * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.blue.withValues(alpha: 0.1), width: 1),
          ),
        ),
      );
    }).toList();
  }

  double _cos(double radians) => _cosTable(radians);
  double _sin(double radians) => _sinTable(radians);

  static double _cosTable(double r) {
    // Simple cos using dart:math import workaround
    return _mathCos(r);
  }

  static double _sinTable(double r) {
    return _mathSin(r);
  }

  static double _mathCos(double r) {
    // Taylor series cos approximation for simplicity
    // In production, just import dart:math
    double x = r % (2 * 3.14159265);
    double result = 1.0;
    double term = 1.0;
    for (int n = 1; n <= 10; n++) {
      term *= -x * x / ((2 * n - 1) * (2 * n));
      result += term;
    }
    return result;
  }

  static double _mathSin(double r) {
    double x = r % (2 * 3.14159265);
    double result = x;
    double term = x;
    for (int n = 1; n <= 10; n++) {
      term *= -x * x / ((2 * n) * (2 * n + 1));
      result += term;
    }
    return result;
  }
}
