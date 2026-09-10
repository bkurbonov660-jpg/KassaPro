import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'theme/app_theme.dart';
import 'models/download_item.dart';
import 'services/queue_manager.dart';
import 'widgets/video_player_modal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: ObanColors.bgDark,
  ));
  runApp(const ObanDownloaderApp());
}

class ObanDownloaderApp extends StatelessWidget {
  const ObanDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBAN Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ObanColors.bgDark,
        primaryColor: ObanColors.accentRed,
        colorScheme: const ColorScheme.dark(
          primary: ObanColors.accentRed,
          surface: ObanColors.surfaceDark,
        ),
      ),
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _tab = 0;
  static const _platform = MethodChannel("com.obanstudio.downloader/shared");
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentAudioPath;
  String? _currentAudioTitle;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _checkSharedIntent();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlayingAudio = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkSharedIntent() async {
    try {
      final String? link = await _platform.invokeMethod('getSharedLink');
      if (link != null && link.isNotEmpty && mounted) {
        _showQuickDownloadModal(link);
      }
    } catch (_) {}
  }

  void _showQuickDownloadModal(String sharedUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ObanColors.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => QuickDownloadSheet(initialUrl: sharedUrl),
    );
  }

  void _playAudio(String path, String title) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(path));
    setState(() {
      _currentAudioPath = path;
      _currentAudioTitle = title;
      _isPlayingAudio = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onOpenSheet: _showQuickDownloadModal),
      LibraryScreen(onPlayAudio: _playAudio),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            bottom: _currentAudioPath != null ? 70 : 0,
            child: screens[_tab],
          ),
          if (_currentAudioPath != null)
            Positioned(
              left: 16, right: 16, bottom: 10,
              child: _buildMiniAudioPlayer(),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: ObanColors.surfaceDark,
          border: Border(top: BorderSide(color: ObanColors.borderDark, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: Colors.transparent,
          selectedItemColor: ObanColors.accentRed,
          unselectedItemColor: ObanColors.textSecondary,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.cloud_download_rounded), label: 'Главная'),
            BottomNavigationBarItem(icon: Icon(Icons.video_library_rounded), label: 'Файлы'),
            BottomNavigationBarItem(icon: Icon(Icons.tune_rounded), label: 'Настройки'),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAudioPlayer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ObanColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ObanColors.accentRed.withOpacity(0.5)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.audiotrack_rounded, color: ObanColors.accentRed, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_currentAudioTitle ?? "Аудио", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          IconButton(
            icon: Icon(_isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 30),
            onPressed: () {
              if (_isPlayingAudio) {
                _audioPlayer.pause();
              } else if (_currentAudioPath != null) {
                _audioPlayer.resume();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: ObanColors.textSecondary, size: 20),
            onPressed: () {
              _audioPlayer.stop();
              setState(() => _currentAudioPath = null);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 1. ЭКРАН СКАЧИВАНИЯ И ОЧЕРЕДИ
// ─────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final void Function(String) onOpenSheet;
  const HomeScreen({super.key, required this.onOpenSheet});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlCtrl = TextEditingController();
  bool _isAudio = false;
  String _videoQuality = "720p";
  String _audioQuality = "320 kbps";

  void _addToQueue() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    final item = DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      title: "Подготовка потока...",
      isAudio: _isAudio,
      quality: _isAudio ? _audioQuality : _videoQuality,
    );

    QueueManager.instance.add(item);
    _urlCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Добавлено в очередь загрузки"), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ObanColors.accentRed, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.download, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("OBAN DOWNLOADER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  Text("Докачка • Скорость/ETA • Без рекламы", style: TextStyle(fontSize: 12, color: ObanColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Поле ввода
          Container(
            decoration: BoxDecoration(
              color: ObanColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ObanColors.borderDark),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      hintText: "Вставьте ссылку YouTube или TikTok...",
                      hintStyle: TextStyle(color: ObanColors.textSecondary, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.paste_rounded, color: ObanColors.textSecondary),
                  onPressed: () async {
                    final d = await Clipboard.getData(Clipboard.kTextPlain);
                    if (d?.text != null) _urlCtrl.text = d!.text!;
                  },
                )
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Выбор формата
          Row(
            children: [
              Expanded(
                child: _pillBtn("Видео (MP4)", Icons.movie_rounded, !_isAudio, () => setState(() => _isAudio = false)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pillBtn("Музыка (MP3)", Icons.music_note_rounded, _isAudio, () => setState(() => _isAudio = true)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Качество
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: ObanColors.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ObanColors.borderDark),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_isAudio ? "Битрейт аудио:" : "Качество видео:", style: const TextStyle(fontSize: 13, color: ObanColors.textSecondary)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: ObanColors.surfaceDark,
                    value: _isAudio ? _audioQuality : _videoQuality,
                    items: (_isAudio ? ["320 kbps", "128 kbps"] : ["1080p", "720p", "480p"]).map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _isAudio ? _audioQuality = v : _videoQuality = v);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ObanColors.accentRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _addToQueue,
            child: const Text("СКАЧАТЬ В ОЧЕРЕДЬ", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Colors.white)),
          ),

          const SizedBox(height: 28),
          const Text("Очередь загрузок", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Список очереди
          AnimatedBuilder(
            animation: QueueManager.instance,
            builder: (context, _) {
              final list = QueueManager.instance.items;
              if (list.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: ObanColors.surfaceDark, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text("Очередь пуста. Вставьте ссылку выше.", style: TextStyle(color: ObanColors.textSecondary, fontSize: 13))),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _buildQueueCard(list[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _pillBtn(String text, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? ObanColors.accentRed.withOpacity(0.15) : ObanColors.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? ObanColors.accentRed : ObanColors.borderDark),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? ObanColors.accentRed : ObanColors.textSecondary),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? Colors.white : ObanColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueCard(DownloadItem item) {
    Color statusColor = ObanColors.textSecondary;
    String statusLabel = "В очереди";

    if (item.status == DownloadStatus.downloading) {
      statusColor = ObanColors.accentRed;
      statusLabel = "${item.speed} • Осталось: ${item.eta}";
    } else if (item.status == DownloadStatus.done) {
      statusColor = ObanColors.success;
      statusLabel = "Сохранено в Галерею";
    } else if (item.status == DownloadStatus.error) {
      statusColor = ObanColors.accentRed;
      statusLabel = item.error ?? "Ошибка";
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ObanColors.surfaceDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: ObanColors.borderDark)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.isAudio ? Icons.music_note_rounded : Icons.movie_rounded, color: ObanColors.accentRed, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              Text(item.quality, style: const TextStyle(fontSize: 11, color: ObanColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          if (item.status == DownloadStatus.downloading) ...[
            LinearProgressIndicator(value: item.progress > 0 ? item.progress : null, backgroundColor: ObanColors.cardDark, color: ObanColors.accentRed),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500)),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: ObanColors.textSecondary),
                onPressed: () => QueueManager.instance.removeItem(item.id),
              )
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 2. БЫСТРОЕ ОКНО ПРИ НАЖАТИИ «ПОДЕЛИТЬСЯ»
// ─────────────────────────────────────────────
class QuickDownloadSheet extends StatefulWidget {
  final String initialUrl;
  const QuickDownloadSheet({super.key, required this.initialUrl});

  @override
  State<QuickDownloadSheet> createState() => _QuickDownloadSheetState();
}

class _QuickDownloadSheetState extends State<QuickDownloadSheet> {
  static const _platform = MethodChannel("com.obanstudio.downloader/shared");
  bool _isAudio = false;
  String _quality = "720p";

  void _startAndMinimize() {
    QueueManager.instance.add(DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: widget.initialUrl,
      title: "Медиа...",
      isAudio: _isAudio,
      quality: _quality,
    ));

    // Окно мгновенно испаряется, приложение сворачивается обратно в YouTube
    Navigator.pop(context);
    _platform.invokeMethod('minimizeApp');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 24, left: 24, right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: ObanColors.accentRed, size: 28),
              SizedBox(width: 8),
              Text("Быстрая загрузка", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.initialUrl, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ObanColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isAudio ? ObanColors.accentRed : ObanColors.cardDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => setState(() { _isAudio = false; _quality = "720p"; }),
                  child: const Text("Видео (MP4)", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAudio ? ObanColors.accentRed : ObanColors.cardDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => setState(() { _isAudio = true; _quality = "320 kbps"; }),
                  child: const Text("Музыка (MP3)", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ObanColors.accentRed,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _startAndMinimize,
            child: const Text("СКАЧАТЬ В ФОНЕ (ИСПАРИТЬСЯ)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 3. ЭКРАН ФАЙЛОВ И МЕДИАТЕКА
// ─────────────────────────────────────────────
class LibraryScreen extends StatefulWidget {
  final void Function(String path, String title) onPlayAudio;
  const LibraryScreen({super.key, required this.onPlayAudio});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final List<FileSystemEntity> all = [];
    final paths = [
      '/storage/emulated/0/Movies/OBAN',
      '/storage/emulated/0/Music/OBAN',
    ];

    for (final p in paths) {
      final dir = Directory(p);
      if (await dir.exists()) {
        all.addAll(dir.listSync().where((f) => !f.path.contains('.part')));
      }
    }

    final ext = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final fallback = Directory("${ext.path}/OBAN_Downloads");
    if (await fallback.exists()) {
      all.addAll(fallback.listSync().where((f) => !f.path.contains('.part')));
    }

    setState(() => _files = all.reversed.toList());
  }

  void _openFile(String path, String name) {
    if (name.endsWith('.mp4')) {
      showDialog(context: context, builder: (_) => VideoPlayerModal(filePath: path, title: name));
    } else if (name.endsWith('.mp3')) {
      widget.onPlayAudio(path, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Загруженные медиа", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("Сохранено в системную Галерею и Музыку", style: TextStyle(fontSize: 12, color: ObanColors.textSecondary)),
            const SizedBox(height: 16),
            Expanded(
              child: _files.isEmpty
                  ? const Center(child: Text("Нет скачанных файлов", style: TextStyle(color: ObanColors.textSecondary)))
                  : ListView.separated(
                      itemCount: _files.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final file = _files[i];
                        final name = file.path.split('/').last;
                        final isAudio = name.endsWith('.mp3');

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ObanColors.surfaceDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ObanColors.borderDark),
                          ),
                          child: Row(
                            children: [
                              Icon(isAudio ? Icons.audiotrack_rounded : Icons.play_circle_fill_rounded, color: ObanColors.accentRed, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                onPressed: () => _openFile(file.path, name),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: ObanColors.textSecondary),
                                onPressed: () {
                                  file.deleteSync();
                                  _loadFiles();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 4. НАСТРОЙКИ, OVERLAY И ПАМЯТЬ
// ─────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _platform = MethodChannel("com.obanstudio.downloader/shared");
  double _storageMb = 0.0;
  bool _hasOverlay = false;

  @override
  void initState() {
    super.initState();
    _calculateStorage();
    _checkOverlay();
  }

  Future<void> _checkOverlay() async {
    try {
      final res = await _platform.invokeMethod<bool>('checkOverlayPermission');
      setState(() => _hasOverlay = res ?? false);
    } catch (_) {}
  }

  Future<void> _calculateStorage() async {
    double totalBytes = 0;
    final dirs = [
      Directory('/storage/emulated/0/Movies/OBAN'),
      Directory('/storage/emulated/0/Music/OBAN'),
    ];

    for (final d in dirs) {
      if (await d.exists()) {
        for (final f in d.listSync()) {
          if (f is File) totalBytes += f.lengthSync();
        }
      }
    }

    setState(() => _storageMb = totalBytes / (1024 * 1024));
  }

  Future<void> _clearCache() async {
    final tempDir = await getTemporaryDirectory();
    if (await tempDir.exists()) {
      tempDir.deleteSync(recursive: true);
    }
    _calculateStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Временный кэш очищен"), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Настройки", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Разрешение: Поверх других приложений
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ObanColors.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: ObanColors.accentRed.withOpacity(0.4))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Отображение поверх окон", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Icon(_hasOverlay ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: _hasOverlay ? ObanColors.success : ObanColors.accentRed, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "Зачем это нужно:\nКогда вы находитесь в YouTube или TikTok и нажимаете «Поделиться» → «OBAN Downloader», поверх текущего видео сразу всплывает компактное окно загрузки. Вы выбираете качество, жмёте «Скачать», окно тут же испаряется, а ролик качается в фоне с уведомлением в шторке. Вам не нужно переключать приложения вручную.",
                  style: TextStyle(color: ObanColors.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: ObanColors.accentRed, foregroundColor: Colors.white),
                  onPressed: () async {
                    await _platform.invokeMethod('openOverlaySettings');
                    _checkOverlay();
                  },
                  icon: const Icon(Icons.layers_rounded, size: 18),
                  label: Text(_hasOverlay ? "Права выданы (Изменить)" : "Выдать разрешение"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Хранилище
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ObanColors.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: ObanColors.borderDark)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Хранилище приложения", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text("Занято скачанными файлами: ${_storageMb.toStringAsFixed(1)} МБ", style: const TextStyle(color: ObanColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: ObanColors.cardDark, foregroundColor: Colors.white),
                  onPressed: _clearCache,
                  icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                  label: const Text("Очистить кэш"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Разрешения
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ObanColors.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: ObanColors.borderDark)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Системные права доступа", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                const Text("Доступ к Галерее, Музыке и уведомлениям шторки.", style: TextStyle(color: ObanColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: ObanColors.accentRed, foregroundColor: Colors.white),
                      onPressed: () async {
                        await [Permission.storage, Permission.notification, Permission.mediaLibrary].request();
                      },
                      child: const Text("Проверить доступ"),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: ObanColors.borderDark)),
                      onPressed: () => openAppSettings(),
                      child: const Text("Параметры Android"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Разработчики
          const Text("Команда разработчиков", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _devCard("Курбонов Б.", "Основатель & Lead System Architect", "Сетевое ядро с докачкой Range, расчёт скорости/ETA и интеграция YouTube Explode."),
          _devCard("Райская Ева", "Head of UI/UX Design", "Дизайн плавающего окна Share-Overlay, мини-плеера и графитового стиля."),
          _devCard("Сергей Александрович", "Core Media Engineer", "Обработка и декодирование аудио/видеопотоков без водяных знаков."),
          _devCard("Артём Волков", "Security & QA Architect", "Управление шторкой уведомлений, защита файлового кэша и фоновые процессы."),

          const SizedBox(height: 30),
          Center(
            child: Column(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: ObanColors.accentRed, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text("O", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
                ),
                const SizedBox(height: 8),
                const Text("obanstudio", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2, color: ObanColors.textPrimary)),
                const SizedBox(height: 4),
                const Text("Version 3.0.0 Pro Edition", style: TextStyle(fontSize: 11, color: ObanColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _devCard(String name, String role, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ObanColors.surfaceDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: ObanColors.borderDark)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(role, style: const TextStyle(color: ObanColors.accentRed, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(color: ObanColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
