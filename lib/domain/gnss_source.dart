import 'dart:typed_data';
import 'models/source_config.dart';

/// Common contract every transport (Windows COM, simulation, Android
/// internal/BLE/SPP) implements, per spec section 5.
abstract interface class GnssSource {
  Stream<Uint8List> get byteStream;
  Stream<SourceStatus> get statusStream;

  Future<void> connect(SourceConfig config);
  Future<void> disconnect();
}
