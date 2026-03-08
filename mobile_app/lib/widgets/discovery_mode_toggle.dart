import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum DiscoveryMode { ble, gps }

class DiscoveryModeToggle extends StatelessWidget {
  final DiscoveryMode current;
  final ValueChanged<DiscoveryMode> onChanged;

  const DiscoveryModeToggle({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChoiceChip(
          avatar: const Icon(LucideIcons.bluetooth, size: 16),
          label: const Text("BLE Radar"),
          selected: current == DiscoveryMode.ble,
          onSelected: (_) => onChanged(DiscoveryMode.ble),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          avatar: const Icon(LucideIcons.mapPin, size: 16),
          label: const Text("GPS"),
          selected: current == DiscoveryMode.gps,
          onSelected: (_) => onChanged(DiscoveryMode.gps),
        ),
      ],
    );
  }
}
