import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

class VideoPlayerModal extends StatefulWidget {
  final String filePath;
  final String title;
  const VideoPlayerModal({super.key, required this.filePath, required this.title});

  @override
  State<VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<VideoPlayerModal> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ObanColors.bgDark,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          if (_initialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(_controller),
                  VideoProgressIndicator(_controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: ObanColors.accentRed)),
                ],
              ),
            )
          else
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: ObanColors.accentRed))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 40,
                  icon: Icon(_controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: ObanColors.accentRed),
                  onPressed: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
