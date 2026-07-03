import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL for the FastAPI backend.
///
/// Android emulators can't reach the host machine via `localhost` — they need
/// the special alias `10.0.2.2`. Web, desktop, and iOS simulators can use
/// `localhost` directly.
String get apiBaseUrl {
  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}
