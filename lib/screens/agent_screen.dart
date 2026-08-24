import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _commandController = TextEditingController();
  final _logController = TextEditingController();
  bool _isExecuting = false;

  @override
  void dispose() {
    _commandController.dispose();
    _logController.dispose();
    super.dispose();
  }

  void _log(String text) {
    _logController.text += '$text\n';
    setState(() {});
  }

  Future<void> _executeCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty || _isExecuting) return;
    _commandController.clear();
    setState(() => _isExecuting = true);
    _logController.clear();
    _log('▶️ Выполняется: $command');

    final app = Provider.of<AppProvider>(context, listen: false);

    try {
      // --- Wi-Fi ---
      if (command.contains('включи вайфай') || command.contains('включи wifi')) {
        final success = await app.setWiFi(true);
        _log(success ? '✅ Wi-Fi включён' : '❌ Не удалось включить Wi-Fi');
      } else if (command.contains('выключи вайфай') || command.contains('выключи wifi')) {
        final success = await app.setWiFi(false);
        _log(success ? '✅ Wi-Fi выключён' : '❌ Не удалось выключить Wi-Fi');
      }
      // --- Bluetooth ---
      else if (command.contains('включи блютуз') || command.contains('включи bluetooth')) {
        final success = await app.setBluetooth(true);
        _log(success ? '✅ Bluetooth включён' : '❌ Не удалось включить Bluetooth');
      } else if (command.contains('выключи блютуз') || command.contains('выключи bluetooth')) {
        final success = await app.setBluetooth(false);
        _log(success ? '✅ Bluetooth выключён' : '❌ Не удалось выключить Bluetooth');
      }
      // --- Фонарик ---
      else if (command.contains('включи фонарик')) {
        await app.toggleTorch();
        _log(app.torchOn ? '✅ Фонарик включён' : '✅ Фонарик выключён');
      } else if (command.contains('выключи фонарик')) {
        if (app.torchOn) {
          await app.toggleTorch();
          _log('✅ Фонарик выключён');
        } else {
          _log('ℹ️ Фонарик уже выключен');
        }
      }
      // --- Громкость ---
      else if (command.contains('громкость')) {
        final parts = command.split(' ');
        for (var p in parts) {
          if (p.endsWith('%')) {
            final value = int.tryParse(p.replaceAll('%', ''));
            if (value != null && value >= 0 && value <= 100) {
              await app.setVolume(value / 100);
              _log('✅ Громкость установлена на $value%');
            } else {
              _log('❌ Некорректное значение громкости');
            }
            break;
          }
        }
      }
      // --- Будильник ---
      else if (command.contains('будильник')) {
        final regex = RegExp(r'(\d{1,2}):(\d{2})');
        final match = regex.firstMatch(command);
        if (match != null) {
          final hour = int.parse(match.group(1)!);
          final minute = int.parse(match.group(2)!);
          String label = command.replaceAll(regex, '').trim();
          if (label.isEmpty) label = 'Будильник';
          await app.setAlarm(hour, minute, label);
          _log('✅ Будильник на $hour:$minute установлен');
        } else {
          _log('❌ Не удалось распознать время (формат ЧЧ:ММ)');
        }
      }
      // --- WhatsApp ---
      else if (command.contains('ватсап') || command.contains('whatsapp')) {
        final numbers = RegExp(r'\+?\d+').allMatches(command);
        if (numbers.isNotEmpty) {
          final phone = numbers.first.group(0)!;
          await app.openWhatsApp(phone);
          _log('✅ Открыт WhatsApp для номера $phone');
        } else {
          _log('❌ Номер не найден');
        }
      }
      // --- Telegram ---
      else if (command.contains('телеграм') || command.contains('telegram')) {
        final parts = command.split(' ');
        String? identifier;
        for (int i = 0; i < parts.length; i++) {
          if (parts[i].toLowerCase() == 'телеграм' || parts[i].toLowerCase() == 'telegram') {
            if (i + 1 < parts.length) {
              identifier = parts[i + 1];
              break;
            }
          }
        }
        if (identifier != null && identifier.isNotEmpty) {
          await app.openTelegram(identifier);
          _log('✅ Открыт Telegram для $identifier');
        } else {
          _log('❌ Не указан номер или юзернейм');
        }
      }
      // --- Чтение файла ---
      else if (command.startsWith('прочитай файл ')) {
        final path = command.substring('прочитай файл '.length).trim();
        try {
          final content = await app.readFile(path);
          _log('📄 Содержимое файла:\n$content');
        } catch (e) {
          _log('❌ Ошибка чтения: $e');
        }
      }
      // --- Создание заметки ---
      else if (command.startsWith('заметка ')) {
        final content = command.substring('заметка '.length).trim();
        if (content.isNotEmpty) {
          final path = await app.createNote('Заметка', content);
          _log('✅ Заметка сохранена: $path');
        } else {
          _log('❌ Нет текста заметки');
        }
      }
      // --- Открытие приложений ---
      else if (command.contains('открой') || command.contains('open')) {
        final parts = command.split(RegExp(r'\s+'));
        String? appName;
        for (int i = 0; i < parts.length; i++) {
          if (parts[i].toLowerCase() == 'открой' || parts[i].toLowerCase() == 'open') {
            if (i + 1 < parts.length) {
              appName = parts.sublist(i + 1).join(' ');
              break;
            }
          }
        }
        if (appName != null) {
          _log('🔍 Ищем приложение "$appName"...');
          try {
            final success = await app.openApp(appName);
            if (success) {
              _log('✅ Приложение открыто');
            } else {
              _log('❌ Не удалось открыть приложение');
            }
          } catch (e) {
            _log('❌ Ошибка: $e');
          }
        } else {
          _log('❌ Не указано имя приложения');
        }
      }
      // --- Звонок ---
      else if (command.contains('звонок') || command.contains('call')) {
        final number = command.replaceAll(RegExp(r'[^0-9+]'), '');
        if (number.isNotEmpty) {
          _log('📞 Звонок на $number...');
          final success = await app.callPhone(number);
          _log(success ? '✅ Звонок инициирован' : '❌ Не удалось позвонить');
        } else {
          _log('❌ Номер не найден');
        }
      }
      // --- SMS ---
      else if (command.contains('смс') || command.contains('sms')) {
        final parts = command.split(' ');
        String? phone;
        String? text;
        for (int i = 0; i < parts.length; i++) {
          if (parts[i].toLowerCase() == 'смс' || parts[i].toLowerCase() == 'sms') {
            if (i + 1 < parts.length) {
              phone = parts[i + 1].replaceAll(RegExp(r'[^0-9+]'), '');
              if (i + 2 < parts.length) {
                text = parts.sublist(i + 2).join(' ');
              }
            }
            break;
          }
        }
        if (phone != null && text != null) {
          _log('📤 Отправка SMS на $phone...');
          final success = await app.sendSms(phone, text);
          _log(success ? '✅ SMS открыто для отправки' : '❌ Не удалось отправить');
        } else {
          _log('❌ Не удалось распарсить команду SMS');
        }
      }
      // --- Сайт ---
      else if (command.contains('сайт') || command.contains('site')) {
        final parts = command.split(' ');
        String? url;
        for (int i = 0; i < parts.length; i++) {
          if (parts[i].toLowerCase() == 'сайт' || parts[i].toLowerCase() == 'site') {
            if (i + 1 < parts.length) {
              url = parts[i + 1];
              break;
            }
          }
        }
        if (url != null) {
          if (!url.startsWith('http')) url = 'https://$url';
          _log('🌐 Открытие сайта $url...');
          final success = await app.openWebsite(url);
          _log(success ? '✅ Сайт открыт' : '❌ Не удалось открыть');
        } else {
          _log('❌ URL не указан');
        }
      }
      // --- Файл (выбор) ---
      else if (command.contains('файл') || command.contains('file')) {
        _log('📂 Выбор файла...');
        final path = await app.pickFile();
        if (path != null) {
          _log('✅ Выбран файл: $path');
        } else {
          _log('❌ Файл не выбран');
        }
      }
      // --- Список приложений ---
      else if (command.contains('список приложений')) {
        _log('📱 Получение списка приложений...');
        final apps = await app.getInstalledApps();
        _log('Найдено ${apps.length} приложений:');
        for (var app in apps.take(10)) {
          _log('- ${app.appName}');
        }
        if (apps.length > 10) _log('... и еще ${apps.length - 10}');
      }
      // --- Если ничего не распознано, отправляем в ИИ ---
      else {
        _log('🤖 Команда не распознана. Отправляю в ИИ...');
        try {
          final response = await app.sendToAI(command);
          _log('💬 Ответ ИИ: $response');
        } catch (e) {
          _log('❌ Ошибка ИИ: $e');
        }
      }
    } catch (e) {
      _log('⚠️ Ошибка: $e');
    } finally {
      setState(() => _isExecuting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commandController,
                      decoration: const InputDecoration(
                        hintText: 'Введите команду...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _executeCommand(),
                    ),
                  ),
                  IconButton(
                    icon: _isExecuting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow, color: Color(0xFF3B82F6)),
                    onPressed: _isExecuting ? null : _executeCommand,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: Text(
                      _logController.text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
