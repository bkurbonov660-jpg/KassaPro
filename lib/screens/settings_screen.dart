import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = Provider.of<AppProvider>(context, listen: false);
    _apiKeyController.text = app.apiKey;
    _modelController.text = app.model;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('API и модель'),
          _buildApiKeyTile(app),
          _buildModelTile(app),
          _buildWebSearchTile(app),
          const SizedBox(height: 20),
          _buildSection('Разрешения'),
          ...app.permissions.map((p) => _buildPermissionTile(app, p)),
          const SizedBox(height: 20),
          _buildSection('Данные'),
          _buildClearDataTile(app),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildApiKeyTile(AppProvider app) {
    return Card(
      color: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('API ключ OpenRouter'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'sk-or-...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    app.setApiKey(_apiKeyController.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API ключ сохранён')),
                    );
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelTile(AppProvider app) {
    return Card(
      color: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Модель ИИ'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: app.model,
              items: const [
                DropdownMenuItem(value: 'openrouter/free', child: Text('Free Router (авто)')),
                DropdownMenuItem(value: 'stealth/ox-alpha', child: Text('Ox Alpha (stealth)')),
                DropdownMenuItem(value: 'nvidia/nemotron-3-ultra-550b-a55b:free', child: Text('Nemotron 3 Ultra')),
                DropdownMenuItem(value: 'z-ai/glm-5.2:free', child: Text('GLM 5.2')),
                DropdownMenuItem(value: 'deepseek/deepseek-v4:free', child: Text('DeepSeek V4')),
              ],
              onChanged: (val) {
                if (val != null) app.setModel(val);
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSearchTile(AppProvider app) {
    return Card(
      color: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: const Text('Веб-поиск'),
        subtitle: const Text('Использовать :online для актуальных данных'),
        value: app.webSearch,
        onChanged: (_) => app.toggleWebSearch(),
        secondary: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildPermissionTile(AppProvider app, PermissionItem p) {
    return Card(
      color: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(
          p.granted ? Icons.check_circle : Icons.circle_outlined,
          color: p.granted ? Colors.green : Colors.grey,
        ),
        title: Text(p.title),
        subtitle: Text(p.description, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!p.granted)
              TextButton(
                onPressed: () => app.requestPermission(p.type),
                child: const Text('Запросить'),
              ),
            TextButton(
              onPressed: () => app.openAppSettings(),
              child: const Text('Настройки'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearDataTile(AppProvider app) {
    return Card(
      color: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.delete_forever, color: Colors.red),
        title: const Text('Очистить все данные', style: TextStyle(color: Colors.red)),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Очистка данных'),
              content: const Text('Будут удалены все диалоги, настройки и API ключи. Продолжить?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    app.setApiKey('');
                    app.setModel('openrouter/free');
                    if (app.webSearch) app.toggleWebSearch();
                    final ids = app.conversations.map((c) => c.id).toList();
                    for (var id in ids) {
                      if (app.conversations.length > 1) {
                        app.deleteConversation(id);
                      } else {
                        final conv = app.activeConversation;
                        if (conv != null) {
                          conv.messages.clear();
                          conv.title = 'Новый диалог';
                          app.notifyListeners();
                        }
                      }
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Все данные очищены')),
                    );
                  },
                  child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
