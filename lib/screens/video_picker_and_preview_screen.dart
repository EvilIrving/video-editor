import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_editor_screen.dart';

class VideoPickerAndPreviewScreen extends StatefulWidget {
  const VideoPickerAndPreviewScreen({super.key});

  @override
  State<VideoPickerAndPreviewScreen> createState() => _VideoPickerAndPreviewScreenState();
}

class _VideoPickerAndPreviewScreenState extends State<VideoPickerAndPreviewScreen> {
  VideoPlayerController? _videoPlayerController;
  String? _videoPath;

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      debugPrint('[VideoPicker] Opening file picker...');
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null) {
        debugPrint('[VideoPicker] User canceled file picking');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未选择文件')));
        return;
      }
      final String? path = result.files.single.path;
      if (path == null || path.isEmpty) {
        debugPrint('[VideoPicker] Picked result but no path');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未获取到文件路径')));
        return;
      }

      // 直接进入统一裁剪页面
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoEditorScreen(videoPath: path),
        ),
      );
      return;
    } catch (e) {
      debugPrint('[VideoPicker] Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择视频失败: $e')));
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    // 预览页不再使用，保留以防后续需要
    if (_videoPath == null) return;
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(File(_videoPath!));
    await _videoPlayerController!.initialize();
    setState(() {});
    await _videoPlayerController!.setLooping(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择视频')),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _videoPlayerController != null && _videoPlayerController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    child: VideoPlayer(_videoPlayerController!),
                  )
                : const Center(child: Text('请选择视频')),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _pickVideo,
              child: const Text('选择视频'),
            ),
          ),
          // 统一到编辑页，移除两个入口按钮
        ],
      ),
    );
  }
}

enum EditorMode { trim, cropCanvas }


