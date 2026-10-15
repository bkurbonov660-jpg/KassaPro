import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'net.dart';
import 'secrets.dart';

class OpenRouter {
  static String key = Secrets.openRouterKey;
  static bool webPlugin = false;
  static bool badKey = false;
  static bool lastOk = false;
  static String lastModel = '';
  static String lastError = '';
  static List<String> _free = [];
  static final Map<String, int> _bad = {};

  static const List<String> _fallbackModels = [
    'openrouter/free',
    'deepseek/deepseek-chat-v3-0324:free',
    'meta-llama/llama-3.3-70b-instruct:free',
    'google/gemma-3-27b-it:free',
    'qwen/qwen3-235b-a22b:free',
    'openai/gpt-oss-20b:free',
    'mistralai/mistral-small-3.2-24b-instruct:free',
  ];

  static int _score(String id) {
    const pref = ['deepseek','llama-3.3','gpt-oss','qwen','gemma','mistral','glm','kimi','llama','nemotron'];
    for (var i = 0; i < pref.length; i++) { if (id.contains(pref[i])) return i; }
    return 50;
  }

  static Future<List<String>> freeModels() async {
    if (_free.isNotEmpty) return _free;
    final out = <String>[];
    final j = await Net.json(Uri.parse('https://openrouter.ai/api/v1/models'), retries: 1);
    if (j is Map && j['data'] is List) {
      for (final m in j['data'] as List) {
        if (m is! Map) continue;
        final id = (m['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final p = m['pricing'];
        final free = id.endsWith(':free') ||
            (p is Map && p['prompt'].toString() == '0' && p['completion'].toString() == '0');
        if (!free) continue;
        if (RegExp(r'vision|image|embed|guard|moderation|audio|vl', caseSensitive: false).hasMatch(id)) continue;
        out.add(id);
      }
    }
    out.sort((a, b) => _score(a).compareTo(_score(b)));
    for (final f in _fallbackModels) { if (!out.contains(f)) out.add(f); }
    _free = out;
    return _free;
  }

  static String _strip(String s) => s.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();

  static dynamic extractJson(String s) {
    final t = _strip(s);
    final a = t.indexOf('['); final b = t.lastIndexOf(']');
    if (a >= 0 && b > a) { try { return jsonDecode(t.substring(a, b + 1)); } catch (_) {} }
    final c = t.indexOf('{'); final d = t.lastIndexOf('}');
    if (c >= 0 && d > c) { try { return jsonDecode(t.substring(c, d + 1)); } catch (_) {} }
    return null;
  }

  static Future<String?> chat(String system, String user, {int maxTokens = 900}) async {
    if (key.trim().isEmpty || badKey) return null;
    final models = await freeModels();
    var tried = 0;
    for (final m in models) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if ((_bad[m] ?? 0) > now) continue;
      if (++tried > 6) break;
      try {
        final body = <String, dynamic>{
          'model': m,
          'messages': [
            {'role': 'system', 'content': system},
            {'role': 'user', 'content': user},
          ],
          'temperature': 0.3, 'max_tokens': maxTokens,
        };
        if (webPlugin) body['plugins'] = [{'id': 'web', 'max_results': 3}];
        final r = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${key.trim()}',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://github.com/bkurbonov660-jpg/KassaPro',
            'X-Title': 'Dorama Pulse',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 60));
        if (r.statusCode == 200) {
          final j = jsonDecode(utf8.decode(r.bodyBytes));
          final c = (j is Map && j['choices'] is List && (j['choices'] as List).isNotEmpty)
              ? ((j['choices'] as List)[0] as Map)['message'] : null;
          final txt = c is Map ? c['content'] : null;
          if (txt is String && _strip(txt).isNotEmpty) {
            lastOk = true; lastModel = m; lastError = '';
            return _strip(txt);
          }
          _bad[m] = now + 5 * 60000; continue;
        }
        if (r.statusCode == 401) { badKey = true; lastOk = false; lastError = 'Ключ не принят'; return null; }
        lastError = 'HTTP ${r.statusCode}';
        _bad[m] = now + (r.statusCode == 429 ? 90000 : 10 * 60000);
      } catch (_) {
        lastError = 'Нет связи с OpenRouter';
        _bad[m] = now + 2 * 60000;
      }
    }
    lastOk = false;
    return null;
  }

  static void resetErrors() { _bad.clear(); badKey = false; _free = []; }
}
