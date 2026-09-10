/// Connection/lifecycle states shown on the Dashboard tab (spec 8.1).
enum ConnectionState {
  idle,
  permissionRequired,
  scanning,
  connecting,
  connected,
  receiving,
  reconnecting,
  readingFile,
  disconnected,
  error,
}

/// The single normalized position/observation record produced by the parser
/// and consumed by both the dashboard and the CSV logger.
/// Field set matches spec section 6 exactly.
class GnssFix {
  final DateTime receivedAtUtc;
  final DateTime? gnssTimeUtc;
  final String source; // e.g. "windows_com", "simulation", "android_internal"
  final double? latitudeDeg;
  final double? longitudeDeg;
  final double? altitudeM;
  final double? speedKmh;
  final double? headingDeg;
  final bool fixValid;
  final String fixQuality; // no_fix, gps_fix, dgps_fix, rtk_fix ...
  final int? satellitesUsed;
  final int? satellitesInView;
  final double? hdop;
  final double? vdop;
  final double? pdop;
  final String rawSentenceType; // GGA, RMC, GGA+RMC, etc.

  const GnssFix({
    required this.receivedAtUtc,
    this.gnssTimeUtc,
    required this.source,
    this.latitudeDeg,
    this.longitudeDeg,
    this.altitudeM,
    this.speedKmh,
    this.headingDeg,
    required this.fixValid,
    required this.fixQuality,
    this.satellitesUsed,
    this.satellitesInView,
    this.hdop,
    this.vdop,
    this.pdop,
    required this.rawSentenceType,
  });

  GnssFix mergedWith(GnssFix other) {
    // Combine complementary sentences (e.g. GGA altitude + RMC speed/heading)
    // without letting an invalid sentence overwrite a valid displayed fix
    // (spec rule 6.4).
    return GnssFix(
      receivedAtUtc: other.receivedAtUtc,
      gnssTimeUtc: other.gnssTimeUtc ?? gnssTimeUtc,
      source: other.source,
      latitudeDeg: other.fixValid ? other.latitudeDeg ?? latitudeDeg : latitudeDeg,
      longitudeDeg: other.fixValid ? other.longitudeDeg ?? longitudeDeg : longitudeDeg,
      altitudeM: other.altitudeM ?? altitudeM,
      speedKmh: other.speedKmh ?? speedKmh,
      headingDeg: other.headingDeg ?? headingDeg,
      fixValid: other.fixValid || fixValid,
      fixQuality: other.fixValid ? other.fixQuality : fixQuality,
      satellitesUsed: other.satellitesUsed ?? satellitesUsed,
      satellitesInView: other.satellitesInView ?? satellitesInView,
      hdop: other.hdop ?? hdop,
      vdop: other.vdop ?? vdop,
      pdop: other.pdop ?? pdop,
      rawSentenceType: '$rawSentenceType+${other.rawSentenceType}',
    );
  }

  static GnssFix empty(String source) => GnssFix(
        receivedAtUtc: DateTime.now().toUtc(),
        source: source,
        fixValid: false,
        fixQuality: 'no_fix',
        rawSentenceType: '-',
      );

  /// RFC 4180 CSV row matching the header in [csvHeader].
  String toCsvRow() {
    String f(Object? v) => v == null ? '' : _escape(v.toString());
    return [
      receivedAtUtc.toIso8601String(),
      gnssTimeUtc?.toIso8601String() ?? '',
      source,
      f(latitudeDeg?.toStringAsFixed(6)),
      f(longitudeDeg?.toStringAsFixed(6)),
      f(altitudeM?.toStringAsFixed(1)),
      f(speedKmh?.toStringAsFixed(2)),
      f(headingDeg?.toStringAsFixed(1)),
      fixValid.toString(),
      fixQuality,
      f(satellitesUsed),
      f(satellitesInView),
      f(hdop),
      f(vdop),
      f(pdop),
      rawSentenceType,
    ].join(',');
  }

  static const csvHeader =
      'received_at_utc,gnss_time_utc,source,latitude_deg,longitude_deg,altitude_m,'
      'speed_kmh,heading_deg,fix_valid,fix_quality,satellites_used,satellites_in_view,'
      'hdop,vdop,pdop,raw_sentence_type';

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
