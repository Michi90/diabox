import 'package:flutter/material.dart';
import 'package:diabox/screens/home_page.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:diabox/database_helper.dart';
import 'package:diabox/models/consumable_type.dart';
import 'package:diabox/models/active_consumable.dart';
import 'package:diabox/utils/formatters.dart';
import 'dart:io' show Platform;

// Initialize FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// This function will be called by Workmanager in the background
@pragma('vm:entry-point')
void callbackDispatcher() async {
  Workmanager().executeTask((taskName, inputData) async {
    // Initialize database and notifications for background task
    WidgetsFlutterBinding.ensureInitialized();
    final DatabaseHelper dbHelper = DatabaseHelper();

    // Configure local notifications for background task
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Extract data from inputData
    final int? consumableTypeId = inputData?['consumableTypeId'];
    final String? notificationType = inputData?['notificationType']; // e.g., 'reminder', 'expiration'
    final int? activeConsumableId = inputData?['activeConsumableId'];
    final int? offset = inputData?['offset'];

    if (consumableTypeId != null && notificationType != null && activeConsumableId != null) {
      final ConsumableType? type = await dbHelper.getConsumableTypeById(consumableTypeId);
      final ActiveConsumable? activeConsumable = await dbHelper.getActiveConsumableById(activeConsumableId);

      if (type != null && activeConsumable != null) {
        String title = '';
        String body = '';

        if (notificationType == 'expiration') {
          title = '${type.name} ist abgelaufen!';
          body = 'Dein ${type.name} ist am ${formatDateTime(activeConsumable.expectedEndDate)} abgelaufen.';
        } else if (notificationType == 'reminder') {
          title = 'Erinnerung: ${type.name} läuft bald ab!';
          if (offset != null) {
            body = 'Dein ${type.name} läuft in ${formatDuration(Duration(minutes: offset))} ab.';
          } else {
            body = 'Dein ${type.name} läuft am ${formatDateTime(activeConsumable.expectedEndDate)} ab.';
          }
        }

        // Show notification
        const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
          'diabox_channel_id',
          'Diabox Benachrichtigungen',
          channelDescription: 'Benachrichtigungen für ablaufende Verbrauchsmaterialien',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );
        const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails();
        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidNotificationDetails,
          iOS: darwinNotificationDetails,
        );

        await flutterLocalNotificationsPlugin.show(
          activeConsumable.id!, // Unique ID for the notification
          title,
          body,
          notificationDetails,
          payload: 'item_id_${activeConsumable.id}',
        );
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure local notifications for the main app
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
  const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings); 

  if (Platform.isAndroid) {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  } else if (Platform.isIOS || Platform.isMacOS) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // Initialize Workmanager
  Workmanager().initialize(
    callbackDispatcher,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diabox',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      themeMode: ThemeMode.dark, // Default to dark mode
      debugShowCheckedModeBanner: false, // Remove debug banner
      home: const HomePage(),
    );
  }
}