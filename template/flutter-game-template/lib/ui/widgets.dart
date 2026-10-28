import 'package:flutter/material.dart';

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 18, color: color),
    label: Text(label),
  );
}

class MenuButton extends StatelessWidget {
  const MenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge = false,
    this.primary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool badge;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = primary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return SizedBox(
      width: 260,
      height: 52,
      child: Badge(isLabelVisible: badge, smallSize: 12, child: child),
    );
  }
}
