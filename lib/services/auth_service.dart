import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 利用者認証サービス（匿名認証ベース、将来メール認証へ拡張可能）
abstract interface class AuthService {
  String? get currentUserId;
  bool get isAuthenticated;
  Stream<String?> get userIdChanges;

  /// 既存セッションがなければ匿名サインインを行い、ユーザーIDを返す（未初期化・失敗時は null）
  Future<String?> ensureAnonymousSession();

  Future<void> signOut();
  void dispose();
}

/// `Supabase.instance.client`（または注入・リゾルバクライアント）を用いる AuthService 実装
class SupabaseAuthService implements AuthService {
  SupabaseAuthService({
    SupabaseClient? client,
    this.clientResolver,
  }) : _injectedClient = client;

  final SupabaseClient? _injectedClient;
  final SupabaseClient? Function()? clientResolver;
  final StreamController<String?> _userIdController =
      StreamController<String?>.broadcast();
  StreamSubscription<AuthState>? _authSub;
  Future<String?>? _inFlightSignIn;
  Future<void>? _inFlightSignOut;
  int _authEpoch = 0;
  bool _listening = false;
  bool _disposed = false;

  SupabaseClient? _resolveClient() {
    if (_disposed) return null;
    if (_injectedClient != null) return _injectedClient;
    final resolver = clientResolver;
    if (resolver != null) {
      try {
        final resolved = resolver();
        if (resolved != null) return resolved;
      } catch (e) {
        debugPrint('MAMO 認証クライアント解決エラー: $e');
        return null;
      }
    }
    try {
      if (Supabase.instance.isInitialized) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  void _ensureAuthListener(SupabaseClient client) {
    if (_listening || _disposed) return;
    _listening = true;
    _authSub = client.auth.onAuthStateChange.listen((state) {
      if (!_disposed && !_userIdController.isClosed) {
        _userIdController.add(state.session?.user.id);
      }
    });
  }

  @override
  String? get currentUserId => _resolveClient()?.auth.currentUser?.id;

  @override
  bool get isAuthenticated => currentUserId != null;

  @override
  Stream<String?> get userIdChanges {
    final client = _resolveClient();
    if (client != null) {
      _ensureAuthListener(client);
    }
    return _userIdController.stream;
  }

  @override
  Future<String?> ensureAnonymousSession() async {
    if (_disposed) return null;
    while (_inFlightSignOut != null) {
      await _inFlightSignOut!.catchError((_) {});
      if (_disposed) return null;
    }

    final client = _resolveClient();
    if (client == null) return null;
    _ensureAuthListener(client);

    final existing = client.auth.currentUser?.id;
    if (existing != null) return existing;

    final inFlight = _inFlightSignIn;
    if (inFlight != null) return inFlight;

    final epoch = _authEpoch;
    Future<String?>? future;
    var settled = false;
    future = () async {
      try {
        final response = await client.auth.signInAnonymously();
        if (_disposed || _authEpoch != epoch) return null;
        return response.user?.id ?? client.auth.currentUser?.id;
      } catch (e) {
        debugPrint('MAMO 匿名認証エラー: $e');
        return null;
      } finally {
        settled = true;
        if (future != null && identical(_inFlightSignIn, future)) {
          _inFlightSignIn = null;
        }
      }
    }();
    if (!settled) {
      _inFlightSignIn = future;
    }
    return future;
  }

  @override
  Future<void> signOut() {
    _authEpoch++;
    final previousSignOut = _inFlightSignOut;
    Future<void>? future;
    var settled = false;
    future = () async {
      try {
        if (previousSignOut != null) {
          await previousSignOut.catchError((_) {});
        }
        final inFlightSignIn = _inFlightSignIn;
        if (inFlightSignIn != null) {
          await inFlightSignIn.catchError((_) => null);
        }
        if (_disposed) return;
        final client = _resolveClient();
        if (client == null) return;
        try {
          await client.auth.signOut();
        } catch (e) {
          debugPrint('MAMO サインアウトエラー: $e');
        }
      } catch (e) {
        debugPrint('MAMO サインアウトエラー: $e');
      } finally {
        settled = true;
        if (future != null && identical(_inFlightSignOut, future)) {
          _inFlightSignOut = null;
        }
      }
    }();
    if (!settled) {
      _inFlightSignOut = future;
    }
    return future;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _authEpoch++;
    unawaited(_authSub?.cancel());
    unawaited(_userIdController.close());
  }
}
