class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oqkuvygkchsftzclakyu.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const documentsBucket = String.fromEnvironment(
    'SUPABASE_BUCKET_DOCUMENTOS',
    defaultValue: 'documentos-credito',
  );
  static const coreBaseUrl = String.fromEnvironment(
    'CORE_BASE_URL',
    defaultValue: 'https://n-stack22-bancofallabela-production.up.railway.app',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
