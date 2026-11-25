/// MAMO Supabase 接続設定
class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.publishableKey,
  });

  /// `--dart-define=SUPABASE_URL=...` / `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`
  /// で上書き可能な環境設定（未指定時は展示用プロジェクトへフォールバック）
  static const fromEnvironment = SupabaseConfig(
    url: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://qmbdouenpcquabahxryt.supabase.co',
    ),
    publishableKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_06W02bS6DJ4-pcoyg86Zaw_uczS0nKv',
    ),
  );

  /// 展示用デフォルト設定（プロジェクト: mamo-cross）
  static const exhibition = SupabaseConfig(
    url: 'https://qmbdouenpcquabahxryt.supabase.co',
    publishableKey: 'sb_publishable_06W02bS6DJ4-pcoyg86Zaw_uczS0nKv',
  );

  /// 未設定フォールバック検証用の空設定
  static const empty = SupabaseConfig(
    url: '',
    publishableKey: '',
  );

  final String url;
  final String publishableKey;

  bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;
}
