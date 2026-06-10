import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../models/gesture_mapping.dart';
import '../services/gesture_settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController ipController =
      TextEditingController(text: '10.0.2.2'); // windown 127.0.0.1

  final TextEditingController portController =
      TextEditingController(text: '8765');

  String openPalmUpCommand = 'SCROLL_UP';
  String openPalmDownCommand = 'SCROLL_DOWN';
  String openPalmRightCommand = 'NONE';
  String openPalmLeftCommand = 'NONE';
  String twoFingerCommand = 'NONE';
  String fistCommand = 'OPEN_THAIJO';
  String pinchCommand = 'CLICK';

  double smoothingWindow = 5;
  double debounceTime = 300;

  final List<DropdownMenuItem<String>> commandItems = const [
    DropdownMenuItem(value: 'SCROLL_UP', child: Text('Scroll Up')),
    DropdownMenuItem(value: 'SCROLL_DOWN', child: Text('Scroll Down')),
    DropdownMenuItem(value: 'CLICK', child: Text('Click')),
    DropdownMenuItem(value: 'CONFIRM', child: Text('Confirm / Enter')),
    DropdownMenuItem(value: 'OPEN_THAIJO', child: Text('Open ThaiJO')),
    DropdownMenuItem(value: 'THAIJO_SUBMIT_SEARCH', child: Text('Submit ThaiJO Search')),
    DropdownMenuItem(value: 'NONE', child: Text('None')),
  ];

  @override
  void dispose() {
    ipController.dispose();
    portController.dispose();
    super.dispose();
  }

  void connectToServer() {
    webSocketService.connect(
      ip: ipController.text.trim(),
      port: portController.text.trim(),
    );
  }

  void disconnectFromServer() {
    webSocketService.disconnect();
  }

  void resetDefaultSettings() {
    setState(() {
      openPalmUpCommand = 'SCROLL_UP';
      openPalmDownCommand = 'SCROLL_DOWN';
      openPalmRightCommand = 'NONE';
      openPalmLeftCommand = 'NONE';
      twoFingerCommand = 'NONE';
      fistCommand = 'OPEN_THAIJO';
      pinchCommand = 'CLICK';

      smoothingWindow = 5;
      debounceTime = 300;
    });
    gestureSettingsService.reset();
  }

  void updateSharedGestureSettings() {
    gestureSettingsService.update(
      GestureMapping(
        openPalmUpCommand: openPalmUpCommand,
        openPalmDownCommand: openPalmDownCommand,
        openPalmRightCommand: openPalmRightCommand,
        openPalmLeftCommand: openPalmLeftCommand,
        twoFingerCommand: twoFingerCommand,
        fistCommand: fistCommand,
        pinchCommand: pinchCommand,
        smoothingWindow: smoothingWindow,
        debounceTime: debounceTime,
      ),
    );
  }

  Widget gestureMappingRow({
    required String icon,
    required String gestureName,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 26),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              gestureName,
              style: const TextStyle(fontSize: 15),
            ),
          ),

          const Icon(Icons.arrow_forward, size: 18),

          const SizedBox(width: 10),

          SizedBox(
            width: 135,
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: commandItems,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.settings,
              size: 80,
            ),

            const SizedBox(height: 24),

            const Text(
              'หน้าตั้งค่าการเชื่อมต่อ',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'กรอก IP Address และ Port ของคอมพิวเตอร์ที่เปิด Python WebSocket Server',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: 'เช่น 127.0.0.1 หรือ 192.168.1.xx',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: 'เช่น 8765',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(237, 243, 114, 88),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: connectToServer,
                    icon: const Icon(Icons.wifi),
                    label: const Text('Connect'),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: disconnectFromServer,
                    icon: const Icon(Icons.close),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            ValueListenableBuilder<bool>(
              valueListenable: webSocketService.isConnected,
              builder: (context, connected, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: connected
                        ? Colors.green.withOpacity(0.18)
                        : Colors.red.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    connected ? 'Status: Connected' : 'Status: Disconnected',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: connected ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            ValueListenableBuilder<String>(
              valueListenable: webSocketService.statusText,
              builder: (context, status, child) {
                return Text(
                  status,
                  textAlign: TextAlign.center,
                );
              },
            ),

            const SizedBox(height: 12),

            ValueListenableBuilder<String>(
              valueListenable: webSocketService.lastAck,
              builder: (context, ack, child) {
                return Text(
                  'Last ACK: $ack',
                  textAlign: TextAlign.center,
                );
              },
            ),

            const SizedBox(height: 28),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GESTURE MAPPING',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  gestureMappingRow(
                    icon: '🖐️',
                    gestureName: 'Open Palm Up',
                    value: openPalmUpCommand,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        openPalmUpCommand = value;
                        updateSharedGestureSettings();
                      });
                    },
                  ),

                  gestureMappingRow(
                    icon: '🖐️',
                    gestureName: 'Open Palm Down',
                    value: openPalmDownCommand,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        openPalmDownCommand = value;
                        updateSharedGestureSettings();
                      });
                    },
                  ),

                  gestureMappingRow(
                    icon: '👉',
                    gestureName: 'Open Palm Right',
                    value: openPalmRightCommand,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        openPalmRightCommand = value;
                        updateSharedGestureSettings();
                      });
                    },
                  ),

                  gestureMappingRow(
                    icon: '👈',
                    gestureName: 'Open Palm Left',
                    value: openPalmLeftCommand,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        openPalmLeftCommand = value;
                        updateSharedGestureSettings();
                      });
                    },
                  ),

                  gestureMappingRow(
                    icon: '✌️',
                    gestureName: 'Two Finger',
                    value: twoFingerCommand,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        twoFingerCommand = value;
                        updateSharedGestureSettings();
                      });
                    },
                  ),

                  gestureMappingRow(
                    icon: '✊',
                    gestureName: 'Fist',
                    value: fistCommand,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        fistCommand = value;
                        updateSharedGestureSettings();
                      });
                    },
                  ),

                  gestureMappingRow(
                    icon: '👌',
                    gestureName: 'Pinch / OK Sign',
                    value: pinchCommand,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        pinchCommand = value;
                        updateSharedGestureSettings();
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: resetDefaultSettings,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset to Default'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SENSITIVITY & PROCESSING',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Smoothing Window'),
                      Text(smoothingWindow.round().toString()),
                    ],
                  ),

                  Slider(
                    value: smoothingWindow,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: const Color.fromARGB(237, 243, 114, 88),
                    onChanged: (value) {
                      setState(() {
                        smoothingWindow = value;
                        updateSharedGestureSettings();
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Debounce Time (ms)'),
                      Text('${debounceTime.round()} ms'),
                    ],
                  ),

                  Slider(
                    value: debounceTime,
                    min: 100,
                    max: 1000,
                    divisions: 9,
                    activeColor: const Color.fromARGB(237, 243, 114, 88),
                    onChanged: (value) {
                      setState(() {
                        debounceTime = value;
                        updateSharedGestureSettings();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}