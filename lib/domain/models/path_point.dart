class PathPoint {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;

  PathPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
  });

  String toLogString() => '${timestamp.toIso8601String()};'
      '${latitude.toStringAsFixed(6)};'
      '${longitude.toStringAsFixed(6)};'
      '${altitude.toStringAsFixed(2)};'
      '${speed.toStringAsFixed(2)}';
}
