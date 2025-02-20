// Global Health instance
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_health_data/global_keys.dart';
import 'package:test_health_data/utils.dart';

import 'data_type/health_data_type.dart';
import 'enum_state/app_state_enum.dart';

final health = Health();

class HealthDataService {
//For Google Fit and Apple Health

  List<HealthDataPoint> _healthDataList = [];
  static AppState state = AppState.DATA_NOT_FETCHED;
  int _nofSteps = 0;
  List<RecordingMethod> recordingMethodsToFilter = [];

  // All types available depending on platform (iOS ot Android).
  static List<HealthDataType> get types => (Platform.isAndroid)
      ? dataTypesAndroid
      : (Platform.isIOS)
          ? dataTypesIOS
          : [];

  // Or both READ and WRITE
  static List<HealthDataAccess> get permissions => types
      .map((type) =>
          // can only request READ permissions to the following list of types on iOS
          [
            HealthDataType.WALKING_HEART_RATE,
            HealthDataType.ELECTROCARDIOGRAM,
            HealthDataType.HEART_RATE,
            HealthDataType.HIGH_HEART_RATE_EVENT,
            HealthDataType.LOW_HEART_RATE_EVENT,
            HealthDataType.IRREGULAR_HEART_RATE_EVENT,
            HealthDataType.EXERCISE_TIME,
            HealthDataType.BLOOD_GLUCOSE,
            HealthDataType.BLOOD_OXYGEN,
            HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
            HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
            HealthDataType.BODY_TEMPERATURE,
            HealthDataType.WEIGHT,
            HealthDataType.HEIGHT,
          ].contains(type)
              ? HealthDataAccess.READ
              : HealthDataAccess.READ_WRITE)
      .toList();
  static bool hasPermissions = false;

  static bool authorized = false;

//================ ============================///
  static initialization() async {
    await _getHealthConnectSdkStatus();
    await authorize();
  }

  /// Install Google Health Connect on this phone.
  static Future<void> _installHealthConnect() async => await health.installHealthConnect();

  /// Gets the Health Connect status on Android.
  static Future<void> _getHealthConnectSdkStatus() async {
    assert(Platform.isAndroid, "This is only available on Android");

    final status = await health.getHealthConnectSdkStatus();

    if (status == HealthConnectSdkStatus.sdkUnavailable) {
      Utils.createToast("Health Sdk Unavailable");
      return;
    }
    if (Platform.isAndroid && health.healthConnectSdkStatus != HealthConnectSdkStatus.sdkAvailable) {
      _showUserDialog(
        title: 'Warning!',
        status: 'Please install health connect',
        child: TextButton(
            onPressed: _installHealthConnect,
            style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
            child: const Text("Install Health Connect", style: TextStyle(color: Colors.white))),
      );
    }

    state = AppState.HEALTH_CONNECT_STATUS;
    log("State :$state");
  }

  static Future<void> authorize() async {
    // If we are trying to read Step Count, Workout, Sleep or other data that requires
    // the ACTIVITY_RECOGNITION permission, we need to request the permission first.
    // This requires a special request authorization call.
    //
    // The location permission is requested for Workouts using the Distance information.
    PermissionStatus activityRecognitionStatus = await Permission.activityRecognition.request();
    PermissionStatus locationStatus = await Permission.location.request();
    if (activityRecognitionStatus.isGranted && locationStatus.isGranted) {
      // Check if we have health permissions
      hasPermissions = await health.hasPermissions(types, permissions: permissions) ?? false;
      // log("hasPermissions.value:${await health.hasPermissions(types, permissions: permissions)}");
      // hasPermissions = false because the hasPermission cannot disclose if WRITE access exists.
      // Hence, we have to request with WRITE as well.
      hasPermissions = false;

      if (!hasPermissions) {
        // requesting access to the data types before reading them
        try {
          authorized = await health.requestAuthorization(types, permissions: permissions);
        } catch (error) {
          debugPrint("Exception in authorize: $error");
        }
      }

      state = (authorized) ? AppState.AUTHORIZED : AppState.AUTH_NOT_GRANTED;
      log("Authorized State :$state");
    } else {
      state = AppState.AUTH_NOT_GRANTED;
    }
  }

//Check Bllod Pressure
  /// Fetch steps from the health plugin and show them in the app.
  static Future<List<HealthDataPoint>> fetchBloodPressureData() async {
    List<HealthDataPoint> healthData = [];
    // get steps for today (i.e., since midnight)
    final now = DateTime.now();
    DateTime start = now.subtract(Duration(hours: 1));
    final List<HealthDataType> types = [
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    ];
    bool bloodPermission = await health.hasPermissions(types) ?? false;
    if (!bloodPermission) {
      bloodPermission = await health.requestAuthorization(types);
    }

    if (bloodPermission) {
      try {
        healthData = await health.getHealthDataFromTypes(startTime: start, endTime: now, types: types);
        if (healthData.isNotEmpty) {
          for (var healthItem in healthData) {
            log("Health :${healthItem.type} ==> Value : ${healthItem.value}");

            return healthData;
          }
        } else {
          debugPrint("Health data not found");
          return healthData;
        }
        return healthData;
      } catch (error) {
        debugPrint("Exception in getTotalStepsInInterval: $error");
      }
    } else {
      debugPrint("Authorization not granted - error in authorization");
      state = AppState.DATA_NOT_FETCHED;
    }
    return healthData;
  }

  static Future<List<HealthDataPoint>> fetchHeightWeightData() async {
    List<HealthDataPoint> healthData = [];
    // get steps for today (i.e., since midnight)
    final now = DateTime.now();
    DateTime start = now.subtract(Duration(days: 7));
    final List<HealthDataType> types = [
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
    ];
    bool bloodPermission = await health.hasPermissions(types) ?? false;
    if (!bloodPermission) {
      bloodPermission = await health.requestAuthorization(types);
    }

    if (bloodPermission) {
      try {
        healthData = await health.getHealthDataFromTypes(startTime: start, endTime: now, types: types);
        if (healthData.isNotEmpty) {
          for (var healthItem in healthData) {
            log("Health :${healthItem.type} ==> Value : ${healthItem.value}");
          }
        } else {
          debugPrint("Health data not found");
        }
      } catch (error) {
        debugPrint("Exception in getTotalStepsInInterval: $error");
      }
    } else {
      debugPrint("Authorization not granted - error in authorization");
      state = AppState.DATA_NOT_FETCHED;
    }
    return healthData;
  }

  static Future<List<HealthDataPoint>> fetchGlucoseHeartRateTemperatureData() async {
    List<HealthDataPoint> healthData = [];
    // get steps for today (i.e., since midnight)
    final now = DateTime.now();
    DateTime start = now.subtract(Duration(hours: 1));
    final List<HealthDataType> types = [
      HealthDataType.BLOOD_GLUCOSE,
      HealthDataType.HEART_RATE,
      HealthDataType.BODY_TEMPERATURE,
    ];
    bool bloodPermission = await health.hasPermissions(types) ?? false;
    if (!bloodPermission) {
      bloodPermission = await health.requestAuthorization(types);
    }

    if (bloodPermission) {
      try {
        healthData = await health.getHealthDataFromTypes(startTime: start, endTime: now, types: types);
        if (healthData.isNotEmpty) {
          for (var healthItem in healthData) {
            log("Health :${healthItem.type} ==> Value : ${healthItem.value}");
          }
        } else {
          debugPrint("Health data not found");
        }
      } catch (error) {
        debugPrint("Exception in getTotalStepsInInterval: $error");
      }
    } else {
      debugPrint("Authorization not granted - error in authorization");
      state = AppState.DATA_NOT_FETCHED;
    }
    return healthData;
  }

  static _showUserDialog({required String title, required String status, Widget? child}) async {
    await showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 20,
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
                SizedBox(
                  height: 20,
                ),
                Text(
                  status,
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
                if (child != null)
                  SizedBox(
                    height: 10,
                  ),
                if (child != null) child,
                SizedBox(
                  height: 20,
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
