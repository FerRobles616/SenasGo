/// Configuración de Supabase por compilación.
///
/// Se pasan con:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// Si faltan, la app funciona 100% offline y no muestra la sección de nube.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get configured => url.isNotEmpty && anonKey.isNotEmpty;
}
