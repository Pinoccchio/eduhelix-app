import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:flutter_app/pages/Notification_Handler/notification_handler.dart';
import 'package:flutter_app/routes/app_routes.dart'; // Import the routes
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Lock the app to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize time zones and notifications
  tz.initializeTimeZones();
  NotificationHandler notificationHandler = NotificationHandler();
  notificationHandler.initializeNotifications();

  // Request notification permissions
  await notificationHandler.requestNotificationPermissions();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splashScreen, // Set initial route if needed
      routes: AppRoutes.getRoutes(), // Use the routes defined in AppRoutes
    );
  }
}