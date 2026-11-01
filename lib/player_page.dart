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
    _resolveStreamWithIframePriority(
      initialCandidate: widget.initialStreamUrl,
      episode: _ep,
      dub: _dub,
    );
  }

  /// Логика по образцу DoramaOn:
  /// 1. Всегда используем готовую iframe-ссылку (embed из StreamsLoader), если она доступна.
  /// 2. Только если iframe-ссылка недоступна, пытаемся извлечь прямой .m3u8 через KodikParser.
  Future<void> _resolveStreamWithIframePriority({
    String? initialCandidate,
    required int episode,
    required String dub,
  }) async {
    final tok = ++_resolveToken;

    // Шаг 1: Проверяем iframe-ссылку (embed) из StreamsLoader
    var candidate = initialCandidate ??
        StreamsLoader.getExactStreamUrl(
          entries: widget.streamEntries,
          episode: episode,
          dub: dub,
        );

    if (candidate != null && candidate.isNotEmpty) {
      // Если ссылка является доверенным iframe-плеером (Kodik, Alloha, VeoVeo) — используем её напрямую!
      if (StreamsLoader.isTrustedIframeUrl(candidate) ||
          candidate.contains('.m3u8') ||
          candidate.contains('.mp4')) {
        if (!mounted || tok != _resolveToken) return;
        setState(() {
          _playUrl = candidate;
          _dubNotAvailable = false;
        });
        return;
      }
    }

    // Шаг 2 (Fallback): Только если готовый iframe недоступен — пробуем получить прямой .m3u8 через KodikParser
    String? fallbackM3u8;
    for (final entry in widget.streamEntries) {
      final entryDub = (entry['dub'] ?? '').toString().toLowerCase();
      if (entryDub.contains(dub.toLowerCase()) || dub.toLowerCase().contains(entryDub)) {
        final rawUrl = (entry['embed'] ?? entry['url'] ?? '').toString();
        if (rawUrl.isNotEmpty) {
          fallbackM3u8 = await KodikParser.extractDirectStream(rawUrl, episode: episode);
          if (fallbackM3u8 != null && fallbackM3u8.isNotEmpty) break;
        }
      }
    }

    if (!mounted || tok != _resolveToken) return;
    setState(() {
      _playUrl = fallbackM3u8;
      _dubNotAvailable = (_playUrl == null || _playUrl!.isEmpty);
    });
  }

  void _switchEpisode(int ep) {
    if (!store.isEpAired(d, ep)) {
      Ep? epMeta;
      final list = widget.episodesList ?? store.epCache[d.id];
      if (list != null) {
        for (final e in list) {
          if (e.number == ep) {
            epMeta = e;
            break;
          }
        }
      }
      final dateTxt = (epMeta != null && epMeta.airdate.isNotEmpty)
          ? '${fmtDate(epMeta.airdate)}${epMeta.time.isNotEmpty ? ", ${epMeta.time}" : ""}'
          : 'скоро';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Серия $ep ещё не вышла (ожидается: $dateTxt)'),
          backgroundColor: C.s2,
        ),
      );
      return;
    }

    setState(() {
      _ep = ep;
    });
    if ((store.prog[d.id] ?? 0) < ep) {
      store.setProg(d, ep);
    }
    _resolveStreamWithIframePriority(episode: ep, dub: _dub);
  }

  void _switchDub(String dub) {
    store.setDub(d, dub);
    setState(() {
      _dub = dub;
    });
    _resolveStreamWithIframePriority(episode: _ep, dub: dub);
  }

  @override
  Widget build(BuildContext context) {
    final ru = store.ruTitle(d);
    final total = widget.totalEpisodes > 0 ? widget.totalEpisodes : 16;
    final airedCnt = store.airedCount(d);
    final nextInfo = store.nextEpInfo(d);

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
              '$_ep серия · $_dub · Вышло $airedCnt/$total',
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
          // 16:9 ВСТРОЕННЫЙ IFRAME/HLS ВИДЕОПЛЕЕР
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildPlayerArea(),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
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
                  const SizedBox(height: 16),
                ],

                // Статус и прогресс серий (X/Y) + дата следующей серии
                Row(
                  children: [
                    const Text(
                      'Сезон 1',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: airedCnt < total ? C.jd.withValues(alpha: 0.18) : Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        store.ruEffectiveStatus(d),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: airedCnt < total ? C.jd : Colors.white70,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Вышло $airedCnt из $total серий ($airedCnt/$total)',
                      style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if (nextInfo != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Следующая серия (${nextInfo.number} серия): ${fmtDate(nextInfo.airdate)}, ${nextInfo.time.isNotEmpty ? nextInfo.time : "21:00"}',
                    style: const TextStyle(fontSize: 12, color: C.jd, fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 12),

                for (var i = 1; i <= total; i++) _buildEpisodeRow(i, nextInfo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeRow(int epNum, NextEpInfo? nextInfo) {
    final isAired = store.isEpAired(d, epNum);
    final isCurrent = epNum == _ep && isAired;
    final isNext = !isAired && nextInfo != null && nextInfo.number == epNum;
    final watched = isAired && (store.prog[d.id] ?? 0) >= epNum;

    Ep? epMeta;
    final list = widget.episodesList ?? store.epCache[d.id];
    if (list != null) {
      for (final e in list) {
        if (e.number == epNum) {
          epMeta = e;
          break;
        }
      }
    }
    final epTitle = (epMeta != null && epMeta.name.trim().isNotEmpty && !epMeta.name.toLowerCase().startsWith('episode'))
        ? '$epNum. ${epMeta.name.trim()}'
        : '$epNum. Серия $epNum';
    final airDateTxt = (epMeta != null && epMeta.airdate.isNotEmpty)
        ? fmtDate(epMeta.airdate)
        : '';
    final airTimeTxt = (epMeta != null && epMeta.time.isNotEmpty) ? epMeta.time : '21:00';
    final subText = isAired
        ? '${58 + (epNum % 9)} мин${airDateTxt.isNotEmpty ? " · Вышла $airDateTxt" : ""}'
        : (airDateTxt.isNotEmpty
            ? '${isNext ? "Следующая серия" : "Ожидается"}: $airDateTxt, $airTimeTxt'
            : 'Ожидается анонс даты');

    return Opacity(
      opacity: isAired ? 1.0 : 0.48,
      child: InkWell(
        onTap: () => _switchEpisode(epNum),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCurrent ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isCurrent
                ? Border.all(color: Colors.white24)
                : (isNext ? Border.all(color: C.jd.withValues(alpha: 0.4)) : null),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                      Container(color: Colors.black.withValues(alpha: isAired ? 0.30 : 0.62)),
                      Center(
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.white
                                : Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(color: isAired ? Colors.white70 : Colors.white38, width: 1.4),
                          ),
                          child: Icon(
                            !isAired
                                ? Icons.lock_clock_rounded
                                : (isCurrent ? Icons.equalizer_rounded : Icons.play_arrow_rounded),
                            color: isCurrent ? Colors.black : (isAired ? Colors.white : Colors.white60),
                            size: 19,
                          ),
                        ),
                      ),
                      if (watched)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(height: 3, color: C.jd),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            epTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isAired ? Colors.white : Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAired
                                ? C.jd.withValues(alpha: 0.16)
                                : (isNext ? C.gd.withValues(alpha: 0.20) : Colors.white10),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isAired ? 'Вышла' : (isNext ? 'Ожидается' : 'Скоро'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isAired ? C.jd : (isNext ? C.gd : Colors.white60),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isNext ? C.jd : Colors.white54,
                        fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAired)
                IconButton(
                  icon: Icon(
                    watched ? Icons.check_circle_rounded : Icons.arrow_downward_rounded,
                    color: watched ? C.jd : Colors.white38,
                    size: 20,
                  ),
                  onPressed: () => store.setProg(d, watched ? epNum - 1 : epNum),
                ),
            ],
          ),
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
