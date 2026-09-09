import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'theme/app_theme.dart';
import 'services/media_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentTab = 0;
  static const _platformChannel = MethodChannel("com.obanstudio.downloader/shared");
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkSharedIntent();
  }

  Future<void> _checkSharedIntent() async {
    try {
      final String? link = await _platformChannel.invokeMethod('getSharedLink');
      if (link != null && link.isNotEmpty) {
        setState(() {
          _urlController.text = link;
          _currentTab = 0;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(controller: _urlController),
      const LibraryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_currentTab],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: ObanColors.surfaceDark,
          border: Border(top: BorderSide(color: ObanColors.borderDark, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          backgroundColor: Colors.transparent,
          selectedItemColor: ObanColors.accentRed,
          unselectedItemColor: ObanColors.textSecondary,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.cloud_download_rounded), label: 'Главная'),
            BottomNavigationBarItem(icon: Icon(Icons.folder_copy_rounded), label: 'Файлы'),
            BottomNavigationBarItem(icon: Icon(Icons.tune_rounded), label: 'Настройки'),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final TextEditingController controller;
  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _format = 0; // 0 = Video, 1 = MP3
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = "";
  String? _aiText;

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      widget.controller.text = data!.text!;
    }
  }

  Future<void> _startDownload() async {
    final url = widget.controller.text.trim();
    if (url.isEmpty) {
      _showMsg("Вставьте ссылку на медиа");
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = "Анализ медиапотока...";
      _aiText = null;
    });

    try {
      String downloadUrl = url;
      String filename = "media_${DateTime.now().millisecondsSinceEpoch}.${_format == 1 ? 'mp3' : 'mp4'}";
      String title = "Медиафайл";

      if (url.contains("tiktok.com")) {
        final info = await MediaService.fetchTikTokMedia(url);
        if (info != null) {
          title = info['title'] ?? title;
          downloadUrl = _format == 1 ? (info['audioUrl'] ?? info['videoUrl']) : info['videoUrl'];
          filename = "${title.replaceAll(RegExp(r'[^\w\s]+'), '')}.${_format == 1 ? 'mp3' : 'mp4'}";
        }
      }

      setState(() => _statusText = "Загрузка файла...");
      final file = await MediaService.downloadFile(
        downloadUrl: downloadUrl,
        fileName: filename,
        onProgress: (p) => setState(() => _progress = p),
      );

      if (file != null) {
        setState(() => _statusText = "Файл успешно сохранён!");
        _showMsg("Сохранено: $filename");
        
        final aiRes = await MediaService.getAiInsight(title);
        setState(() => _aiText = aiRes);
      } else {
        setState(() => _statusText = "Не удалось скачать поток");
      }
    } catch (e) {
      setState(() => _statusText = "Ошибка: $e");
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  void _showMsg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: ObanColors.cardDark,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  Text("Профессиональный медиа-центр", style: TextStyle(fontSize: 12, color: ObanColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: ObanColors.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ObanColors.borderDark),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: "Вставьте ссылку YouTube / TikTok...",
                      hintStyle: TextStyle(color: ObanColors.textSecondary, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _pasteLink,
                  icon: const Icon(Icons.paste_rounded, color: ObanColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _formatBtn("Видео (MP4)", Icons.video_collection_rounded, _format == 0, () => setState(() => _format = 0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _formatBtn("Аудио (MP3)", Icons.graphic_eq_rounded, _format == 1, () => setState(() => _format = 1)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isDownloading ? null : _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: ObanColors.accentRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isDownloading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("СКАЧАТЬ СЕЙЧАС", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Colors.white)),
          ),
          if (_isDownloading || _statusText.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ObanColors.surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ObanColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusText, style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: _progress > 0 ? _progress : null, backgroundColor: ObanColors.cardDark, color: ObanColors.accentRed),
                  if (_progress > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text("${(_progress * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12, color: ObanColors.textSecondary)),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_aiText != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ObanColors.surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ObanColors.accentRed.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: ObanColors.accentRed, size: 18),
                      SizedBox(width: 8),
                      Text("ИИ Ассистент (OpenRouter)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ObanColors.accentRed)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_aiText!, style: const TextStyle(fontSize: 13, color: ObanColors.textPrimary)),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _formatBtn(String title, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? ObanColors.accentRed.withOpacity(0.15) : ObanColors.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? ObanColors.accentRed : ObanColors.borderDark),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: active ? ObanColors.accentRed : ObanColors.textSecondary),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: active ? Colors.white : ObanColors.textSecondary, fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
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
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final saveDir = Directory("${dir.path}/OBAN_Downloads");
    if (await saveDir.exists()) {
      setState(() {
        _files = saveDir.listSync().reversed.toList();
      });
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
            const Text("Загруженные файлы", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: _files.isEmpty
                  ? const Center(child: Text("Нет загруженных файлов", style: TextStyle(color: ObanColors.textSecondary)))
                  : ListView.separated(
                      itemCount: _files.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final file = _files[i];
                        final name = file.path.split('/').last;
                        final isAudio = name.endsWith('.mp3');

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ObanColors.surfaceDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ObanColors.borderDark),
                          ),
                          child: Row(
                            children: [
                              Icon(isAudio ? Icons.audiotrack_rounded : Icons.movie_rounded, color: ObanColors.accentRed),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                onPressed: () => OpenFilex.open(file.path),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: ObanColors.textSecondary),
                                onPressed: () { file.deleteSync(); _loadFiles(); },
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _requestPermissions(BuildContext context) async {
    await [Permission.storage, Permission.notification].request();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Разрешения проверены"),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Настройки", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ObanColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ObanColors.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Системные разрешения", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text("Доступ к хранилищу для сохранения видео и аудио файлов.", style: TextStyle(color: ObanColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: ObanColors.cardDark, foregroundColor: Colors.white),
                  onPressed: () => _requestPermissions(context),
                  icon: const Icon(Icons.security_rounded, size: 18),
                  label: const Text("Проверить доступ"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Команда разработчиков", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _devCard("Курбонов Б.", "Основатель & Lead System Architect", "Архитектура ядра приложения, сетевые сервисы и автоматизация сборки."),
          _devCard("Райская Ева", "Head of UI/UX Design", "Дизайн строгой графитовой темы и эргономика мобильных экранов."),
          _devCard("Сергей Александрович", "Core Media Engineer", "Парсинг медиапотоков, конвертация аудио и интеграция API."),
          _devCard("Артём Волков", "Security & QA Architect", "Защита локальных данных, управление правами доступа и стабильность."),
          const SizedBox(height: 30),
          Center(
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: ObanColors.accentRed, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text("O", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
                ),
                const SizedBox(height: 8),
                const Text("obanstudio", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2, color: ObanColors.textPrimary)),
                const SizedBox(height: 4),
                const Text("Version 1.0.0 Pro Edition", style: TextStyle(fontSize: 11, color: ObanColors.textSecondary)),
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
      decoration: BoxDecoration(
        color: ObanColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ObanColors.borderDark),
      ),
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
