import 'package:flutter/material.dart';

class ToolIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final String? tooltip;
  final double size;
  final Color activeColor;
  final Color color;

  const ToolIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.tooltip,
    this.size = 24,
    this.activeColor = Colors.blue,
    this.color = const Color(0xFF9AA0A6),
  });

  @override
  Widget build(BuildContext context) {
    final Widget btn = IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: size,
      color: active ? activeColor : color,
      splashRadius: size,
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}


