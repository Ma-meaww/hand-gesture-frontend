import 'dart:math';

class GestureClassifierService {
  String classify(List<double> features) {
    if (features.length != 63) {
      return 'UNKNOWN';
    }

    final thumbTip = _point(features, 4);
    final indexTip = _point(features, 8);
    final indexPip = _point(features, 6);
    final indexMcp = _point(features, 5);

    final middleTip = _point(features, 12);
    final middlePip = _point(features, 10);
    final middleMcp = _point(features, 9);

    final ringTip = _point(features, 16);
    final ringPip = _point(features, 14);
    final ringMcp = _point(features, 13);

    final pinkyTip = _point(features, 20);
    final pinkyPip = _point(features, 18);
    final pinkyMcp = _point(features, 17);

    final wrist = _point(features, 0);

    final thumbIndexDistance = _distance(thumbTip, indexTip);
    final palmSize = _distance(wrist, middleMcp);

    final indexUp = indexTip.y < indexPip.y - 0.02;
    final middleUp = middleTip.y < middlePip.y - 0.02;
    final ringUp = ringTip.y < ringPip.y - 0.02;
    final pinkyUp = pinkyTip.y < pinkyPip.y - 0.02;

    final indexFolded = _distance(indexTip, wrist) < _distance(indexMcp, wrist) * 1.15;
    final middleFolded = _distance(middleTip, wrist) < _distance(middleMcp, wrist) * 1.15;
    final ringFolded = _distance(ringTip, wrist) < _distance(ringMcp, wrist) * 1.15;
    final pinkyFolded = _distance(pinkyTip, wrist) < _distance(pinkyMcp, wrist) * 1.15;

    final upCount = [
      indexUp,
      middleUp,
      ringUp,
      pinkyUp,
    ].where((isUp) => isUp).length;

    final foldedCount = [
      indexFolded,
      middleFolded,
      ringFolded,
      pinkyFolded,
    ].where((isFolded) => isFolded).length;

    // 1. OPEN PALM ก่อน
    // แบมือแล้วนิ้วเหยียดหลาย ๆ นิ้ว ให้เป็น UP/DOWN เท่านั้น
    if (upCount >= 3) {
      return _classifyOpenPalmDirection(wrist, indexTip, middleTip, ringTip, pinkyTip);
    }

    // 2. FIST
    // กำมือต้องนิ้วงอหลาย ๆ นิ้ว ไม่ใช่แค่นิ้วดูต่ำกว่า PIP
    if (foldedCount >= 4) {
      return 'FIST';
    }

    // 3. TWO_FINGER
    if (indexUp && middleUp && !ringUp && !pinkyUp) {
      return 'TWO_FINGER';
    }

    // 4. ONE_FINGER
    if (indexUp && !middleUp && !ringUp && !pinkyUp) {
      return 'ONE_FINGER';
    }

    // 5. PINCH ไว้ท้าย ๆ เพราะติดง่าย
    // ต้องโป้งใกล้นิ้วชี้ และต้องไม่ใช่กำมือ
    if (thumbIndexDistance < palmSize * 0.35 && foldedCount <= 1) {
      return 'PINCH';
    }

    return 'UNKNOWN';
  }

  String _classifyOpenPalmDirection(
    _Point wrist,
    _Point indexTip,
    _Point middleTip,
    _Point ringTip,
    _Point pinkyTip,
  ) {
    final avgFingerTipY =
        (indexTip.y + middleTip.y + ringTip.y + pinkyTip.y) / 4;

    // ใน coordinate ของกล้อง/MediaPipe:
    // y น้อยกว่า = อยู่สูงกว่าในภาพ
    // y มากกว่า = อยู่ต่ำกว่าในภาพ
    if (avgFingerTipY < wrist.y) {
      return 'OPEN_PALM_UP';
    }

    return 'OPEN_PALM_DOWN';
  }

  _Point _point(List<double> features, int landmarkIndex) {
    final baseIndex = landmarkIndex * 3;

    return _Point(
      features[baseIndex],
      features[baseIndex + 1],
    );
  }

  double _distance(_Point a, _Point b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;

    return sqrt(dx * dx + dy * dy);
  }
}

class _Point {
  final double x;
  final double y;

  const _Point(this.x, this.y);
}