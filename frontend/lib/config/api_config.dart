import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Base URL of the FastAPI backend (TOTP, escrow, RAG search). Configurable
/// via `.env` so it can point at localhost during dev or the deployed
/// Railway service in production.
String get backendUrl => dotenv.env['BACKEND_URL']!;
