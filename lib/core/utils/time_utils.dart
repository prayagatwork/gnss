/// Time helpers per spec section 6:
/// "Store timestamps in UTC ISO 8601 and convert to local time only for display."
class TimeUtils {
  /// Parses NMEA hhmmss(.ss) + optional ddmmyy into a UTC DateTime.
  /// If [ddmmyy] is null, today's UTC date is assumed (GGA has no date field;
  /// the date should be combined in from a paired RMC sentence per spec 6.9).
  static DateTime? fromNmeaTimeDate(String hhmmss, [String? ddmmyy]) {
    if (hhmmss.length < 6) return null;
    try {
      final hh = int.parse(hhmmss.substring(0, 2));
      final mm = int.parse(hhmmss.substring(2, 4));
      final ss = double.parse(hhmmss.substring(4));
      final now = DateTime.now().toUtc();
      var day = now.day, month = now.month, year = now.year;
      if (ddmmyy != null && ddmmyy.length == 6) {
        day = int.parse(ddmmyy.substring(0, 2));
        month = int.parse(ddmmyy.substring(2, 4));
        year = 2000 + int.parse(ddmmyy.substring(4, 6));
      }
      return DateTime.utc(
        year,
        month,
        day,
        hh,
        mm,
        ss.floor(),
        ((ss - ss.floor()) * 1000).round(),
      );
    } catch (_) {
      return null;
    }
  }

  static String toIso8601Utc(DateTime dt) => dt.toUtc().toIso8601String();

  /// Default log filename per client spec: yyyymmdd_hhmmssmmm.txt
  static String defaultLogFilename(DateTime dt, {String ext = 'txt'}) {
    final u = dt.toUtc();
    String p(int v, [int width = 2]) => v.toString().padLeft(width, '0');
    return '${p(u.year, 4)}${p(u.month)}${p(u.day)}_'
        '${p(u.hour)}${p(u.minute)}${p(u.second)}${p(u.millisecond, 3)}.$ext';
  }
}
