import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oktoast/oktoast.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

import '../controllers/desktop_controller.dart';

class DesktopView extends GetView<DesktopController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTitleBar(),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildControlBrightness(),
                      _buildControlSensor(),
                      _buildIpAndPortInput(),
                      _buildAccessKeyInput(),
                      _buildStartUpButton(),
                      // _buildSysKeyButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSysKeyButton() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: ElevatedButton(
        onPressed: () {
          Get.defaultDialog(
            title: "使用快捷键调节亮度",
            titleStyle: const TextStyle(fontWeight: FontWeight.normal),
            middleText:
                "使用前先关闭手机端APP\n使用 Alt + Shift + Q 增加亮度\n使用 Alt + Shift + A 减小亮度",
            textConfirm: "好的",
            onConfirm: () => Get.back(),
          );
        },
        child: const Text(
          "如何使用快捷键调节显示器亮度",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  Widget _buildIpAndPortInput() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) {
                if (value.isNotEmpty) {
                  if (!value.isIPv4) {
                    showToast("请输入合法的IP地址",
                        duration: Duration(milliseconds: 800));
                  } else {
                    controller.ip.value = value;
                  }
                } else {
                  controller.ip.value = "localhost";
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'HA地址',
                hintText: 'localhost',
              ),
              controller: controller.ipController,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            ":",
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: '端口号',
                hintText: '8123',
              ),
              controller: controller.portController,
              onChanged: (value) {
                if (value.isEmpty) {
                  controller.port.value = 8123;
                } else {
                  controller.port.value = int.parse(value);
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'nodeId',
                hintText: 'node1',
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  controller.nodeId.value = "node1";
                } else {
                  controller.nodeId.value = value;
                }
              },
              controller: controller.nodeController,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAccessKeyInput() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              maxLines: 2,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  controller.key.value = value;
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'HA Access Key',
                hintText: 'xxx',
              ),
              controller: controller.keyController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartUpButton() {
    return Obx(() => Container(
        margin: const EdgeInsets.only(top: 15),
        child: Row(children: [
          const Text("开机自启动",
              style: TextStyle(color: Colors.blueAccent, fontSize: 20)),
          Switch(
              value: controller.isAutoStart.value,
              onChanged: (v) {
                controller.isAutoStart.value = v;
                controller.setupStartUp(v);
                controller.saveParas();
              }),
          const Spacer(),
          const Text("暂停",
              style: TextStyle(color: Colors.blueAccent, fontSize: 20)),
          Switch(
              value: controller.pause.value,
              onChanged: (v) {
                controller.pause.value = v;
                controller.saveParas();
              }),
        ])));
  }

  Widget _buildTitleBar() {
    return WindowTitleBarBox(
      child: Row(
        children: [
          Expanded(child: MoveWindow()),
          MinimizeWindowButton(
              colors: WindowButtonColors(iconNormal: Colors.white)),
          CloseWindowButton(
            colors: WindowButtonColors(
                iconNormal: Colors.white, mouseOver: Colors.red),
            onPressed: () {
              appWindow.hide();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlSensor() {
    return Obx(() => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "环境光范围：${controller.minSensorValue}-${controller.maxSensorValue} [当前：${controller.sensorValue >= 0 ? controller.sensorValue : 0}]",
              style: const TextStyle(color: Colors.blueAccent, fontSize: 20),
            ),
            SfRangeSlider(
              min: 0,
              max: 3000,
              stepSize: 1,
              values: SfRangeValues(controller.minSensorValue.value.toDouble(),
                  controller.maxSensorValue.value.toDouble()),
              onChanged: (v) {
                controller.pause.value = true;
                controller.minSensorValue.value = v.start.round();
                controller.maxSensorValue.value = v.end.round();
                controller.saveParas();
              },
              onChangeEnd: (v) {
                controller.pause.value = false;
              },
            ),
          ],
        ));
  }

  Widget _buildControlBrightness() {
    return Obx(() => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "显示器亮度范围：${controller.minBrightness}-${controller.maxBrightness} [当前：${controller.brightness}]",
              style: const TextStyle(color: Colors.blueAccent, fontSize: 20),
            ),
            SfRangeSlider(
                min: 0,
                max: 100,
                stepSize: 1,
                values: SfRangeValues(controller.minBrightness.value.toDouble(),
                    controller.maxBrightness.value.toDouble()),
                onChanged: (v) {
                  controller.pause.value = true;
                  controller.minBrightness.value = v.start.round();
                  controller.maxBrightness.value = v.end.round();
                  controller.saveParas();
                },
                onChangeEnd: (v) {
                  controller.pause.value = false;
                }),
          ],
        ));
  }
}
