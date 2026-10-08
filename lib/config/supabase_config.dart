/// Supabase connection settings.
///
/// Override at build time without editing code, e.g. for the self-hosted server:
///   flutter run --dart-define=SUPABASE_URL=https://api.example.com \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dgwrsfjpxuvgqrbhhjro.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3JzZmpweHV2Z3FyYmhoanJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDUzMTYsImV4cCI6MjA4NjkyMTMxNn0.g9IBC8ZjBOYWpa4-k6FWA6qiEV0CvZcqd5AG8JZLyPE',
  );
}
