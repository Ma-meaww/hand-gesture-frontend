import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import '../app_settings.dart';
import '../services/camera_service.dart';
import '../services/websocket_service.dart';
import '../services/training_sample_service.dart';
import '../services/gesture_settings_service.dart';
import '../services/gesture_classifier_service.dart';

class GestureControlPage extends StatefulWidget {
  const GestureControlPage({super.key});

  @override
  State<GestureControlPage> createState() => _GestureControlPageState();
}

class _GestureControlPageState extends State<GestureControlPage> {
  CameraController? cameraController;
  Future<void>? initializeCameraFuture;

  bool isDetecting = false;
  HandLandmarkerPlugin? handLandmarkerPlugin;

  bool isProcessingFrame = false;
  int detectedHandCount = 0;
  List<double> latestLandmarkFeatures = [];

  String latestGesture = 'UNKNOWN';
  int debugFrameCount = 0;

  final List<String> gestureHistory = [];

  DateTime? lastCommandSentAt;
  DateTime? lastCursorMoveSentAt;
  String lastSentGesture = 'UNKNOWN';

  double? smoothedCursorX;
  double? smoothedCursorY;
  bool cursorWasActive = false;

  int cursorLostFrameCount = 0;
  static const int cursorMaxLostFrames = 4;

  int oneFingerCandidateFrameCount = 0;
  static const int oneFingerRequiredFrames = 2;

  int oneFingerMissFrameCount = 0;
  static const int oneFingerMaxMissFrames = 1;

  static const bool cursorMirrorX = true;
  static const bool cursorMirrorY = true;
  static const bool cursorSwapXY = true;

  static const double cursorSmoothingFactor = 0.35;
  static const double cursorEdgeMargin = 0.12;

  // Training Mode
  bool isTrainingMode = false;
  bool isRecording = false;
  String selectedGestureLabel = 'ONE_FINGER';

  Timer? recordingTimer;

  final TrainingSampleService trainingService = TrainingSampleService();
  final Map<String, int> lastGestureCommandSentAt = {};
  final List<List<double>> landmarkFeatureHistory = [];
  final GestureClassifierService gestureClassifier = GestureClassifierService();

  final List<String> gestureLabels = const [
    'ONE_FINGER',
    'THUMB',
    'FIST',
    'OPEN_PALM_UP',
    'OPEN_PALM_DOWN',
    'TWO_FINGER',
  ];

  @override
  void initState() {
    super.initState();
    setupAll();
  }

  Future<void> setupAll() async {
    await setupGestureClassifier();
    await setupCamera();
  }

  Future<void> setupGestureClassifier() async {
    try {
      await gestureClassifier.loadDataset();
      webSocketService.statusText.value = 'Gesture dataset loaded';
      debugPrint('Gesture dataset loaded successfully');
    } catch (e) {
      webSocketService.statusText.value = 'Gesture dataset load failed';
      debugPrint('Gesture dataset load error: $e');
    }
  }

  Future<void> setupCamera() async {
    try {
      final selectedCamera = cameraService.frontCamera;

      if (selectedCamera == null) {
        webSocketService.statusText.value = 'ไม่พบกล้องในอุปกรณ์นี้';
        return;
      }

      cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      initializeCameraFuture = cameraController!.initialize();
      await initializeCameraFuture;

      try {
        handLandmarkerPlugin = HandLandmarkerPlugin.create(
          numHands: 1,
          minHandDetectionConfidence: 0.5,
          delegate: HandLandmarkerDelegate.cpu,
        );

        webSocketService.statusText.value = 'Camera and Hand Landmarker ready';
      } catch (e, stackTrace) {
        handLandmarkerPlugin = null;
        webSocketService.statusText.value =
            'Camera ready, Hand Landmarker not ready';

        debugPrint('Hand Landmarker create error: $e');
        debugPrint('Hand Landmarker stack trace: $stackTrace');
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      webSocketService.statusText.value = 'Camera setup failed';
      debugPrint('Camera setup error: $e');

      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    recordingTimer?.cancel();

    try {
      final controller = cameraController;

      if (controller != null && controller.value.isStreamingImages) {
        controller.stopImageStream().catchError((error) {
          debugPrint('Stop image stream error: $error');
        });
      }

      controller?.dispose();
    } catch (e) {
      debugPrint('Camera dispose error: $e');
    }

    handLandmarkerPlugin?.dispose();

    super.dispose();
  }

  Future<void> startHandDetection() async {
    gestureHistory.clear();
    oneFingerCandidateFrameCount = 0;
    oneFingerMissFrameCount = 0;
    latestGesture = 'UNKNOWN';
    if (cameraController == null || !cameraController!.value.isInitialized) {
      webSocketService.statusText.value = 'Camera not ready';
      return;
    }

    if (handLandmarkerPlugin == null) {
      webSocketService.statusText.value =
          'Hand Landmarker not ready: test on real Android phone later';
    }

    if (cameraController!.value.isStreamingImages) {
      return;
    }

    await cameraController!.startImageStream(processCameraImage);

    setState(() {
      isDetecting = true;
    });

    webSocketService.statusText.value = 'Hand detection started';
  }

  Future<void> stopHandDetection() async {
    recordingTimer?.cancel();

    if (cameraController != null && cameraController!.value.isStreamingImages) {
      await cameraController!.stopImageStream();
    }

    setState(() {
      isDetecting = false;
      isRecording = false;
      detectedHandCount = 0;
      latestLandmarkFeatures = [];
      latestGesture = 'UNKNOWN';
    });

    landmarkFeatureHistory.clear();
    webSocketService.statusText.value = 'Hand detection stopped';
    gestureHistory.clear();
    oneFingerCandidateFrameCount = 0;
    oneFingerMissFrameCount = 0;
    resetCursorControl();
  }

  List<double> smoothLandmarkFeatures(List<double> features) {
    if (features.length != 63) {
      landmarkFeatureHistory.clear();
      return features;
    }

    final configuredWindow = gestureSettingsService
        .mapping
        .value
        .smoothingWindow
        .round();

    final windowSize = configuredWindow < 1 ? 1 : configuredWindow;

    landmarkFeatureHistory.add(List<double>.from(features));

    while (landmarkFeatureHistory.length > windowSize) {
      landmarkFeatureHistory.removeAt(0);
    }

    final smoothedFeatures = List<double>.filled(features.length, 0);

    for (final sample in landmarkFeatureHistory) {
      for (int i = 0; i < sample.length; i++) {
        smoothedFeatures[i] += sample[i];
      }
    }

    for (int i = 0; i < smoothedFeatures.length; i++) {
      smoothedFeatures[i] = smoothedFeatures[i] / landmarkFeatureHistory.length;
    }

    return smoothedFeatures;
  }

  Future<void> processCameraImage(CameraImage image) async {
    if (isProcessingFrame ||
        handLandmarkerPlugin == null ||
        cameraController == null) {
      return;
    }

    isProcessingFrame = true;

    try {
      final hands = handLandmarkerPlugin!.detect(
        image,
        cameraController!.description.sensorOrientation,
      );      

      final features = <double>[];

      if (hands.isNotEmpty) {
        final firstHand = hands.first;

        for (final landmark in firstHand.landmarks) {
          features.add(landmark.x);
          features.add(landmark.y);
          features.add(landmark.z);
        }
      }

      final processedFeatures = smoothLandmarkFeatures(features);
      final normalizedFeatures = normalizeFeatures(processedFeatures);

      final predictedGesture = gestureClassifier.classify(normalizedFeatures);
      final guardedGesture = applyGestureRuleGuard(
        predictedGesture,
        normalizedFeatures,
      );

      final detectedGesture = confirmOneFingerGesture(guardedGesture);

      debugFrameCount++;
      if (debugFrameCount % 30 == 0) {
        debugPrint(
          'KNN gesture: $detectedGesture | hands=${hands.length} | features=${processedFeatures.length}',
        );
      }

      final stableGesture = smoothGesture(detectedGesture);

      if (!mounted) return;

      setState(() {
        detectedHandCount = hands.length;
        latestLandmarkFeatures = processedFeatures;
        latestGesture = stableGesture;
      });

      handleGestureCommand(stableGesture, processedFeatures);
    } catch (e) {
      debugPrint('Hand detection error: $e');
    } finally {
      isProcessingFrame = false;
    }
  }

  double landmarkX(List<double> features, int index) {
    return features[index * 3];
  }

  double landmarkY(List<double> features, int index) {
    return features[index * 3 + 1];
  }

  double distance2D(List<double> features, int a, int b) {
    final dx = landmarkX(features, a) - landmarkX(features, b);
    final dy = landmarkY(features, a) - landmarkY(features, b);

    return (dx * dx + dy * dy);
  }

  List<double> normalizeFeatures(List<double> features) {
    if (features.length != 63) {
      return features;
    }

    final wristX = landmarkX(features, 0);
    final wristY = landmarkY(features, 0);
    final wristZ = features[2];

    // ขนาดมืออ้างอิงจากระยะ wrist -> middle_mcp (index 9)
    final handSize = math.sqrt(distance2D(features, 0, 9));

    if (handSize < 0.001) {
      return features;
    }

    final normalized = List<double>.filled(features.length, 0);

    for (int i = 0; i < 21; i++) {
      normalized[i * 3] = (features[i * 3] - wristX) / handSize;
      normalized[i * 3 + 1] = (features[i * 3 + 1] - wristY) / handSize;
      normalized[i * 3 + 2] = (features[i * 3 + 2] - wristZ) / handSize;
    }

    return normalized;
  }

  bool isFingerExtended(
    List<double> features, {
    required int tip,
    required int pip,
  }) {
    return landmarkY(features, tip) < landmarkY(features, pip) - 0.025;
  }

  bool isFingerLikelyExtended(
    List<double> features, {
    required int tip,
    required int pip,
  }) {
    if (features.length != 63) {
      return false;
    }

    return landmarkY(features, tip) < landmarkY(features, pip) - 0.02;
  }

  bool isThumbExtended(List<double> features) {
    if (features.length != 63) {
      return false;
    }

    final thumbTipToWrist = distance2D(features, 4, 0);
    final thumbIpToWrist = distance2D(features, 3, 0);

    return thumbTipToWrist > thumbIpToWrist * 1.15;
  }

  bool isFingerFolded(
    List<double> features, {
    required int tip,
    required int pip,
    required int mcp,
  }) {
    final tipToWrist = distance2D(features, tip, 0);
    final mcpToWrist = distance2D(features, mcp, 0);

    // นิ้วงอจริง = ปลายนิ้วต้องอยู่ใกล้ข้อมือกว่าข้อนิ้วโคน
    return tipToWrist < mcpToWrist * 1.15;
  }

  String applyGestureRuleGuard(String predictedGesture, List<double> features) {

    if (features.length != 63) {
      return 'UNKNOWN';
    }

    final indexExtended = isFingerExtended(features, tip: 8, pip: 6);
    final middleExtended = isFingerExtended(features, tip: 12, pip: 10);
    final ringExtended = isFingerExtended(features, tip: 16, pip: 14);
    final pinkyExtended = isFingerExtended(features, tip: 20, pip: 18);

    final indexFolded = isFingerFolded(features, tip: 8, pip: 6, mcp: 5);
    final middleFolded = isFingerFolded(features, tip: 12, pip: 10, mcp: 9);
    final ringFolded = isFingerFolded(features, tip: 16, pip: 14, mcp: 13);
    final pinkyFolded = isFingerFolded(features, tip: 20, pip: 18, mcp: 17);

    final foldedCount = [
      indexFolded,
      middleFolded,
      ringFolded,
      pinkyFolded,
    ].where((value) => value).length;

    final thumbExtended = isThumbExtended(features);

    // ★ เช็ก THUMB ก่อน เพราะไม่ได้นับอยู่ใน foldedCount/extendedFingerCount
    final isThumbByRule =
        thumbExtended &&
        !indexExtended &&
        !middleExtended &&
        !ringExtended &&
        !pinkyExtended;

    if (isThumbByRule) {
      return 'THUMB';
    }

    final extendedFingerCount = 4 - foldedCount;

    if (!thumbExtended && extendedFingerCount == 0) {
      return 'FIST';
    }

    if (extendedFingerCount == 1) {
      return 'ONE_FINGER';
    }

    if (extendedFingerCount == 2) {
      return 'TWO_FINGER';
    }

    if (extendedFingerCount >= 3) {
      final wristY = landmarkY(features, 0);

      final avgFingerTipY =
          (landmarkY(features, 8) +
              landmarkY(features, 12) +
              landmarkY(features, 16) +
              landmarkY(features, 20)) /
          4;

      return avgFingerTipY < wristY ? 'OPEN_PALM_UP' : 'OPEN_PALM_DOWN';
    }

    return predictedGesture;
  }

  String confirmOneFingerGesture(String gesture) {
    if (gesture == 'ONE_FINGER') {
      oneFingerCandidateFrameCount++;
      oneFingerMissFrameCount = 0;

      if (oneFingerCandidateFrameCount < oneFingerRequiredFrames) {
        return 'UNKNOWN';
      }

      return 'ONE_FINGER';
    }

    if (gesture == 'UNKNOWN' && oneFingerCandidateFrameCount > 0) {
      oneFingerMissFrameCount++;

      if (oneFingerMissFrameCount <= oneFingerMaxMissFrames) {
        return latestGesture == 'ONE_FINGER' ? 'ONE_FINGER' : 'UNKNOWN';
      }
    }

    oneFingerCandidateFrameCount = 0;
    oneFingerMissFrameCount = 0;

    return gesture;
  }

  String smoothGesture(String gesture) {
    gestureHistory.add(gesture);

    final configuredWindow =
        gestureSettingsService.mapping.value.smoothingWindow.round();

    final maxWindow = configuredWindow < 1 ? 1 : configuredWindow;

    if (gestureHistory.length > maxWindow) {
      gestureHistory.removeAt(0);
    }

    final counts = <String, int>{};

    for (final item in gestureHistory) {
      counts[item] = (counts[item] ?? 0) + 1;
    }

    String bestGesture = 'UNKNOWN';
    int bestCount = 0;

    counts.forEach((key, value) {
      if (value > bestCount) {
        bestGesture = key;
        bestCount = value;
      }
    });

    final requiredCount = (maxWindow * 0.6).ceil();

    if (gestureHistory.length >= maxWindow && bestCount >= requiredCount) {
      return bestGesture;
    }

    return latestGesture;
  }

  double clamp01(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  double expandCursorRange(double value) {
    final expanded = (value - cursorEdgeMargin) / (1 - cursorEdgeMargin * 2);
    return clamp01(expanded);
  }

  bool isOneFingerCursorPose(List<double> features) {
    if (features.length != 63) {
      return false;
    }

    final indexLikelyExtended =
        isFingerLikelyExtended(features, tip: 8, pip: 6);
    final middleLikelyExtended =
        isFingerLikelyExtended(features, tip: 12, pip: 10);
    final ringLikelyExtended =
        isFingerLikelyExtended(features, tip: 16, pip: 14);
    final pinkyLikelyExtended =
        isFingerLikelyExtended(features, tip: 20, pip: 18);

    final middleFolded = isFingerFolded(features, tip: 12, pip: 10, mcp: 9);
    final ringFolded = isFingerFolded(features, tip: 16, pip: 14, mcp: 13);
    final pinkyFolded = isFingerFolded(features, tip: 20, pip: 18, mcp: 17);

    final middleClearlyDown =
        landmarkY(features, 12) > landmarkY(features, 8) + 0.08;

    return indexLikelyExtended &&
        middleClearlyDown &&
        middleFolded &&
        ringFolded &&
        pinkyFolded &&
        !middleLikelyExtended &&
        !ringLikelyExtended &&
        !pinkyLikelyExtended;
  }

  Offset? buildCursorPosition(List<double> features) {
    if (features.length != 63) {
      return null;
    }

    double x = landmarkX(features, 8);
    double y = landmarkY(features, 8);

    if (cursorSwapXY) {
      final temp = x;
      x = y;
      y = temp;
    }

    if (cursorMirrorX) {
      x = 1 - x;
    }

    if (cursorMirrorY) {
      y = 1 - y;
    }

    x = expandCursorRange(x);
    y = expandCursorRange(y);

    if (smoothedCursorX == null || smoothedCursorY == null) {
      smoothedCursorX = x;
      smoothedCursorY = y;
    } else {
      smoothedCursorX =
          smoothedCursorX! + (x - smoothedCursorX!) * cursorSmoothingFactor;
      smoothedCursorY =
          smoothedCursorY! + (y - smoothedCursorY!) * cursorSmoothingFactor;
    }

    return Offset(
      clamp01(smoothedCursorX!),
      clamp01(smoothedCursorY!),
    );
  }

  void resetCursorControl() {
    smoothedCursorX = null;
    smoothedCursorY = null;
    lastCursorMoveSentAt = null;
    cursorLostFrameCount = 0;

    if (cursorWasActive && webSocketService.isConnected.value) {
      webSocketService.sendCommand(
        command: 'CURSOR_RESET',
        gesture: 'CURSOR_RESET',
      );
    }

    cursorWasActive = false;
  }

  void handleGestureCommand(String gesture, List<double> features) {
    if (isTrainingMode || isRecording) {
      resetCursorControl();
      return;
    }

    final mapping = gestureSettingsService.mapping.value;
    final now = DateTime.now();

    // Cursor ต้องมาก่อนการเช็ก UNKNOWN / NONE
    // เพราะตอนขยับมือ classifier อาจหลุดเป็น UNKNOWN/FIST ชั่วคราว
    final oneFingerCommand = mapping.commandForGesture('ONE_FINGER');
    final normalizedCursorFeatures = normalizeFeatures(features);
    final isCursorPose = isOneFingerCursorPose(normalizedCursorFeatures);

    final canTrackCursor =
        oneFingerCommand == 'CURSOR_MOVE' && features.length == 63;

    final shouldTrackCursor =
        canTrackCursor &&
        (gesture == 'ONE_FINGER' || isCursorPose || cursorWasActive);

    if (shouldTrackCursor) {
      if (gesture == 'ONE_FINGER' || isCursorPose) {
        cursorLostFrameCount = 0;
      } else {
        cursorLostFrameCount++;
      }

      if (cursorLostFrameCount > cursorMaxLostFrames) {
        resetCursorControl();
        return;
      }

      final cursorPosition = buildCursorPosition(features);

      if (cursorPosition == null) {
        cursorLostFrameCount++;

        if (cursorLostFrameCount > cursorMaxLostFrames) {
          resetCursorControl();
        }

        return;
      }

      if (lastCursorMoveSentAt != null &&
          now.difference(lastCursorMoveSentAt!).inMilliseconds <
              AppSettings.cursorThrottleMs) {
        return;
      }

      lastCursorMoveSentAt = now;
      cursorWasActive = true;

      webSocketService.sendCommand(
        command: 'CURSOR_MOVE',
        gesture: 'ONE_FINGER',
        x: cursorPosition.dx,
        y: cursorPosition.dy,
      );

      return;
    }

    if (gesture == 'UNKNOWN') {
      lastSentGesture = 'UNKNOWN';
      return;
    }

    final command = mapping.commandForGesture(gesture);

    if (command == 'NONE') {
      webSocketService.statusText.value = 'No command mapped for $gesture';
      return;
    }

    final oneShotCommands = {
      'OPEN_THAIJO',
      'CLICK',
      'CONFIRM',
      'THAIJO_SUBMIT_SEARCH',
      'CLOSE_BROWSER',
    };

    if (oneShotCommands.contains(command) && lastSentGesture == gesture) {
      return;
    }

    final debounceMs = mapping.debounceTime.round();

    if (!oneShotCommands.contains(command) &&
        lastCommandSentAt != null &&
        lastSentGesture == gesture &&
        now.difference(lastCommandSentAt!).inMilliseconds < debounceMs) {
      return;
    }

    lastCommandSentAt = now;
    lastSentGesture = gesture;

    webSocketService.sendCommand(
      command: command,
      gesture: gesture,
    );
  }

  int get totalSampleCount => trainingService.totalSampleCount;

  int getSampleCountByLabel(String label) {
    return trainingService.getSampleCountByLabel(label);
  }

  void toggleDetection() {
    if (isDetecting) {
      stopHandDetection();
    } else {
      startHandDetection();
    }
  }

  void toggleTrainingMode() {
    setState(() {
      isTrainingMode = !isTrainingMode;
    });
  }

  Future<void> startRecording() async {
    if (isRecording) return;

    if (!isDetecting) {
      await startHandDetection();
    }

    if (handLandmarkerPlugin == null || !isDetecting) {
      webSocketService.statusText.value =
          'ยังเริ่มบันทึกไม่ได้ เพราะ Hand Landmarker ยังไม่พร้อม';
      return;
    }

    setState(() {
      isRecording = true;
    });

    webSocketService.statusText.value =
        'Recording $selectedGestureLabel: กรุณาวางมือให้อยู่ในกล้อง';

    recordingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      addLandmarkSample();
    });
  }

  void stopRecording() {
    recordingTimer?.cancel();

    setState(() {
      isRecording = false;
    });

    webSocketService.statusText.value = 'Recording stopped';
  }

  void addLandmarkSample() {
    if (latestLandmarkFeatures.length != 63) {
      webSocketService.statusText.value =
          'ไม่พบ landmark มือ กรุณาวางมือให้อยู่ในกล้อง';
      return;
    }

    trainingService.addSample(
      label: selectedGestureLabel,
      features: latestLandmarkFeatures,
    );

    setState(() {});

    webSocketService.statusText.value =
        'Saved $selectedGestureLabel sample (${getSampleCountByLabel(selectedGestureLabel)})';
  }

  Future<void> exportCsvMock() async {
    if (trainingService.totalSampleCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มี sample สำหรับ export')),
      );
      return;
    }

    final csvText = trainingService.buildCsvText();

    await Clipboard.setData(ClipboardData(text: csvText));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Export CSV แล้ว ($totalSampleCount samples) คัดลอกไว้ใน clipboard',
        ),
      ),
    );
  }

  void clearSamples() {
    stopRecording();

    setState(() {
      trainingService.clear();
    });

    webSocketService.statusText.value = 'Training samples cleared';
  }

  void sendMappedGestureCommand({
    required String command,
    required String gesture,
  }) {
    if (command == 'NONE') {
      webSocketService.statusText.value = 'No command mapped for $gesture';
      return;
    }

    final mapping = gestureSettingsService.mapping.value;
    final debounceMs = mapping.debounceTime.round();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastSentAt = lastGestureCommandSentAt[gesture];

    if (lastSentAt != null && now - lastSentAt < debounceMs) {
      webSocketService.statusText.value =
          'Ignored $gesture: debounce active (${debounceMs}ms)';
      return;
    }

    lastGestureCommandSentAt[gesture] = now;

    webSocketService.sendCommand(command: command, gesture: gesture);
  }

  void sendMacro() {
    webSocketService.sendCommand(command: 'OPEN_THAIJO', gesture: 'MACRO');
  }

  Widget wifiIcon(bool isConnected) {
    if (isConnected) {
      return const Icon(Icons.wifi, color: Colors.green, size: 22);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.wifi, color: Colors.red, size: 22),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 9),
          ),
        ),
      ],
    );
  }

  Widget commandButton({
    required String label,
    required String command,
    required String gesture,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(237, 243, 114, 88),
        foregroundColor: Colors.white,
      ),
      onPressed: () {
        sendMappedGestureCommand(command: command, gesture: gesture);
      },
      child: Text(label),
    );
  }

  Widget cameraPreviewBox() {
    if (cameraController == null || initializeCameraFuture == null) {
      return const Center(
        child: Text(
          'Camera Preview\nไม่พบกล้องหรือยังไม่ได้เปิดกล้อง',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return FutureBuilder<void>(
      future: initializeCameraFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            cameraController!.value.isInitialized) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(cameraController!),

                CustomPaint(
                  painter: HandLandmarkPainter(
                    landmarks: latestLandmarkFeatures,
                    mirrorX: true,
                    mirrorY: true,
                    swapXY: true,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'เปิดกล้องไม่สำเร็จ\n${snapshot.error}',
            textAlign: TextAlign.center,
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget labelCountChip(String label) {
    final count = getSampleCountByLabel(label);

    return Chip(
      label: Text('$label: $count'),
      backgroundColor: label == selectedGestureLabel
          ? const Color.fromARGB(90, 243, 114, 88)
          : Colors.white.withOpacity(0.6),
    );
  }

  Widget trainingModeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color.fromARGB(120, 243, 114, 88)),
      ),
      child: Column(
        children: [
          const Text(
            'Training Mode',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Current Label: $selectedGestureLabel',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: selectedGestureLabel,
            decoration: const InputDecoration(
              labelText: 'Gesture Label',
              border: OutlineInputBorder(),
            ),
            items: gestureLabels.map((label) {
              return DropdownMenuItem(value: label, child: Text(label));
            }).toList(),
            onChanged: isRecording
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      selectedGestureLabel = value;
                    });
                  },
          ),

          const SizedBox(height: 16),

          Text(
            'Total Sample Count: $totalSampleCount',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: gestureLabels.map(labelCountChip).toList(),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording
                        ? Colors.grey
                        : const Color.fromARGB(237, 243, 114, 88),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isRecording
                      ? null
                      : () {
                          startRecording();
                        },
                  child: const Text('Start Recording'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isRecording ? stopRecording : null,
                  child: const Text('Stop'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: exportCsvMock,
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export CSV'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: clearSamples,
                  icon: const Icon(Icons.delete),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'ระบบจะบันทึก landmark 21 จุดจาก MediaPipe เมื่อพบมือในกล้อง',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gesture Control',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: webSocketService.isConnected,
              builder: (context, connected, child) {
                return Container(
                  height: 40,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(96, 249, 136, 71),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('สถานะ : ', style: TextStyle(fontSize: 14)),
                      ValueListenableBuilder<String>(
                        valueListenable: webSocketService.statusText,
                        builder: (context, status, child) {
                          return Flexible(
                            child: Text(
                              status,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      wifiIcon(connected),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            Container(
              height: 420,
              width: 280,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(16),
              ),
              child: cameraPreviewBox(),
            ),

            const SizedBox(height: 8),

            Text(
              isDetecting
                  ? 'Detected Hands: $detectedHandCount | Features: ${latestLandmarkFeatures.length} | Gesture: $latestGesture'
                  : 'Detection is stopped',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            const Text(
              'หน้าตรวจจับท่าทางมือ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDetecting
                          ? Colors.grey
                          : const Color.fromARGB(237, 243, 114, 88),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: toggleDetection,
                    child: Text(
                      isDetecting ? 'Stop Detection' : 'Start Detection',
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(237, 243, 114, 88),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: sendMacro,
                    child: const Text("Macro"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              isDetecting
                  ? 'Auto gesture control is active. Hand gestures can send commands automatically.'
                  : 'Press Start Detection to enable auto gesture control.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: toggleTrainingMode,
                icon: const Icon(Icons.model_training),
                label: Text(
                  isTrainingMode ? 'Hide Training Mode' : 'Show Training Mode',
                ),
              ),
            ),

            if (isTrainingMode) ...[
              const SizedBox(height: 16),
              trainingModeSection(),
            ],

            const SizedBox(height: 20),

            const Text(
              'Manual Test Commands',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ValueListenableBuilder(
              valueListenable: gestureSettingsService.mapping,
              builder: (context, mapping, child) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    commandButton(
                      label: 'Open Palm Up',
                      command: mapping.openPalmUpCommand,
                      gesture: 'OPEN_PALM_UP',
                    ),
                    commandButton(
                      label: 'Open Palm Down',
                      command: mapping.openPalmDownCommand,
                      gesture: 'OPEN_PALM_DOWN',
                    ),
                    commandButton(
                      label: 'Two Finger',
                      command: mapping.twoFingerCommand,
                      gesture: 'TWO_FINGER',
                    ),
                    commandButton(
                      label: 'Fist',
                      command: mapping.fistCommand,
                      gesture: 'FIST',
                    ),
                    commandButton(
                      label: 'Thumb',
                      command: mapping.thumbCommand,
                      gesture: 'THUMB',
                    ),
                    commandButton(
                      label: 'Close Browser',
                      command: 'CLOSE_BROWSER',
                      gesture: 'CLOSE_BROWSER',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            ValueListenableBuilder<String>(
              valueListenable: webSocketService.lastAck,
              builder: (context, ack, child) {
                return Text('Last ACK: $ack', textAlign: TextAlign.center);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HandLandmarkPainter extends CustomPainter {
  final List<double> landmarks;
  final bool mirrorX;
  final bool mirrorY;
  final bool swapXY;

  HandLandmarkPainter({
    required this.landmarks,
    this.mirrorX = false,
    this.mirrorY = false,
    this.swapXY = false,
  });

  static const List<List<int>> fingerConnections = [
    [0, 1, 2, 3, 4],      // Thumb
    [0, 5, 6, 7, 8],      // Index
    [0, 9, 10, 11, 12],   // Middle
    [0, 13, 14, 15, 16],  // Ring
    [0, 17, 18, 19, 20],  // Pinky
    [5, 9, 13, 17, 5],    // Palm
  ];

  static const Map<int, String> fingertipLabels = {
    4: 'โป้ง',
    8: 'ชี้',
    12: 'กลาง',
    16: 'นาง',
    20: 'ก้อย',
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.length != 63) {
      return;
    }

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill;

    final fingertipPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    Offset pointOf(int index) {
      double x = landmarks[index * 3].clamp(0.0, 1.0).toDouble();
      double y = landmarks[index * 3 + 1].clamp(0.0, 1.0).toDouble();

      if (swapXY) {
        final temp = x;
        x = y;
        y = temp;
      }

      if (mirrorX) {
        x = 1 - x;
      }

      if (mirrorY) {
        y = 1 - y;
      }

      return Offset(
        x * size.width,
        y * size.height,
      );
    }

    // วาดเส้นเชื่อมข้อนิ้ว
    for (final connection in fingerConnections) {
      for (int i = 0; i < connection.length - 1; i++) {
        final start = pointOf(connection[i]);
        final end = pointOf(connection[i + 1]);

        canvas.drawLine(start, end, linePaint);
      }
    }

    // วาดจุด landmark ทั้ง 21 จุด
    for (int i = 0; i < 21; i++) {
      final point = pointOf(i);

      final isFingertip = fingertipLabels.containsKey(i);

      canvas.drawCircle(
        point,
        isFingertip ? 7 : 4,
        isFingertip ? fingertipPaint : pointPaint,
      );
    }

    // เขียนชื่อปลายนิ้ว
    fingertipLabels.forEach((index, label) {
      final point = pointOf(index);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final labelOffset = Offset(
        point.dx + 8,
        point.dy - 18,
      );

      textPainter.paint(canvas, labelOffset);
    });
  }

  @override
  bool shouldRepaint(covariant HandLandmarkPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
      oldDelegate.mirrorX != mirrorX ||
      oldDelegate.mirrorY != mirrorY ||
      oldDelegate.swapXY != swapXY;
  }
}