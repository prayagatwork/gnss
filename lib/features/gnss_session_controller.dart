import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/logging/txt_log_saver.dart';
import '../data/sources/windows_com_source.dart';
import '../domain/models/gnss_fix.dart';
import '../domain/models/path_point.dart';
import '../domain/models/source_config.dart';
import '../data/parser/nmea_parser.dart';

class GnssSessionController extends StateNotifier<GnssSessionState> {
  GnssSessionController() : super(GnssSessionState.initial());

  final _diagnostics = ParserDiagnostics();
  late final _parser = NmeaParser(_diagnostics);
  late final _framer = NmeaFramer(_diagnostics);
  WindowsComSource? _windowsSource;
  StreamSubscription<Uint8List>? _byteSub;
  StreamSubscription<SourceStatus>? _statusSub;
  Timer? _simTimer;
  SourceConfig? _sourceConfig;
  DateTime? _lastPointAt;
  String? _savedLogPath;
  bool _logLocked = false;

  Future<void> connect(SourceConfig config) async {
    await disconnect();
    _sourceConfig = config;

    if (config.type != SourceType.windowsCom) {
      state = state.copyWith(
        status: SourceStatus.error,
        statusMessage: 'Unsupported source for Windows exe handover.',
      );
      return;
    }

    final source = WindowsComSource();
    _windowsSource = source;
    _statusSub = source.statusStream.listen((status) {
      state = state.copyWith(status: status);
    });
    _byteSub = source.byteStream.listen(
      _consumeBytes,
      onError: (Object error) {
        state = state.copyWith(
          status: SourceStatus.error,
          statusMessage: error.toString(),
        );
      },
    );

    try {
      await source.connect(config);
    } catch (error) {
      state = state.copyWith(
        status: SourceStatus.error,
        statusMessage: error.toString(),
      );
    }
  }

  Future<void> setLoggingEnabled(bool enabled) async {
    state = state.copyWith(loggingEnabled: enabled);
  }

  Future<String?> saveLog() async {
    final points = state.pathPoints;
    if (points.isEmpty || _logLocked) return _savedLogPath;

    _savedLogPath = await TxtLogSaver.save(points);
    if (_savedLogPath == null) return null;

    _logLocked = true;
    state = state.copyWith(savedLogPath: _savedLogPath, logLocked: true);
    return _savedLogPath;
  }

  Future<void> clearLog() async {
    _lastPointAt = null;
    _savedLogPath = null;
    _logLocked = false;
    state = state.copyWith(
      pathPoints: [],
      totalDistance: 0,
      savedLogPath: '',
      logLocked: false,
    );
  }

  void stopRecording() {
    state = state.copyWith(isRecording: false, isPaused: false);
  }

  void togglePause() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

  void startRecording(RecordMode mode, double val, bool filter, double acc) {
    _lastPointAt = null;
    _logLocked = false;
    _savedLogPath = null;
    state = state.copyWith(
      isRecording: true,
      isPaused: false,
      recordMode: mode,
      recordEvery: val,
      filterByAccuracy: filter,
      requiredAccuracyM: acc,
      pathPoints: [],
      totalDistance: 0,
      savedLogPath: '',
      logLocked: false,
    );
    final fix = state.currentFix;
    if (fix != null) {
      _appendPointIfNeeded(fix, force: true);
    }
  }

  bool addWaypoint() {
    final fix = state.currentFix;
    if (fix == null ||
        !fix.fixValid ||
        fix.latitudeDeg == null ||
        fix.longitudeDeg == null ||
        _logLocked) {
      return false;
    }

    final previous = state.pathPoints.isEmpty ? null : state.pathPoints.last;
    final distanceFromPrevious = previous == null
        ? 0.0
        : _distanceMeters(
            previous.latitude,
            previous.longitude,
            fix.latitudeDeg!,
            fix.longitudeDeg!,
          );
    final point = PathPoint(
      timestamp: fix.gnssTimeUtc ?? fix.receivedAtUtc,
      latitude: fix.latitudeDeg!,
      longitude: fix.longitudeDeg!,
      altitude: fix.altitudeM ?? 0,
      speed: fix.speedKmh ?? 0,
    );

    state = state.copyWith(
      pathPoints: [...state.pathPoints, point],
      totalDistance: state.totalDistance + distanceFromPrevious,
    );
    _lastPointAt = point.timestamp;
    return true;
  }

  void startWebSimulation(Uint8List fileBytes) {
    disconnect(); // Stop existing simulation
    final content = utf8.decode(fileBytes);
    final lines = content.split('\n');
    int index = 0;

    _simTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (index >= lines.length) {
        timer.cancel();
        state = state.copyWith(status: SourceStatus.disconnected);
        return;
      }
      
      final rawLine = lines[index++];
      if (rawLine.trim().isEmpty) return;

      // FEED THE FRAMER
      final frames = _framer.feed(Uint8List.fromList(utf8.encode('$rawLine\r\n')));
      
      for (var frame in frames) {
        final fix = _parser.parse(frame, sourceName: 'simulation');
        if (fix != null) {
          // UPDATE STATE LIVE
          final merged = (state.currentFix ?? GnssFix.empty('sim')).mergedWith(fix);
          state = state.copyWith(
            currentFix: merged, 
            status: SourceStatus.receiving,
            // Logic to calculate distance and add points
          );
          _appendPointIfNeeded(merged); // Crucial for "Path" card update
        }
      }
    });
  }

  Future<void> disconnect() async {
    _simTimer?.cancel();
    _simTimer = null;
    await _byteSub?.cancel();
    await _statusSub?.cancel();
    _byteSub = null;
    _statusSub = null;
    await _windowsSource?.dispose();
    _windowsSource = null;
  }

  void _consumeBytes(Uint8List bytes, {String? sourceName}) {
    final source = sourceName ?? _sourceConfig?.type.name ?? 'windows_com';
    final frames = _framer.feed(bytes);
    for (final frame in frames) {
      final fix = _parser.parse(frame, sourceName: source);
      if (fix == null) continue;

      final merged =
          (state.currentFix ?? GnssFix.empty(source)).mergedWith(fix);
      state = state.copyWith(
        currentFix: merged,
        status: SourceStatus.receiving,
        diagnostics: _diagnostics,
        statusMessage: '',
      );
      _appendPointIfNeeded(merged);
    }
  }

  void _appendPointIfNeeded(GnssFix fix, {bool force = false}) {
    if (!state.isRecording || state.isPaused || _logLocked) return;
    if (!fix.fixValid || fix.latitudeDeg == null || fix.longitudeDeg == null) {
      return;
    }
    if (state.filterByAccuracy &&
        fix.hdop != null &&
        fix.hdop! > state.requiredAccuracyM) {
      return;
    }

    final now = fix.gnssTimeUtc ?? fix.receivedAtUtc;
    final previous = state.pathPoints.isEmpty ? null : state.pathPoints.last;
    final distanceFromPrevious = previous == null
        ? 0.0
        : _distanceMeters(
            previous.latitude,
            previous.longitude,
            fix.latitudeDeg!,
            fix.longitudeDeg!,
          );

    var shouldAdd = force || previous == null;
    if (!shouldAdd && state.recordMode == RecordMode.time) {
      final last = _lastPointAt ?? previous.timestamp;
      shouldAdd = now.difference(last).inMilliseconds.abs() >=
          (state.recordEvery * 1000).round();
    }
    if (!shouldAdd && state.recordMode == RecordMode.distance) {
      shouldAdd = distanceFromPrevious >= state.recordEvery;
    }
    if (!shouldAdd) return;

    final nextPoint = PathPoint(
      timestamp: now,
      latitude: fix.latitudeDeg!,
      longitude: fix.longitudeDeg!,
      altitude: fix.altitudeM ?? 0,
      speed: fix.speedKmh ?? 0,
    );

    state = state.copyWith(
      pathPoints: [...state.pathPoints, nextPoint],
      totalDistance: state.totalDistance + distanceFromPrevious,
    );
    _lastPointAt = now;
  }

  double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        _sin2(dLat / 2) + _cos(_rad(lat1)) * _cos(_rad(lat2)) * _sin2(dLon / 2);
    return earthRadiusM * 2 * _atan2(_sqrt(a), _sqrt(1 - a));
  }

  double _rad(double degrees) => degrees * 3.141592653589793 / 180.0;
  double _sin2(double value) => _mathSin(value) * _mathSin(value);
  double _mathSin(double value) => math.sin(value);
  double _cos(double value) => math.cos(value);
  double _sqrt(double value) => math.sqrt(value);
  double _atan2(double y, double x) => math.atan2(y, x);

  @override
  void dispose() {
    disconnect();
    super.dispose();
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
  final double recordEvery;
  final bool filterByAccuracy;
  final double requiredAccuracyM;
  final String? savedLogPath;
  final bool logLocked;
  final String? statusMessage;

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
    required this.recordEvery,
    required this.filterByAccuracy,
    required this.requiredAccuracyM,
    this.savedLogPath,
    required this.logLocked,
    this.statusMessage,
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
        recordEvery: 1,
        filterByAccuracy: true,
        requiredAccuracyM: 10,
        logLocked: false,
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
    double? recordEvery,
    bool? filterByAccuracy,
    double? requiredAccuracyM,
    String? savedLogPath,
    bool? logLocked,
    String? statusMessage,
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
        recordEvery: recordEvery ?? this.recordEvery,
        filterByAccuracy: filterByAccuracy ?? this.filterByAccuracy,
        requiredAccuracyM: requiredAccuracyM ?? this.requiredAccuracyM,
        savedLogPath: savedLogPath ?? this.savedLogPath,
        logLocked: logLocked ?? this.logLocked,
        statusMessage: statusMessage ?? this.statusMessage,
      );
}

enum RecordMode { time, distance }

final gnssSessionProvider =
    StateNotifierProvider<GnssSessionController, GnssSessionState>(
        (ref) => GnssSessionController());
