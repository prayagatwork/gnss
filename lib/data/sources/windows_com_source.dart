import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../../domain/gnss_source.dart';
import '../../domain/models/source_config.dart';

/// Windows serial COM source per spec 3.1 / 5.2.
/// Bluetooth Classic receivers (e.g. HC-05) must be paired in Windows
/// Settings first; Windows then exposes them as a virtual COM port that
/// this class opens like any other serial device.
class WindowsComSource implements GnssSource {
  final _byteController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<SourceStatus>.broadcast();

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readerSub;

  @override
  Stream<Uint8List> get byteStream => _byteController.stream;
  @override
  Stream<SourceStatus> get statusStream => _statusController.stream;

  /// Enumerates available COM ports with name/description/manufacturer
  /// when the OS provides them (spec: Source Selection tab).
  static List<Map<String, String?>> listPorts() {
    return SerialPort.availablePorts.map((name) {
      final p = SerialPort(name);
      final desc = p.description;
      final mfr = p.manufacturer;
      p.dispose();
      return {'name': name, 'description': desc, 'manufacturer': mfr};
    }).toList();
  }

  @override
  Future<void> connect(SourceConfig config) async {
    if (config.comPortName == null) {
      throw ArgumentError('comPortName is required for Windows COM source');
    }
    _statusController.add(SourceStatus.connecting);
    try {
      final port = SerialPort(config.comPortName!);
      if (!port.openReadWrite()) {
        _statusController.add(SourceStatus.error);
        throw SerialPortError('Failed to open ${config.comPortName}');
      }
      final cfg = SerialPortConfig()
        ..baudRate = config.baudRate
        ..bits = config.dataBits
        ..stopBits = config.stopBits
        ..parity = _mapParity(config.parity)
        ..setFlowControl(SerialPortFlowControl.none);
      port.config = cfg;
      _port = port;

      _reader = SerialPortReader(port);
      _readerSub = _reader!.stream.listen(
        (data) {
          _byteController.add(data);
          _statusController.add(SourceStatus.receiving);
        },
        onError: (_) {
          _statusController.add(SourceStatus.error);
        },
        onDone: () {
          _statusController.add(SourceStatus.disconnected);
        },
      );
      _statusController.add(SourceStatus.connected);
    } catch (e) {
      _statusController.add(SourceStatus.error);
      rethrow;
    }
  }

  int _mapParity(String parity) {
    switch (parity) {
      case 'even':
        return SerialPortParity.even;
      case 'odd':
        return SerialPortParity.odd;
      default:
        return SerialPortParity.none;
    }
  }

  @override
  Future<void> disconnect() async {
    await _readerSub?.cancel();
    _port?.close();
    _port?.dispose();
    _port = null;
    _statusController.add(SourceStatus.disconnected);
  }

  void dispose() {
    _byteController.close();
    _statusController.close();
  }
}
