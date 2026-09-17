import 'dart:async';
import 'dart:typed_data';

import '../../domain/gnss_source.dart';
import '../../domain/models/source_config.dart';

class WindowsComSource implements GnssSource {
  final _byteController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<SourceStatus>.broadcast();

  @override
  Stream<Uint8List> get byteStream => _byteController.stream;

  @override
  Stream<SourceStatus> get statusStream => _statusController.stream;

  static List<Map<String, String?>> listPorts() => [];

  @override
  Future<void> connect(SourceConfig config) async {
    _statusController.add(SourceStatus.error);
    throw UnsupportedError(
      'Serial COM ports are available only in the Windows desktop build.',
    );
  }

  @override
  Future<void> disconnect() async {
    _statusController.add(SourceStatus.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _byteController.close();
    await _statusController.close();
  }
}
