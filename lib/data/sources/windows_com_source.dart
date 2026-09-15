import 'dart:async';
import 'dart:typed_data';
import '../../domain/gnss_source.dart';
import '../../domain/models/source_config.dart';

// This is a STUB for Web testing. Serial ports don't work in browsers.
class WindowsComSource implements GnssSource {
  @override
  Stream<Uint8List> get byteStream => StreamController<Uint8List>().stream;
  @override
  Stream<SourceStatus> get statusStream =>
      StreamController<SourceStatus>().stream;

  static List<Map<String, String?>> listPorts() => [
        {'name': 'COM1 (Simulated)', 'description': 'Web Mode'}
      ];

  @override
  Future<void> connect(SourceConfig config) async {}
  @override
  Future<void> disconnect() async {}
}
