// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : validators.dart
// Description     : Input validators, notably the .edu.my university-email format check.
// First Written on: Friday,03-Jul-2026
// Edited on       : Saturday,04-Jul-2026

/// Basic shape check: one `@`, a non-empty local part, a domain with at
/// least one dot, no whitespace. Not a full RFC 5322 validator — just enough
/// to catch obvious typos before a round trip to Supabase.
final _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Only students with a `.edu.my` university email may register.
bool isValidUniversityEmail(String email) {
  final trimmed = email.trim().toLowerCase();
  if (!_emailShape.hasMatch(trimmed)) return false;

  final domain = trimmed.substring(trimmed.lastIndexOf('@') + 1);
  return domain.endsWith('.edu.my');
}
