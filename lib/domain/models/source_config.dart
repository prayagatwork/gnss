enum SourceType { windowsCom, simulation, androidInternal, androidBle, androidSpp }

enum SourceStatus {
  idle,
  scanning,
  connecting,
  connected,
  receiving,
  reconnecting,
  disconnected,
  error,
}

/// Configuration needed to open a given [GnssSource].
/// Only the fields relevant to the chosen [type] need to be set.
class SourceConfig {
  final SourceType type;

  // Windows COM
  final String? comPortName;
  final int baudRate;
  final int dataBits;
  final String parity; // none, even, odd
  final int stopBits;

  // Simulation
  final String? simulationFilePath;
  final double playbackSpeed; // 0.5, 1, 2, 5
  final bool loop;

  const SourceConfig({
    required this.type,
    this.comPortName,
    this.baudRate = 9600,
    this.dataBits = 8,
    this.parity = 'none',
    this.stopBits = 1,
    this.simulationFilePath,
    this.playbackSpeed = 1.0,
    this.loop = false,
  });

  static const supportedBaudRates = [4800, 9600, 38400, 57600, 115200];
  static const supportedPlaybackSpeeds = [0.5, 1.0, 2.0, 5.0];
}
