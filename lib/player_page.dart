import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'kodik_parser.dart';
import 'models.dart';
import 'native.dart';
import 'store.dart';
import 'streams_loader.dart';
import 'ui_common.dart';

class VideoPlayerPage extends StatefulWidget {
  final Drama drama;
  final int initialEpisode;
  final String initialDub;
  final int totalEpisodes;
  final String? initialStreamUrl;
  final List<Map<String, dynamic>> streamEntries;
  final List<String> availableDubs;
  final List<Ep>? episodesList;

  const VideoPlayerPage({
    super.key,
    required this.drama,
    required this.initialEpisode,
    required this.initialDub,
    required this.totalEpisodes,
    required this.initialStreamUrl,
    required this.streamEntries,
    required this.availableDubs,
    this.episodesList,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late int _ep;
  late String _dub;
  String? _playUrl;
  bool _dubNotAvailable = false;
  int _resolveToken = 0;

  Drama get d => widget.drama;

  @override
  void initState() {
    super.initState();
    final maxEp = widget.totalEpisodes > 0 ? widget.totalEpisodes : 16;
    _ep = widget.initialEpisode.clamp(1, maxEp);
    _dub = widget.initialDub;
    _playUrl = widget.initialStreamUrl;
    _dubNotAvailable = (_playUrl == null || _playUrl!.isEmpty);
    _tryUpgradeDirectKodikStream();
  }

  // Если ссылка ведёт на Kodik embed — пробуем через KodikParser расшифровать прямой поток .m3u8/.mp4 без рекламы
  Future<void> _tryUpgradeDirectKodikStream() async {
    final currentUrl = _playUrl;
    if (currentUrl == null || currentUrl.isEmpty) return;
    if (!currentUrl.contains('kodikplayer.com/serial/') &&
        !currentUrl.contains('kodikplayer.com/seria/') &&
        !currentUrl.contains('kodikplayer.com/video/')) {
      return;
    }
    final tok = ++_resolveToken;
    final direct = await KodikParser.extractDirectStream(currentUrl, episode: _ep);
    if (!mounted || tok != _resolveToken) return;
    if (direct != null && direct.isNotEmpty && direct != _playUrl) {
      setState(() {
        _playUrl = direct;
      });
    }
  }

  void _switchEpisode(int ep) {
    final url = StreamsLoader.getExactStreamUrl(
      entries: widget.streamEntries,
      episode: ep,
      dub: _dub,
    );
    setState(() {
      _ep = ep;
      _playUrl = url;
      _dubNotAvailable = (url == null || url.isEmpty);
    });
    if ((store.prog[d.id] ?? 0) < ep) {
      store.setProg(d, ep);
    }
    _tryUpgradeDirectKodikStream();
  }

  void _switchDub(String dub) {
    final url = StreamsLoader.getExactStreamUrl(
      entries: widget.streamEntries,
      episode: _ep,
      dub: dub,
    );
    store.setDub(d, dub);
    setState(() {
      _dub = dub;
      _playUrl = url;
      _dubNotAvailable = (url == null || url.isEmpty);
    });
    _tryUpgradeDirectKodikStream();
  }

  @override
  Widget build(BuildContext context) {
    final ru = store.ruTitle(d);
    final total = widget.totalEpisodes > 0 ? widget.totalEpisodes : 16;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0B14),
        elevation: 0,
        foregroundColor: C.tx,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ru,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              '$_ep серия · $_dub',
              style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          if (_playUrl != null && _playUrl!.isNotEmpty)
            IconButton(
              tooltip: 'Во весь экран',
              icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
              onPressed: () => Native.playStream(_playUrl!, '$ru · $_ep серия ($_dub)'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 16:9 ВИДЕОПЛЕЕР
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildPlayerArea(),
          ),

          // КОНТЕНТ ПОД ПЛЕЕРОМ: выбор озвучки + выбор эпизода в стиле скриншота
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                // Предупреждение если выбранной озвучки нет
                if (_dubNotAvailable) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: C.gd.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.gd.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: C.gd, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Озвучки «$_dub» нет для этой серии',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: C.gd, fontSize: 14),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        const Text(
                          'Выберите одну из доступных озвучек ниже:',
                          style: TextStyle(fontSize: 12, color: C.tx2),
                        ),
                      ],
                    ),
                  ),
                ],

                // Компактный ряд озвучек
                if (widget.availableDubs.isNotEmpty) ...[
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.availableDubs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final dub = widget.availableDubs[idx];
                        final selected = dub.toLowerCase() == _dub.toLowerCase();
                        return GestureDetector(
                          onTap: () => _switchDub(dub),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : const Color(0xFF1C1924),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected ? Colors.white : Colors.white12,
                              ),
                            ),
                            child: Text(
                              dub,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: selected ? Colors.black : Colors.white70,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Заголовок Сезон 1 (как на фото)
                Row(
                  children: [
                    const Text(
                      'Сезон 1',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
                    const Spacer(),
                    Text(
                      '$_ep из $total',
                      style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Список эпизодов с превью-постером и кнопкой Play (точь-в-точь как на фото)
                for (var i = 1; i <= total; i++) _buildEpisodeRow(i),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeRow(int epNum) {
    final isCurrent = epNum == _ep;
    final watched = (store.prog[d.id] ?? 0) >= epNum;
    Ep? epMeta;
    if (widget.episodesList != null) {
      for (final e in widget.episodesList!) {
        if (e.number == epNum) {
          epMeta = e;
          break;
        }
      }
    }
    final epTitle = (epMeta != null && epMeta.name.trim().isNotEmpty && !epMeta.name.toLowerCase().startsWith('episode'))
        ? '$epNum. ${epMeta.name.trim()}'
        : '$epNum. Серия $epNum';
    final durationText = '${58 + (epNum % 9)} мин';

    return InkWell(
      onTap: () => _switchEpisode(epNum),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrent ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isCurrent ? Border.all(color: Colors.white24) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Превью-кадр 16:9 с круглой кнопкой Play по центру
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 126,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    d.poster.isNotEmpty
                        ? Image.network(
                            d.poster,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1B26)),
                          )
                        : Container(color: const Color(0xFF1E1B26)),
                    Container(color: Colors.black.withValues(alpha: 0.30)),
                    Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isCurrent ? Colors.white : Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 1.4),
                        ),
                        child: Icon(
                          isCurrent ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                          color: isCurrent ? Colors.black : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    if (watched)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(height: 3, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    epTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    durationText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                watched ? Icons.check_circle_rounded : Icons.arrow_downward_rounded,
                color: watched ? Colors.white70 : Colors.white38,
                size: 20,
              ),
              onPressed: () => store.setProg(d, watched ? epNum - 1 : epNum),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerArea() {
    if (_playUrl == null || _playUrl!.isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_rounded, color: C.tx2, size: 48),
            const SizedBox(height: 12),
            Text(
              'Нет потока для озвучки «$_dub»',
              style: const TextStyle(color: C.tx2, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Выберите другую озвучку ниже',
              style: TextStyle(color: C.tx2, fontSize: 12),
            ),
          ]),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AndroidView(
          key: ValueKey('dp_player_${d.id}_${_ep}_${_dub}_${_playUrl.hashCode}'),
          viewType: 'dp/video_view',
          creationParams: <String, dynamic>{
            'url': _playUrl!,
            'title': store.ruTitle(d),
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
              onTap: () => Native.playStream(_playUrl!, '${store.ruTitle(d)} · $_ep серия'),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
