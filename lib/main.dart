// import 'dart:async';
// import 'dart:io';

import 'dart:async';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_health_data/back_service.dart';
import 'package:test_health_data/firebase_options.dart';
import 'package:test_health_data/global_keys.dart';
import 'package:test_health_data/notification_service.dart';

import 'health_service/health_data_service.dart';

Future<void> requestPermission(Permission permission) async {
  if (await permission.isDenied) {
    await permission.request();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermission(Permission.notification);
  await requestPermission(Permission.location);
  await requestPermission(Permission.locationAlways);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(backgroundHandler);

  LocalNotificationService.initialize();
  await HealthDataService.initialization();
  await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(navigatorKey: navigatorKey, home: LogView());
  }
}

class LogView extends StatefulWidget {
  const LogView({Key? key}) : super(key: key);

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              child: Text('Go to next page'),
              onPressed: () {
                Get.offAll(() => BackgroundServicePage());
              },
            )
          ],
        ),
      ),
    );
  }
}

class BackgroundServicePage extends StatefulWidget {
  const BackgroundServicePage({super.key});

  @override
  State<BackgroundServicePage> createState() => _BackgroundServicePageState();
}

class _BackgroundServicePageState extends State<BackgroundServicePage> {
  String text = "Stop Service";
  String systolic = '';
  String diastolic = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service App'),
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StreamBuilder<Map<String, dynamic>?>(
              stream: FlutterBackgroundService().on('update'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final data = snapshot.data!;
                String? device = data["device"];
                DateTime? date = DateTime.tryParse(data["current_date"]);
                return Column(
                  children: [
                    Text(device ?? 'Unknown'),
                    Text(date.toString()),
                  ],
                );
              },
            ),
            ElevatedButton(
              child: const Text("Foreground Mode"),
              onPressed: () => FlutterBackgroundService().invoke("setAsForeground"),
            ),
            ElevatedButton(
              child: const Text("Background Mode"),
              onPressed: () => FlutterBackgroundService().invoke("setAsBackground"),
            ),
            ElevatedButton(
              child: Text(text),
              onPressed: () async {
                final service = FlutterBackgroundService();
                var isRunning = await service.isRunning();
                isRunning ? service.invoke("stopService") : service.startService();

                setState(() {
                  text = isRunning ? 'Start Service' : 'Stop Service';
                });
              },
            ),
            ElevatedButton(
                child: const Text("Check Blod Pressure"),
                onPressed: () async {
                  await HealthDataService.fetchBloodPressureData().then(
                    (List<HealthDataPoint> healthData) {
                      for (var item in healthData) {
                        if (item.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC) {
                          systolic = (item.value as NumericHealthValue).numericValue.toString();
                        }
                        if (item.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC) {
                          diastolic = (item.value as NumericHealthValue).numericValue.toString();
                        }
                      }
                      setState(() {});
                    },
                  );
                }),
            Expanded(
              child: Column(
                children: [
                  Text('Blood Pressure Systolic : $systolic, Diastolic :$diastolic '),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
