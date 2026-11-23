/// MAMO展示用 Supabase 接続設定（mamo-main/config.js 相当）
class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.publishableKey,
  });

  /// 展示用デフォルト設定
  static const exhibition = SupabaseConfig(
    url: 'https://zoxmtqpoglnwjprsmfkq.supabase.co',
    publishableKey: 'sb_publishable_AmFVQVIe2eeWmUp1p8S__w_OEBXhxoz',
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
