import 'dart:math';

class GestureClassifierService {
  String classify(List<double> features) {
    if (features.length != 63) {
      return 'UNKNOWN';
    }

    final thumbTip = _point(features, 4);
    final indexTip = _point(features, 8);
    final indexPip = _point(features, 6);
    final middleTip = _point(features, 12);
    final middlePip = _point(features, 10);
    final ringTip = _point(features, 16);
    final ringPip = _point(features, 14);
    final pinkyTip = _point(features, 20);
    final pinkyPip = _point(features, 18);
    final wrist = _point(features, 0);
    final middleMcp = _point(features, 9);

    final thumbIndexDistance = _distance(thumbTip, indexTip);

    final indexUp = indexTip.y < indexPip.y;
    final middleUp = middleTip.y < middlePip.y;
    final ringUp = ringTip.y < ringPip.y;
    final pinkyUp = pinkyTip.y < pinkyPip.y;

    final upCount = [
      indexUp,
      middleUp,
      ringUp,
      pinkyUp,
    ].where((isUp) => isUp).length;

    if (thumbIndexDistance < 0.06) {
      return 'PINCH';
    }

    if (upCount == 0) {
      return 'FIST';
    }

    if (indexUp && middleUp && !ringUp && !pinkyUp) {
      return 'TWO_FINGER';
    }

    if (upCount >= 3) {
      return _classifyOpenPalmDirection(wrist, middleMcp);
    }

    if (indexUp && !middleUp && !ringUp && !pinkyUp) {
      return 'ONE_FINGER';
    }

    return 'UNKNOWN';
  }

  String _classifyOpenPalmDirection(_Point wrist, _Point middleMcp) {
    final dx = middleMcp.x - wrist.x;
    final dy = middleMcp.y - wrist.y;

    if (dy.abs() > dx.abs()) {
      if (dy < 0) {
        return 'OPEN_PALM_UP';
      }

      return 'OPEN_PALM_DOWN';
    }

    if (dx > 0) {
      return 'OPEN_PALM_RIGHT';
    }

    return 'OPEN_PALM_LEFT';
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