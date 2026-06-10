import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import '../services/camera_service.dart';
import '../services/websocket_service.dart';
import '../services/training_sample_service.dart';

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

  // Training Mode
  bool isTrainingMode = false;
  bool isRecording = false;
  String selectedGestureLabel = 'OPEN_PALM';

  Timer? recordingTimer;

  final List<String> gestureLabels = const [
    'OPEN_PALM',
    'FIST',
    'PINCH',
    'ONE_FINGER',
    'TWO_FINGER',
    'FIST_HOLD',
  ];

  @override
  void initState() {
    super.initState();
    setupCamera();
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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      initializeCameraFuture = cameraController!.initialize();
      await initializeCameraFuture;

      try {
        handLandmarkerPlugin = HandLandmarkerPlugin.create(
          numHands: 2,
          minHandDetectionConfidence: 0.7,
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
    if (cameraController == null || !cameraController!.value.isInitialized) {
      webSocketService.statusText.value = 'Camera not ready';
      return;
    }

    if (handLandmarkerPlugin == null) {
      webSocketService.statusText.value =
          'Hand Landmarker not ready: test on real Android phone later';
      return;
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
    });

    webSocketService.statusText.value = 'Hand detection stopped';
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

      if (!mounted) return;

      setState(() {
        detectedHandCount = hands.length;
        latestLandmarkFeatures = features;
      });
    } catch (e) {
      debugPrint('Hand detection error: $e');
    } finally {
      isProcessingFrame = false;
    }
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

  String buildCsvText() {
    final headers = <String>['label'];

    for (int i = 0; i < 21; i++) {
      headers.add('x$i');
      headers.add('y$i');
      headers.add('z$i');
    }

    final rows = [
      headers.join(','),
      ...trainingSamples.map((row) => row.join(',')),
    ];

    return rows.join('\n');
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

  void sendGestureCommand({required String command, required String gesture}) {
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
        sendGestureCommand(command: command, gesture: gesture);
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
            child: CameraPreview(cameraController!),
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
            value: selectedGestureLabel,
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
                  ? 'Detected Hands: $detectedHandCount | Landmark Features: ${latestLandmarkFeatures.length}'
                  : 'Detection is stopped',
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
              'Mock Gesture Commands',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                commandButton(
                  label: 'Scroll Up',
                  command: 'SCROLL_UP',
                  gesture: 'OPEN_PALM_UP',
                ),
                commandButton(
                  label: 'Scroll Down',
                  command: 'SCROLL_DOWN',
                  gesture: 'OPEN_PALM_DOWN',
                ),
                commandButton(
                  label: 'Click',
                  command: 'CLICK',
                  gesture: 'PINCH',
                ),
                commandButton(
                  label: 'Confirm',
                  command: 'CONFIRM',
                  gesture: 'PINCH_CONFIRM',
                ),
                commandButton(
                  label: 'Open ThaiJO',
                  command: 'OPEN_THAIJO',
                  gesture: 'FIST_HOLD',
                ),
                commandButton(
                  label: 'Close Browser',
                  command: 'CLOSE_BROWSER',
                  gesture: 'CLOSE_BROWSER',
                ),
              ],
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

final TrainingSampleService trainingService = TrainingSampleService();
