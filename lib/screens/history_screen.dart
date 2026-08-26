import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    final conversations = app.conversations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('История диалогов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Очистить историю?'),
                  content: const Text('Все диалоги будут удалены без возможности восстановления.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () {
                        final ids = conversations.map((c) => c.id).toList();
                        for (var id in ids) {
                          if (conversations.length > 1) {
                            app.deleteConversation(id);
                          } else {
                            final conv = app.activeConversation;
                            if (conv != null) {
                              conv.messages.clear();
                              conv.title = 'Новый диалог';
                              app.notifyChanges();
                            }
                          }
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('Удалить всё', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              app.createNewConversation();
              setState(() {});
            },
          ),
        ],
      ),
      body: conversations.isEmpty
          ? const Center(child: Text('Нет диалогов'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: conversations.length,
              itemBuilder: (_, i) {
                final conv = conversations[i];
                final isActive = conv.id == app.activeConversation?.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF2A2A2E) : const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(16),
                    border: isActive ? Border.all(color: const Color(0xFF3B82F6)) : null,
                  ),
                  child: ListTile(
                    title: Text(
                      conv.title,
                      style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
                    ),
                    subtitle: Text(
                      conv.messages.isNotEmpty
                          ? '${conv.messages.last.content.substring(0, conv.messages.last.content.length > 50 ? 50 : conv.messages.last.content.length)}...'
                          : 'Пусто',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) {
                        if (value == 'rename') {
                          _renameDialog(context, conv.id);
                        } else if (value == 'delete') {
                          app.deleteConversation(conv.id);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                        const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                      ],
                    ),
                    onTap: () {
                      app.switchConversation(conv.id);
                      setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }

  void _renameDialog(BuildContext context, String id) {
    final app = Provider.of<AppProvider>(context, listen: false);
    final conv = app.conversations.firstWhere((c) => c.id == id);
    final controller = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Переименовать диалог'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Новое название',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              app.renameConversation(id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
