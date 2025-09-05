import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../widgets/crop_box_overlay.dart';
import 'preview_player_screen.dart';

class VideoEditorScreen extends StatefulWidget {
  final String videoPath;

  const VideoEditorScreen({super.key, required this.videoPath});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _videoPlayerController;

  // 时间轴裁剪
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  List<String> _thumbnailPaths = <String>[];

  // 画布裁剪
  Rect _cropRect = Rect.zero; // 相对原始视频尺寸
  double _videoWidth = 0;
  double _videoHeight = 0;

  bool _isProcessing = false;
  bool _cropEnabled = false;   // 画布裁剪开关
  bool _muteEnabled = false;   // 静音导出
  bool _showRatioButtons = false; // 控制比例按钮展开状态

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_onVideoPlayerUpdate);
    _videoPlayerController?.dispose();
    for (final path in _thumbnailPaths) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _initializeVideoPlayer() async {
    _videoPlayerController = VideoPlayerController.file(File(widget.videoPath));
    await _videoPlayerController!.initialize();
    setState(() {
      _trimEnd = _videoPlayerController!.value.duration;
      _videoWidth = _videoPlayerController!.value.size.width;
      _videoHeight = _videoPlayerController!.value.size.height;
      _cropRect = Rect.fromLTWH(0, 0, _videoWidth, _videoHeight);
    });
    await _videoPlayerController!.setLooping(false);
    
    // 添加播放监听器，用于预览模式的播放控制
    _videoPlayerController!.addListener(_onVideoPlayerUpdate);
    
    // 不自动播放，统一添加播放按钮控制
    await _generateThumbnails();
  }

  // ---- 视频播放监听器 ----
  void _onVideoPlayerUpdate() {
    if (mounted) {
      setState(() {
        // 触发UI更新，让播放按钮图标能够切换
      });
    }
  }

  // ---- 预览播放控制 ----
  Future<void> _togglePreviewPlayback() async {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;

    if (_videoPlayerController!.value.isPlaying) {
      // 当前正在播放，暂停
      await _videoPlayerController!.pause();
    } else {
      // 跳转到裁剪开始时间并播放
      await _videoPlayerController!.seekTo(_trimStart);
      await _videoPlayerController!.play();
    }
  }

  // ---- 计算预览进度 ----
  double _calculatePreviewProgress() { return 0.0; }

  // ---- 时间轴裁剪：缩略图生成 ----
  Future<void> _generateThumbnails() async {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    final Duration videoDuration = _videoPlayerController!.value.duration;
    const int thumbnailCount = 10;
    if (videoDuration.inMilliseconds <= 0) return;
    final int intervalMs = (videoDuration.inMilliseconds ~/ thumbnailCount).clamp(1, 1 << 30);

    final Directory tempDir = await getTemporaryDirectory();
    final List<String> paths = <String>[];

    for (int i = 0; i < thumbnailCount; i++) {
      final Duration seekTime = Duration(milliseconds: i * intervalMs);
      final String outPath = p.join(tempDir.path, 'thumbnail_$i.jpg');
      final String cmd = "-ss ${_formatDuration(seekTime)} -i '${widget.videoPath}' -frames:v 1 -q:v 2 -y '$outPath'";
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        paths.add(outPath);
      }
    }

    if (mounted) {
      setState(() {
        _thumbnailPaths = paths;
      });
    }
  }


  // ---- 画布裁剪 ----
  Widget _buildCropCanvasEditor() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: _videoPlayerController!.value.aspectRatio,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  double actualVideoWidth = constraints.maxWidth;
                  double actualVideoHeight = constraints.maxWidth / _videoPlayerController!.value.aspectRatio;
                  if (actualVideoHeight > constraints.maxHeight) {
                    actualVideoHeight = constraints.maxHeight;
                    actualVideoWidth = constraints.maxHeight * _videoPlayerController!.value.aspectRatio;
                  }

                  final double scaleX = actualVideoWidth / _videoWidth;
                  final double scaleY = actualVideoHeight / _videoHeight;

                  final Rect scaledCropRect = Rect.fromLTWH(
                    _cropRect.left * scaleX,
                    _cropRect.top * scaleY,
                    _cropRect.width * scaleX,
                    _cropRect.height * scaleY,
                  );

                  return Center(
                    child: SizedBox(
                      width: actualVideoWidth,
                      height: actualVideoHeight,
                      child: Stack(
                        children: [
                          if (_cropEnabled)
                            CropBoxOverlay(
                              cropRect: scaledCropRect,
                              onUpdateCropRect: (Rect newScaled) {
                                setState(() {
                                  _cropRect = Rect.fromLTWH(
                                    newScaled.left / scaleX,
                                    newScaled.top / scaleY,
                                    newScaled.width / scaleX,
                                    newScaled.height / scaleY,
                                  );
                                });
                              },
                              videoSize: Size(actualVideoWidth, actualVideoHeight),
                            ),
                          // 左上角尺寸信息（更轻量）
                          if (_cropEnabled)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_cropRect.width.toInt()}×${_cropRect.height.toInt()}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // 悬浮比例按钮 - 仅在画布裁剪模式下显示
              if (_cropEnabled)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: _buildFloatingRatioButtons(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- 悬浮比例按钮 ----
  Widget _buildFloatingRatioButtons() {
    return SizedBox(
      width: 60,
      height: _showRatioButtons ? 300 : 60, // 展开时增加高度
      child: Stack(
        clipBehavior: Clip.none, // 允许子组件超出边界
        alignment: Alignment.bottomCenter,
        children: [
          // 1:1 按钮
          if (_showRatioButtons)
            Positioned(
              bottom: 70,
              child: _buildRatioButton(
                '1:1',
                Icons.crop_square,
                () => _setCropRatio(1.0),
              ),
            ),
          // 4:3 按钮
          if (_showRatioButtons)
            Positioned(
              bottom: 125,
              child: _buildRatioButton(
                '4:3',
                Icons.crop_3_2,
                () => _setCropRatio(4.0 / 3.0),
              ),
            ),
          // 16:9 按钮
          if (_showRatioButtons)
            Positioned(
              bottom: 180,
              child: _buildRatioButton(
                '16:9',
                Icons.crop_16_9,
                () => _setCropRatio(16.0 / 9.0),
              ),
            ),
          // 3:4 按钮（竖屏）
          if (_showRatioButtons)
            Positioned(
              bottom: 235,
              child: _buildRatioButton(
                '3:4',
                Icons.crop_portrait,
                () => _setCropRatio(3.0 / 4.0),
              ),
            ),
          // 主按钮
          Positioned(
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'ratioMainBtn',
              mini: true,
              backgroundColor: _showRatioButtons ? Colors.yellow[600] : Colors.black.withOpacity(0.8),
              elevation: 6,
              onPressed: () {
                setState(() {
                  _showRatioButtons = !_showRatioButtons;
                });
              },
              child: Icon(
                _showRatioButtons ? Icons.close : Icons.aspect_ratio,
                color: _showRatioButtons ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatioButton(String label, IconData icon, VoidCallback onPressed) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.yellow.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () {
            onPressed();
            setState(() {
              _showRatioButtons = false; // 选择后收起
            });
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 设置裁剪比例的辅助方法
  void _setCropRatio(double ratio) {
    setState(() {
      double width, height;
      if (ratio == 1.0) {
        // 1:1 正方形
        final double size = _videoWidth < _videoHeight ? _videoWidth : _videoHeight;
        width = height = size;
      } else if (ratio > 1.0) {
        // 横屏比例
        if (_videoWidth / _videoHeight > ratio) {
          height = _videoHeight;
          width = height * ratio;
        } else {
          width = _videoWidth;
          height = width / ratio;
        }
      } else {
        // 竖屏比例
        if (_videoWidth / _videoHeight > ratio) {
          height = _videoHeight;
          width = height * ratio;
        } else {
          width = _videoWidth;
          height = width / ratio;
        }
      }
      
      final double x = (_videoWidth - width) / 2;
      final double y = (_videoHeight - height) / 2;
      _cropRect = Rect.fromLTWH(x, y, width, height);
    });
  }

  // ---- 处理视频 ----
  Future<void> _processVideoCombined({bool preview = false}) async {
    setState(() {
      _isProcessing = true;
    });

    final Directory dir = preview ? await getTemporaryDirectory() : await getApplicationDocumentsDirectory();
    final String outputPath = p.join(dir.path, preview ? 'preview_${DateTime.now().millisecondsSinceEpoch}.mp4' : 'edited_${DateTime.now().millisecondsSinceEpoch}.mp4');

    String cmd;
    final Duration duration = _trimEnd - _trimStart;
    final bool hasTrim = duration > Duration.zero;
    final bool hasCrop = _cropEnabled && (
      _cropRect.width.toInt() != _videoWidth.toInt() ||
      _cropRect.height.toInt() != _videoHeight.toInt() ||
      _cropRect.left.toInt() != 0 ||
      _cropRect.top.toInt() != 0
    );
    final bool wantMute = _muteEnabled;

    if (!hasCrop && !wantMute) {
      // 仅时间轴裁剪，直接复制所有流
      final String timing = hasTrim ? "-ss ${_formatDuration(_trimStart)} -t ${_formatDuration(duration)}" : "";
      cmd = "$timing -i '${widget.videoPath}' -c copy '$outputPath'".trim();
    } else if (!hasCrop && wantMute) {
      // 仅静音 + 可叠加时间轴，视频流copy，去掉音频
      final String timing = hasTrim ? "-ss ${_formatDuration(_trimStart)} -t ${_formatDuration(duration)}" : "";
      cmd = "$timing -i '${widget.videoPath}' -c:v copy -an '$outputPath'".trim();
    } else {
      // 需要画布裁剪 -> 重新编码视频，音频拷贝；可叠加时间轴
      if (_cropRect.width <= 0 || _cropRect.height <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('裁剪区域无效')));
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }
      final int w = _cropRect.width.toInt();
      final int h = _cropRect.height.toInt();
      final int x = _cropRect.left.toInt();
      final int y = _cropRect.top.toInt();
      final String timing = hasTrim ? "-ss ${_formatDuration(_trimStart)} -t ${_formatDuration(duration)}" : "";
      final String audioPart = wantMute ? "-an" : "-c:a copy";
      final String preset = preview ? "ultrafast" : "medium";
      final String crf = preview ? "28" : "23";
      cmd = "$timing -i '${widget.videoPath}' -vf \"crop=$w:$h:$x:$y\" -c:v libx264 -preset $preset -crf $crf $audioPart -movflags +faststart '$outputPath'".trim();
    }

    try {
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        if (mounted) {
          if (preview) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('预览已生成')));
            // 打开预览播放页
            // ignore: use_build_context_synchronously
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PreviewPlayerScreen(videoPath: outputPath)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('视频处理成功：$outputPath')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('视频处理失败，code: $rc')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('视频处理异常: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // 构建工具按钮的辅助方法
  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? Colors.yellow[600] : Colors.grey[700],
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive ? Colors.yellow[600]! : Colors.grey[600]!,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onPressed,
              child: Icon(
                icon,
                color: isActive ? Colors.black : Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.yellow[600] : Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatDuration(Duration d) {
    final String h = _twoDigits(d.inHours);
    final String m = _twoDigits(d.inMinutes.remainder(60));
    final String s = _twoDigits(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          '视频裁剪',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.yellow[600],
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextButton.icon(
              onPressed: _isProcessing ? null : () => _processVideoCombined(preview: false),
              icon: const Icon(Icons.file_upload, color: Colors.black, size: 18),
              label: const Text(
                '导出',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _videoPlayerController == null || !_videoPlayerController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 顶部：视频 + 裁剪框
                Expanded(flex: 2, child: _buildCropCanvasEditor()),
                const SizedBox(height: 12),
                // 中部：缩略图 + 时间轴滑块
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _thumbnailPaths.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: Container(
                                width: 80, // 1:1 正方形容器
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.file(
                                    File(_thumbnailPaths[index]), 
                                    fit: BoxFit.cover, // 保持居中裁剪
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: Colors.yellow[600],
                          inactiveTrackColor: Colors.grey[300],
                          thumbColor: Colors.yellow[700],
                          overlayColor: Colors.yellow[600]!.withAlpha(32),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
                          rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                        ),
                        child: RangeSlider(
                          values: RangeValues(
                            _trimStart.inMilliseconds.toDouble(),
                            _trimEnd.inMilliseconds.toDouble(),
                          ),
                          min: 0,
                          max: _videoPlayerController!.value.duration.inMilliseconds.toDouble(),
                          onChanged: (RangeValues values) {
                            setState(() {
                              _trimStart = Duration(milliseconds: values.start.toInt());
                              _trimEnd = Duration(milliseconds: values.end.toInt());
                            });
                            _videoPlayerController!.seekTo(_trimStart);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 显示当前裁剪时长
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '当前裁剪时长: ${_formatDuration(_trimEnd - _trimStart)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // 工具栏：位于时间轴下方
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildToolButton(
                        icon: _videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        label: _videoPlayerController!.value.isPlaying ? '暂停' : '播放',
                        isActive: _videoPlayerController!.value.isPlaying,
                        onPressed: _togglePreviewPlayback,
                      ),
                      _buildToolButton(
                        icon: Icons.crop,
                        label: '裁剪',
                        isActive: _cropEnabled,
                        onPressed: () => setState(() => _cropEnabled = !_cropEnabled),
                      ),
                      _buildToolButton(
                        icon: _muteEnabled ? Icons.volume_off : Icons.volume_up,
                        label: _muteEnabled ? '静音' : '音频',
                        isActive: _muteEnabled,
                        onPressed: () => setState(() => _muteEnabled = !_muteEnabled),
                      ),
                      _buildToolButton(
                        icon: Icons.preview,
                        label: '预览',
                        isActive: false,
                        onPressed: _isProcessing ? null : () => _processVideoCombined(preview: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}


