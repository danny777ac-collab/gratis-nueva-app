import 'package:supabase_flutter/supabase_flutter.dart';

/// Credenciales de Supabase.
///
/// Se pasan en tiempo de compilación con `--dart-define` para no dejar
/// secretos en el repositorio, por ejemplo:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
///
/// Si prefieres, puedes reemplazar los `defaultValue` por tus credenciales
/// directamente (la Anon Key es pública y segura para clientes).
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://YOUR_PROJECT.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'YOUR_ANON_KEY',
);

/// Acceso rápido al cliente de Supabase ya inicializado.
SupabaseClient get supabase => Supabase.instance.client;
