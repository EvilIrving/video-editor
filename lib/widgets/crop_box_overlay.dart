import 'package:flutter/material.dart';

class CropBoxOverlay extends StatefulWidget {
  final Rect cropRect; // 屏幕坐标系中的裁剪框
  final ValueChanged<Rect> onUpdateCropRect;
  final Size videoSize; // 视频在屏幕上的渲染区域尺寸

  const CropBoxOverlay({
    super.key,
    required this.cropRect,
    required this.onUpdateCropRect,
    required this.videoSize,
  });

  @override
  State<CropBoxOverlay> createState() => _CropBoxOverlayState();
}

class _CropBoxOverlayState extends State<CropBoxOverlay> {
  static const double _handleSize = 20.0;  // 更小的手柄尺寸，适配手机端
  static const double _minSize = 40.0;     // 更小的最小裁剪框尺寸

  Rect _current = Rect.zero;
  Offset _startDrag = Offset.zero;
  Rect _initial = Rect.zero;
  _DragMode _mode = _DragMode.none;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _current = widget.cropRect;
  }

  @override
  void didUpdateWidget(covariant CropBoxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cropRect != oldWidget.cropRect) {
      _current = widget.cropRect;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 背景手势检测器 - 只处理整体移动
        Positioned.fill(
          child: GestureDetector(
            onPanStart: _onBackgroundPanStart,
            onPanUpdate: _onBackgroundPanUpdate,
            onPanEnd: _onBackgroundPanEnd,
            child: CustomPaint(
              painter: _CropBoxPainter(_current, _isDragging),
            ),
          ),
        ),
        
        // 手柄（可开关显示）
        if (mounted) ...[
          _buildCornerHandle(_DragMode.topLeft, Alignment.topLeft),
          _buildCornerHandle(_DragMode.topRight, Alignment.topRight),
          _buildCornerHandle(_DragMode.bottomLeft, Alignment.bottomLeft),
          _buildCornerHandle(_DragMode.bottomRight, Alignment.bottomRight),
          _buildEdgeHandle(_DragMode.top, Alignment.topCenter),
          _buildEdgeHandle(_DragMode.bottom, Alignment.bottomCenter),
          _buildEdgeHandle(_DragMode.left, Alignment.centerLeft),
          _buildEdgeHandle(_DragMode.right, Alignment.centerRight),
        ],
      ],
    );
  }

  Widget _buildCornerHandle(_DragMode mode, Alignment alignment) {
    return Positioned(
      left: _getHandleLeft(alignment),
      top: _getHandleTop(alignment),
      child: GestureDetector(
        onPanStart: (details) => _onHandlePanStart(details, mode),
        onPanUpdate: _onHandlePanUpdate,
        onPanEnd: _onHandlePanEnd,
        child: Container(
          width: _handleSize,
          height: _handleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue, width: 2.0),
            borderRadius: BorderRadius.circular(4.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getCornerIcon(mode),
            size: 16.0,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeHandle(_DragMode mode, Alignment alignment) {
    return Positioned(
      left: _getHandleLeft(alignment),
      top: _getHandleTop(alignment),
      child: GestureDetector(
        onPanStart: (details) => _onHandlePanStart(details, mode),
        onPanUpdate: _onHandlePanUpdate,
        onPanEnd: _onHandlePanEnd,
        child: Container(
          width: _handleSize,
          height: _handleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue, width: 2.0),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getEdgeIcon(mode),
            size: 16.0,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  double _getHandleLeft(Alignment alignment) {
    switch (alignment) {
      case Alignment.topLeft:
      case Alignment.centerLeft:
      case Alignment.bottomLeft:
        return _current.left - _handleSize / 2;
      case Alignment.topCenter:
      case Alignment.bottomCenter:
        return _current.left + _current.width / 2 - _handleSize / 2;
      case Alignment.topRight:
      case Alignment.centerRight:
      case Alignment.bottomRight:
        return _current.right - _handleSize / 2;
      default:
        return 0;
    }
  }

  double _getHandleTop(Alignment alignment) {
    switch (alignment) {
      case Alignment.topLeft:
      case Alignment.topCenter:
      case Alignment.topRight:
        return _current.top - _handleSize / 2;
      case Alignment.centerLeft:
      case Alignment.centerRight:
        return _current.top + _current.height / 2 - _handleSize / 2;
      case Alignment.bottomLeft:
      case Alignment.bottomCenter:
      case Alignment.bottomRight:
        return _current.bottom - _handleSize / 2;
      default:
        return 0;
    }
  }

  IconData _getCornerIcon(_DragMode mode) {
    switch (mode) {
      case _DragMode.topLeft:
        return Icons.north_west;
      case _DragMode.topRight:
        return Icons.north_east;
      case _DragMode.bottomLeft:
        return Icons.south_west;
      case _DragMode.bottomRight:
        return Icons.south_east;
      default:
        return Icons.crop_free;
    }
  }

  IconData _getEdgeIcon(_DragMode mode) {
    switch (mode) {
      case _DragMode.top:
        return Icons.north;
      case _DragMode.bottom:
        return Icons.south;
      case _DragMode.left:
        return Icons.west;
      case _DragMode.right:
        return Icons.east;
      default:
        return Icons.crop_free;
    }
  }

  // 背景手势处理 - 整体移动
  void _onBackgroundPanStart(DragStartDetails details) {
    if (!_current.contains(details.localPosition)) return;
    
    _startDrag = details.localPosition;
    _initial = _current;
    _mode = _DragMode.move;
    setState(() {
      _isDragging = true;
    });
  }

  void _onBackgroundPanUpdate(DragUpdateDetails details) {
    if (_mode != _DragMode.move) return;
    
    final Offset delta = details.localPosition - _startDrag;
    _updateCropRect(delta);
  }

  void _onBackgroundPanEnd(DragEndDetails details) {
    if (_mode != _DragMode.move) return;
    
    _mode = _DragMode.none;
    setState(() {
      _isDragging = false;
    });
    widget.onUpdateCropRect(_current);
  }

  // 手柄手势处理
  void _onHandlePanStart(DragStartDetails details, _DragMode mode) {
    _startDrag = details.localPosition;
    _initial = _current;
    _mode = mode;
    setState(() {
      _isDragging = true;
    });
  }

  void _onHandlePanUpdate(DragUpdateDetails details) {
    final Offset delta = details.localPosition - _startDrag;
    _updateCropRect(delta);
  }

  void _onHandlePanEnd(DragEndDetails details) {
    _mode = _DragMode.none;
    setState(() {
      _isDragging = false;
    });
    widget.onUpdateCropRect(_current);
  }

  void _updateCropRect(Offset delta) {
    if (!mounted) return;
    
    setState(() {
      double newLeft = _initial.left;
      double newTop = _initial.top;
      double newWidth = _initial.width;
      double newHeight = _initial.height;

      switch (_mode) {
        case _DragMode.move:
          newLeft = _initial.left + delta.dx;
          newTop = _initial.top + delta.dy;
          break;
        case _DragMode.topLeft:
          newLeft = _initial.left + delta.dx;
          newTop = _initial.top + delta.dy;
          newWidth = _initial.width - delta.dx;
          newHeight = _initial.height - delta.dy;
          break;
        case _DragMode.topRight:
          newTop = _initial.top + delta.dy;
          newWidth = _initial.width + delta.dx;
          newHeight = _initial.height - delta.dy;
          break;
        case _DragMode.bottomLeft:
          newLeft = _initial.left + delta.dx;
          newWidth = _initial.width - delta.dx;
          newHeight = _initial.height + delta.dy;
          break;
        case _DragMode.bottomRight:
          newWidth = _initial.width + delta.dx;
          newHeight = _initial.height + delta.dy;
          break;
        case _DragMode.top:
          newTop = _initial.top + delta.dy;
          newHeight = _initial.height - delta.dy;
          break;
        case _DragMode.bottom:
          newHeight = _initial.height + delta.dy;
          break;
        case _DragMode.left:
          newLeft = _initial.left + delta.dx;
          newWidth = _initial.width - delta.dx;
          break;
        case _DragMode.right:
          newWidth = _initial.width + delta.dx;
          break;
        case _DragMode.none:
          break;
      }

      // 应用边界和尺寸限制
      newWidth = newWidth.clamp(_minSize, widget.videoSize.width);
      newHeight = newHeight.clamp(_minSize, widget.videoSize.height);
      
      newLeft = newLeft.clamp(0.0, widget.videoSize.width - newWidth);
      newTop = newTop.clamp(0.0, widget.videoSize.height - newHeight);

      _current = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
    });
  }
}

enum _DragMode { none, move, topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right }

class _CropBoxPainter extends CustomPainter {
  final Rect cropRect;
  final bool isDragging;

  _CropBoxPainter(this.cropRect, this.isDragging);

  @override
  void paint(Canvas canvas, Size size) {
    // 半透明遮罩
    final Paint maskPaint = Paint()..color = Colors.black.withOpacity(0.6);

    // 绘制外部遮罩区域
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), maskPaint);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.bottom, size.width, size.height - cropRect.bottom), maskPaint);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height), maskPaint);
    canvas.drawRect(Rect.fromLTWH(cropRect.right, cropRect.top, size.width - cropRect.right, cropRect.height), maskPaint);

    // 裁剪框边框
    final Paint borderPaint = Paint()
      ..color = isDragging ? Colors.blue : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDragging ? 3.0 : 2.0;
    
    canvas.drawRect(cropRect, borderPaint);

    // 九宫格网格线（仅在拖拽时显示）
    if (isDragging) {
      final Paint gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // 垂直网格线
      final double thirdWidth = cropRect.width / 3;
      canvas.drawLine(
        Offset(cropRect.left + thirdWidth, cropRect.top),
        Offset(cropRect.left + thirdWidth, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left + thirdWidth * 2, cropRect.top),
        Offset(cropRect.left + thirdWidth * 2, cropRect.bottom),
        gridPaint,
      );

      // 水平网格线
      final double thirdHeight = cropRect.height / 3;
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdHeight),
        Offset(cropRect.right, cropRect.top + thirdHeight),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdHeight * 2),
        Offset(cropRect.right, cropRect.top + thirdHeight * 2),
        gridPaint,
      );
    }

    // 裁剪框内部轻微高亮（拖拽时）
    if (isDragging) {
      final Paint highlightPaint = Paint()..color = Colors.blue.withOpacity(0.1);
      canvas.drawRect(cropRect, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropBoxPainter oldDelegate) => 
      oldDelegate.cropRect != cropRect || oldDelegate.isDragging != isDragging;
}


