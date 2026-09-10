import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          OpenFilex.open(response.payload!);
        }
      },
    );
    _initialized = true;
  }

  Future<void> updateProgressNotification({
    required int id,
    required String title,
    required double progress,
    required String speed,
    required String eta,
  }) async {
    final int progressPercent = (progress * 100).clamp(0, 100).toInt();

    final androidDetails = AndroidNotificationDetails(
      'oban_downloads',
      'Загрузки OBAN',
      channelDescription: 'Уведомления о прогрессе скачивания',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progressPercent,
      ongoing: true,
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',
    );

    await _notifications.show(
      id,
      title,
      "$progressPercent% • $speed • ост. $eta",
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showCompleteNotification({
    required int id,
    required String title,
    required String filePath,
  }) async {
    await _notifications.cancel(id);

    const androidDetails = AndroidNotificationDetails(
      'oban_completed',
      'Завершенные загрузки',
      channelDescription: 'Уведомления о скачанных файлах',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    await _notifications.show(
      id + 10000,
      'Загрузка завершена! ✅',
      '$title сохранен в Галерею. Нажмите для открытия.',
      const NotificationDetails(android: androidDetails),
      payload: filePath,
    );
  }

  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
