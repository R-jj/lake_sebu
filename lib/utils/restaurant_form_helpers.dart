/// Pure helper functions for the owner restaurant setup and edit forms.
///
/// These are extracted to a package-visible file so they can be imported
/// directly by unit and property-based tests without relying on Flutter's
/// widget tree or Firebase.
library;

/// Returns a map containing only the entries in [updated] whose values
/// differ from the corresponding entries in [original].
///
/// When the two maps are identical the result is empty.
/// Keys present in [updated] but absent in [original] are included in the
/// diff (their value in [original] is implicitly null, so any non-null
/// value in [updated] counts as a change).
Map<String, dynamic> computeDiff(
  Map<String, dynamic> original,
  Map<String, dynamic> updated,
) {
  return Map.fromEntries(
    updated.entries.where((e) => e.value != original[e.key]),
  );
}

/// Returns true when [url] is a valid HTTP or HTTPS URL with a non-empty host.
///
/// Empty strings and whitespace-only strings return false.
/// Only `http` and `https` schemes are accepted; `ftp`, `mailto`, and all
/// other schemes are rejected.
bool isValidImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}
