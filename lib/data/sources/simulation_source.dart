import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/gnss_source.dart';
import '../../domain/models/source_config.dart';

/// Simulation source per spec 5.5: plays back a sample NMEA file line by
/// line, with Start/Pause/Stop and 0.5x/1x/2x/5x speed. This is what the
/// whole app is built and verified against while no hardware is available
/// (per the feasibility terms).
class SimulationSource implements GnssSource {
  final _byteController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<SourceStatus>.broadcast();

  List<String> _lines = [];
  int _index = 0;
  Timer? _timer;
  bool _paused = false;
  SourceConfig? _config;

  @override
  Stream<Uint8List> get byteStream => _byteController.stream;
  @override
  Stream<SourceStatus> get statusStream => _statusController.stream;

  @override
  Future<void> connect(SourceConfig config) async {
    _config = config;
    _statusController.add(SourceStatus.connecting);
    final path = config.simulationFilePath;
    if (path == null) {
      _statusController.add(SourceStatus.error);
      throw ArgumentError('simulationFilePath is required');
    }
    final file = File(path);
    if (!await file.exists()) {
      _statusController.add(SourceStatus.error);
      throw FileSystemException('Simulation file not found', path);
    }
    _lines = await file.readAsLines();
    _index = 0;
    _paused = false;
    _statusController.add(SourceStatus.connected);
    _scheduleNext();
  }

  void pause() {
    _paused = true;
    _timer?.cancel();
    _statusController.add(SourceStatus.idle);
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _statusController.add(SourceStatus.receiving);
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_paused || _config == null) return;
    if (_index >= _lines.length) {
      if (_config!.loop) {
        _index = 0;
      } else {
        _statusController.add(SourceStatus.disconnected);
        return;
      }
    }
    final delayMs = (1000 / _config!.playbackSpeed).round();
    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (_index < _lines.length) {
        final line = _lines[_index];
        _index++;
        if (line.trim().isNotEmpty) {
          _byteController.add(Uint8List.fromList(utf8.encode('$line\r\n')));
          _statusController.add(SourceStatus.receiving);
        }
      }
      _scheduleNext();
    });
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _paused = false;
    _statusController.add(SourceStatus.disconnected);
  }

  void dispose() {
    _timer?.cancel();
    _byteController.close();
    _statusController.close();
  }
}
