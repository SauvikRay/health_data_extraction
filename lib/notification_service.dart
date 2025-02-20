import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:health/health.dart';
import 'package:test_health_data/health_service/health_data_service.dart';

void notificationTapBackground(NotificationResponse notificationResponse) {
  _handleNotificationResponse(notificationResponse);
}

@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
  _handleNotificationResponse(notificationResponse);
}

void _handleNotificationResponse(NotificationResponse notificationResponse) {
  final String? payload = notificationResponse.payload;
  if (payload != null) {
    final Map<String, dynamic> data = jsonDecode(payload);

    debugPrint('Notification data: $data');
  }
}

@pragma('vm:entry-point')
Future<void> backgroundHandler(RemoteMessage message) async {
  if (message != null) {
    LocalNotificationService.createAndDisplayNotification(message);
    getBloodPressure();
    getHeightWeight();
  }
}

getBloodPressure() async {
  await HealthDataService.fetchBloodPressureData().then(
    (List<HealthDataPoint> healthData) {
      for (var item in healthData) {
        if (item.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC) {
          debugPrint((item.value as NumericHealthValue).numericValue.toString());
        }
        if (item.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC) {
          debugPrint((item.value as NumericHealthValue).numericValue.toString());
        }
      }
    },
  );
}

getHeightWeight() async {
  await HealthDataService.fetchHeightWeightData().then(
    (List<HealthDataPoint> healthData) {
      for (var item in healthData) {
        if (item.type == HealthDataType.HEIGHT) {
          debugPrint('Height: ${(item.value as NumericHealthValue).numericValue.toString()}');
        }
        if (item.type == HealthDataType.WEIGHT) {
          debugPrint("Weight: ${(item.value as NumericHealthValue).numericValue.toString()}");
        }
      }
    },
  );
}

getGlucoseHeartRateTemperatureData() async {
  await HealthDataService.fetchGlucoseHeartRateTemperatureData().then(
    (List<HealthDataPoint> healthData) {
      for (var item in healthData) {
        if (item.type == HealthDataType.BLOOD_GLUCOSE) {
          debugPrint('BLOOD_GLUCOSE: ${(item.value as NumericHealthValue).numericValue.toString()}');
        }
        if (item.type == HealthDataType.HEART_RATE) {
          debugPrint("HEART_RATE: ${(item.value as NumericHealthValue).numericValue.toString()}");
        }
        if (item.type == HealthDataType.BODY_TEMPERATURE) {
          debugPrint("BODY_TEMPERATURE: ${(item.value as NumericHealthValue).numericValue.toString()}");
        }
      }
    },
  );
}

class LocalNotificationService {
  LocalNotificationService._();
  static final _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final _firebaseMessaging = FirebaseMessaging.instance;

  static void initialize() {
    final initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings("@mipmap/ic_launcher"),
      iOS: DarwinInitializationSettings(),
    );

    _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    _requestPermissions();
    _setupFirebaseListeners();
    getToken();
    // fcmSubscribe();
  }

  static void _requestPermissions() {
    if (Platform.isAndroid) {
      _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
    if (Platform.isIOS) {
      _firebaseMessaging.requestPermission();
      _firebaseMessaging.getNotificationSettings();
    }
  }

  static void _setupFirebaseListeners() {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        createAndDisplayNotification(message);
        log(message.data.toString());
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) {
        createAndDisplayNotification(message);
        log(message.data.toString());
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      log("Notification opened: ${message.data}");
      createAndDisplayNotification(message);
    });
  }

  static Future<void> createAndDisplayNotification(RemoteMessage message) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          "texbazar-60510",
          "texbazarpushnotificationappchannel",
          importance: Importance.max,
          priority: Priority.high,
          color: Colors.deepOrange,
          chronometerCountDown: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _notificationsPlugin.show(
        id,
        message.notification?.title,
        message.notification?.body,
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      log(e.toString());
    }
  }

  // static void fcmSubscribe() => _firebaseMessaging.subscribeToTopic('texbazarfcm');
  // static void fcmUnSubscribe() => _firebaseMessaging.unsubscribeFromTopic('texbazarfcm');

  static Future<void> getToken() async {
    _firebaseMessaging.getToken().then((token) async {
      if (token != null) {
        log('[FCM]--> Token: [$token]');
        await _sendToken(token);
      }
    });

    _firebaseMessaging.onTokenRefresh.listen((token) async {
      log('[FCM]--> Token refreshed: [$token]');
      await _sendToken(token);
    });
  }

  static Future<void> _sendToken(String token) async {
    try {
      log("Sending token: $token");
      // await postDeviceTokenRXobj.postDeviceToken(token: token);
    } catch (error) {
      log("Error sending token: $error");
      rethrow;
    }
  }

  static Future<void> removeToken() async {
    try {
      await _firebaseMessaging.deleteToken();
    } catch (error) {
      log("Error removing token: $error");
      rethrow;
    }
  }
}
