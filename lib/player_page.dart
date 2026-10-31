import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data2026.dart';
import 'models.dart';
import 'native.dart';
import 'store.dart';
import 'streams_loader.dart';
import 'ui_common.dart';

class VideoPlayerPage extends StatefulWidget {
  final Drama drama;
  final List<String> urls;
  final List<Map<String, dynamic>> streams;
  final int initialEpisode;
  final String? activeDub;

  const VideoPlayerPage({
    super.key,
    required this.drama,
    this.urls = const <String>[],
    this.streams = const <Map<String, dynamic>>[],
    this.initialEpisode = 1,
    this.activeDub,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late int _ep;
  late String _dub;
  List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];
  bool _resolving = true;
  String _playUrl = '';
  int _reloadKey = 0;

  Drama get d => widget.drama;

  int get _totalEps {
    final t = store.totals[d.id] ?? (store.epCache[d.id]?.length ?? 0);
    if (t > 0) return t;
    final aired = store.airedCount(d);
    return aired > 0 ? aired : 16;
  }

  List<String> get _dubs {
    final out = <String>[];
    for (final s in _entries) {
      final db = (s['dub'] ?? '').toString().trim();
      if (db.isNotEmpty && !out.contains(db)) out.add(db);
    }
    for (final studio in kDubStudios) {
      if (!out.contains(studio)) out.add(studio);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    final maxEp = _totalEps;
    _ep = widget.initialEpisode.clamp(1, maxEp);
    _dub = (widget.activeDub != null && widget.activeDub!.trim().isNotEmpty)
        ? widget.activeDub!.trim()
        : (store.dubOf[d.id] ?? 'SoftBox');
    _entries = List<Map<String, dynamic>>.from(widget.streams);
    _initStreams();
  }

  Future<void> _initStreams() async {
    setState(() => _resolving = true);
    final ru = store.ruTitle(d);
    if (_entries.isEmpty) {
      final found = await StreamsLoader.discoverLiveStreams(d, ru);
      if (mounted && found.isNotEmpty) {
        _entries = found;
      }
    }
    _updatePlayUrl(markProgress: true);
  }

  void _updatePlayUrl({bool markProgress = false}) {
    final ru = store.ruTitle(d);
    final nextUrl = StreamsLoader.resolveEpisodeStreamUrl(
      drama: d,
      ruTitle: ru,
      episode: _ep,
      dub: _dub,
      entries: _entries,
    );
    if (markProgress) {
      if (store.listOf[d.id] == null) {
        store.setList(d, 'watch');
      }
      store.setProg(d, _ep);
    }
    if (!mounted) return;
    setState(() {
      _playUrl = nextUrl;
      _resolving = false;
      _reloadKey++;
    });
  }

  void _selectDub(String studio) {
    if (_dub == studio) return;
    store.setDub(d, studio);
    setState(() => _dub = studio);
    _updatePlayUrl(markProgress: false);
  }

  void _selectEp(int epNum) {
    if (_ep == epNum) return;
    setState(() => _ep = epNum);
    _updatePlayUrl(markProgress: true);
  }

  Future<void> _openFullscreen() async {
    if (_playUrl.isEmpty) return;
    final title = '${store.ruTitle(d)} · $_ep серия · $_dub';
    await Native.playStream(_playUrl, title);
  }

  @override
  Widget build(BuildContext context) {
    final title = store.ruTitle(d);
    final total = _totalEps;
    final dubList = _dubs;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        foregroundColor: C.tx,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.tx),
            ),
            Text(
              '$_ep серия из $total · $_dub',
              style: const TextStyle(fontSize: 11.5, color: C.jd, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Во весь экран',
            onPressed: _openFullscreen,
            icon: const Icon(Icons.fullscreen_rounded, color: C.tx, size: 26),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
        children: [
          // Встроенный видеоплеер 16:9 прямо на экране
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: C.line),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _resolving || _playUrl.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: C.jd, strokeWidth: 2.5),
                            SizedBox(height: 12),
                            Text(
                              'Загрузка видеопотока…',
                              style: TextStyle(color: C.tx2, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          AndroidView(
                            key: ValueKey('dp_player_${d.id}_${_ep}_${_dub}_$_reloadKey'),
                            viewType: 'dp/video_view',
                            creationParams: <String, dynamic>{
                              'url': _playUrl,
                              'title': title,
                              'episode': _ep,
                              'dub': _dub,
                            },
                            creationParamsCodec: const StandardMessageCodec(),
                            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                            },
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: _openFullscreen,
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 22),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Переключение предыдущей / следующей серии
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ep > 1 ? () => _selectEp(_ep - 1) : null,
                  icon: const Icon(Icons.skip_previous_rounded, size: 18),
                  label: const Text('Пред. серия', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.tx,
                    side: const BorderSide(color: C.line),
                    backgroundColor: C.s1,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _ep < total ? () => _selectEp(_ep + 1) : null,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text('След. серия', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: C.gd,
                    foregroundColor: C.bg,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          // Выбор озвучки
          const SectionTitle('Озвучка'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final studio in dubList)
                GestureDetector(
                  onTap: () => _selectDub(studio),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _dub == studio ? C.gd : C.s1,
                      border: Border.all(color: _dub == studio ? C.gd : C.line),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _dub == studio ? Icons.volume_up_rounded : Icons.mic_none_rounded,
                          size: 15,
                          color: _dub == studio ? C.bg : C.tx2,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          studio,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: _dub == studio ? C.bg : C.tx,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Выбор серии (ровно 1..total, никогда не выходит за лимит серий)
          SectionTitle('Серии ($total)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 1; i <= total; i++)
                GestureDetector(
                  onTap: () => _selectEp(i),
                  child: Container(
                    width: 52,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _ep == i ? C.gd : ((store.prog[d.id] ?? 0) >= i ? C.s2 : C.s1),
                      border: Border.all(color: _ep == i ? C.gd : ((store.prog[d.id] ?? 0) >= i ? C.jd : C.line)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: _ep == i ? C.bg : ((store.prog[d.id] ?? 0) >= i ? C.jd : C.tx),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
