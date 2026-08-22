import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/photo_provider.dart';
import '../widgets/qr_export_modal.dart';
import '../widgets/qr_import_modal.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<PhotoProvider>(context);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Язык
          Card(
            color: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translate(context, 'language'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _langButton(context, 'ru', 'Русский'),
                      const SizedBox(width: 8),
                      _langButton(context, 'tg', 'Тоҷикӣ'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Разработчики
          Card(
            color: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translate(context, 'developers'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  _devTile('Курбонов Б.', translate(context, 'role_ceo'), Icons.architecture),
                  _devTile('Райская Ева', translate(context, 'role_creative'), Icons.brush),
                  _devTile('Александр Смирнов', translate(context, 'role_lead_dev'), Icons.code),
                  _devTile('Дмитрий Петров', translate(context, 'role_uiux'), Icons.design_services),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Кнопка "О приложении"
          Card(
            color: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blueAccent),
              title: Text(translate(context, 'about_title')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
            ),
          ),
          const SizedBox(height: 20),

          // QR-обмен
          Card(
            color: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translate(context, 'qr_exchange'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: app.photos.isEmpty
                              ? null
                              : () => showDialog(
                                    context: context,
                                    builder: (_) => QRExportModal(
                                      data: app.exportTextData(),
                                      title: translate(context, 'export_qr_title'),
                                    ),
                                  ),
                          icon: const Icon(Icons.qr_code),
                          label: Text(translate(context, 'export_qr')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => QRImportModal(
                              onImport: (data) {
                                try {
                                  app.importTextData(data);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(translate(context, 'import_success'))),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${translate(context, 'import_error')}: $e')),
                                  );
                                }
                              },
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(translate(context, 'import_qr')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Полный экспорт/импорт
          Card(
            color: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translate(context, 'full_export'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: app.photos.isEmpty
                              ? null
                              : () async {
                                  final dir = await app.exportFullDatabase();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${translate(context, 'exported_to')}: $dir')),
                                  );
                                },
                          icon: const Icon(Icons.folder_open),
                          label: Text(translate(context, 'export_folder')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.getDirectoryPath();
                            if (result != null) {
                              try {
                                await app.importFullDatabase(result);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(translate(context, 'import_success'))),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${translate(context, 'import_error')}: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.upload_file),
                          label: Text(translate(context, 'import_folder')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC4899),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Очистка
          Card(
            color: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(translate(context, 'clear_all_title')),
                        content: Text(translate(context, 'clear_all_confirm')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(translate(context, 'cancel')),
                          ),
                          TextButton(
                            onPressed: () {
                              app.clearAll();
                              Navigator.pop(context);
                            },
                            child: Text(translate(context, 'delete'), style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_forever),
                  label: Text(translate(context, 'clear_all')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _devTile(String name, String role, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(role, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _langButton(BuildContext context, String lang, String label) {
    final app = Provider.of<PhotoProvider>(context, listen: false);
    final isActive = app.language == lang;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => app.setLanguage(lang),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? const Color(0xFF3B82F6) : const Color(0xFF27272A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label),
      ),
    );
  }

  String translate(BuildContext context, String key) {
    final app = Provider.of<PhotoProvider>(context, listen: false);
    final dict = {
      'ru': {
        'language': 'Язык интерфейса',
        'developers': 'Разработчики',
        'role_ceo': 'Основатель и CEO',
        'role_creative': 'Креативный директор',
        'role_lead_dev': 'Ведущий разработчик',
        'role_uiux': 'UI/UX дизайнер',
        'qr_exchange': 'Обмен данными (текст)',
        'export_qr': 'Экспорт QR',
        'import_qr': 'Импорт QR',
        'export_qr_title': 'Экспорт данных (QR)',
        'import_success': 'Данные импортированы',
        'import_error': 'Ошибка импорта',
        'full_export': 'Полный экспорт/импорт (с фото)',
        'export_folder': 'Экспорт папки',
        'import_folder': 'Импорт папки',
        'exported_to': 'Экспортировано в',
        'clear_all': 'Очистить все',
        'clear_all_title': 'Очистка всех данных?',
        'clear_all_confirm': 'Будут удалены все фотографии и метаданные.',
        'delete': 'Удалить',
        'cancel': 'Отмена',
        'about_title': 'О приложении',
      },
      'tg': {
        'language': 'Забони барнома',
        'developers': 'Таҳиягарон',
        'role_ceo': 'Асосгузор ва CEO',
        'role_creative': 'Директори эҷодӣ',
        'role_lead_dev': 'Таҳиягари пешбари',
        'role_uiux': 'Дизайнери UI/UX',
        'qr_exchange': 'Мубодилаи маълумот (матн)',
        'export_qr': 'Экспорти QR',
        'import_qr': 'Импорти QR',
        'export_qr_title': 'Экспорти маълумот (QR)',
        'import_success': 'Маълумот ворид шуд',
        'import_error': 'Хатои импорт',
        'full_export': 'Экспорт/импорти пурра (бо акс)',
        'export_folder': 'Экспорти папка',
        'import_folder': 'Импорти папка',
        'exported_to': 'Экспорт ба',
        'clear_all': 'Тоза кардани ҳама',
        'clear_all_title': 'Тоза кардани ҳамаи маълумот?',
        'clear_all_confirm': 'Ҳамаи аксҳо ва метамаълумотҳо нест карда мешаванд.',
        'delete': 'Нест кардан',
        'cancel': 'Бекор',
        'about_title': 'Дар бораи барнома',
      },
    };
    return dict[app.language]?[key] ?? key;
  }
}
