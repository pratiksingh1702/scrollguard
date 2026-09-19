/// Environment configuration loaded via `--dart-define`.
class EnvConfig {
  const EnvConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'placeholder-anon-key',
  );

  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_placeholder',
  );

  static const bool contractEnabled = bool.fromEnvironment(
    'CONTRACT_ENABLED',
  );

  static const bool isDevelopment = bool.fromEnvironment(
    'DEVELOPMENT',
    defaultValue: true,
  );
}
