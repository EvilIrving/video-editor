import 'package:flutter/material.dart';

/// 带有旋转loading状态的通用按钮组件
class LoadingButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double? elevation;
  final TextStyle? textStyle;
  final double iconSize;
  final MainAxisSize mainAxisSize;
  final bool showIconWhenLoading;
  
  const LoadingButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
    this.elevation,
    this.textStyle,
    this.iconSize = 18.0,
    this.mainAxisSize = MainAxisSize.min,
    this.showIconWhenLoading = false,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    if (widget.isLoading) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(LoadingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _animationController.repeat();
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.foregroundColor,
        padding: widget.padding,
        shape: RoundedRectangleBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        ),
        elevation: widget.elevation,
        disabledBackgroundColor: widget.backgroundColor?.withOpacity(0.6),
        disabledForegroundColor: widget.foregroundColor?.withOpacity(0.6),
      ),
      child: Row(
        mainAxisSize: widget.mainAxisSize,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isLoading)
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: Icon(
                    Icons.hourglass_empty,
                    size: widget.iconSize,
                  ),
                );
              },
            )
          else if (widget.icon != null)
            Icon(
              widget.icon,
              size: widget.iconSize,
            ),
          if ((widget.icon != null && !widget.isLoading) || 
              (widget.isLoading && widget.showIconWhenLoading))
            const SizedBox(width: 8),
          Text(
            widget.text,
            style: widget.textStyle,
          ),
        ],
      ),
    );
  }
}

/// 带有旋转loading状态的文本按钮组件
class LoadingTextButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final double iconSize;
  final MainAxisSize mainAxisSize;
  final bool showIconWhenLoading;
  
  const LoadingTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.foregroundColor,
    this.padding,
    this.textStyle,
    this.iconSize = 18.0,
    this.mainAxisSize = MainAxisSize.min,
    this.showIconWhenLoading = false,
  });

  @override
  State<LoadingTextButton> createState() => _LoadingTextButtonState();
}

class _LoadingTextButtonState extends State<LoadingTextButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    if (widget.isLoading) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(LoadingTextButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _animationController.repeat();
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: widget.foregroundColor,
        padding: widget.padding,
        disabledForegroundColor: widget.foregroundColor?.withOpacity(0.6),
      ),
      child: Row(
        mainAxisSize: widget.mainAxisSize,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isLoading)
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: Icon(
                    Icons.hourglass_empty,
                    size: widget.iconSize,
                  ),
                );
              },
            )
          else if (widget.icon != null)
            Icon(
              widget.icon,
              size: widget.iconSize,
            ),
          if ((widget.icon != null && !widget.isLoading) || 
              (widget.isLoading && widget.showIconWhenLoading))
            const SizedBox(width: 8),
          Text(
            widget.text,
            style: widget.textStyle,
          ),
        ],
      ),
    );
  }
}

/// 带有旋转loading状态的工具按钮组件（用于底部工具栏）
class LoadingToolButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isLoading;
  final Color? activeColor;
  final Color? inactiveColor;
  final double iconSize;
  
  const LoadingToolButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isActive = false,
    this.isLoading = false,
    this.activeColor,
    this.inactiveColor,
    this.iconSize = 24.0,
  });

  @override
  State<LoadingToolButton> createState() => _LoadingToolButtonState();
}

class _LoadingToolButtonState extends State<LoadingToolButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    if (widget.isLoading) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(LoadingToolButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _animationController.repeat();
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveActiveColor = widget.activeColor ?? Colors.yellow[600]!;
    final Color effectiveInactiveColor = widget.inactiveColor ?? Colors.grey[400]!;
    final bool isEffectiveActive = widget.isActive || widget.isLoading;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: widget.isLoading ? null : widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: widget.isLoading
                  ? AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value * 2 * 3.14159,
                          child: Icon(
                            Icons.hourglass_empty,
                            color: effectiveActiveColor,
                            size: widget.iconSize,
                          ),
                        );
                      },
                    )
                  : Icon(
                      widget.icon,
                      color: isEffectiveActive ? effectiveActiveColor : effectiveInactiveColor,
                      size: widget.iconSize,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.label,
          style: TextStyle(
            color: isEffectiveActive ? effectiveActiveColor : effectiveInactiveColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
