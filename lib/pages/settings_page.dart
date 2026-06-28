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
  late final TextEditingController ipController;
  late final TextEditingController portController;

  String oneFingerCommand = 'CURSOR_MOVE';
  String thumbCommand = 'CLOSE_BROWSER';
  String openPalmUpCommand = 'SCROLL_UP';
  String openPalmDownCommand = 'SCROLL_DOWN';
  String fistCommand = 'OPEN_THAIJO';
  String twoFingerCommand = 'THAIJO_SUBMIT_SEARCH';

  double smoothingWindow = 5;
  double debounceTime = 300;

  final List<DropdownMenuItem<String>> commandItems = const [
    DropdownMenuItem(value: 'NONE', child: Text('None')),
    DropdownMenuItem(value: 'CURSOR_MOVE', child: Text('Cursor Move')),
    DropdownMenuItem(value: 'CLICK', child: Text('Click')),
    DropdownMenuItem(value: 'CONFIRM', child: Text('Confirm / Enter')),
    DropdownMenuItem(value: 'SCROLL_UP', child: Text('Scroll Up')),
    DropdownMenuItem(value: 'SCROLL_DOWN', child: Text('Scroll Down')),
    DropdownMenuItem(value: 'OPEN_THAIJO', child: Text('Open ThaiJO')),
    DropdownMenuItem(
      value: 'THAIJO_SUBMIT_SEARCH',
      child: Text('Submit ThaiJO Search'),
    ),
    DropdownMenuItem(value: 'CLOSE_BROWSER', child: Text('Close Browser')),
  ];

  @override
  void initState() {
    super.initState();

    ipController = TextEditingController(text: webSocketService.lastIp);
    portController = TextEditingController(text: webSocketService.lastPort);

    final mapping = gestureSettingsService.mapping.value;

    oneFingerCommand = mapping.oneFingerCommand;
    thumbCommand = mapping.thumbCommand;
    openPalmUpCommand = mapping.openPalmUpCommand;
    openPalmDownCommand = mapping.openPalmDownCommand;
    fistCommand = mapping.fistCommand;
    twoFingerCommand = mapping.twoFingerCommand;

    smoothingWindow = mapping.smoothingWindow;
    debounceTime = mapping.debounceTime;
  }

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
    gestureSettingsService.reset();

    final mapping = gestureSettingsService.mapping.value;

    setState(() {
      oneFingerCommand = mapping.oneFingerCommand;
      thumbCommand = mapping.thumbCommand;
      openPalmUpCommand = mapping.openPalmUpCommand;
      openPalmDownCommand = mapping.openPalmDownCommand;
      fistCommand = mapping.fistCommand;
      twoFingerCommand = mapping.twoFingerCommand;

      smoothingWindow = mapping.smoothingWindow;
      debounceTime = mapping.debounceTime;
    });
  }

  void updateSharedGestureSettings() {
    gestureSettingsService.update(
      GestureMapping(
        oneFingerCommand: oneFingerCommand,
        thumbCommand: thumbCommand,
        openPalmUpCommand: openPalmUpCommand,
        openPalmDownCommand: openPalmDownCommand,
        fistCommand: fistCommand,
        twoFingerCommand: twoFingerCommand,
        smoothingWindow: smoothingWindow,
        debounceTime: debounceTime,
      ),
    );
  }

  static const Color reginaBeige = Color(0xFFFFF5D7);
  static const Color coralPink = Color.fromARGB(255, 246, 151, 203);
  static const Color sleutheYellow = Color(0xFFFEB300);
  static const Color pinkLeaf = Color(0xFFFFAAAB);
  static const Color warmBrown = Color(0xFF6B4E3D);
  static const Color softBrown = Color(0xFF9A7B5F);

  Widget _softCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pinkLeaf.withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: warmBrown.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: softBrown),
      hintStyle: TextStyle(color: softBrown.withOpacity(0.65)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.64),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: pinkLeaf.withOpacity(0.45)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: pinkLeaf.withOpacity(0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: coralPink, width: 1.6),
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
          SizedBox(
            width: 34,
            child: Text(
              icon,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 25),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              gestureName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: warmBrown,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: value,
              isExpanded: true,
              items: commandItems,
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.68),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: pinkLeaf.withOpacity(0.45)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: pinkLeaf.withOpacity(0.45)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: warmBrown,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [reginaBeige, Color(0xFFFFE4B8), Color(0xFFFFD1D2)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            child: Column(
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.72),
                    shape: BoxShape.circle,
                    border: Border.all(color: pinkLeaf.withOpacity(0.55)),
                    boxShadow: [
                      BoxShadow(
                        color: warmBrown.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    size: 58,
                    color: warmBrown,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Connection Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: warmBrown,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Enter the IP address and port of the Python WebSocket Server.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: softBrown,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 18),

                _softCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: ipController,
                        style: const TextStyle(
                          color: warmBrown,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _inputDecoration(
                          label: 'IP Address',
                          hint: 'Example: 127.0.0.1 or 192.168.1.xx',
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: portController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: warmBrown,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _inputDecoration(
                          label: 'Port',
                          hint: 'Example: 8765',
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  elevation: 4,
                                  backgroundColor: coralPink,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: connectToServer,
                                icon: const Icon(Icons.wifi_rounded),
                                label: const Text(
                                  'Connect',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  elevation: 2,
                                  backgroundColor: softBrown,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: disconnectFromServer,
                                icon: const Icon(Icons.close_rounded),
                                label: const Text(
                                  'Disconnect',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

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
        border: Border.all(
          color: connected
              ? Colors.green.withOpacity(0.35)
              : Colors.red.withOpacity(0.35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: connected ? Colors.green : Colors.red,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            connected ? 'Succeed' : 'Disconnected',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: connected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  },
),

                const SizedBox(height: 16),

                _softCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gesture Mapping',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: warmBrown,
                        ),
                      ),

                      const SizedBox(height: 14),

                      gestureMappingRow(
                        icon: '🖐️',
                        gestureName: 'Open Palm Up',
                        value: openPalmUpCommand,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            openPalmUpCommand = value;
                          });
                          updateSharedGestureSettings();
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
                          });
                          updateSharedGestureSettings();
                        },
                      ),

                      gestureMappingRow(
                        icon: '☝️',
                        gestureName: 'One Finger',
                        value: oneFingerCommand,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            oneFingerCommand = value;
                          });
                          updateSharedGestureSettings();
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
                          });
                          updateSharedGestureSettings();
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
                          });
                          updateSharedGestureSettings();
                        },
                      ),

                      gestureMappingRow(
                        icon: '👍',
                        gestureName: 'Thumb',
                        value: thumbCommand,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            thumbCommand = value;
                          });
                          updateSharedGestureSettings();
                        },
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: coralPink,
                            side: const BorderSide(color: coralPink),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: resetDefaultSettings,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text(
                            'Reset to Default',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _softCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sensitivity & Processing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: warmBrown,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Smoothing Window',
                            style: TextStyle(
                              color: warmBrown,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            smoothingWindow.round().toString(),
                            style: const TextStyle(
                              color: softBrown,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),

                      Slider(
                        value: smoothingWindow,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        activeColor: coralPink,
                        inactiveColor: pinkLeaf.withOpacity(0.35),
                        onChanged: (value) {
                          setState(() {
                            smoothingWindow = value;
                          });
                          updateSharedGestureSettings();
                        },
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Debounce Time',
                            style: TextStyle(
                              color: warmBrown,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${debounceTime.round()} ms',
                            style: const TextStyle(
                              color: softBrown,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),

                      Slider(
                        value: debounceTime,
                        min: 100,
                        max: 1000,
                        divisions: 9,
                        activeColor: coralPink,
                        inactiveColor: pinkLeaf.withOpacity(0.35),
                        onChanged: (value) {
                          setState(() {
                            debounceTime = value;
                          });
                          updateSharedGestureSettings();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
