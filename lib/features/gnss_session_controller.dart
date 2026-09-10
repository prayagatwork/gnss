import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/logging/csv_logger.dart';
import '../data/parser/nmea_parser.dart';
import '../data/sources/simulation_source.dart';
import '../data/sources/windows_com_source.dart';
import '../domain/gnss_source.dart';
import '../domain/models/gnss_fix.dart';
import '../domain/models/source_config.dart';

/// Everything the Dashboard/Settings/Source Selection tabs read from.
/// Only one live source may be active at a time; switching sources disposes
/// the previous one before connecting the next (spec section 7).
class GnssSessionController extends StateNotifier<GnssSessionState> {
  GnssSessionController() : super(GnssSessionState.initial());

  GnssSource? _source;
  StreamSubscription? _byteSub;
  StreamSubscription? _statusSub;
  final _diagnostics = ParserDiagnostics();
  late final _framer = NmeaFramer(_diagnostics);
  late final _parser = NmeaParser(_diagnostics);
  CsvLogger? _logger;
  Timer? _staleTimer;

  Future<void> connect(SourceConfig config) async {
    await _teardownSource();
    _diagnostics.reset();

    final sourceName = switch (config.type) {
      SourceType.windowsCom => 'windows_com',
      SourceType.simulation => 'simulation',
      SourceType.androidInternal => 'android_internal',
      SourceType.androidBle => 'android_ble',
      SourceType.androidSpp => 'android_spp',
    };

    final source = switch (config.type) {
      SourceType.windowsCom => WindowsComSource(),
      SourceType.simulation => SimulationSource(),
      _ => throw UnimplementedError(
          'Android transports are implemented in the .apk build, out of scope for this .exe phase'),
    };
    _source = source;

    _statusSub = source.statusStream.listen((status) {
      state = state.copyWith(status: status);
    });

    _byteSub = source.byteStream.listen((bytes) {
      final lines = _framer.feed(bytes);
      for (final line in lines) {
        final fix = _parser.parse(line, sourceName: sourceName);
        if (fix == null) continue;
        final merged = (state.currentFix ?? GnssFix.empty(sourceName)).mergedWith(fix);
        state = state.copyWith(currentFix: merged, diagnostics: _diagnostics);
        _logger?.onFix(merged);
      }
    });

    if (state.loggingEnabled) {
      await _startLogger(sourceName);
    }

    await source.connect(config);
    _resetStaleTimer(sourceName);
  }

  void _resetStaleTimer(String sourceName) {
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final fix = state.currentFix;
      if (fix == null) return;
      final age = DateTime.now().toUtc().difference(fix.receivedAtUtc);
      final isStale = age > staleDataThreshold;
      if (isStale != state.isStale) {
        state = state.copyWith(isStale: isStale);
      }
    });
  }

  Future<void> _startLogger(String sourceName) async {
    final docsDir = Platform.isWindows
        ? Directory('${(await getApplicationDocumentsDirectory()).path}/SkyTrack/Logs')
        : await getApplicationDocumentsDirectory();
    await CsvLogger.recoverOrphans(docsDir);
    _logger = CsvLogger(
      outputDir: docsDir,
      samplingInterval: state.samplingInterval,
      rotationInterval: state.rotationInterval,
      sourceName: sourceName,
    );
    await _logger!.start();
  }

  Future<void> setLoggingEnabled(bool enabled) async {
    state = state.copyWith(loggingEnabled: enabled);
    if (!enabled) {
      await _logger?.save();
      _logger = null;
    }
  }

  Future<void> saveLog() async {
    await _logger?.save();
  }

  Future<void> clearLog() async {
    await _logger?.clear();
  }

  Future<void> _teardownSource() async {
    await _byteSub?.cancel();
    await _statusSub?.cancel();
    await _source?.disconnect();
    _source = null;
    _staleTimer?.cancel();
  }

  Future<void> disconnect() async {
    await _teardownSource();
    state = state.copyWith(status: SourceStatus.disconnected);
  }

  @override
  void dispose() {
    _teardownSource();
    _logger?.dispose();
    super.dispose();
  }
}

class GnssSessionState {
  final SourceStatus status;
  final GnssFix? currentFix;
  final ParserDiagnostics diagnostics;
  final bool isStale;
  final bool loggingEnabled;
  final Duration samplingInterval;
  final Duration rotationInterval;

  const GnssSessionState({
    required this.status,
    this.currentFix,
    required this.diagnostics,
    required this.isStale,
    required this.loggingEnabled,
    required this.samplingInterval,
    required this.rotationInterval,
  });

  factory GnssSessionState.initial() => GnssSessionState(
        status: SourceStatus.idle,
        diagnostics: ParserDiagnostics(),
        isStale: false,
        loggingEnabled: true,
        samplingInterval: const Duration(seconds: 1),
        rotationInterval: const Duration(hours: 1),
      );

  GnssSessionState copyWith({
    SourceStatus? status,
    GnssFix? currentFix,
    ParserDiagnostics? diagnostics,
    bool? isStale,
    bool? loggingEnabled,
    Duration? samplingInterval,
    Duration? rotationInterval,
  }) {
    return GnssSessionState(
      status: status ?? this.status,
      currentFix: currentFix ?? this.currentFix,
      diagnostics: diagnostics ?? this.diagnostics,
      isStale: isStale ?? this.isStale,
      loggingEnabled: loggingEnabled ?? this.loggingEnabled,
      samplingInterval: samplingInterval ?? this.samplingInterval,
      rotationInterval: rotationInterval ?? this.rotationInterval,
    );
  }
}

final gnssSessionProvider =
    StateNotifierProvider<GnssSessionController, GnssSessionState>(
  (ref) => GnssSessionController(),
);
