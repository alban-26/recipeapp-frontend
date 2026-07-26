import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// M3-Toggle: hält den Bildschirm an, solange aktiv.
class WakelockToggle extends StatefulWidget {
  const WakelockToggle({
    super.key,
    this.onAppBar = false,
  });

  final bool onAppBar;

  @override
  State<WakelockToggle> createState() => _WakelockToggleState();
}

class _WakelockToggleState extends State<WakelockToggle> {
  bool _active = false;

  Future<void> _toggle() async {
    final next = !_active;
    await WakelockPlus.toggle(enable: next);
    if (mounted) {
      setState(() => _active = next);
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inactiveColor =
    widget.onAppBar ? Colors.white : Theme.of(context).iconTheme.color;

    final activeColor =
    widget.onAppBar ? Colors.black : Theme.of(context).colorScheme.primary;

    return IconButton(
      isSelected: _active,
      onPressed: _toggle,
      tooltip: _active ? 'Bildschirm bleibt an' : 'Bildschirm aktiv halten',
      icon: Icon(
        Icons.remove_red_eye_outlined,
        color: inactiveColor,
      ),
      selectedIcon: Icon(
        Icons.remove_red_eye,
        color: activeColor,
      ),
    );
  }
}