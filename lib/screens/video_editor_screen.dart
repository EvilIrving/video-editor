import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../widgets/crop_box_overlay.dart';
import '../widgets/tool_icon_button.dart';
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
  void _onVideoPlayerUpdate() {}

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
              // 移除中心控制条（工具统一到时间轴下方）
            ],
          ),
        ),
      ],
    );
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
      appBar: AppBar(
        title: const Text('视频裁剪'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          ToolIconButton(
            icon: Icons.file_upload,
            onPressed: _isProcessing ? null : () => _processVideoCombined(preview: false),
            active: false,
            tooltip: '导出',
          ),
          const SizedBox(width: 4),
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
                              child: Image.file(File(_thumbnailPaths[index]), fit: BoxFit.cover),
                            );
                          },
                        ),
                      ),
                      RangeSlider(
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
                      const SizedBox(height: 8),
                      // 比例按钮：显示在工具栏上方，仅在开启裁剪时出现
                      if (_cropEnabled)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ToolIconButton(
                              icon: Icons.fullscreen,
                              onPressed: () => setState(() { _cropRect = Rect.fromLTWH(0, 0, _videoWidth, _videoHeight); }),
                              tooltip: '重置',
                            ),
                            const SizedBox(width: 8),
                            ToolIconButton(
                              icon: Icons.crop_square,
                              onPressed: () {
                                setState(() {
                                  final double size = _videoWidth < _videoHeight ? _videoWidth : _videoHeight;
                                  final double x = (_videoWidth - size) / 2;
                                  final double y = (_videoHeight - size) / 2;
                                  _cropRect = Rect.fromLTWH(x, y, size, size);
                                });
                              },
                              tooltip: '1:1',
                            ),
                            const SizedBox(width: 8),
                            ToolIconButton(
                              icon: Icons.crop_16_9,
                              onPressed: () {
                                setState(() {
                                  const double targetRatio = 16.0 / 9.0;
                                  double width, height;
                                  if (_videoWidth / _videoHeight > targetRatio) {
                                    height = _videoHeight; width = height * targetRatio;
                                  } else { width = _videoWidth; height = width / targetRatio; }
                                  final double x = (_videoWidth - width) / 2;
                                  final double y = (_videoHeight - height) / 2;
                                  _cropRect = Rect.fromLTWH(x, y, width, height);
                                });
                              },
                              tooltip: '16:9',
                            ),
                            const SizedBox(width: 8),
                            ToolIconButton(
                              icon: Icons.aspect_ratio,
                              onPressed: () {
                                setState(() {
                                  const double targetRatio = 3.0 / 4.0; // 竖屏 3:4
                                  double width, height;
                                  if (_videoWidth / _videoHeight > targetRatio) {
                                    height = _videoHeight; width = height * targetRatio;
                                  } else { width = _videoWidth; height = width / targetRatio; }
                                  final double x = (_videoWidth - width) / 2;
                                  final double y = (_videoHeight - height) / 2;
                                  _cropRect = Rect.fromLTWH(x, y, width, height);
                                });
                              },
                              tooltip: '3:4',
                            ),
                            const SizedBox(width: 8),
                            ToolIconButton(
                              icon: Icons.aspect_ratio,
                              onPressed: () {
                                setState(() {
                                  const double targetRatio = 4.0 / 3.0; // 横屏 4:3
                                  double width, height;
                                  if (_videoWidth / _videoHeight > targetRatio) {
                                    height = _videoHeight; width = height * targetRatio;
                                  } else { width = _videoWidth; height = width / targetRatio; }
                                  final double x = (_videoWidth - width) / 2;
                                  final double y = (_videoHeight - height) / 2;
                                  _cropRect = Rect.fromLTWH(x, y, width, height);
                                });
                              },
                              tooltip: '4:3',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // 工具栏：位于时间轴下方（均为图标，无底色圆角）
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ToolIconButton(
                        icon: _videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        onPressed: _togglePreviewPlayback,
                        active: _videoPlayerController!.value.isPlaying,
                        tooltip: '播放/暂停',
                      ),
                      const SizedBox(width: 8),
                      ToolIconButton(
                        icon: Icons.crop,
                        onPressed: () => setState(() => _cropEnabled = !_cropEnabled),
                        active: _cropEnabled,
                        tooltip: '画布裁剪',
                      ),
                      
                      const SizedBox(width: 8),
                      ToolIconButton(
                        icon: _muteEnabled ? Icons.volume_off : Icons.volume_up,
                        onPressed: () => setState(() => _muteEnabled = !_muteEnabled),
                        active: _muteEnabled,
                        tooltip: '静音',
                      ),
                      const SizedBox(width: 8),
                      ToolIconButton(
                        icon: Icons.preview,
                        onPressed: _isProcessing ? null : () => _processVideoCombined(preview: true),
                        active: false,
                        tooltip: '生成预览',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}


