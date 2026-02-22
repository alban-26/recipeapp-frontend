import 'package:flutter/material.dart';

typedef ShowNavigatorFunction = void Function();

class CommonFloatingActionButton extends StatelessWidget {
  final VoidCallback showNavigator;
  final IconData iconData;

  final Color? iconColor;
  final Color? backgroundColor;
  final double? iconSize;

  const CommonFloatingActionButton({
    super.key,
    required this.showNavigator,
    required this.iconData,
    this.iconColor,
    this.backgroundColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton(
      onPressed: showNavigator,

      backgroundColor: backgroundColor ?? colorScheme.primaryContainer,
      foregroundColor: iconColor ?? colorScheme.onPrimaryContainer,

      elevation: 0,
      highlightElevation: 1,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),

      child: Icon(
        iconData,
        size: iconSize ?? 24,
      ),
    );
  }
}
