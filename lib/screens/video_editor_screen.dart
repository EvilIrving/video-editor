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
  bool _isGeneratingPreview = false; // 预览生成状态
  bool _cropEnabled = false;   // 画布裁剪开关
  bool _muteEnabled = false;   // 静音导出

  // 视频信息
  double _originalFrameRate = 30.0;
  int _originalWidth = 1920;
  int _originalHeight = 1080;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _detectVideoInfo();
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

  // ---- 视频信息检测 ----
  Future<void> _detectVideoInfo() async {
    try {
      final String cmd = "-i '${widget.videoPath}' -hide_banner";
      final session = await FFmpegKit.execute(cmd);
      final String? output = await session.getOutput();
      
      if (output != null) {
        // 解析帧率
        final RegExp fpsRegex = RegExp(r'(\d+\.?\d*)\s*fps');
        final Match? fpsMatch = fpsRegex.firstMatch(output);
        if (fpsMatch != null) {
          _originalFrameRate = double.tryParse(fpsMatch.group(1) ?? '30') ?? 30.0;
        }

        // 解析分辨率
        final RegExp resolutionRegex = RegExp(r'(\d+)x(\d+)');
        final Match? resolutionMatch = resolutionRegex.firstMatch(output);
        if (resolutionMatch != null) {
          _originalWidth = int.tryParse(resolutionMatch.group(1) ?? '1920') ?? 1920;
          _originalHeight = int.tryParse(resolutionMatch.group(2) ?? '1080') ?? 1080;
        }
      }
    } catch (e) {
      debugPrint('视频信息检测失败: $e');
    }
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
            ],
          ),
        ),
      ],
    );
  }

  // ---- 横向比例按钮栏 ----
  Widget _buildHorizontalRatioButtons() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _cropEnabled ? 52 : 0, // 减少高度避免溢出
      child: _cropEnabled ? Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // 减少边距
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 减少内边距
        decoration: BoxDecoration(
          color: Colors.grey[900]?.withOpacity(0.9),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRatioButton(
              '1:1',
              Icons.crop_square,
              () => _setCropRatio(1.0),
            ),
            _buildRatioButton(
              '4:3',
              Icons.crop_3_2,
              () => _setCropRatio(4.0 / 3.0),
            ),
            _buildRatioButton(
              '16:9',
              Icons.crop_16_9,
              () => _setCropRatio(16.0 / 9.0),
            ),
            _buildRatioButton(
              '3:4',
              Icons.crop_portrait,
              () => _setCropRatio(3.0 / 4.0),
            ),
            _buildRatioButton(
              '自由',
              Icons.crop_free,
              () => _setCropRatio(0), // 0表示自由比例
            ),
          ],
        ),
      ) : const SizedBox(),
    );
  }

  Widget _buildRatioButton(String label, IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          width: 44, // 减少宽度
          height: 40, // 减少高度
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.yellow[600], size: 14), // 减少图标大小
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  color: Colors.yellow[600],
                  fontSize: 9, // 减少字体大小
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
      if (ratio == 0) {
        // 自由比例，恢复到全屏
        width = _videoWidth;
        height = _videoHeight;
      } else if (ratio == 1.0) {
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
      if (preview) {
        _isGeneratingPreview = true;
      } else {
        _isProcessing = true;
      }
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

    // 预览模式优化参数
    String previewOptimizations = "";
    if (preview) {
      // 帧率优化：如果原始帧率大于15，则降到15；否则保持原帧率
      final double targetFrameRate = _originalFrameRate > 15.0 ? 15.0 : _originalFrameRate;
      
      // 分辨率优化：如果原始分辨率大于720p，则缩放到720p；否则保持原分辨率
      String scaleFilter = "";
      if (_originalWidth > 1280 || _originalHeight > 720) {
        // 保持宽高比，限制最大边为720p
        if (_originalWidth > _originalHeight) {
          // 横屏视频，以宽为准
          scaleFilter = "scale=1280:720:force_original_aspect_ratio=decrease";
        } else {
          // 竖屏视频，以高为准
          scaleFilter = "scale=720:1280:force_original_aspect_ratio=decrease";
        }
      }
      
      // 组合滤镜
      List<String> filters = [];
      if (hasCrop) {
        final int w = _cropRect.width.toInt();
        final int h = _cropRect.height.toInt();
        final int x = _cropRect.left.toInt();
        final int y = _cropRect.top.toInt();
        filters.add("crop=$w:$h:$x:$y");
      }
      if (scaleFilter.isNotEmpty) {
        filters.add(scaleFilter);
      }
      filters.add("fps=$targetFrameRate");
      
      if (filters.isNotEmpty) {
        previewOptimizations = "-vf \"${filters.join(',')}\"";
      } else {
        previewOptimizations = "-vf \"fps=$targetFrameRate\"";
      }
    }

    if (!hasCrop && !wantMute && !preview) {
      // 仅时间轴裁剪，直接复制所有流（非预览模式）
      final String timing = hasTrim ? "-ss ${_formatDuration(_trimStart)} -t ${_formatDuration(duration)}" : "";
      cmd = "$timing -i '${widget.videoPath}' -c copy '$outputPath'".trim();
    } else if (!hasCrop && wantMute && !preview) {
      // 仅静音 + 可叠加时间轴，视频流copy，去掉音频（非预览模式）
      final String timing = hasTrim ? "-ss ${_formatDuration(_trimStart)} -t ${_formatDuration(duration)}" : "";
      cmd = "$timing -i '${widget.videoPath}' -c:v copy -an '$outputPath'".trim();
    } else {
      // 需要画布裁剪或预览模式 -> 重新编码视频
      if (hasCrop && (_cropRect.width <= 0 || _cropRect.height <= 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('裁剪区域无效')));
        }
        setState(() {
          if (preview) {
            _isGeneratingPreview = false;
          } else {
            _isProcessing = false;
          }
        });
        return;
      }
      
      final String timing = hasTrim ? "-ss ${_formatDuration(_trimStart)} -t ${_formatDuration(duration)}" : "";
      final String audioPart = wantMute ? "-an" : "-c:a copy";
      final String preset = preview ? "ultrafast" : "medium";
      final String crf = preview ? "28" : "23";
      
      if (preview) {
        // 预览模式使用优化后的滤镜
        cmd = "$timing -i '${widget.videoPath}' $previewOptimizations -c:v libx264 -preset $preset -crf $crf $audioPart -movflags +faststart '$outputPath'".trim();
      } else {
        // 正式导出模式
        if (hasCrop) {
          final int w = _cropRect.width.toInt();
          final int h = _cropRect.height.toInt();
          final int x = _cropRect.left.toInt();
          final int y = _cropRect.top.toInt();
          cmd = "$timing -i '${widget.videoPath}' -vf \"crop=$w:$h:$x:$y\" -c:v libx264 -preset $preset -crf $crf $audioPart -movflags +faststart '$outputPath'".trim();
        } else {
          cmd = "$timing -i '${widget.videoPath}' -c:v libx264 -preset $preset -crf $crf $audioPart -movflags +faststart '$outputPath'".trim();
        }
      }
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
          if (preview) {
            _isGeneratingPreview = false;
          } else {
            _isProcessing = false;
          }
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                color: isActive ? Colors.yellow[600] : Colors.grey[400],
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
          TextButton.icon(
            onPressed: _isProcessing ? null : () => _processVideoCombined(preview: false),
            icon: Icon(
              Icons.file_upload, 
              color: Colors.yellow[600], 
              size: 18
            ),
            label: Text(
              '导出',
              style: TextStyle(
                color: Colors.yellow[600],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.yellow[600],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                Expanded(
                  child: _buildCropCanvasEditor(),
                ),
                // 中部：缩略图 + 时间轴滑块 - 使用固定高度避免溢出
                Container(
                  height: 180, // 固定高度避免溢出
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 70, // 减少缩略图高度
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _thumbnailPaths.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: Container(
                                width: 70, // 减少宽度
                                height: 70,
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
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
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
                      const SizedBox(height: 4),
                      // 显示当前裁剪时长
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '当前裁剪时长: ${_formatDuration(_trimEnd - _trimStart)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12, // 减少字体大小
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // 横向比例按钮栏：位于工具栏上方
                _buildHorizontalRatioButtons(),
                // 工具栏：位于底部
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), // 减少内边距
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SafeArea(
                    top: false,
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
                          icon: _isGeneratingPreview ? Icons.hourglass_empty : Icons.preview,
                          label: _isGeneratingPreview ? '生成中' : '预览',
                          isActive: _isGeneratingPreview,
                          onPressed: (_isProcessing || _isGeneratingPreview) ? null : () => _processVideoCombined(preview: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}


