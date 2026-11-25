import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'rescue_data_source.dart';
import 'supabase_rescue_data_source.dart';

/// 対策本部（HQ）オペレーター認証の失敗
class HqAuthException implements Exception {
  const HqAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 対策本部（HQ）モード用の認証サービス
///
/// 市民用の匿名セッションとは分離した HQ 専用クライアントで認証し、
/// 認証済みデータソース（全件閲覧・ステータス更新が RLS で許可される）を返す。
abstract interface class HqAuthService {
  /// パスコード（HQ アカウントのパスワード）を検証し、認証済みデータソースを返す
  Future<RescueDataSource> signIn(String passcode);

  Future<void> signOut();
}

/// Supabase Auth を用いた HQ 認証（`app_metadata.role = 'hq_admin'` を要求）
class SupabaseHqAuthService implements HqAuthService {
  SupabaseHqAuthService({
    this.config = SupabaseConfig.fromEnvironment,
    this.email = defaultEmail,
    this.maxFailures = 5,
    this.lockout = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// HQ オペレーターのメールアドレス（秘匿情報ではない。パスコードが秘密）
  static const defaultEmail = String.fromEnvironment(
    'HQ_OPERATOR_EMAIL',
    defaultValue: 'hq-operator@mamo-demo.example',
  );

  final SupabaseConfig config;
  final String email;
  final int maxFailures;
  final Duration lockout;
  final DateTime Function() _clock;

  SupabaseClient? _client;
  int _failures = 0;
  DateTime? _lockedUntil;

  @override
  Future<RescueDataSource> signIn(String passcode) async {
    final now = _clock();
    final lockedUntil = _lockedUntil;
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      throw const HqAuthException('試行回数が上限に達しました。しばらくお待ちください。');
    }
    if (!config.isConfigured || passcode.isEmpty || passcode.length > 128) {
      throw const HqAuthException('パスコードが正しくありません。');
    }

    await signOut();
    final client = SupabaseClient(
      config.url,
      config.publishableKey,
      // メモリ内セッション（永続化しない）。長時間展示向けにトークン自動更新は有効。
      authOptions: const AuthClientOptions(autoRefreshToken: true),
    );
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: passcode,
      );
      final role = response.user?.appMetadata['role'];
      if (role != 'hq_admin') {
        throw const HqAuthException('このアカウントには権限がありません。');
      }
      _failures = 0;
      _lockedUntil = null;
      _client = client;
      return SupabaseRescueDataSource(config: config, client: client);
    } on HqAuthException {
      await _discard(client);
      rethrow;
    } catch (e) {
      await _discard(client);
      _failures++;
      if (_failures >= maxFailures) {
        _lockedUntil = _clock().add(lockout);
        _failures = 0;
      }
      if (kDebugMode) debugPrint('MAMO HQ認証エラー: $e');
      throw const HqAuthException('パスコードが正しくありません。');
    }
  }

  @override
  Future<void> signOut() async {
    final client = _client;
    _client = null;
    if (client != null) await _discard(client);
  }

  Future<void> _discard(SupabaseClient client) async {
    try {
      await client.auth.signOut();
    } catch (_) {}
    try {
      await client.dispose();
    } catch (_) {}
  }
}

/// HQ モードを無効化したビルド用（常に認証失敗）
class DisabledHqAuthService implements HqAuthService {
  const DisabledHqAuthService();

  @override
  Future<RescueDataSource> signIn(String passcode) async =>
      throw const HqAuthException('このビルドでは自治体モードは無効です。');

  @override
  Future<void> signOut() async {}
}
