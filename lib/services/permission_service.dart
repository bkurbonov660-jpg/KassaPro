import 'package:permission_handler/permission_handler.dart';
import '../models/setting_item.dart';

class PermissionService {
  static List<PermissionItem> getPermissionItems() {
    return [
      PermissionItem(
        type: PermissionType.camera,
        title: 'Камера',
        description: 'Для сканирования QR-кодов и фото',
      ),
      PermissionItem(
        type: PermissionType.microphone,
        title: 'Микрофон',
        description: 'Для голосового ввода',
      ),
      PermissionItem(
        type: PermissionType.contacts,
        title: 'Контакты',
        description: 'Для отправки сообщений контактам',
      ),
      PermissionItem(
        type: PermissionType.storage,
        title: 'Хранилище',
        description: 'Для доступа к файлам',
      ),
      PermissionItem(
        type: PermissionType.notifications,
        title: 'Уведомления',
        description: 'Для напоминаний',
      ),
      PermissionItem(
        type: PermissionType.location,
        title: 'Геолокация',
        description: 'Для поиска мест',
      ),
      PermissionItem(
        type: PermissionType.bluetooth,
        title: 'Bluetooth',
        description: 'Для управления Bluetooth',
      ),
    ];
  }

  static Future<bool> checkPermission(PermissionType type) async {
    final p = _toPermission(type);
    final status = await p.status;
    return status.isGranted;
  }

  static Future<bool> requestPermission(PermissionType type) async {
    final p = _toPermission(type);
    final status = await p.request();
    return status.isGranted;
  }

  static Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  static Permission _toPermission(PermissionType type) {
    switch (type) {
      case PermissionType.camera:
        return Permission.camera;
      case PermissionType.microphone:
        return Permission.microphone;
      case PermissionType.contacts:
        return Permission.contacts;
      case PermissionType.storage:
        return Permission.storage;
      case PermissionType.notifications:
        return Permission.notification;
      case PermissionType.location:
        return Permission.location;
      case PermissionType.bluetooth:
        return Permission.bluetooth;
    }
  }

  static Future<Map<PermissionType, bool>> getAllStatuses() async {
    final items = getPermissionItems();
    final result = <PermissionType, bool>{};
    for (var item in items) {
      result[item.type] = await checkPermission(item.type);
    }
    return result;
  }
}
