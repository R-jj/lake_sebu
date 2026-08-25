/// Philippine phone-number validation and normalisation utilities.
///
/// Supported input formats
/// ─────────────────────────
///   09171234567     → local mobile (leading 0)
///   9171234567      → local mobile without leading 0
///   +639171234567   → E.164 international
///   639171234567    → international without +
///   +63 917 123 4567  → with spaces
///   0917-123-4567   → with hyphens
///
/// Valid PH mobile prefixes (NTC-assigned ranges as of 2024)
/// ──────────────────────────────────────────────────────────
///   Globe / TM   : 817, 905, 906, 915, 916, 917, 926, 927, 935, 936,
///                  945, 955, 956, 965, 966, 967, 975, 976, 977
///   Smart / TNT  : 908, 909, 910, 911, 912, 913, 914, 918, 919, 920,
///                  921, 928, 929, 930, 938, 939, 946, 947, 948, 949,
///                  950, 951, 961, 998, 999
///   DITO         : 895, 896, 897, 898
///   Sun / Smart  : 922, 923, 924, 925, 931, 932, 933, 934, 940, 941,
///                  942, 943, 944
///   Landline     : 2 (Metro Manila) + 7–8 digit subscriber number
///                  — not handled here; mobile only.
///
/// A "valid" number is one that:
///   1. Strips to exactly 10 digits after removing the country/trunk code.
///   2. Has a recognised PH mobile prefix (first 3 digits of the 10-digit
///      subscriber number, i.e. digits 1–3 after stripping trunk/country).
///   3. Contains only digits (and allowed separators: spaces, hyphens, +).
class PhoneValidator {
  PhoneValidator._();

  static const String _countryCode = '+63';

  // All currently assigned PH mobile 3-digit prefixes.
  static const Set<String> _validPrefixes = {
    '817',
    '895', '896', '897', '898',
    '905', '906', '908', '909', '910',
    '911', '912', '913', '914', '915', '916', '917', '918', '919',
    '920', '921', '922', '923', '924', '925', '926', '927', '928', '929',
    '930', '931', '932', '933', '934', '935', '936', '938', '939',
    '940', '941', '942', '943', '944', '945', '946', '947', '948', '949',
    '950', '951', '955', '956', '961', '965', '966', '967',
    '975', '976', '977',
    '998', '999',
  };

  /// Normalises the input and returns the E.164 string (e.g. "+639171234567")
  /// or `null` when the input is invalid.
  static String? normalize(String raw) {
    // Strip everything except digits and leading +.
    String cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '');

    // Strip the leading + so we work with digits only.
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    // Handle "639XXXXXXXXX" → strip country code → "9XXXXXXXXX"
    if (cleaned.startsWith('63') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    }

    // Handle "09XXXXXXXXX" → strip trunk code → "9XXXXXXXXX"
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }

    // At this point we need exactly 10 digits starting with 9.
    if (cleaned.length != 10) return null;
    if (!RegExp(r'^\d{10}$').hasMatch(cleaned)) return null;
    if (!cleaned.startsWith('9')) return null;

    // Check prefix (first 3 digits of the 10-digit subscriber number).
    final prefix = cleaned.substring(0, 3);
    if (!_validPrefixes.contains(prefix)) return null;

    return '$_countryCode$cleaned';
  }

  /// Returns `true` when [raw] can be normalised to a valid PH mobile number.
  static bool isValid(String raw) => normalize(raw) != null;

  /// Returns a user-facing error string or `null` when valid.
  static String? errorMessage(String raw) {
    if (raw.trim().isEmpty) return 'Phone number is required.';

    final cleaned =
        raw.replaceAll(RegExp(r'[\s\-+()]'), '');
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Phone number must contain digits only.';
    }

    final normalized = normalize(raw);
    if (normalized == null) {
      return 'Please enter a valid Philippine mobile number '
          '(e.g. 0917 123 4567).';
    }
    return null;
  }

  /// Returns a display-friendly formatted version of the number.
  /// E.g. "+639171234567" → "0917 123 4567"
  static String format(String e164) {
    if (!e164.startsWith('+63') || e164.length != 13) return e164;
    final local = '0${e164.substring(3)}'; // "09171234567"
    return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7)}';
  }
}
