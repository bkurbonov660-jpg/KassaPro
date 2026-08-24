import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenRouterService {
  static const String baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static Future<String> sendMessage({
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    bool webSearch = false,
  }) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    String finalModel = model;
    if (webSearch && !model.endsWith(':online')) {
      finalModel = '$model:online';
    }

    final body = {
      'model': finalModel,
      'messages': messages,
      'stream': false,
    };

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception('API error: ${error['error']['message'] ?? response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] ?? '';
    return content;
  }
}
