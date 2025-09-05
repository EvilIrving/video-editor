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
    final Widget btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Padding(
          padding: EdgeInsets.all(size / 4),
          child: Icon(
            icon,
            size: size,
            color: active ? activeColor : color,
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}


