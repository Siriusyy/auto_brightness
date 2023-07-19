import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/cupertino.dart' hide MenuItem;
import 'package:get/get.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:win32/win32.dart';

class DesktopController extends GetxController {
  final sensorValue = (-1).obs;
  final maxSensorValue = 300.obs;
  final minSensorValue = 0.obs;

  final brightness = 0.obs;
  final maxBrightness = 100.obs;
  final minBrightness = 0.obs;
  final ip = "localhost".obs;
  final port = 8123.obs;
  final nodeId = "node1".obs;
  final key = "".obs;
  final pause = false.obs;

  static final monitors = <int>[];
  final physicalMonitorHandles = <int>[];
  static int nextBrightness = 0;

  final isAutoStart = false.obs;
  late TextEditingController portController = TextEditingController();
  late TextEditingController ipController = TextEditingController();
  late TextEditingController nodeController = TextEditingController();
  late TextEditingController keyController = TextEditingController();


  Future<void> startHttpService() async {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      final url = 'http://$ip:$port/api/states/$nodeId';
      try {
        final response = await Dio().get(
          url,
          options: Options(headers: {
            'Authorization': 'Bearer $key',
            "content-type": "application/json"
          }),
        );
        final data = jsonDecode(response.data) as Map<String, dynamic>;
        double doubleValue = double.tryParse(data['state'].toString()) ?? 0;
        sensorValue.value = doubleValue.round();
      } catch (e) {
      }
    });
  }

  static int enumMonitorCallback(
      int hMonitor, int hDC, Pointer lpRect, int lParam) {
    monitors.add(hMonitor);
    return TRUE;
  }

  void initMonitors() {
    monitors.clear();
    physicalMonitorHandles.clear();
    var result = FALSE;
    result = EnumDisplayMonitors(NULL, nullptr,
        Pointer.fromFunction<MonitorEnumProc>(enumMonitorCallback, 0), NULL);
    if (result == FALSE) return;
    for (var monitor in monitors) {
      final physicalMonitorCountPtr = calloc<DWORD>();
      result = GetNumberOfPhysicalMonitorsFromHMONITOR(
          monitor, physicalMonitorCountPtr);
      if (result == FALSE) return;
      final physicalMonitorArray =
          calloc<PHYSICAL_MONITOR>(physicalMonitorCountPtr.value);
      result = GetPhysicalMonitorsFromHMONITOR(
          monitor, physicalMonitorCountPtr.value, physicalMonitorArray);
      if (result == FALSE) return;
      physicalMonitorHandles.add(physicalMonitorArray.cast<IntPtr>().value);
    }
    if (physicalMonitorHandles.isEmpty) return;
    final minimumBrightnessPtr = calloc<DWORD>();
    final currentBrightnessPtr = calloc<DWORD>();
    final maximumBrightnessPtr = calloc<DWORD>();
    result = GetMonitorBrightness(physicalMonitorHandles[0],
        minimumBrightnessPtr, currentBrightnessPtr, maximumBrightnessPtr);
    if (result == FALSE) return;
    nextBrightness = currentBrightnessPtr.value;
    brightness.value = currentBrightnessPtr.value;
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!pause.value) {
        refreshBrightness();
      }
    });
  }

  void refreshBrightness() {
    if (sensorValue.value == -1) return;
    var mSensorValue = sensorValue.value;
    if (mSensorValue > maxSensorValue.value)
      mSensorValue = maxSensorValue.value;
    if (mSensorValue < minSensorValue.value)
      mSensorValue = minSensorValue.value;
    var mBrightness =
        ((mSensorValue / maxSensorValue.value) * maxBrightness.value).toInt();
    if (mBrightness > maxBrightness.value) mBrightness = maxBrightness.value;
    if (mBrightness < minBrightness.value) mBrightness = minBrightness.value;
    brightness.value = mBrightness;
    if (nextBrightness > brightness.value) {
      nextBrightness = nextBrightness - 1;
      for (var handle in physicalMonitorHandles) {
        SetMonitorBrightness(handle, nextBrightness);
      }
    } else if (nextBrightness < brightness.value) {
      nextBrightness = nextBrightness + 1;
      for (var handle in physicalMonitorHandles) {
        SetMonitorBrightness(handle, nextBrightness);
      }
    }
  }

  Future<void> setupTray() async {
    await trayManager.setIcon('assets/images/icon-35x35.ico');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(
        key: 'show_window',
        label: '显示主界面',
      ),
      MenuItem(
        key: 'exit_app',
        label: '退出',
      ),
    ]));
    trayManager.addListener(_MyTrayListener(this));
  }

  Future<void> setupStartUp(bool enable) async {
    WidgetsFlutterBinding.ensureInitialized();

    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
    );

    if (enable) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }

  Future<void> initParas() async {
    final prefs = await SharedPreferences.getInstance();
    minBrightness.value = prefs.getInt("minBrightness")!;
    maxBrightness.value = prefs.getInt("maxBrightness")!;
    minSensorValue.value = prefs.getInt("minSensorValue")!;
    maxSensorValue.value = prefs.getInt("maxSensorValue")!;
    isAutoStart.value = prefs.getBool("isAutoStart")!;
    port.value = prefs.getInt("port")!;
    ip.value = prefs.getString("ip")!;
    nodeId.value = prefs.getString("nodeId")!;
    key.value = prefs.getString("key")!;
    // 在这里可以设置默认文本值
    portController.text = port.value.toString();
    ipController.text = ip.value.toString();
    nodeController.text = nodeId.value.toString();
    keyController.text = key.value.toString();
  }

  Future<void> saveParas() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("minBrightness", minBrightness.value);
    prefs.setInt("maxBrightness", maxBrightness.value);
    prefs.setInt("minSensorValue", minSensorValue.value);
    prefs.setInt("maxSensorValue", maxSensorValue.value);
    prefs.setBool("isAutoStart", isAutoStart.value);
    prefs.setInt("port", port.value);
    prefs.setString("ip", ip.value);
    prefs.setString("nodeId", nodeId.value);
    prefs.setString("key", key.value);
  }

  Future<void> initHotKeys() async {
    await hotKeyManager.register(
      HotKey(KeyCode.keyQ,
          modifiers: [KeyModifier.alt, KeyModifier.shift],
          scope: HotKeyScope.system),
      keyDownHandler: (hotKey) {
        if (brightness.value > 95) {
          brightness.value = 100;
        } else {
          brightness.value += 5;
        }
        for (var handle in physicalMonitorHandles) {
          SetMonitorBrightness(handle, brightness.value);
        }
      },
    );
    await hotKeyManager.register(
      HotKey(KeyCode.keyA,
          modifiers: [KeyModifier.alt, KeyModifier.shift],
          scope: HotKeyScope.system),
      keyDownHandler: (hotKey) {
        if (brightness.value < 5) {
          brightness.value = 0;
        } else {
          brightness.value -= 5;
        }
        for (var handle in physicalMonitorHandles) {
          SetMonitorBrightness(handle, brightness.value);
        }
      },
    );
  }

  @override
  void onInit() {
    setupTray();
    initParas();
    initMonitors();
    // startUdpService();
    startHttpService();
    // initUsbMode();
    // initHotKeys();
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {}
}

class _MyTrayListener extends TrayListener {
  final DesktopController controller;
  _MyTrayListener(this.controller);

  @override
  void onTrayIconMouseDown() {
    appWindow.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      appWindow.show();
    } else if (menuItem.key == 'exit_app') {
      hotKeyManager.unregisterAll();
      controller.saveParas();
      appWindow.close();
    }
  }
}
