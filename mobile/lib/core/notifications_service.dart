import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// On-device notifications: upcoming-trip reminders (scheduled) and
/// new host message alerts (shown when the app is not on that chat).
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  static const _messagesChannel = AndroidNotificationDetails(
    'messages',
    'Messages',
    channelDescription: 'New messages from hosts',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _tripsChannel = AndroidNotificationDetails(
    'trips',
    'Trip reminders',
    channelDescription: 'Reminders about upcoming trips',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> showHostMessage(String hostName, String content) async {
    await init();
    await _plugin.show(
      id: content.hashCode,
      title: hostName,
      body: content,
      notificationDetails: const NotificationDetails(
        android: _messagesChannel,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedule a reminder the day before check-in at 09:00 local time
  /// (or 2 hours from now if that moment already passed).
  Future<void> scheduleTripReminder({
    required String bookingId,
    required String listingTitle,
    required DateTime checkIn,
  }) async {
    await init();
    final dayBefore = DateTime(checkIn.year, checkIn.month, checkIn.day - 1, 9);
    var when = tz.TZDateTime.from(dayBefore, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (when.isBefore(now)) {
      if (checkIn.isBefore(DateTime.now())) return; // trip already started
      when = now.add(const Duration(hours: 2));
    }

    await _plugin.zonedSchedule(
      id: bookingId.hashCode,
      title: 'Your trip is coming up!',
      body: 'Tomorrow you check in at $listingTitle. Have a great stay!',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: _tripsChannel,
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelTripReminder(String bookingId) async {
    await _plugin.cancel(id: bookingId.hashCode);
  }
}
