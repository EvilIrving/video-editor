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
  static const double _handleSize = 24.0;

  Rect _current = Rect.zero;
  Offset _startDrag = Offset.zero;
  Rect _initial = Rect.zero;
  _DragMode _mode = _DragMode.none;

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
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: CustomPaint(
        painter: _CropBoxPainter(_current),
        child: Stack(
          children: [
            Positioned(
              left: _current.left - _handleSize / 2,
              top: _current.top - _handleSize / 2,
              child: _buildHandle(_DragMode.topLeft),
            ),
            Positioned(
              right: widget.videoSize.width - _current.right - _handleSize / 2,
              top: _current.top - _handleSize / 2,
              child: _buildHandle(_DragMode.topRight),
            ),
            Positioned(
              left: _current.left - _handleSize / 2,
              bottom: widget.videoSize.height - _current.bottom - _handleSize / 2,
              child: _buildHandle(_DragMode.bottomLeft),
            ),
            Positioned(
              right: widget.videoSize.width - _current.right - _handleSize / 2,
              bottom: widget.videoSize.height - _current.bottom - _handleSize / 2,
              child: _buildHandle(_DragMode.bottomRight),
            ),
            Positioned(
              left: _current.left + _current.width / 2 - _handleSize / 2,
              top: _current.top - _handleSize / 2,
              child: _buildHandle(_DragMode.top),
            ),
            // bottom handles贴边，确保以裁剪框与画布底边对齐
            Positioned(
              left: _current.left + _current.width / 2 - _handleSize / 2,
              bottom: widget.videoSize.height - _current.bottom - _handleSize / 2,
              child: _buildHandle(_DragMode.bottom),
            ),
            Positioned(
              left: _current.left - _handleSize / 2,
              top: _current.top + _current.height / 2 - _handleSize / 2,
              child: _buildHandle(_DragMode.left),
            ),
            Positioned(
              right: widget.videoSize.width - _current.right - _handleSize / 2,
              top: _current.top + _current.height / 2 - _handleSize / 2,
              child: _buildHandle(_DragMode.right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(_DragMode mode) {
    return GestureDetector(
      onPanStart: (details) {
        _startDrag = details.localPosition;
        _initial = _current;
        _mode = mode;
      },
      onPanUpdate: (details) {
        final Offset delta = details.localPosition - _startDrag;
        _updateCropRect(delta);
      },
      onPanEnd: (_) {
        _mode = _DragMode.none;
        widget.onUpdateCropRect(_current);
      },
      child: Container(
        width: _handleSize,
        height: _handleSize,
        decoration: BoxDecoration(
          color: Colors.yellow.withOpacity(0.7),
          border: Border.all(color: Colors.white, width: 1.5),
          borderRadius: BorderRadius.circular(_handleSize / 2),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    _startDrag = details.localPosition;
    _initial = _current;
    if (_current.contains(_startDrag)) {
      _mode = _DragMode.move;
    } else {
      _mode = _DragMode.move; // 简化：不在手柄上即移动
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final Offset delta = details.localPosition - _startDrag;
    _updateCropRect(delta);
  }

  void _onPanEnd(DragEndDetails details) {
    _mode = _DragMode.none;
    widget.onUpdateCropRect(_current);
  }

  void _updateCropRect(Offset delta) {
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

      newLeft = newLeft.clamp(0.0, widget.videoSize.width - 10.0);
      newTop = newTop.clamp(0.0, widget.videoSize.height - 10.0);
      newWidth = newWidth.clamp(10.0, widget.videoSize.width - newLeft);
      newHeight = newHeight.clamp(10.0, widget.videoSize.height - newTop);

      _current = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);

      _current = Rect.fromLTWH(
        _current.left.clamp(0.0, widget.videoSize.width - _current.width),
        _current.top.clamp(0.0, widget.videoSize.height - _current.height),
        _current.width,
        _current.height,
      );
    });
  }
}

enum _DragMode { none, move, topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right }

class _CropBoxPainter extends CustomPainter {
  final Rect cropRect;

  _CropBoxPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()..color = Colors.black.withOpacity(0.5);

    // 外部遮罩
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), fillPaint);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.bottom, size.width, size.height - cropRect.bottom), fillPaint);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height), fillPaint);
    canvas.drawRect(Rect.fromLTWH(cropRect.right, cropRect.top, size.width - cropRect.right, cropRect.height), fillPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, borderPaint);

    final Paint gridPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 垂直九宫格
    canvas.drawLine(
      Offset(cropRect.left + cropRect.width / 3, cropRect.top),
      Offset(cropRect.left + cropRect.width / 3, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + cropRect.width * 2 / 3, cropRect.top),
      Offset(cropRect.left + cropRect.width * 2 / 3, cropRect.bottom),
      gridPaint,
    );

    // 水平九宫格
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + cropRect.height / 3),
      Offset(cropRect.right, cropRect.top + cropRect.height / 3),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + cropRect.height * 2 / 3),
      Offset(cropRect.right, cropRect.top + cropRect.height * 2 / 3),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropBoxPainter oldDelegate) => oldDelegate.cropRect != cropRect;
}


