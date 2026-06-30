import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';

class StorageService {
  static const _historyKey = 'downloader_history';
  static const _themeKey = 'is_dark_theme';
  static const _saveFolderKey = 'save_folder_path';
  static const _trafficLimitKey = 'traffic_limit_mb';
  static const _monthlyTrafficKey = 'monthly_traffic_bytes';
  static const _trafficMonthKey = 'traffic_month';

  static Future<List<DownloadItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_historyKey);
    if (data == null) return [];
    final List raw = jsonDecode(data);
    return raw.map((e) => DownloadItem.fromJson(e)).toList();
  }

  static Future<void> saveHistory(List<DownloadItem> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  static Future<bool> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? true;
  }

  static Future<void> saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  static Future<String?> getSaveFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_saveFolderKey);
  }

  static Future<void> setSaveFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveFolderKey, path);
  }

  static Future<int> getTrafficLimitMB() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_trafficLimitKey) ?? 0;
  }

  static Future<void> setTrafficLimitMB(int mb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_trafficLimitKey, mb);
  }

  static Future<int> getMonthlyTrafficBytes() async {
    final prefs = await SharedPreferences.getInstance();
    final currentMonth = DateTime.now().month.toString();
    final savedMonth = prefs.getString(_trafficMonthKey);
    if (savedMonth != currentMonth) {
      await prefs.setString(_trafficMonthKey, currentMonth);
      await prefs.setInt(_monthlyTrafficKey, 0);
      return 0;
    }
    return prefs.getInt(_monthlyTrafficKey) ?? 0;
  }

  static Future<void> addMonthlyTrafficBytes(int bytes) async {
    final current = await getMonthlyTrafficBytes();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_monthlyTrafficKey, current + bytes);
  }
}
