import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../services/database_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings: initSettings);
  }

  /// Schedules a reminder for 8 PM (4 hours before midnight) if the user hasn't studied today.
  Future<void> scheduleStreakReminder() async {
    final now = DateTime.now();
    final todayStats = await DatabaseService.instance.getTodayStats();
    
    // If user already studied today, we don't need a reminder for today.
    // Move to next day 8 PM.
    DateTime scheduledDate = DateTime(now.year, now.month, now.day, 20, 0);
    
    if (todayStats.studied > 0 || now.isAfter(scheduledDate)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id: 0,
      title: 'Serini Kaybetme! 🔥',
      body: 'Bugün henüz çalışmadın, serini devam ettirmek için 4 saatin kaldı.',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_reminder',
          'Streak Reminder',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
