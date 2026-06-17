import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

class GestureClassifierService {
  static const String unknownGesture = 'UNKNOWN';

  static const String oneFinger = 'ONE_FINGER';
  static const String thumb = 'THUMB';
  static const String openPalmUp = 'OPEN_PALM_UP';
  static const String openPalmDown = 'OPEN_PALM_DOWN';
  static const String fist = 'FIST';
  static const String twoFinger = 'TWO_FINGER';

  static const int _featureCount = 63;
  static const int _k = 5;

  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  int get sampleCount => _samples.length;
  Set<String> get loadedLabels =>
      _samples.map((sample) => sample.label).toSet();

  final List<_GestureSample> _samples = [];
  late List<double> _means;
  late List<double> _stds;

  /// ปรับได้หลังเทสจริง
  /// ถ้า UNKNOWN บ่อยเกินไป ให้เพิ่ม เช่น 8.5 หรือ 9.0
  /// ถ้า gesture มั่วเกินไป ให้ลด เช่น 6.0 หรือ 6.5
  final double _unknownDistanceThreshold = 999.0;

  Future<void> loadDataset() async {
    if (_isLoaded) return;

    final datasetAssets = [
       'assets/datasets/custom_gesture_dataset.csv',
    ];

    Future<List<_RawGestureRow>> _loadRowsFromProjectCsv(
      String assetPath,
    ) async {
      final csvText = await rootBundle.loadString(assetPath);

      final lines = csvText
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.length <= 1) {
        throw Exception('Dataset CSV is empty or invalid: $assetPath');
      }

      final header = _splitCsvLine(lines.first);
      final labelIndex = header.indexOf('label');

      if (labelIndex == -1) {
        throw Exception('CSV must contain a label column: $assetPath');
      }

      final rows = <_RawGestureRow>[];

      for (int i = 1; i < lines.length; i++) {
        final cols = _splitCsvLine(lines[i]);

        if (cols.length != header.length) {
          continue;
        }

        final label = cols[labelIndex].trim();

        if (!_isAllowedGesture(label)) {
          continue;
        }

        final features = <double>[];

        for (int colIndex = 0; colIndex < cols.length; colIndex++) {
          if (colIndex == labelIndex) continue;

          final value = double.tryParse(cols[colIndex].trim());

          if (value == null) {
            features.clear();
            break;
          }

          features.add(value);
        }

        if (features.length != _featureCount) {
          continue;
        }

        rows.add(_RawGestureRow(label: label, features: features));
      }

      return rows;
    }

    final rawRows = <_RawGestureRow>[];

    for (final assetPath in datasetAssets) {
      final rows = await _loadRowsFromProjectCsv(assetPath);
      rawRows.addAll(rows);

      print('Loaded ${rows.length} rows from $assetPath');
    }

    if (rawRows.isEmpty) {
      throw Exception('No valid rows found in dataset.');
    }

    _means = _calculateMeans(rawRows);
    _stds = _calculateStds(rawRows, _means);

    _samples.clear();

    for (final row in rawRows) {
      _samples.add(
        _GestureSample(label: row.label, features: _standardize(row.features)),
      );
    }

    _isLoaded = true;

    print('Dataset loaded rows: ${_samples.length}');
    print('Dataset labels: ${loadedLabels}');
  }

  /// เรียก method นี้จาก Gesture Control ตอนมี landmark 63 ค่า
  ///
  /// landmarks ต้องเรียงแบบ:
  /// x0,y0,z0,x1,y1,z1,...,x20,y20,z20
  String classify(List<double> landmarks) {
    if (!_isLoaded) {
      return unknownGesture;
    }

    if (landmarks.length != _featureCount) {
      return unknownGesture;
    }

    final normalizedInput = _normalizeLandmarks(landmarks);

    if (normalizedInput == null) {
      return unknownGesture;
    }

    final scaledInput = _standardize(normalizedInput);

    final neighbors = _samples.map((sample) {
      return _Neighbor(
        label: sample.label,
        distance: _euclideanDistance(scaledInput, sample.features),
      );
    }).toList()..sort((a, b) => a.distance.compareTo(b.distance));

    final topK = neighbors.take(_k).toList();

    if (topK.isEmpty) {
      return unknownGesture;
    }

    final averageDistance =
        topK.map((n) => n.distance).reduce((a, b) => a + b) / topK.length;

    if (averageDistance > _unknownDistanceThreshold) {
      return unknownGesture;
    }

    final voteCount = <String, int>{};
    final distanceSumByLabel = <String, double>{};

    for (final neighbor in topK) {
      voteCount[neighbor.label] = (voteCount[neighbor.label] ?? 0) + 1;
      distanceSumByLabel[neighbor.label] =
          (distanceSumByLabel[neighbor.label] ?? 0) + neighbor.distance;
    }

    final sortedVotes = voteCount.entries.toList()
      ..sort((a, b) {
        final voteCompare = b.value.compareTo(a.value);

        if (voteCompare != 0) {
          return voteCompare;
        }

        final avgA = distanceSumByLabel[a.key]! / a.value;
        final avgB = distanceSumByLabel[b.key]! / b.value;

        return avgA.compareTo(avgB);
      });

    return sortedVotes.first.key;
  }

  bool _isAllowedGesture(String label) {
    return label == oneFinger ||
        label == thumb ||
        label == fist ||
        label == openPalmUp ||
        label == openPalmDown ||
        label == twoFinger;
  }

  /// ทำ live landmark ให้ใกล้กับ dataset:
  /// wrist เป็นจุดเริ่มต้น และ scale ด้วยขนาดฝ่ามือ
  List<double>? _normalizeLandmarks(List<double> landmarks) {
    final wristX = _x(landmarks, 0);
    final wristY = _y(landmarks, 0);
    final wristZ = _z(landmarks, 0);

    final middleMcpX = _x(landmarks, 9);
    final middleMcpY = _y(landmarks, 9);
    final middleMcpZ = _z(landmarks, 9);

    final handSize = sqrt(
      pow(middleMcpX - wristX, 2) +
          pow(middleMcpY - wristY, 2) +
          pow(middleMcpZ - wristZ, 2),
    );

    if (handSize == 0) {
      return null;
    }

    final normalized = <double>[];

    for (int i = 0; i < 21; i++) {
      normalized.add((_x(landmarks, i) - wristX) / handSize);
      normalized.add((_y(landmarks, i) - wristY) / handSize);
      normalized.add((_z(landmarks, i) - wristZ) / handSize);
    }

    return normalized;
  }

  List<String> _splitCsvLine(String line) {
    return line.split(',');
  }

  List<double> _calculateMeans(List<_RawGestureRow> rows) {
    final means = List<double>.filled(_featureCount, 0);

    for (final row in rows) {
      for (int i = 0; i < _featureCount; i++) {
        means[i] += row.features[i];
      }
    }

    for (int i = 0; i < _featureCount; i++) {
      means[i] /= rows.length;
    }

    return means;
  }

  List<double> _calculateStds(List<_RawGestureRow> rows, List<double> means) {
    final stds = List<double>.filled(_featureCount, 0);

    for (final row in rows) {
      for (int i = 0; i < _featureCount; i++) {
        final diff = row.features[i] - means[i];
        stds[i] += diff * diff;
      }
    }

    for (int i = 0; i < _featureCount; i++) {
      stds[i] = sqrt(stds[i] / rows.length);

      if (stds[i] == 0) {
        stds[i] = 1;
      }
    }

    return stds;
  }

  List<double> _standardize(List<double> features) {
    final result = List<double>.filled(_featureCount, 0);

    for (int i = 0; i < _featureCount; i++) {
      result[i] = (features[i] - _means[i]) / _stds[i];
    }

    return result;
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;

    for (int i = 0; i < _featureCount; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }

    return sqrt(sum);
  }

  double _x(List<double> landmarks, int index) {
    return landmarks[index * 3];
  }

  double _y(List<double> landmarks, int index) {
    return landmarks[index * 3 + 1];
  }

  double _z(List<double> landmarks, int index) {
    return landmarks[index * 3 + 2];
  }
}

class _RawGestureRow {
  final String label;
  final List<double> features;

  const _RawGestureRow({required this.label, required this.features});
}

class _GestureSample {
  final String label;
  final List<double> features;

  const _GestureSample({required this.label, required this.features});
}

class _Neighbor {
  final String label;
  final double distance;

  const _Neighbor({required this.label, required this.distance});
}
