class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oqkuvygkchsftzclakyu.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9xa3V2eWdrY2hzZnR6Y2xha3l1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTg2NTA1OCwiZXhwIjoyMDk3NDQxMDU4fQ.xOGIHaiGg42vgei4Zubj3xOz6sC-rCk-RcjdjaVzV24',
  );
  static const documentsBucket = String.fromEnvironment(
    'SUPABASE_BUCKET_DOCUMENTOS',
    defaultValue: 'documentos-credito',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
