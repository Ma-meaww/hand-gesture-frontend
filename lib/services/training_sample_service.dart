class TrainingSampleService {
  final List<List<String>> samples = [];

  int get totalSampleCount => samples.length;

  int getSampleCountByLabel(String label) {
    return samples
        .where((row) => row.isNotEmpty && row.first == label)
        .length;
  }

  void addSample({
    required String label,
    required List<double> features,
  }) {
    final row = [
      label,
      ...features.map((value) => value.toStringAsFixed(6)),
    ];

    samples.add(row);
  }

  void clear() {
    samples.clear();
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
      ...samples.map((row) => row.join(',')),
    ];

    return rows.join('\n');
  }
}