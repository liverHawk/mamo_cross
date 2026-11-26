import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/rescue_request.dart';
import 'rescue_data_source.dart';
import '../utils/app_logger.dart';

/// Supabase (`public.rescue_requests`) に対する本番データソース実装
class SupabaseRescueDataSource implements RescueDataSource {
  SupabaseRescueDataSource({
    this.config = SupabaseConfig.fromEnvironment,
    SupabaseClient? client,
  }) : _injectedClient = client;

  static const String _tableName = 'rescue_requests';
  static const String _channelName = 'mamo-rescue-live';

  final SupabaseConfig config;
  final SupabaseClient? _injectedClient;

  SupabaseClient? _ownedClient;
  SupabaseClient? _activeClient;
  RealtimeChannel? _channel;
  StreamController<RescueRealtimeEvent>? _realtimeController;
  final Completer<void> _disposeCompleter = Completer<void>();
  bool _disposed = false;

  SupabaseClient? _resolveClient() {
    if (_disposed) return null;
    if (_injectedClient != null) {
      _activeClient = _injectedClient;
      return _injectedClient;
    }
    if (!config.isConfigured) {
      appLog('Supabase設定がありません');
      return null;
    }
    try {
      if (config.url == SupabaseConfig.fromEnvironment.url &&
          config.publishableKey ==
              SupabaseConfig.fromEnvironment.publishableKey &&
          Supabase.instance.isInitialized) {
        _activeClient = Supabase.instance.client;
        return _activeClient;
      }
    } catch (_) {}
    _ownedClient ??= SupabaseClient(
      config.url,
      config.publishableKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      realtimeClientOptions: const RealtimeClientOptions(
        connectionCloseTimeout: Duration.zero,
      ),
    );
    _activeClient = _ownedClient;
    return _ownedClient;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInitialRequests({
    int limit = 50,
  }) async {
    final client = _resolveClient();
    if (client == null) return const [];

    final rows = await client
        .from(_tableName)
        .select('*')
        .order('created_at', ascending: false)
        .order('id', ascending: true)
        .limit(limit)
        .abortSignal(_disposeCompleter.future);

    return rows
        .map<Map<String, dynamic>>(
          (row) => Map<String, dynamic>.from(row),
        )
        .toList();
  }

  @override
  Stream<RescueRealtimeEvent> subscribeRequests({
    void Function(bool connected)? onConnectionChanged,
  }) {
    final client = _resolveClient();
    if (client == null) {
      onConnectionChanged?.call(false);
      return const Stream.empty();
    }

    final prevChannel = _channel;
    final prevController = _realtimeController;

    final controller = StreamController<RescueRealtimeEvent>.broadcast();
    _realtimeController = controller;
    RealtimeChannel? channel;
    var cleanedUpPrev = false;

    try {
      channel = client.channel(_channelName);
      _channel = channel;

      if (prevChannel != null || prevController != null) {
        cleanedUpPrev = true;
        unawaited(_cleanupChannelResources(prevChannel, prevController));
      }

      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: _tableName,
            callback: (payload) {
              if (!controller.isClosed) {
                controller.add(
                  RescueInsertedEvent(
                    Map<String, dynamic>.from(payload.newRecord),
                  ),
                );
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: _tableName,
            callback: (payload) {
              if (!controller.isClosed) {
                controller.add(
                  RescueUpdatedEvent(
                    Map<String, dynamic>.from(payload.newRecord),
                  ),
                );
              }
            },
          )
          .subscribe((status, error) {
            final connected = status == RealtimeSubscribeStatus.subscribed;
            if (error != null) {
              appLog('MAMO realtime error ($status): $error');
            }
            if (!_disposed) {
              onConnectionChanged?.call(connected);
            }
          });

      controller.onCancel = () {
        if (!_disposed &&
            !controller.hasListener &&
            identical(_realtimeController, controller)) {
          unawaited(_cleanupChannel());
        }
      };
    } catch (e) {
      appLog('MAMO realtime subscribe failed: $e');
      if (identical(_channel, channel)) {
        _channel = null;
      }
      if (identical(_realtimeController, controller)) {
        _realtimeController = null;
      }
      if (channel != null || !controller.isClosed) {
        unawaited(_cleanupChannelResources(channel, controller));
      }
      if (!cleanedUpPrev && (prevChannel != null || prevController != null)) {
        unawaited(_cleanupChannelResources(prevChannel, prevController));
      }
      onConnectionChanged?.call(false);
    }

    return controller.stream;
  }

  @override
  Future<void> updateStatus({
    required String dbId,
    required RequestStatus status,
  }) async {
    final client = _resolveClient();
    if (client == null) return;

    final Object matchId = int.tryParse(dbId) ?? dbId;
    await client
        .from(_tableName)
        .update({'status': status.label})
        .eq('id', matchId);
  }

  @override
  Future<Map<String, dynamic>?> insertRequest(
    Map<String, dynamic> payload,
  ) async {
    try {
      final client = _resolveClient();
      if (client == null) return null;

      // RLS: 本人の要請のみ参照可能にするため、認証済みなら user_id を付与
      final uid = client.auth.currentUser?.id;
      final data = <String, dynamic>{...payload};
      if (uid != null && data['user_id'] == null) data['user_id'] = uid;

      final row = await client
          .from(_tableName)
          .insert(data)
          .select()
          .maybeSingle()
          .abortSignal(_disposeCompleter.future);
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (e) {
      appLog('MAMO救助要請送信エラー: $e');
      return null;
    }
  }

  Future<void> _cleanupChannel() {
    final channel = _channel;
    final controller = _realtimeController;
    _channel = null;
    _realtimeController = null;
    return _cleanupChannelResources(channel, controller);
  }

  Future<void> _cleanupChannelResources(
    RealtimeChannel? channel,
    StreamController<RescueRealtimeEvent>? controller,
  ) async {
    if (channel != null) {
      try {
        final client = _injectedClient ?? _ownedClient ?? _activeClient;
        if (client != null) {
          await client.removeChannel(channel);
        } else {
          await channel.unsubscribe();
        }
      } catch (e) {
        appLog('MAMO realtime channel cleanup error: $e');
      }
    }

    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (!_disposeCompleter.isCompleted) {
      _disposeCompleter.complete();
    }

    final channel = _channel;
    final controller = _realtimeController;
    _channel = null;
    _realtimeController = null;
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }

    final owned = _ownedClient;
    _ownedClient = null;
    final activeClient = _activeClient;
    _activeClient = null;
    if (owned != null) {
      final realtime = owned.realtime;
      final conn = realtime.conn;
      realtime.connState = SocketStates.disconnected;
      realtime.conn = null;
      realtime.reconnectTimer.reset();
      realtime.heartbeatTimer?.cancel();
      unawaited(realtime.disconnect());
      if (conn != null) {
        unawaited(conn.sink.close().catchError((Object _) {}));
      }
    }

    if (channel != null) {
      try {
        final clientToRemoveFrom =
            _injectedClient ?? (owned == null ? activeClient : null);
        if (clientToRemoveFrom != null) {
          await clientToRemoveFrom.removeChannel(channel);
        } else {
          final unsubFuture = channel.unsubscribe(Duration.zero);
          if (owned != null) {
            unawaited(owned.realtime.disconnect());
          }
          await unsubFuture;
        }
      } catch (e) {
        appLog('MAMO realtime channel cleanup error: $e');
      }
    }

    if (owned != null) {
      try {
        await owned.dispose();
      } catch (e) {
        appLog('SupabaseClient dispose error: $e');
      }
    }
  }
}
