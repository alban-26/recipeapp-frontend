import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// M3-Toggle für die AppBar: hält den Bildschirm an, solange aktiv.
class WakelockToggle extends StatefulWidget {
  const WakelockToggle({super.key});

  @override
  State<WakelockToggle> createState() => _WakelockToggleState();
}

class _WakelockToggleState extends State<WakelockToggle> {
  bool _active = false;

  Future<void> _toggle() async {
    final next = !_active;
    await WakelockPlus.toggle(enable: next);
    if (mounted) setState(() => _active = next);
  }

  @override
  void dispose() {
    // Bildschirm nicht anlassen, wenn man den Screen verlässt
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      isSelected: _active,
      onPressed: _toggle,
      tooltip: _active ? 'Bildschirm bleibt an' : 'Bildschirm aktiv halten',
      icon: const Icon(Icons.lightbulb_outline),
      selectedIcon: const Icon(Icons.lightbulb),
    );
  }
}