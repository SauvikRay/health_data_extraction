// import 'dart:developer';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
// import 'package:kambaiihealth/main.dart' show notificationsPlugin;
// import 'package:kambaiihealth/wellnessapp/module/menu_pages/my_medicine/medicine_taken/medicine_taken_screen.dart';

// import '../wellnessapp/core/utils/fcm_keys.dart';
final notificationsPlugin = FlutterLocalNotificationsPlugin();
@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
  debugPrint("From onDidReceiveNotificationResponse");
  _routing(notificationResponse);
}

//From Flutter Local Notification
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint("From notificationTapBackground");
  _routing(notificationResponse);
}

_routing(NotificationResponse notificationResponse) {
  final String? payload = notificationResponse.payload;
  if (payload != null) {
    final Map<String, dynamic> data = jsonDecode(payload);
    // if (data['type'].trim() == medicine_alarm) {
    //   log("NAvigating from  handelRouting");
    //   Navigator.of(Get.context!).push(
    //     MaterialPageRoute(
    //       builder: (context) => MedicineTakenScreen(),
    //       settings: RouteSettings(arguments: {'timeOfDay': data['timeOfDay']}),
    //     ),
    //   );
    //   // Get.to(() => MedicineTakenScreen(), arguments: {'timeOfDay': message.data['timeOfDay']});
    // }
  }
}

const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'kambaii_wellness_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description,
    importance: Importance.max,
    playSound: true,
    showBadge: true,
    sound: RawResourceAndroidNotificationSound('notification'));

class FirebaseNotificationService {
  static Future<void> requestNotiPermission() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('Permission granted: ${settings.authorizationStatus}');
    }
    if (Platform.isIOS) {
      await notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation = notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      if (Platform.isAndroid) {
        await notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
      }

      if (Platform.isIOS) {
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true, // Required to display a heads up notification
          badge: true,
          sound: true,
        );
      }
      // if (kDebugMode) {
      //   log("Notification is granted: $granted");
      // }
    }
  }

  static Future<void> initializeNotification() async {
    const InitializationSettings initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
        requestCriticalPermission: true,
      ),
    );
    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
  }

  static Future<void> handelRouting(RemoteMessage message) async {
    log("HandleRouting Data:${message.data['type']}");
    final String medicineTakenPath = message.data['type'];
    // try {
    //   if (medicineTakenPath.trim() == medicine_alarm) {
    //     log("NAvigating from  handelRouting");
    //     Navigator.of(Get.context!).push(
    //       MaterialPageRoute(
    //         builder: (context) => MedicineTakenScreen(),
    //         settings: RouteSettings(arguments: {'timeOfDay': message.data['timeOfDay']}),
    //       ),
    //     );
    //     // Get.to(() => MedicineTakenScreen(), arguments: {'timeOfDay': message.data['timeOfDay']});
    //   }
    // } catch (e) {}
  }

  static void createAndDisplaynotification(RemoteMessage message) async {
    try {
      // final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: channel.sound,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      log("=========> ${message.data}");
      await notificationsPlugin.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } on Exception catch (e) {
      debugPrint('Notification showing error :$e');
    }
  }

  static void notificationHandel() {
    // 1. This method call when app in terminated state and you get a notification
    // when you click on notification app open from terminated state and you can get notification data in this method

    FirebaseMessaging.instance.getInitialMessage().then(
      (RemoteMessage? message) {
        // log("FirebaseMessaging.instance.getInitialMessage");
        if (message != null) {
          handelRouting(message);
        }
      },
    );

    // 2. This method only call when App in forground it mean app must be opened
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        if (kDebugMode) {
          log("FirebaseMessaging.onMessage.listen");
        }
        if (message.notification != null) {
          // if (kDebugMode) {
          //   log('Notification Data :${message.data}');
          // }

          // log('Notification Body: ${message.notification!.body}');
          FirebaseNotificationService.initializeNotification();
          FirebaseNotificationService.createAndDisplaynotification(message);
        }
      },
    );

    // 3. This method only call when App in background and not terminated(not closed)
    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        if (kDebugMode) {
          log("FirebaseMessaging.onMessageOpenedApp.listen");
          log("${message.data["type"]}");
        }
        if (message.notification != null) {
          handelRouting(message);
        }
      },
    );
  }
}
