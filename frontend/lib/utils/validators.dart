/// Only students with a `.edu.my` university email may register.
bool isValidUniversityEmail(String email) {
  final trimmed = email.trim().toLowerCase();
  final atIndex = trimmed.lastIndexOf('@');
  if (atIndex == -1 || atIndex == trimmed.length - 1) return false;

  final domain = trimmed.substring(atIndex + 1);
  return domain.endsWith('.edu.my');
}
