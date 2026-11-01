import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'native.dart';
import 'store.dart';
import 'streams_loader.dart';
import 'ui_common.dart';

class VideoPlayerPage extends StatefulWidget {
  final Drama drama;
  final List<Map<String, dynamic>> streams; // Уже загруженные потоки
  final int initialEpisode;
  final String? initialDub; // Выбранная пользователем озвучка (может быть null)

  const VideoPlayerPage({
    super.key,
    required this.drama,
    required this.streams,
    this.initialEpisode = 1,
    this.initialDub,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late int _ep;
  late String _dub;
  late List<Map<String, dynamic>> _entries;
  String? _playUrl; // null = нет потока для этой озвучки
  bool _showDubPicker = false; // Показывать выбор озвучки вместо видео

  Drama get d => widget.drama;

  int get _totalEps {
    final t = store.totals[d.id] ?? (store.epCache[d.id]?.length ?? 0);
    if (t > 0) return t;
    final aired = store.airedCount(d);
    return aired > 0 ? aired : 16;
  }

  List<String> get _availableDubs => StreamsLoader.getAvailableDubs(_entries);

  @override
  void initState() {
    super.initState();
    _ep = widget.initialEpisode.clamp(1, _totalEps);
    _entries = List<Map<String, dynamic>>.from(widget.streams);

    // Определяем начальную озвучку
    final userDub = widget.initialDub ?? store.dubOf[d.id];
    if (userDub != null && userDub.trim().isNotEmpty) {
      _dub = userDub.trim();
    } else if (_availableDubs.isNotEmpty) {
      _dub = _availableDubs.first; // Берём первую доступную
    } else {
      _dub = 'SoftBox';
    }

    _updatePlayUrl();
  }

  void _updatePlayUrl() {
    final url = StreamsLoader.getExactStreamUrl(
      entries: _entries,
      episode: _ep,
      dub: _dub,
    );

    setState(() {
      _playUrl = url;
      // Если URL нет — честно показываем выбор доступных озвучек
      _showDubPicker = url == null && _entries.isNotEmpty;
    });

    // Отмечаем прогресс только если поток реально найден
    if (url != null) {
      if (store.listOf[d.id] == null) store.setList(d, 'watch');
      store.setProg(d, _ep);
    }
  }

  void _selectDub(String studio) {
    if (_dub == studio && _playUrl != null) return;
    setState(() {
      _dub = studio;
      _showDubPicker = false;
    });
    store.setDub(d, studio);
    _updatePlayUrl();
  }

  void _selectEp(int epNum) {
    if (_ep == epNum) return;
    setState(() => _ep = epNum);
    _updatePlayUrl();
  }

  @override
  Widget build(BuildContext context) {
    final title = store.ruTitle(d);
    final total = _totalEps;
    final dubs = _availableDubs;
    final eps = store.epCache[d.id];

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
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'Серия $_ep из $total · $_dub',
              style: const TextStyle(fontSize: 11.5, color: C.jd, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
        children: [
          // ВИДЕОПЛЕЕР (16:9)
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
                child: _buildPlayerArea(),
              ),
            ),
          ),

          // Сообщение если нет потока для выбранной озвучки
          if (_showDubPicker) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: C.s1,
                border: Border.all(color: C.gd),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.warning_rounded, color: C.gd, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Озвучки «$_dub» нет для этой серии',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.tx),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Выберите доступную озвучку:',
                    style: TextStyle(color: C.tx2, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final studio in dubs)
                        GestureDetector(
                          onTap: () => _selectDub(studio),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: studio == _dub ? C.gd : C.s2,
                              border: Border.all(color: studio == _dub ? C.gd : C.line),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              studio,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: studio == _dub ? C.bg : C.tx,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Переключение серий
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _ep > 1 ? () => _selectEp(_ep - 1) : null,
                icon: const Icon(Icons.skip_previous_rounded, size: 18),
                label: const Text('Пред.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                label: const Text('След.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),

          // Выбор озвучки
          const SectionTitle('Озвучка'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final studio in dubs)
                GestureDetector(
                  onTap: () => _selectDub(studio),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _dub == studio ? Colors.white : C.s1,
                      border: Border.all(color: _dub == studio ? Colors.white : C.line),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _dub == studio ? Icons.volume_up_rounded : Icons.mic_none_rounded,
                        size: 15,
                        color: _dub == studio ? Colors.black : C.tx2,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        studio,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: _dub == studio ? Colors.black : C.tx,
                        ),
                      ),
                    ]),
                  ),
                ),
            ],
          ),

          // Выбор эпизода в стиле скриншота (Temporada 1 -> карточки эпизодов с превью и кнопкой Play)
          const SizedBox(height: 22),
          const Text(
            'Сезон 1',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.tx),
          ),
          const SizedBox(height: 12),
          for (var i = 1; i <= total; i++)
            GestureDetector(
              onTap: () => _selectEp(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _ep == i ? C.s2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _ep == i ? Colors.white54 : Colors.transparent),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 132,
                        height: 76,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Poster(d),
                            Container(color: Colors.black38),
                            Center(
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _ep == i ? Colors.white : Colors.white.withOpacity(0.85),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                              ),
                            ),
                            if ((store.prog[d.id] ?? 0) >= i)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(height: 3.5, color: C.jd),
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
                            '$i. Серия $i',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _ep == i ? Colors.white : C.tx,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (eps != null && i <= eps.length && eps[i - 1].airdate.isNotEmpty)
                                ? '1 ч 05 мин · ${fmtDate(eps[i - 1].airdate)}'
                                : '1 ч 05 мин',
                            style: const TextStyle(color: C.tx2, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    // Если нет URL — показываем заглушку с выбором озвучки
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

    // МГНОВЕННЫЙ запуск WebView с Kodik embed
    return Stack(
      fit: StackFit.expand,
      children: [
        AndroidView(
          key: ValueKey('dp_player_${d.id}_${_ep}_$_dub'),
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
        // Кнопка fullscreen
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
