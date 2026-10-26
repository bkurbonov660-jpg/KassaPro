import 'package:flutter/services.dart';

// Мост к Android-коду (MainActivity.kt): уведомления и системные диалоги файлов.
class Native {
  static const MethodChannel _c = MethodChannel('dp/native');

  static Future<bool> notifPermission() async {
    try {
      return (await _c.invokeMethod<bool>('notifPermission')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> notifSchedule(String json) async {
    try {
      return (await _c.invokeMethod<bool>('notifSchedule', json)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> notifCancel() async {
    try {
      return (await _c.invokeMethod<bool>('notifCancel')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> notifShow(int id, String title, String body) async {
    try {
      final r = await _c.invokeMethod<bool>('notifShow', <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
      });
      return r ?? false;
    } catch (_) {
      return false;
    }
  }

  // Системное меню «Сохранить как…». true — файл записан.
  static Future<bool> saveFile(String name, String text) async {
    try {
      final r = await _c.invokeMethod<bool>('saveFile', <String, String>{'name': name, 'text': text});
      return r ?? false;
    } catch (_) {
      return false;
    }
  }

  // Системный выбор файла. null — ничего не выбрано или файл не прочитан.
  static Future<String?> pickFile() async {
    try {
      return await _c.invokeMethod<String>('pickFile');
    } catch (_) {
      return null;
    }
  }

  // Файлы во внутренней папке приложения: надёжнее SharedPreferences для больших данных.
  static Future<bool> fileWrite(String name, String text) async {
    try {
      return (await _c.invokeMethod<bool>('fileWrite', <String, String>{'name': name, 'text': text})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> fileRead(String name) async {
    try {
      return await _c.invokeMethod<String>('fileRead', name);
    } catch (_) {
      return null;
    }
  }

  // Нативное хранилище настроек Android (без сбоев плагина shared_preferences и R8).
  static Future<Map<String, String>> prefsAll() async {
    try {
      final r = await _c.invokeMapMethod<String, String>('prefsAll');
      return r ?? <String, String>{};
    } catch (_) {
      return <String, String>{};
    }
  }

  static Future<bool> prefWrite(String key, String value) async {
    try {
      return (await _c.invokeMethod<bool>('prefWrite', <String, String>{'key': key, 'value': value})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> prefRemove(String key) async {
    try {
      return (await _c.invokeMethod<bool>('prefRemove', key)) ?? false;
    } catch (_) {
      return false;
    }
  }

  // Открывает ссылку (Telegram или браузер). false — не удалось.
  static Future<bool> openUrl(String url) async {
    try {
      return (await _c.invokeMethod<bool>('openUrl', url)) ?? false;
    } catch (_) {
      return false;
    }
  }

  // Открывает почтовое приложение с готовым письмом. false — почты нет.
  static Future<bool> sendMail(String to, String subject, String body) async {
    try {
      final r = await _c.invokeMethod<bool>('sendMail',
          <String, String>{'to': to, 'subject': subject, 'body': body});
      return r ?? false;
    } catch (_) {
      return false;
    }
  }
}
