import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../../domain/gnss_source.dart';
import '../../domain/models/source_config.dart';

class WindowsComSource implements GnssSource {
  final _byteController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<SourceStatus>.broadcast();

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readSub;

  @override
  Stream<Uint8List> get byteStream => _byteController.stream;

  @override
  Stream<SourceStatus> get statusStream => _statusController.stream;

  static List<Map<String, String?>> listPorts() {
    return SerialPort.availablePorts.map((address) {
      final port = SerialPort(address);
      return {
        'name': address,
        'description':
            port.description ?? port.productName ?? port.manufacturer,
      };
    }).toList();
  }

  @override
  Future<void> connect(SourceConfig config) async {
    await disconnect();

    final portName = config.comPortName;
    if (portName == null || portName.isEmpty) {
      _statusController.add(SourceStatus.error);
      throw ArgumentError('A COM port must be selected.');
    }

    _statusController.add(SourceStatus.connecting);

    final port = SerialPort(portName);
    if (!port.openReadWrite()) {
      _statusController.add(SourceStatus.error);
      throw SerialPort.lastError ?? StateError('Unable to open $portName.');
    }

    final serialConfig = SerialPortConfig()
      ..baudRate = config.baudRate
      ..bits = config.dataBits
      ..parity = _parity(config.parity)
      ..stopBits = config.stopBits
      ..setFlowControl(SerialPortFlowControl.none);

    try {
      port.config = serialConfig;
    } finally {
      serialConfig.dispose();
    }

    _port = port;
    _reader = SerialPortReader(port);
    _readSub = _reader!.stream.listen(
      (chunk) {
        _statusController.add(SourceStatus.receiving);
        _byteController.add(chunk);
      },
      onError: (Object error) {
        _statusController.add(SourceStatus.error);
        _byteController.addError(error);
      },
      cancelOnError: false,
    );
    _statusController.add(SourceStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    await _readSub?.cancel();
    _readSub = null;
    _reader?.close();
    _reader = null;
    _port?.close();
    _port?.dispose();
    _port = null;
    _statusController.add(SourceStatus.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _byteController.close();
    await _statusController.close();
  }

  int _parity(String parity) {
    switch (parity) {
      case 'even':
        return SerialPortParity.even;
      case 'odd':
        return SerialPortParity.odd;
      case 'none':
      default:
        return SerialPortParity.none;
    }
  }
}
