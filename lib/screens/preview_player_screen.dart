import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PreviewPlayerScreen extends StatefulWidget {
  final String videoPath;

  const PreviewPlayerScreen({super.key, required this.videoPath});

  @override
  State<PreviewPlayerScreen> createState() => _PreviewPlayerScreenState();
}

class _PreviewPlayerScreenState extends State<PreviewPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath));
    _init();
  }

  Future<void> _init() async {
    await _controller.initialize();
    await _controller.setLooping(true);
    setState(() {
      _initialized = true;
    });
    await _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预览'),
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    onPressed: () async {
                      if (_controller.value.isPlaying) {
                        await _controller.pause();
                      } else {
                        await _controller.play();
                      }
                      setState(() {});
                    },
                    iconSize: 56,
                    color: Colors.white,
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}


