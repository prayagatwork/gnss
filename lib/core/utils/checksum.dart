/// NMEA 0183 XOR checksum utilities.
///
/// A valid sentence looks like: $GPGGA,....,....*5B
/// The checksum is the XOR of every character between (but not including)
/// the leading '$' (or '!') and the trailing '*'.
class NmeaChecksum {
  /// Computes the 2-digit uppercase hex XOR checksum for [body]
  /// (the text between '$'/'!' and '*').
  static String compute(String body) {
    var cs = 0;
    for (final codeUnit in body.codeUnits) {
      cs ^= codeUnit;
    }
    return cs.toRadixString(16).padLeft(2, '0').toUpperCase();
  }

  /// Validates a full raw sentence such as `$GPGGA,...*5B`.
  /// Returns true only if:
  ///  - it starts with '$' or '!'
  ///  - it contains a '*' followed by exactly 2 hex digits
  ///  - the computed checksum matches the provided one
  /// If there is no '*' at all, the sentence is treated as unchecksummed
  /// and this returns null (caller decides how to treat that case).
  static bool? validate(String rawSentence) {
    if (rawSentence.isEmpty ||
        (rawSentence[0] != r'$' && rawSentence[0] != '!')) {
      return false;
    }
    final starIndex = rawSentence.lastIndexOf('*');
    if (starIndex == -1) {
      return null; // no checksum present
    }
    if (rawSentence.length < starIndex + 3) {
      return false; // malformed, checksum digits missing
    }
    final body = rawSentence.substring(1, starIndex);
    final provided = rawSentence.substring(starIndex + 1, starIndex + 3);
    if (!RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(provided)) {
      return false;
    }
    return compute(body).toUpperCase() == provided.toUpperCase();
  }
}
