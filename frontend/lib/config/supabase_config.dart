import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads `.env` and initializes the Supabase client. Call once from `main()`
/// before `runApp`.
Future<void> initSupabase() async {
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
