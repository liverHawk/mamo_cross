import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';

import '../config/supabase_config.dart';
import '../models/rescue_request.dart';
import 'rescue_data_source.dart';

/// Supabase (`public.rescue_requests`) に対する本番データソース実装
class SupabaseRescueDataSource implements RescueDataSource {
  SupabaseRescueDataSource({
    this.config = SupabaseConfig.exhibition,
    SupabaseClient? client,
  }) : _injectedClient = client;

  static const String _tableName = 'rescue_requests';
  static const String _channelName = 'mamo-rescue-live';

  final SupabaseConfig config;
  final SupabaseClient? _injectedClient;

  SupabaseClient? _ownedClient;
  RealtimeChannel? _channel;
  StreamController<RescueRealtimeEvent>? _realtimeController;
  bool _disposed = false;

  SupabaseClient? _resolveClient() {
    if (_disposed) return null;
    if (_injectedClient != null) return _injectedClient;
    if (!config.isConfigured) {
      debugPrint('Supabase設定がありません');
      return null;
    }
    return _ownedClient ??= SupabaseClient(config.url, config.publishableKey);
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
        .limit(limit);

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
    _channel = null;
    _realtimeController = null;
    if (prevChannel != null || prevController != null) {
      unawaited(_cleanupChannelResources(prevChannel, prevController));
    }

    final controller = StreamController<RescueRealtimeEvent>.broadcast();
    _realtimeController = controller;

    try {
      final channel = client.channel(_channelName);
      _channel = channel;

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
              debugPrint('MAMO realtime error ($status): $error');
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
      debugPrint('MAMO realtime subscribe failed: $e');
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
        final client = _injectedClient ?? _ownedClient;
        if (client != null) {
          await client.removeChannel(channel);
        } else {
          await channel.unsubscribe();
        }
      } catch (e) {
        debugPrint('MAMO realtime channel cleanup error: $e');
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
    await _cleanupChannel();
    final owned = _ownedClient;
    _ownedClient = null;
    if (owned != null) {
      try {
        await owned.dispose();
      } catch (e) {
        debugPrint('SupabaseClient dispose error: $e');
      }
    }
  }
}
