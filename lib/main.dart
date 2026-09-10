import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'theme/app_theme.dart';
import 'models/download_item.dart';
import 'services/queue_manager.dart';
import 'services/notification_service.dart';
import 'widgets/video_player_modal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
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
        _showQuickDownloadModal(link, autoCloseAppOnSubmit: true);
      }
    } catch (_) {}
  }

  void _showQuickDownloadModal(String sharedUrl, {bool autoCloseAppOnSubmit = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ObanColors.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => QuickDownloadSheet(
        initialUrl: sharedUrl,
        autoCloseAppOnSubmit: autoCloseAppOnSubmit,
      ),
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
      HomeScreen(onOpenSheet: (url) => _showQuickDownloadModal(url, autoCloseAppOnSubmit: false)),
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
            BottomNavigationBarItem(icon: Icon(Icons.video_library_rounded), label: 'Галерея'),
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
      const SnackBar(content: Text("Добавлено в очередь. Прогресс в шторке уведомлений."), behavior: SnackBarBehavior.floating),
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
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("OBAN DOWNLOADER PRO", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  Text("Прямая загрузка • Поддержка YouTube & TikTok", style: TextStyle(fontSize: 12, color: ObanColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Поле ввода ссылки
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
                child: _pillBtn("Видео (MP4 со звуком)", Icons.movie_rounded, !_isAudio, () => setState(() => _isAudio = false)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pillBtn("Музыка (Чистый MP3)", Icons.music_note_rounded, _isAudio, () => setState(() => _isAudio = true)),
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
                Text(_isAudio ? "Битрейт:" : "Желаемое качество:", style: const TextStyle(fontSize: 13, color: ObanColors.textSecondary)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: ObanColors.surfaceDark,
                    value: _isAudio ? _audioQuality : _videoQuality,
                    items: (_isAudio ? ["320 kbps", "128 kbps"] : ["720p", "480p", "360p"]).map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
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
          const Text("Очередь и активные загрузки", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Список очередей с показом СКОРОСТИ и ТАЙМЕРА
          AnimatedBuilder(
            animation: QueueManager.instance,
            builder: (context, _) {
              final list = QueueManager.instance.items;
              if (list.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: ObanColors.surfaceDark, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text("Очередь пуста. Вставьте ссылку для начала.", style: TextStyle(color: ObanColors.textSecondary, fontSize: 13))),
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
            Text(text, style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? Colors.white : ObanColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueCard(DownloadItem item) {
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
                child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Text(item.quality, style: const TextStyle(fontSize: 11, color: ObanColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          if (item.status == DownloadStatus.downloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.progress > 0 ? item.progress : null,
                backgroundColor: ObanColors.cardDark,
                color: ObanColors.accentRed,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, size: 14, color: ObanColors.blueAccent),
                    const SizedBox(width: 4),
                    Text(item.speedFormatted, style: const TextStyle(color: ObanColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    const Icon(Icons.timer_outlined, size: 14, color: ObanColors.warning),
                    const SizedBox(width: 4),
                    Text("ост. ${item.etaFormatted}", style: const TextStyle(color: ObanColors.textSecondary, fontSize: 12)),
                  ],
                ),
                Text("${(item.progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ] else if (item.status == DownloadStatus.done) ...[
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: ObanColors.success, size: 16),
                SizedBox(width: 6),
                Text("Успешно сохранено в Галерею", style: TextStyle(color: ObanColors.success, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ] else if (item.status == DownloadStatus.error) ...[
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: ObanColors.accentRed, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(item.error ?? "Ошибка", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ObanColors.accentRed, fontSize: 12))),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => QueueManager.instance.removeItem(item.id),
              child: const Text("Удалить из списка", style: TextStyle(color: ObanColors.textSecondary, fontSize: 11)),
            ),
          )
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 2. БЫСТРОЕ МИНИ-ОКНО ПРИ НАЖАТИИ «ПОДЕЛИТЬСЯ»
// ─────────────────────────────────────────────
class QuickDownloadSheet extends StatefulWidget {
  final String initialUrl;
  final bool autoCloseAppOnSubmit;
  const QuickDownloadSheet({super.key, required this.initialUrl, this.autoCloseAppOnSubmit = false});

  @override
  State<QuickDownloadSheet> createState() => _QuickDownloadSheetState();
}

class _QuickDownloadSheetState extends State<QuickDownloadSheet> {
  bool _isAudio = false;
  String _quality = "720p";
  static const _platform = MethodChannel("com.obanstudio.downloader/shared");

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20, left: 20, right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: ObanColors.accentRed, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.downloading_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text("Быстрая загрузка", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 10),
          Text(widget.initialUrl, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ObanColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isAudio ? ObanColors.accentRed : ObanColors.cardDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => setState(() { _isAudio = false; _quality = "720p"; }),
                  child: const Text("Видео (со звуком)", style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAudio ? ObanColors.accentRed : ObanColors.cardDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => setState(() { _isAudio = true; _quality = "320 kbps"; }),
                  child: const Text("Музыка (MP3)", style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ObanColors.accentRed,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              QueueManager.instance.add(DownloadItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                url: widget.initialUrl,
                title: "Медиа из шеринга...",
                isAudio: _isAudio,
                quality: _quality,
              ));

              Navigator.pop(context);

              if (widget.autoCloseAppOnSubmit) {
                try {
                  await _platform.invokeMethod('minimizeApp');
                } catch (_) {}
              }
            },
            child: const Text("СКАЧАТЬ СЕЙЧАС (В ФОНЕ)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 3. ЭКРАН ГАЛЕРЕИ
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
        all.addAll(dir.listSync().where((f) => !f.path.endsWith('.part')));
      }
    }

    final ext = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final fallback = Directory("${ext.path}/OBAN_Downloads");
    if (await fallback.exists()) {
      all.addAll(fallback.listSync().where((f) => !f.path.endsWith('.part')));
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
            const Text("Автоматически синхронизировано с системной Галереей", style: TextStyle(fontSize: 12, color: ObanColors.textSecondary)),
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
// 4. РЕДИЗАЙН НАСТРОЕК С ОБЪЯСНЕНИЕМ ПРАВ
// ─────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _platform = MethodChannel("com.obanstudio.downloader/shared");
  double _storageMb = 0.0;
  bool _canOverlay = false;

  @override
  void initState() {
    super.initState();
    _calculateStorage();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final bool res = await _platform.invokeMethod('checkOverlayPermission') ?? false;
      setState(() => _canOverlay = res);
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
          const Text("Настройки и права", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // БЛОК: Поверх других приложений
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ObanColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _canOverlay ? ObanColors.success.withOpacity(0.5) : ObanColors.accentRed.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text("Отображение поверх других приложений", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _canOverlay ? ObanColors.success.withOpacity(0.2) : ObanColors.accentRed.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _canOverlay ? "ВКЛЮЧЕНО" : "ТРЕБУЕТСЯ",
                        style: TextStyle(color: _canOverlay ? ObanColors.success : ObanColors.accentRed, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "💡 Зачем это нужно:\nКогда вы нажимаете кнопку «Поделиться» в YouTube или TikTok и выбираете OBAN Downloader, приложение открывает компактное всплывающее окно прямо поверх видео. Вы выбираете формат (видео или MP3), нажимаете «Скачать», окно мгновенно закрывается, а загрузка продолжается в шторке. Вам не нужно сворачивать YouTube или прерывать просмотр!",
                  style: TextStyle(color: ObanColors.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: ObanColors.accentRed, foregroundColor: Colors.white),
                  onPressed: () async {
                    await _platform.invokeMethod('requestOverlayPermission');
                    Future.delayed(const Duration(seconds: 1), _checkPermissions);
                  },
                  icon: const Icon(Icons.layers_rounded, size: 18),
                  label: Text(_canOverlay ? "Проверить настройки" : "Включить режим «Поверх окон»"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // БЛОК: Уведомления и шторка
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ObanColors.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: ObanColors.borderDark)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Системные уведомления и прогресс-бар", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                const Text(
                  "Отображает в шторке Android текущую скорость загрузки (МБ/с), процент выполнения и таймер. По окончании отправляет уведомление со звуком, клик по которому сразу открывает скачанный файл.",
                  style: TextStyle(color: ObanColors.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: ObanColors.cardDark, foregroundColor: Colors.white),
                  onPressed: () async {
                    await Permission.notification.request();
                    await [Permission.storage, Permission.mediaLibrary].request();
                  },
                  child: const Text("Выдать разрешения на уведомления"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // БЛОК: Память
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ObanColors.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: ObanColors.borderDark)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Хранилище приложения", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Text("Занято скачанными медиа: ${_storageMb.toStringAsFixed(1)} МБ", style: const TextStyle(color: ObanColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: ObanColors.cardDark, foregroundColor: Colors.white),
                  onPressed: _clearCache,
                  icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                  label: const Text("Очистить временный кэш"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Разработчики
          const Text("Команда проекта", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _devCard("Курбонов Б.", "Lead Core Architect", "Ядро потоков googlevideo, докачка Range и нативный мост Android."),
          _devCard("Райская Ева", "UI/UX Designer", "Дизайн карточек скорости, шторки и модальных окон."),

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
                const Text("Version 2.5.1 Pro Edition", style: TextStyle(fontSize: 11, color: ObanColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 40),
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
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(role, style: const TextStyle(color: ObanColors.accentRed, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: ObanColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
