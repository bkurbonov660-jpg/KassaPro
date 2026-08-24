import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class StorageService {
  static const String _apiKeyKey = 'ai_tols_api_key';
  static const String _modelKey = 'ai_tols_model';
  static const String _webSearchKey = 'ai_tols_websearch';
  static const String _conversationsKey = 'ai_tols_conversations';
  static const String _activeConvKey = 'ai_tols_active_conv';

  static Future<String> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? '';
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
  }

  static Future<String> loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelKey) ?? 'openrouter/free';
  }

  static Future<void> saveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, model);
  }

  static Future<bool> loadWebSearch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_webSearchKey) ?? false;
  }

  static Future<void> saveWebSearch(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_webSearchKey, enabled);
  }

  static Future<List<Conversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_conversationsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => Conversation.fromJson(e)).toList();
  }

  static Future<void> saveConversations(List<Conversation> convs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_conversationsKey, jsonEncode(convs.map((c) => c.toJson()).toList()));
  }

  static Future<String> loadActiveConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeConvKey) ?? '';
  }

  static Future<void> saveActiveConversationId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeConvKey, id);
  }
}
