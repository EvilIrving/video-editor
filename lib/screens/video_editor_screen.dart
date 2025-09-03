import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../widgets/crop_box_overlay.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  @override
  void dispose() {
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
    // 不自动播放，统一添加播放按钮控制
    await _generateThumbnails();
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

  Widget _buildTrimEditor() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController!),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: FloatingActionButton.small(
                  onPressed: () async {
                    if (_videoPlayerController!.value.isPlaying) {
                      await _videoPlayerController!.pause();
                    } else {
                      await _videoPlayerController!.play();
                    }
                    setState(() {});
                  },
                  child: Icon(_videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('裁剪范围: ${_formatDuration(_trimStart)} - ${_formatDuration(_trimEnd)}'),
        const SizedBox(height: 10),
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
        ElevatedButton(
          onPressed: _isProcessing ? null : _processVideoCombined,
          child: _isProcessing ? const CircularProgressIndicator() : const Text('确认裁剪'),
        ),
      ],
    );
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
                      child: CropBoxOverlay(
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
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: FloatingActionButton.small(
                  onPressed: () async {
                    if (_videoPlayerController!.value.isPlaying) {
                      await _videoPlayerController!.pause();
                    } else {
                      await _videoPlayerController!.play();
                    }
                    setState(() {});
                  },
                  child: Icon(_videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Column(
            children: [
              Text('裁剪尺寸: ${_cropRect.width.toInt()}x${_cropRect.height.toInt()}'),
            ],
          ),
        ),
      ],
    );
  }

  // ---- 处理视频 ----
  Future<void> _processVideoCombined() async {
    setState(() {
      _isProcessing = true;
    });

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String outputPath = p.join(appDocDir.path, 'edited_${DateTime.now().millisecondsSinceEpoch}.mp4');

    String cmd;
    final Duration duration = _trimEnd - _trimStart;
    final bool hasTrim = duration > Duration.zero;
    final bool hasCrop = _cropRect.width.toInt() != _videoWidth.toInt() || _cropRect.height.toInt() != _videoHeight.toInt() || _cropRect.left.toInt() != 0 || _cropRect.top.toInt() != 0;

    if (!hasCrop) {
      // 仅时间轴裁剪，直接复制流，保持原画质与体积
      final String timing = hasTrim ? "-ss ${_formatDuration(_trimStart)} -t ${_formatDuration(duration)}" : "";
      cmd = "$timing -i '${widget.videoPath}' -c copy '$outputPath'".trim();
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
      cmd = "$timing -i '${widget.videoPath}' -vf \"crop=$w:$h:$x:$y\" -c:v libx264 -preset medium -crf 23 -c:a copy -movflags +faststart '$outputPath'".trim();
    }

    try {
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('视频处理成功：$outputPath')));
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
                          // 不自动 seek 播放，保持用户手动控制
                        },
                      ),
                      Text('裁剪范围: ${_formatDuration(_trimStart)} - ${_formatDuration(_trimEnd)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 底部：确认导出按钮
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processVideoCombined,
                    child: _isProcessing ? const CircularProgressIndicator() : const Text('导出'),
                  ),
                ),
              ],
            ),
    );
  }
}


