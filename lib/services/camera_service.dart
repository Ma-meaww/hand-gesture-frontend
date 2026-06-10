import 'package:camera/camera.dart';

class CameraService {
  List<CameraDescription> cameras = [];

  Future<void> loadCameras() async {
    try {
      cameras = await availableCameras();
    } catch (_) {
      cameras = [];
    }
  }

  CameraDescription? get frontCamera {
    if (cameras.isEmpty) return null;

    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  }
}

final cameraService = CameraService();