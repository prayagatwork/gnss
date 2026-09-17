import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/path_point.dart';

class TxtLogSaver {
  static Future<String?> save(List<PathPoint> points) async {
    if (points.isEmpty) return null;

    final dir = await _logDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File('${dir.path}/${_defaultTxtName(DateTime.now())}');
    final sink = file.openWrite();
    sink.writeln('timestamp;latitude;longitude;altitude_m;speed_kmh');
    for (final point in points) {
      sink.writeln(point.toLogString());
    }
    await sink.flush();
    await sink.close();
    return file.path;
  }

  static Future<Directory> _logDirectory() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      return Directory('${docs.path}/SkyTrackLogs');
    } catch (_) {
      return Directory('${Directory.systemTemp.path}/SkyTrackLogs');
    }
  }

  static String _defaultTxtName(DateTime dt) {
    String p(int value, [int width = 2]) =>
        value.toString().padLeft(width, '0');
    return '${p(dt.year, 4)}${p(dt.month)}${p(dt.day)}_'
        '${p(dt.hour)}${p(dt.minute)}${p(dt.second)}${p(dt.millisecond, 3)}.txt';
  }
}
