import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:torch_controller/torch_controller.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_apps/device_apps.dart';
import 'package:file_picker/file_picker.dart';
import '../models/chat_message.dart';
import '../models/setting_item.dart';
import '../services/storage_service.dart';
import '../services/openrouter_service.dart';
import '../services/permission_service.dart';

class AppProvider extends ChangeNotifier {
  final TorchController _torchController = TorchController();
  bool _torchOn = false;

  String _apiKey = '';
  String _model = 'openrouter/free';
  bool _webSearch = false;
  List<Conversation> _conversations = [];
  String _activeConvId = '';
  List<PermissionItem> _permissions = [];

  String get apiKey => _apiKey;
  String get model => _model;
  bool get webSearch => _webSearch;
  List<Conversation> get conversations => _conversations;
  Conversation? get activeConversation {
    try {
      return _conversations.firstWhere((c) => c.id == _activeConvId);
    } catch (_) {
      return null;
    }
  }
  List<PermissionItem> get permissions => _permissions;
  bool get torchOn => _torchOn;

  Future<void> init() async {
    _apiKey = await StorageService.loadApiKey();
    _model = await StorageService.loadModel();
    _webSearch = await StorageService.loadWebSearch();
    _conversations = await StorageService.loadConversations();
    _activeConvId = await StorageService.loadActiveConversationId();

    if (_activeConvId.isEmpty || activeConversation == null) {
      createNewConversation();
    }

    await refreshPermissions();
    notifyListeners();
  }

  Future<void> refreshPermissions() async {
    final statuses = await PermissionService.getAllStatuses();
    _permissions = PermissionService.getPermissionItems();
    for (var p in _permissions) {
      p.granted = statuses[p.type] ?? false;
    }
    notifyListeners();
  }

  Future<void> requestPermission(PermissionType type) async {
    await PermissionService.requestPermission(type);
    await refreshPermissions();
  }

  Future<void> openAppSettings() async {
    await PermissionService.openAppSettings();
    await refreshPermissions();
  }

  void setApiKey(String key) {
    _apiKey = key;
    StorageService.saveApiKey(key);
    notifyListeners();
  }

  void setModel(String model) {
    _model = model;
    StorageService.saveModel(model);
    notifyListeners();
  }

  void toggleWebSearch() {
    _webSearch = !_webSearch;
    StorageService.saveWebSearch(_webSearch);
    notifyListeners();
  }

  void createNewConversation() {
    final conv = Conversation(id: DateTime.now().millisecondsSinceEpoch.toString());
    _conversations.insert(0, conv);
    _activeConvId = conv.id;
    _saveConversations();
  }

  void switchConversation(String id) {
    if (_conversations.any((c) => c.id == id)) {
      _activeConvId = id;
      StorageService.saveActiveConversationId(id);
      notifyListeners();
    }
  }

  void deleteConversation(String id) {
    _conversations.removeWhere((c) => c.id == id);
    if (_activeConvId == id) {
      _activeConvId = _conversations.isNotEmpty ? _conversations.first.id : '';
      if (_activeConvId.isEmpty) {
        createNewConversation();
      }
    }
    _saveConversations();
  }

  void renameConversation(String id, String newTitle) {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index != -1) {
      _conversations[index].title = newTitle.trim().isEmpty ? 'Диалог' : newTitle.trim();
      _saveConversations();
    }
  }

  void addMessage(ChatMessage message) {
    final conv = activeConversation;
    if (conv != null) {
      conv.messages.add(message);
      if (conv.messages.length == 1 && message.role == 'user') {
        conv.title = message.content.length > 30
            ? message.content.substring(0, 30) + '…'
            : message.content;
      }
      _saveConversations();
    }
  }

  Future<String> sendToAI(String userMessage) async {
    if (_apiKey.isEmpty) {
      throw Exception('API ключ не задан');
    }

    final conv = activeConversation;
    if (conv == null) throw Exception('Нет активного диалога');

    final userMsg = ChatMessage(role: 'user', content: userMessage);
    addMessage(userMsg);

    final historyMessages = conv.messages.map((m) {
      return {'role': m.role, 'content': m.content};
    }).toList();

    try {
      final response = await OpenRouterService.sendMessage(
        apiKey: _apiKey,
        model: _model,
        messages: historyMessages,
        webSearch: _webSearch,
      );

      final assistantMsg = ChatMessage(role: 'assistant', content: response);
      addMessage(assistantMsg);
      return response;
    } catch (e) {
      conv.messages.removeLast();
      _saveConversations();
      rethrow;
    }
  }

  void _saveConversations() {
    StorageService.saveConversations(_conversations);
    StorageService.saveActiveConversationId(_activeConvId);
    notifyListeners();
  }

  void notifyChanges() {
    notifyListeners();
  }

  // ==================== НОВЫЕ МЕТОДЫ ====================

  // ---- Управление Wi-Fi (через wifi_iot) ----
  Future<bool> setWiFi(bool enabled) async {
    try {
      if (enabled) {
        await WiFiForIoTPlugin.setEnabled(true);
      } else {
        await WiFiForIoTPlugin.setEnabled(false);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---- Управление Bluetooth ----
  Future<bool> setBluetooth(bool enabled) async {
    try {
      if (enabled) {
        await FlutterBluePlus.turnOn();
      } else {
        // Not calling turnOff, as it is deprecated and typically not allowed
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---- Фонарик ----
  Future<void> toggleTorch() async {
    if (_torchOn) {
      await _torchController.toggle();
      _torchOn = false;
    } else {
      await _torchController.toggle();
      _torchOn = true;
    }
    notifyListeners();
  }

  // ---- Громкость (исправлено) ----
  Future<void> setVolume(double volume) async {
    await FlutterVolumeController.setVolume(volume.clamp(0.0, 1.0));
  }

  // ---- Будильник (через Intent) ----
  Future<void> setAlarm(int hour, int minute, String label) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: {
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minute,
        'android.intent.extra.alarm.MESSAGE': label,
        'android.intent.extra.alarm.SKIP_UI': false,
      },
    );
    await intent.launch();
  }

  // ---- Открыть WhatsApp ----
  Future<void> openWhatsApp(String phone) async {
    final url = 'whatsapp://send?phone=$phone';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('WhatsApp не установлен');
    }
  }

  // ---- Открыть Telegram ----
  Future<void> openTelegram(String identifier) async {
    String url;
    if (identifier.startsWith('@')) {
      url = 'tg://resolve?domain=${identifier.substring(1)}';
    } else {
      url = 'tg://resolve?phone=$identifier';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Telegram не установлен');
    }
  }

  // ---- Работа с файлами ----
  Future<String> readFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsString();
    } else {
      throw Exception('Файл не найден');
    }
  }

  Future<void> writeFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  Future<String> createNote(String title, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$title.txt';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
    return file.path;
  }

  // ---- Открыть приложение ----
  Future<bool> openApp(String appName) async {
    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      final found = apps.firstWhere(
        (app) => app.appName.toLowerCase().contains(appName.toLowerCase()),
        orElse: () => throw Exception('Приложение не найдено'),
      );
      return await DeviceApps.openApp(found.packageName);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Application>> getInstalledApps() async {
    return await DeviceApps.getInstalledApplications(
      includeSystemApps: false,
      onlyAppsWithLaunchIntent: true,
    );
  }

  Future<bool> sendSms(String phone, String message) async {
    final url = 'sms:$phone?body=${Uri.encodeComponent(message)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
      return true;
    }
    return false;
  }

  Future<bool> callPhone(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
      return true;
    }
    return false;
  }

  Future<bool> openWebsite(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  Future<String?> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      return result.files.first.path;
    }
    return null;
  }
}
