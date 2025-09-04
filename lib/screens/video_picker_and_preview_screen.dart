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
    final double cardWidth = MediaQuery.of(context).size.width - 32;
    final double cardHeight = cardWidth * 0.55;
    return Scaffold(
      backgroundColor: const Color(0xFF11131A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF11131A),
        // 移除title
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: GestureDetector(
            onTap: _pickVideo,
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFC3A0),
                    Color(0xFFF48FB1),
                    Color(0xFF8E9BFF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_circle, size: 64, color: Colors.white),
                  SizedBox(height: 12),
                  Text('开始创作', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum EditorMode { trim, cropCanvas }


