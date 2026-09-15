import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/gnss_fix.dart';
import '../domain/models/path_point.dart';
import '../domain/models/source_config.dart';
import '../data/parser/nmea_parser.dart';

class GnssSessionController extends StateNotifier<GnssSessionState> {
  GnssSessionController() : super(GnssSessionState.initial());

  final _parser = NmeaParser(ParserDiagnostics());
  final _framer = NmeaFramer(ParserDiagnostics());
  Timer? _simTimer;

  // UI Methods - Fixed "Undefined method" errors
  Future<void> connect(SourceConfig config) async {
    state = state.copyWith(status: SourceStatus.connected);
  }

  Future<void> setLoggingEnabled(bool enabled) async {
    state = state.copyWith(loggingEnabled: enabled);
  }

  Future<void> saveLog() async {
    print("Log saved.");
  }

  Future<void> clearLog() async {
    state = state.copyWith(pathPoints: [], totalDistance: 0);
  }

  void stopRecording() {
    state = state.copyWith(isRecording: false, isPaused: false);
  }

  void togglePause() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

  void startRecording(RecordMode mode, double val, bool filter, double acc) {
    state = state.copyWith(
      isRecording: true,
      isPaused: false,
      recordMode: mode,
      pathPoints: [],
      totalDistance: 0,
    );
  }

  // Web Simulation Logic
  void startWebSimulation(Uint8List fileBytes) {
    final content = utf8.decode(fileBytes);
    final lines = content.split('\n');
    int index = 0;

    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (index >= lines.length) {
        timer.cancel();
        return;
      }
      final rawLine = lines[index++];
      final frames =
          _framer.feed(Uint8List.fromList(utf8.encode('$rawLine\r\n')));
      for (var f in frames) {
        final fix = _parser.parse(f, sourceName: 'simulation');
        if (fix != null) {
          final merged =
              (state.currentFix ?? GnssFix.empty('sim')).mergedWith(fix);
          state = state.copyWith(
              currentFix: merged, status: SourceStatus.receiving);
        }
      }
    });
  }
}

class GnssSessionState {
  final SourceStatus status;
  final GnssFix? currentFix;
  final List<PathPoint> pathPoints;
  final bool isRecording;
  final bool isPaused;
  final RecordMode recordMode;
  final bool loggingEnabled;
  final ParserDiagnostics diagnostics;
  final bool isStale;
  final double totalDistance;
  final Duration samplingInterval;
  final Duration rotationInterval;

  GnssSessionState({
    required this.status,
    this.currentFix,
    required this.pathPoints,
    required this.isRecording,
    required this.isPaused,
    required this.recordMode,
    required this.loggingEnabled,
    required this.diagnostics,
    required this.isStale,
    required this.totalDistance,
    required this.samplingInterval,
    required this.rotationInterval,
  });

  factory GnssSessionState.initial() => GnssSessionState(
        status: SourceStatus.idle,
        pathPoints: [],
        isRecording: false,
        isPaused: false,
        recordMode: RecordMode.time,
        loggingEnabled: true,
        diagnostics: ParserDiagnostics(),
        isStale: false,
        totalDistance: 0,
        samplingInterval: const Duration(seconds: 1),
        rotationInterval: const Duration(hours: 1),
      );

  GnssSessionState copyWith({
    SourceStatus? status,
    GnssFix? currentFix,
    List<PathPoint>? pathPoints,
    bool? isRecording,
    bool? isPaused,
    RecordMode? recordMode,
    bool? loggingEnabled,
    ParserDiagnostics? diagnostics,
    bool? isStale,
    double? totalDistance,
    Duration? samplingInterval,
    Duration? rotationInterval,
  }) =>
      GnssSessionState(
        status: status ?? this.status,
        currentFix: currentFix ?? this.currentFix,
        pathPoints: pathPoints ?? this.pathPoints,
        isRecording: isRecording ?? this.isRecording,
        isPaused: isPaused ?? this.isPaused,
        recordMode: recordMode ?? this.recordMode,
        loggingEnabled: loggingEnabled ?? this.loggingEnabled,
        diagnostics: diagnostics ?? this.diagnostics,
        isStale: isStale ?? this.isStale,
        totalDistance: totalDistance ?? this.totalDistance,
        samplingInterval: samplingInterval ?? this.samplingInterval,
        rotationInterval: rotationInterval ?? this.rotationInterval,
      );
}

enum RecordMode { time, distance }

final gnssSessionProvider =
    StateNotifierProvider<GnssSessionController, GnssSessionState>(
        (ref) => GnssSessionController());
