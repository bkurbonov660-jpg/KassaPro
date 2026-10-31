import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'native.dart';
import 'store.dart';
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
    required this.urls,
    this.streams = const <Map<String, dynamic>>[],
    this.initialEpisode = 1,
    this.activeDub,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late int _ep;
  int _streamIdx = 0;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _ep = widget.initialEpisode > 0 ? widget.initialEpisode : 1;
  }

  String get _currentUrl {
    if (widget.urls.isEmpty) return '';
    final idx = _streamIdx.clamp(0, widget.urls.length - 1);
    return widget.urls[idx];
  }

  String get _currentDub {
    if (widget.streams.isNotEmpty && _streamIdx < widget.streams.length) {
      final d = (widget.streams[_streamIdx]['dub'] ?? '').toString().trim();
      if (d.isNotEmpty) return d;
    }
    return widget.activeDub ?? 'Оригинал / Auto';
  }

  int get _totalEps {
    final t = store.totals[widget.drama.id] ?? (store.epCache[widget.drama.id]?.length ?? 16);
    return t > 0 ? t : 16;
  }

  Future<void> _playInNativePlayer() async {
    final url = _currentUrl;
    if (url.isEmpty) return;
    setState(() => _launching = true);
    final title = '${store.ruTitle(widget.drama)} · Серия $_ep ($_currentDub)';
    final ok = await Native.playStream(url, title);
    if (!mounted) return;
    setState(() => _launching = false);
    if (!ok) {
      await Native.openUrl(url);
    }
  }

  void _markWatched() {
    if (store.listOf[widget.drama.id] == null) {
      store.setList(widget.drama, 'watch');
    }
    store.setProg(widget.drama, _ep);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Отмечено: серия $_ep просмотрена')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.drama;
    final title = store.ruTitle(d);
    final url = _currentUrl;
    final isHls = url.toLowerCase().contains('.m3u8');

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        foregroundColor: C.tx,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Видео-экран / запуск встроенного плеера Android
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [C.s2, C.s1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.jd, width: 1.2),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: C.jd.withOpacity(0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: C.jd, width: 2),
                  ),
                  child: IconButton(
                    onPressed: _launching ? null : _playInNativePlayer,
                    icon: _launching
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: C.jd),
                          )
                        : const Icon(Icons.play_arrow_rounded, color: C.jd, size: 42),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Серия $_ep · $_currentDub',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.tx),
                ),
                const SizedBox(height: 6),
                Text(
                  isHls ? 'Поток HLS (.m3u8) готов к воспроизведению' : 'Прямой видеопоток (.mp4) готов к запуску',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.jd, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _launching ? null : _playInNativePlayer,
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                    label: const Text(
                      'Запустить встроенный видеоплеер',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: C.jd,
                      foregroundColor: C.onPk,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: url.isEmpty ? null : () => Native.openUrl(url),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16, color: C.pk),
                        label: const Text('Внешний плеер', style: TextStyle(color: C.tx, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: C.line),
                          backgroundColor: C.bg,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: url.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(ClipboardData(text: url));
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ссылка на поток скопирована')),
                                );
                              },
                        icon: const Icon(Icons.copy_rounded, size: 16, color: C.tx2),
                        label: const Text('Скопировать URL', style: TextStyle(color: C.tx2, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: C.line),
                          backgroundColor: C.bg,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _markWatched,
              icon: const Icon(Icons.check_circle_outline_rounded, color: C.jd, size: 19),
              label: Text(
                'Отметить серию $_ep как просмотренную',
                style: const TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: C.line),
                backgroundColor: C.s1,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SectionTitle('Выбор серии'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 1; i <= _totalEps; i++)
                GestureDetector(
                  onTap: () => setState(() => _ep = i),
                  child: Container(
                    width: 46,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _ep == i ? C.pk : ((store.prog[d.id] ?? 0) >= i ? C.s2 : C.s1),
                      border: Border.all(color: _ep == i ? C.pk : C.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _ep == i ? C.onPk : ((store.prog[d.id] ?? 0) >= i ? C.jd : C.tx),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          if (widget.urls.length > 1) ...[
            const SectionTitle('Доступные серверы и потоки'),
            Column(
              children: [
                for (var i = 0; i < widget.urls.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _streamIdx == i ? C.s2 : C.s1,
                      border: Border.all(color: _streamIdx == i ? C.jd : C.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      onTap: () => setState(() => _streamIdx = i),
                      leading: Icon(
                        _streamIdx == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: _streamIdx == i ? C.jd : C.tx2,
                      ),
                      title: Text(
                        'Поток #${i + 1} (${i < widget.streams.length ? (widget.streams[i]['dub'] ?? _currentDub) : _currentDub})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.tx),
                      ),
                      subtitle: Text(
                        widget.urls[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: C.tx2, fontSize: 11.5),
                      ),
                      trailing: IconButton(
                        onPressed: () {
                          setState(() => _streamIdx = i);
                          _playInNativePlayer();
                        },
                        icon: const Icon(Icons.play_arrow_rounded, color: C.jd),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
