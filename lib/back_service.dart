import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_health_data/health_service/health_data_service.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  /// OPTIONAL, using custom notification channel id
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'MY FOREGROUND SERVICE', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,

      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'MY HEALTH STATUS',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );
}

// to ensure this is executed
// run app from xcode, then from xcode menu, select Simulate Background Fetch

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  // For flutter prior to version 3.0.0
  // We have to register the plugin manually

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString("hello", "world");

  /// OPTIONAL when use custom notification
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // bring to foreground

  //Time Duration is a HARD CODE , We need it from server side and api is needed.
  Timer.periodic(const Duration(minutes: 2), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        /// OPTIONAL for use custom notification
        /// the notification id must be equals with AndroidConfiguration when you call configure() method.
        final bloodPressureData = await getFormattedBloodPressureData();
        final heightWeight = await getHeightWeight();
        final glucoseHeartRateTemperatureData = await getGlucoseHeartRateTemperatureData();
        final totalData = "$bloodPressureData\n$heightWeight\n$glucoseHeartRateTemperatureData";
        flutterLocalNotificationsPlugin.show(
          888,
          'Health service',
          totalData,
          const NotificationDetails(
              android: AndroidNotificationDetails(
                'my_foreground',
                'MY FOREGROUND HEALTH SERVICE',
                icon: "@mipmap/ic_launcher",
                ongoing: true,
              ),
              iOS: DarwinNotificationDetails()),
        );

        // if you don't using custom notification, uncomment this
        service.setForegroundNotificationInfo(
          title: "My Health Service",
          content: totalData,
        );
      }
    }

    /// you can see this log in logcat
    debugPrint('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

    // test using external plugin
    final deviceInfo = DeviceInfoPlugin();
    String? device;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device = androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
    }

    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": device,
      },
    );
  });
}

Future<String> getFormattedBloodPressureData() async {
  String systolic = '';
  String diastolic = '';
  await HealthDataService.fetchBloodPressureData().then(
    (List<HealthDataPoint> healthData) {
      for (var item in healthData) {
        if (item.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC) {
          systolic = (item.value as NumericHealthValue).numericValue.toString();
          debugPrint('Systolic: $systolic');
        }
        if (item.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC) {
          diastolic = (item.value as NumericHealthValue).numericValue.toString();
          debugPrint("Diastolic: $diastolic");
        }
      }
    },
  );
  return 'Systolic: $systolic, Diastolic: $diastolic';
}

Future<String> getHeightWeight() async {
  String height = '';
  String weight = '';
  await HealthDataService.fetchHeightWeightData().then(
    (List<HealthDataPoint> healthData) {
      for (var item in healthData) {
        if (item.type == HealthDataType.HEIGHT) {
          height = (item.value as NumericHealthValue).numericValue.toString();
          debugPrint('Height: $height');
        }
        if (item.type == HealthDataType.WEIGHT) {
          weight = (item.value as NumericHealthValue).numericValue.toString();
          debugPrint("Weight: $weight");
        }
      }
    },
  );
  return "Height :$height, Weight :$weight";
}

getGlucoseHeartRateTemperatureData() async {
  String bloodGlucose = '';
  String heartRate = '';
  String bodyTemperature = '';
  await HealthDataService.fetchGlucoseHeartRateTemperatureData().then(
    (List<HealthDataPoint> healthData) {
      for (var item in healthData) {
        if (item.type == HealthDataType.BLOOD_GLUCOSE) {
          bloodGlucose = (item.value as NumericHealthValue).numericValue.toString();
          debugPrint('BLOOD_GLUCOSE: $bloodGlucose');
        }
        if (item.type == HealthDataType.HEART_RATE) {
          heartRate = (item.value as NumericHealthValue).numericValue.toString();
          debugPrint("HEART_RATE: $heartRate");
        }
        if (item.type == HealthDataType.BODY_TEMPERATURE) {
          bodyTemperature = (item.value as NumericHealthValue).numericValue.toString();
          debugPrint("BODY_TEMPERATURE: $bodyTemperature");
        }
      }
    },
  );
  return "Glucose :$bloodGlucose,\nHeart Rate :$heartRate,\nTemperature :$bodyTemperature  ";
}
