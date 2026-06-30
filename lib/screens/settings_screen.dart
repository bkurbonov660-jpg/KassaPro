import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/download_provider.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _saveFolder;
  int _trafficLimitMB = 0;
  final TextEditingController _limitController = TextEditingController();
  int _usedMB = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final path = await StorageService.getSaveFolder();
    final limit = await StorageService.getTrafficLimitMB();
    final usedBytes = await StorageService.getMonthlyTrafficBytes();
    setState(() {
      _saveFolder = path;
      _trafficLimitMB = limit;
      _usedMB = (usedBytes / (1024 * 1024)).round();
      _limitController.text = limit > 0 ? limit.toString() : '';
    });
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      await StorageService.setSaveFolder(result);
      setState(() => _saveFolder = result);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Папка сохранения обновлена'), backgroundColor: Colors.green));
    }
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [Permission.storage, Permission.manageExternalStorage, Permission.videos, Permission.audio, Permission.photos].request();
    bool isGranted = statuses.values.any((status) => status.isGranted);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isGranted ? '✅ Разрешения предоставлены' : '❌ Доступ отклонен'),
      backgroundColor: isGranted ? Colors.green : Colors.redAccent,
    ));
  }

  Future<void> _saveTrafficLimit() async {
    final text = _limitController.text.trim();
    int limit = 0;
    if (text.isNotEmpty) {
      final parsed = int.tryParse(text);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите корректное число'), backgroundColor: Colors.redAccent));
        return;
      }
      limit = parsed;
    }
    await StorageService.setTrafficLimitMB(limit);
    setState(() => _trafficLimitMB = limit);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Лимит ${limit > 0 ? "$limit МБ" : "отключён"}'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final isDark = provider.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Настройки', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          _buildCard(isDark, child: SwitchListTile(
            title: const Text('Тёмная тема', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Включить неоновый стиль'),
            value: isDark, activeColor: const Color(0xFF00E5FF),
            onChanged: (v) => provider.toggleTheme(v),
          )),
          const SizedBox(height: 16),
          _buildCard(isDark, child: ListTile(
            leading: const Icon(Icons.folder, color: Colors.blueAccent),
            title: const Text('Папка сохранения', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(_saveFolder ?? 'По умолчанию (Downloads)', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            trailing: IconButton(icon: const Icon(Icons.folder_open, color: Colors.blueAccent), onPressed: _pickFolder),
          )),
          const SizedBox(height: 16),
          _buildCard(isDark, child: ListTile(
            leading: const Icon(Icons.security, color: Colors.orangeAccent),
            title: const Text('Разрешения', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Управление доступом к файлам'),
            trailing: IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: _checkPermissions),
          )),
          const SizedBox(height: 16),
          _buildCard(isDark, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Text('Лимит трафика (МБ в месяц)', style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black))),
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Row(children: [
                Expanded(child: TextField(controller: _limitController, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(hintText: '500', hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600), filled: true,
                        fillColor: isDark ? const Color(0xFF12122A) : Colors.grey.shade200, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _saveTrafficLimit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Сохранить')),
              ])),
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: Text('Использовано в этом месяце: $_usedMB МБ ${_trafficLimitMB > 0 ? 'из $_trafficLimitMB МБ' : ''}',
                  style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600))),
            ],
          )),
          const SizedBox(height: 16),
          _buildCard(isDark, child: const ListTile(
            leading: Icon(Icons.info, color: Colors.purpleAccent),
            title: Text('О приложении', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Версия 5.2 — полный рабочий билд'),
          )),
        ],
      ),
    );
  }

  Widget _buildCard(bool isDark, {required Widget child}) {
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: isDark ? const Color(0xFF1E1E2E) : Colors.white, elevation: 2, child: child);
  }
}
