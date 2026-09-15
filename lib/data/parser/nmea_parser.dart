import 'dart:convert';
import 'dart:typed_data';

import '../../core/utils/checksum.dart';
import '../../core/utils/time_utils.dart';
import '../../domain/models/gnss_fix.dart';

/// Diagnostics counters exposed on the Diagnostics view (spec 8.4).
class ParserDiagnostics {
  int bytesReceived = 0;
  int received = 0;
  int parsed = 0;
  int checksumFailed = 0;
  int malformed = 0;
  int unsupported = 0;
  String? lastError;
  DateTime? lastErrorAt;

  void reset() {
    bytesReceived = 0;
    received = 0;
    parsed = 0;
    checksumFailed = 0;
    malformed = 0;
    unsupported = 0;
    lastError = null;
    lastErrorAt = null;
  }
}

const _maxLineLength = 1024;
const staleDataThreshold = Duration(seconds: 5);

/// Reassembles a raw byte stream into complete NMEA lines, tolerating:
///  - multiple sentences arriving in a single chunk
///  - one sentence split across multiple chunks
///  - \r\n, \n, or \r line endings
///  - noise before '$'
///  - invalid UTF-8/ASCII bytes (dropped, not fatal)
class NmeaFramer {
  final _buffer = StringBuffer();
  final ParserDiagnostics diagnostics;

  NmeaFramer(this.diagnostics);

  /// Feeds raw bytes in; yields complete raw sentence lines (still to be
  /// checksum-validated / parsed).
  List<String> feed(Uint8List chunk) {
    diagnostics.bytesReceived += chunk.length;
    late String decoded;
    try {
      decoded = utf8.decode(chunk, allowMalformed: true);
    } catch (_) {
      decoded = latin1.decode(chunk);
    }
    _buffer.write(decoded);

    final combined = _buffer.toString();
    // Split on any of \r\n, \n, \r
    final rawLines = combined.split(RegExp(r'\r\n|\r|\n'));
    _buffer.clear();

    if (rawLines.isEmpty) return [];

    // Last piece may be incomplete (no trailing newline yet) - keep it buffered.
    final incomplete = rawLines.removeLast();
    _buffer.write(incomplete);

    final results = <String>[];
    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Discard noise before '$' or '!'
      final startIdx = trimmed.indexOf(RegExp(r'[\$!]'));
      if (startIdx == -1) {
        diagnostics.malformed++;
        continue;
      }
      var clean = trimmed.substring(startIdx);
      if (clean.length > _maxLineLength) {
        diagnostics.malformed++;
        continue;
      }
      diagnostics.received++;
      results.add(clean);
    }
    return results;
  }
}

/// Parses validated NMEA sentence bodies into [GnssFix] fragments.
/// Each supported sentence type produces a *partial* GnssFix; the caller
/// (state layer) merges GGA + RMC etc. into the combined displayed fix via
/// [GnssFix.mergedWith].
class NmeaParser {
  final ParserDiagnostics diagnostics;
  static const _supportedTalkers = ['GP', 'GN', 'GL', 'GA', 'GB', 'BD'];

  NmeaParser(this.diagnostics);

  /// Returns null if the sentence type is unsupported, malformed, or fails
  /// checksum validation (unchecksummed sentences are still accepted).
  GnssFix? parse(String rawSentence, {required String sourceName}) {
    final valid = NmeaChecksum.validate(rawSentence);
    if (valid == false) {
      diagnostics.checksumFailed++;
      return null;
    }

    final starIndex = rawSentence.indexOf('*');
    final body = starIndex == -1
        ? rawSentence.substring(1)
        : rawSentence.substring(1, starIndex);
    final fields = body.split(',');
    if (fields.isEmpty || fields[0].length < 5) {
      diagnostics.malformed++;
      return null;
    }

    final talker = fields[0].substring(0, 2);
    final type = fields[0].substring(2);
    if (!_supportedTalkers.contains(talker)) {
      diagnostics.unsupported++;
      return null;
    }

    try {
      GnssFix? fix;
      switch (type) {
        case 'GGA':
          fix = _parseGga(fields, sourceName);
          break;
        case 'RMC':
          fix = _parseRmc(fields, sourceName);
          break;
        case 'GSA':
          fix = _parseGsa(fields, sourceName);
          break;
        case 'GSV':
          fix = _parseGsv(fields, sourceName);
          break;
        case 'VTG':
          fix = _parseVtg(fields, sourceName);
          break;
        case 'GLL':
          fix = _parseGll(fields, sourceName);
          break;
        default:
          diagnostics.unsupported++;
          return null;
      }
      diagnostics.parsed++;
      return fix;
    } catch (e) {
      diagnostics.malformed++;
      diagnostics.lastError = 'Parse error ($type): $e';
      diagnostics.lastErrorAt = DateTime.now().toUtc();
      return null;
    }
  }

  double? _coord(String value, String hemi, {required bool isLat}) {
    if (value.isEmpty) return null;
    final degLen = isLat ? 2 : 3;
    if (value.length < degLen) return null;
    final deg = double.parse(value.substring(0, degLen));
    final min = double.parse(value.substring(degLen));
    var result = deg + min / 60.0;
    if (hemi == 'S' || hemi == 'W') result = -result;
    // Reject impossible ranges (spec rule 6.3).
    if (isLat && (result < -90 || result > 90)) {
      throw const FormatException('latitude out of range');
    }
    if (!isLat && (result < -180 || result > 180)) {
      throw const FormatException('longitude out of range');
    }
    return result;
  }

  String _fixQualityFromCode(String code) {
    switch (code) {
      case '0':
        return 'no_fix';
      case '1':
        return 'gps_fix';
      case '2':
        return 'dgps_fix';
      case '4':
      case '5':
        return 'rtk_fix';
      default:
        return 'unknown';
    }
  }

  GnssFix _parseGga(List<String> f, String source) {
    // $--GGA,time,lat,N,lon,E,quality,numSV,HDOP,alt,M,geoidSep,M,age,stationId
    if (f.length < 10) throw const FormatException('GGA too short');
    final quality = f[6];
    final fixValid = quality != '0' && quality.isNotEmpty;
    final lat = _coord(f[2], f[3], isLat: true);
    final lon = _coord(f[4], f[5], isLat: false);
    if (fixValid && (lat == null || lon == null)) {
      throw const FormatException('GGA missing coordinates on valid fix');
    }
    return GnssFix(
      receivedAtUtc: DateTime.now().toUtc(),
      gnssTimeUtc: TimeUtils.fromNmeaTimeDate(f[1]),
      source: source,
      latitudeDeg: lat,
      longitudeDeg: lon,
      altitudeM: f[9].isNotEmpty ? double.tryParse(f[9]) : null,
      fixValid: fixValid,
      fixQuality: _fixQualityFromCode(quality),
      satellitesUsed: f[7].isNotEmpty ? int.tryParse(f[7]) : null,
      hdop: f[8].isNotEmpty ? double.tryParse(f[8]) : null,
      rawSentenceType: 'GGA',
    );
  }

  GnssFix _parseRmc(List<String> f, String source) {
    // $--RMC,time,status,lat,N,lon,E,speedKnots,course,date,...
    if (f.length < 10) throw const FormatException('RMC too short');
    final status = f[2];
    final fixValid = status == 'A';
    final lat = fixValid ? _coord(f[3], f[4], isLat: true) : null;
    final lon = fixValid ? _coord(f[5], f[6], isLat: false) : null;
    final speedKnots = f[7].isNotEmpty ? double.tryParse(f[7]) : null;
    final speedKmh =
        speedKnots != null ? speedKnots * 1.852 : null; // spec rule 6.6
    var heading = f[8].isNotEmpty ? double.tryParse(f[8]) : null;
    if (heading != null) heading = heading % 360; // spec rule 6.7
    return GnssFix(
      receivedAtUtc: DateTime.now().toUtc(),
      gnssTimeUtc: TimeUtils.fromNmeaTimeDate(
          f[1], f[9]), // combine RMC date+time, spec 6.9
      source: source,
      latitudeDeg: lat,
      longitudeDeg: lon,
      speedKmh: speedKmh,
      headingDeg: heading,
      fixValid: fixValid,
      fixQuality: fixValid ? 'gps_fix' : 'no_fix',
      rawSentenceType: 'RMC',
    );
  }

  GnssFix _parseGsa(List<String> f, String source) {
    if (f.length < 17) throw const FormatException('GSA too short');
    final satsUsed = f.sublist(3, 15).where((s) => s.isNotEmpty).length;
    return GnssFix(
      receivedAtUtc: DateTime.now().toUtc(),
      source: source,
      fixValid: f[2] == '3' || f[2] == '2',
      fixQuality: 'unknown',
      satellitesUsed: satsUsed,
      pdop: f[15].isNotEmpty ? double.tryParse(f[15]) : null,
      hdop: f[16].isNotEmpty ? double.tryParse(f[16]) : null,
      vdop: f.length > 17 && f[17].isNotEmpty ? double.tryParse(f[17]) : null,
      rawSentenceType: 'GSA',
    );
  }

  GnssFix _parseGsv(List<String> f, String source) {
    if (f.length < 4) throw const FormatException('GSV too short');
    return GnssFix(
      receivedAtUtc: DateTime.now().toUtc(),
      source: source,
      fixValid: false,
      fixQuality: 'unknown',
      satellitesInView: int.tryParse(f[3]),
      rawSentenceType: 'GSV',
    );
  }

  GnssFix _parseVtg(List<String> f, String source) {
    if (f.length < 8) throw const FormatException('VTG too short');
    var heading = f[1].isNotEmpty ? double.tryParse(f[1]) : null;
    if (heading != null) heading = heading % 360;
    final speedKmh = f[6].isNotEmpty ? double.tryParse(f[6]) : null;
    return GnssFix(
      receivedAtUtc: DateTime.now().toUtc(),
      source: source,
      fixValid: false,
      fixQuality: 'unknown',
      headingDeg: heading,
      speedKmh: speedKmh,
      rawSentenceType: 'VTG',
    );
  }

  GnssFix _parseGll(List<String> f, String source) {
    // Fallback position source per spec 6 (GLL).
    if (f.length < 7) throw const FormatException('GLL too short');
    final fixValid = f[6] == 'A';
    final lat = fixValid ? _coord(f[1], f[2], isLat: true) : null;
    final lon = fixValid ? _coord(f[3], f[4], isLat: false) : null;
    return GnssFix(
      receivedAtUtc: DateTime.now().toUtc(),
      gnssTimeUtc: TimeUtils.fromNmeaTimeDate(f[5]),
      source: source,
      latitudeDeg: lat,
      longitudeDeg: lon,
      fixValid: fixValid,
      fixQuality: fixValid ? 'gps_fix' : 'no_fix',
      rawSentenceType: 'GLL',
    );
  }
}
