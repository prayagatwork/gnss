import 'dart:async';
import 'dart:io';

import '../../domain/models/gnss_fix.dart';

/// Normalized CSV logger implementing spec section 9:
///  - fixed header, RFC4180 escaping, missing values empty not zero
///  - sampling interval controls write frequency, not read frequency
///  - rotation: write to .partial, flush every 5s, rename at boundary
///  - startup recovery of orphaned .partial files
///  - default filename convention from client notes: yyyymmdd_hhmmssmmm.txt
///    (kept as informational default; normalized logs use the
///    SkyTrack_<source>_<start>_<end>.csv convention from the spec)
class CsvLogger {
  final Directory outputDir;
  final Duration samplingInterval;
  final Duration rotationInterval;
  final String sourceName;

  IOSink? _sink;
  File? _partialFile;
  DateTime? _fileStartUtc;
  Timer? _flushTimer;
  Timer? _rotationTimer;
  GnssFix? _latestFix;
  bool _finalized = false; // "Save" -> locked, cannot be modified further
  int recordsWritten = 0;

  CsvLogger({
    required this.outputDir,
    this.samplingInterval = const Duration(seconds: 1),
    this.rotationInterval = const Duration(hours: 1),
    this.sourceName = 'unknown',
  });

  /// Call once at app startup, before opening any new log, to recover any
  /// `.partial` file left behind by a crash (spec 9.2).
  static Future<void> recoverOrphans(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.partial')) {
        final recoveredPath =
            entity.path.replaceAll('.partial', '_recovered.csv');
        try {
          await entity.rename(recoveredPath);
        } catch (_) {
          // best effort; leave file in place if rename fails
        }
      }
    }
  }

  Future<void> start() async {
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    await _openNewFile();
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sink?.flush());
    _rotationTimer = Timer.periodic(rotationInterval, (_) => _rotate());
  }

  Future<void> _openNewFile() async {
    _fileStartUtc = DateTime.now().toUtc();
    final tmpName = 'SkyTrack_${sourceName}_${_ts(_fileStartUtc!)}.partial';
    _partialFile = File('${outputDir.path}/$tmpName');
    _sink = _partialFile!.openWrite();
    _sink!.writeln(GnssFix.csvHeader);
    recordsWritten = 0;
  }

  String _ts(DateTime dt) {
    final u = dt.toUtc();
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${p(u.year, 4)}${p(u.month)}${p(u.day)}T${p(u.hour)}${p(u.minute)}${p(u.second)}Z';
  }

  /// Called on every parsed fix. Only writes a row at [samplingInterval]
  /// boundaries, always logging the *latest* valid fix (spec 9.2).
  Timer? _sampleTimer;
  void onFix(GnssFix fix) {
    _latestFix = fix;
    _sampleTimer ??= Timer.periodic(samplingInterval, (_) {
      if (_finalized || _sink == null || _latestFix == null) return;
      _sink!.writeln(_latestFix!.toCsvRow());
      recordsWritten++;
    });
  }

  Future<void> _rotate() async {
    if (_finalized) return;
    await _closeAndRename();
    await _openNewFile();
  }

  Future<void> _closeAndRename() async {
    if (_sink == null || _partialFile == null) return;
    await _sink!.flush();
    await _sink!.close();
    final endUtc = DateTime.now().toUtc();
    final finalName =
        'SkyTrack_${sourceName}_${_ts(_fileStartUtc!)}_${_ts(endUtc)}.csv';
    final finalPath = '${outputDir.path}/$finalName';
    try {
      await _partialFile!.rename(finalPath);
    } catch (_) {
      // leave as .partial if rename fails; will be recovered next startup
    }
    _sink = null;
    _partialFile = null;
  }

  /// "Clear" = discard current in-progress log without keeping it queryable
  /// as final. "Save" = flush, rename to final .csv, and lock the logger
  /// so no further writes occur to that file (client notes: file cannot be
  /// modified once saved).
  Future<void> save() async {
    await _closeAndRename();
    _finalized = true;
    _flushTimer?.cancel();
    _rotationTimer?.cancel();
    _sampleTimer?.cancel();
  }

  Future<void> clear() async {
    _sampleTimer?.cancel();
    _flushTimer?.cancel();
    _rotationTimer?.cancel();
    await _sink?.close();
    if (_partialFile != null && await _partialFile!.exists()) {
      await _partialFile!.delete();
    }
    _sink = null;
    _partialFile = null;
    _finalized = false;
    recordsWritten = 0;
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    _rotationTimer?.cancel();
    _sampleTimer?.cancel();
    await _sink?.flush();
    await _sink?.close();
  }
}
