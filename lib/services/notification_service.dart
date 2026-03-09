import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();


    const AndroidInitializationSettings androidInitSettings = AndroidInitializationSettings('@drawable/launch_background');
    const InitializationSettings initSettings = InitializationSettings(android: androidInitSettings);

    await _notificationsPlugin.initialize(initSettings);

    _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
  }



  static Future<void> scheduleGlobalReminder(TimeOfDay time, String title, String body) async {
    await cancelGlobalReminder();

    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(time);

    try {
      await _notificationsPlugin.zonedSchedule(
        0,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'global_channel', 'Global Reminders',
            channelDescription: 'Daily global app reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('4. Status: SUCCESS - Aligned with hardware clock and handed to Android.');
    } catch (e) {
      debugPrint('4. Status: FAILED to schedule - $e');
    }
  }

  static Future<void> cancelGlobalReminder() async {
    await _notificationsPlugin.cancel(0);
  }

  static tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {

    final now = DateTime.now();

    DateTime scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // 3. Convert perfectly to a UTC Timestamp.

    return tz.TZDateTime.from(scheduledDate, tz.UTC);
  }



  static Future<void> scheduleHabitReminder(int habitId, String title, List<TimeOfDay> times, List<int> days) async {
    await cancelHabitReminder(habitId);
    if (days.isEmpty || times.isEmpty) return;

    for (int dayOfWeek in days) {
      for (int t = 0; t < times.length; t++) {
        // Create a unique ID combining Habit ID + Day + Time Index
        int uniqueNotificationId = int.parse('$habitId$dayOfWeek$t');

        await _notificationsPlugin.zonedSchedule(
          uniqueNotificationId,
          'Habit Reminder: $title',
          'Time to complete your habit!',
          _nextInstanceOfDayAndTime(dayOfWeek, times[t]),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'habit_channel', 'Habit Reminders',
              channelDescription: 'Reminders for individual habits',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
    debugPrint('Successfully scheduled ${times.length} reminders across ${days.length} days for $title');
  }

  static Future<void> cancelHabitReminder(int habitId) async {
    // Brute force cancel up to 10 possible times per day for this habit
    for (int day = 1; day <= 7; day++) {
      for (int t = 0; t < 10; t++) {
        await _notificationsPlugin.cancel(int.parse('$habitId$day$t'));
      }
    }
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, TimeOfDay time) {
    DateTime now = DateTime.now();
    DateTime scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return tz.TZDateTime.from(scheduledDate, tz.UTC);
  }

  static Future<void> fireInstantNotification() async {
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel', 'Test Notifications',
        channelDescription: 'Testing if the pop-up works',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await _notificationsPlugin.show(
      999,
      'Test Successful! ',
      ' notification  is working .',
      platformChannelSpecifics,
    );
  }

}