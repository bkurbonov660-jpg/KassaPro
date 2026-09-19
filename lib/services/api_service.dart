import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const String _defaultEncodedKey =
      'c2stb3ItdjEtYjJiZjZjY2UyNGExOGRlMDYzN2I3M2FlNGZhZmQ4MmVkZGY4MDhkNjk4ZDk1NWIxOTdmNGMxNWM2NWE5ZjczOQ==';

  static const List<String> fallbackFreeModels = [
    'meta-llama/llama-3.2-3b-instruct:free',
    'google/gemini-2.0-flash-exp:free',
    'deepseek/deepseek-chat:free',
    'mistralai/mistral-7b-instruct:free',
    'qwen/qwen-2.5-72b-instruct:free',
    'meta-llama/llama-3.1-8b-instruct:free',
  ];

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = prefs.getString('custom_openrouter_key');
    if (customKey != null && customKey.trim().isNotEmpty) {
      return customKey.trim();
    }
    try {
      return utf8.decode(base64.decode(_defaultEncodedKey));
    } catch (_) {
      return '';
    }
  }

  static Future<List<String>> fetchFreeModels() async {
    try {
      final key = await getApiKey();
      final url = Uri.parse('https://openrouter.ai/api/v1/models');
      final res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $key',
          'User-Agent': 'SmartAINotify/1.1',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List items = data['data'] ?? [];
        final List<String> freeList = [];

        for (var m in items) {
          final String id = m['id'] ?? '';
          final pricing = m['pricing'];
          final bool isFreeId = id.endsWith(':free');
          final bool isZeroPrice = pricing != null &&
              pricing['prompt'].toString() == '0' &&
              pricing['completion'].toString() == '0';

          if (isFreeId || isZeroPrice) {
            freeList.add(id);
          }
        }

        if (freeList.isNotEmpty) {
          return freeList;
        }
      }
    } catch (_) {}
    return fallbackFreeModels;
  }

  static Future<Map<String, String>> generateSmartNotification({
    required String category,
    required String model,
    required String tone,
  }) async {
    final key = await getApiKey();
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final systemPrompt =
        'Ты генератор умных micro-уведомлений для смартфона. '
        'Стиль подачи: $tone. '
        'Сформулируй одно поразительное, точное и ёмкое озарение на русском языке по теме: "$category". '
        'Требования: '
        '1. Заголовок — 2-4 ярких слова. '
        '2. Текст — глубокий факт, мысль или парадокс (1-2 предложения, строго до 130 символов). '
        '3. Выдай СТРОГО чистый JSON формата: {"title": "Заголовок", "body": "Текст мысли"} без markdown блоков.';

    try {
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://smartai.app',
          'X-Title': 'Smart AI Notify',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': 'Сгенерируй новое уведомление.'}
          ],
          'max_tokens': 160,
          'temperature': 0.85,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          String raw = choices[0]['message']['content'] ?? '';
          raw = raw.replaceAll('```json', '').replaceAll('```', '').trim();

          final startIdx = raw.indexOf('{');
          final endIdx = raw.lastIndexOf('}');
          if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
            final jsonSub = raw.substring(startIdx, endIdx + 1);
            final parsed = jsonDecode(jsonSub);
            return {
              'title': parsed['title']?.toString() ?? '💡 Умная мысль',
              'body': parsed['body']?.toString() ?? 'Новое вдохновение от ИИ.',
            };
          }

          final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
          if (lines.length >= 2) {
            return {'title': lines[0].trim(), 'body': lines.sublist(1).join(' ').trim()};
          } else if (lines.isNotEmpty) {
            return {'title': '💡 AI Инсайт', 'body': lines[0].trim()};
          }
        }
      }
    } catch (_) {}

    return {
      'title': '⚡ Озарение: $category',
      'body': 'Каждый момент — это возможность узнать нечто совершенно новое.',
    };
  }

  static Future<String> sendChatMessage({
    required List<ChatMessage> history,
    required String userPrompt,
    required String model,
  }) async {
    final key = await getApiKey();
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            'Ты высокоинтеллектуальный, вежливый и точный AI-помощник. '
            'Отвечай чётко, информативно и понятно. '
            'Если вопрос касается науки, кода или философии, давай глубокий анализ.'
      },
    ];

    for (var msg in history.take(10)) {
      messages.add({'role': msg.role, 'content': msg.content});
    }
    messages.add({'role': 'user', 'content': userPrompt});

    try {
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://smartai.app',
          'X-Title': 'Smart AI Notify',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'max_tokens': 600,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content'] ?? 'Пустой ответ от модели.';
        }
      } else {
        return 'Ошибка API OpenRouter: [${res.statusCode}] ${res.body}';
      }
    } catch (e) {
      return 'Сетевая ошибка при обращении к ИИ: $e';
    }
    return 'Не удалось получить ответ от модели.';
  }
}
