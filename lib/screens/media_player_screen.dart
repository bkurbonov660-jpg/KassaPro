import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';
import 'package:just_audio/just_audio.dart';

class MediaPlayerScreen extends StatefulWidget {
  final String filePath;
  final String mediaType;
  const MediaPlayerScreen({Key? key, required this.filePath, required this.mediaType}) : super(key: key);

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  BetterPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isAudio = false;

  @override
  void initState() {
    super.initState();
    _isAudio = widget.mediaType == 'mp3';
    if (_isAudio) {
      _initAudio();
    } else {
      _initVideo();
    }
  }

  void _initVideo() {
    BetterPlayerDataSource dataSource = BetterPlayerDataSource.file(widget.filePath);
    BetterPlayerConfiguration config = const BetterPlayerConfiguration(
      autoPlay: true,
      looping: false,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enableFullscreen: true,
        enablePlayPause: true,
        showControlsOnInitialize: true,
        enableProgressBar: true,
        enableSkips: true,
      ),
    );
    _videoController = BetterPlayerController(config);
    _videoController!.setupDataSource(dataSource);
  }

  void _initAudio() {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.setFilePath(widget.filePath).then((_) {
      _audioPlayer!.play();
      setState(() => _isPlaying = true);
    });
    _audioPlayer!.playerStateStream.listen((state) {
      setState(() => _isPlaying = state.playing);
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isAudio ? AppBar(title: const Text('Аудиоплеер'), backgroundColor: Colors.grey[900]) : null,
      body: _isAudio ? _audioPlayerWidget() : _videoController != null ? BetterPlayer(controller: _videoController!) : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _audioPlayerWidget() {
    if (_audioPlayer == null) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<Duration?>(
      stream: _audioPlayer!.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _audioPlayer!.duration ?? Duration.zero;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.audiotrack, size: 120, color: Colors.white70),
              const SizedBox(height: 20),
              Text(widget.filePath.split('/').last, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 30),
              Slider(
                value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                max: duration.inMilliseconds.toDouble(),
                onChanged: (v) => _audioPlayer!.seek(Duration(milliseconds: v.toInt())),
                activeColor: Colors.cyanAccent,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_formatDuration(position), style: const TextStyle(color: Colors.white70)),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 64, color: Colors.cyanAccent),
                    onPressed: () {
                      if (_isPlaying) {
                        _audioPlayer!.pause();
                      } else {
                        _audioPlayer!.play();
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
