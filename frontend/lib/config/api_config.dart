// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : api_config.dart
// Description     : Provides the backend API base URL, loaded from .env for switching between local and deployed environments.
// First Written on: Friday,03-Jul-2026
// Edited on       : Monday,06-Jul-2026

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Base URL of the FastAPI backend (TOTP, escrow, RAG search). Configurable
/// via `.env` so it can point at localhost during dev or the deployed
/// Railway service in production.
String get backendUrl => dotenv.env['BACKEND_URL']!;
