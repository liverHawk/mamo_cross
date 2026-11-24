/// MAMO展示用 Supabase 接続設定（mamo-main/config.js 相当）
class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.publishableKey,
  });

  /// 展示用デフォルト設定（新規プロジェクト: mamo-cross）
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
