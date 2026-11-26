import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/citizen_models.dart';
import 'citizen_data_source.dart';
import '../utils/app_logger.dart';

/// Supabase に対する利用者側データソース実装
class SupabaseCitizenDataSource implements CitizenDataSource {
  SupabaseCitizenDataSource({
    this.config = SupabaseConfig.fromEnvironment,
    SupabaseClient? client,
  }) : _injectedClient = client;

  static final RegExp _safeGroupIdPattern = RegExp(r'^[a-zA-Z0-9_-]+$');

  final SupabaseConfig config;
  final SupabaseClient? _injectedClient;

  SupabaseClient? _ownedClient;
  SupabaseClient? _activeClient;
  RealtimeChannel? _familyChannel;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _sheltersChannel;
  StreamController<List<FamilyMember>>? _familyController;
  StreamController<CitizenMessage>? _messagesController;
  StreamController<List<CitizenShelter>>? _sheltersController;
  final Completer<void> _disposeCompleter = Completer<void>();
  bool _disposed = false;

  /// `AuthService` とクライアントを共有するためのアクセサ
  SupabaseClient? get sharedClient => _resolveClient();

  static String? _sanitizeGroupId(String? groupId) {
    final trimmed = groupId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (!_safeGroupIdPattern.hasMatch(trimmed)) return null;
    return trimmed;
  }

  SupabaseClient? _resolveClient() {
    if (_disposed) return null;
    if (_injectedClient != null) {
      _activeClient = _injectedClient;
      return _injectedClient;
    }
    if (!config.isConfigured) return null;
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
  Future<({CitizenRegistrationProfile profile, CitizenSafetyStatus safety})?>
      fetchProfile(String userId) async {
    final client = _resolveClient();
    if (client == null) return null;
    try {
      final row = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .abortSignal(_disposeCompleter.future);
      if (row == null) return null;
      final profile = CitizenRegistrationProfile.fromSupabaseRow(row);
      final rawSafety = (row['safety_status'] ?? 'safe').toString();
      final safety = CitizenSafetyStatus.values.firstWhere(
        (s) => s.name == rawSafety,
        orElse: () => CitizenSafetyStatus.safe,
      );
      return (profile: profile, safety: safety);
    } catch (e) {
      appLog('MAMO プロフィール取得エラー: $e');
      rethrow;
    }
  }

  @override
  Future<void> upsertProfile({
    required String userId,
    required CitizenRegistrationProfile profile,
    required CitizenSafetyStatus safetyStatus,
    String locationNote = kDefaultCitizenLocationNote,
  }) async {
    final client = _resolveClient();
    if (client == null) return;
    try {
      await client
          .from('profiles')
          .upsert(
            profile.toSupabaseUpsert(
              userId,
              safetyStatus: safetyStatus,
              locationNote: locationNote,
            ),
          )
          .abortSignal(_disposeCompleter.future);
    } catch (e) {
      appLog('MAMO プロフィール保存エラー: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateSafetyStatus({
    required String userId,
    required CitizenSafetyStatus status,
    String? locationNote,
  }) async {
    final client = _resolveClient();
    if (client == null) return;
    try {
      final payload = <String, dynamic>{
        'id': userId,
        'safety_status': status.name,
        'safety_updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (locationNote != null && locationNote.trim().isNotEmpty) {
        payload['location_note'] = locationNote.trim();
      }
      await client
          .from('profiles')
          .upsert(payload)
          .abortSignal(_disposeCompleter.future);
    } catch (e) {
      appLog('MAMO 安否更新エラー: $e');
      rethrow;
    }
  }

  @override
  Future<FamilyGroupInfo?> fetchOrCreateDefaultFamilyGroup({
    required String userId,
    required String displayName,
  }) async {
    final client = _resolveClient();
    if (client == null) return null;
    try {
      final memberships = await client
          .from('family_members')
          .select('group_id')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .order('safety_updated_at', ascending: false)
          .limit(1)
          .abortSignal(_disposeCompleter.future);
      if (memberships.isNotEmpty) {
        final groupId = memberships.first['group_id']?.toString();
        if (groupId != null && groupId.isNotEmpty) {
          final groupRow = await client
              .from('family_groups')
              .select()
              .eq('id', groupId)
              .maybeSingle()
              .abortSignal(_disposeCompleter.future);
          if (groupRow != null) {
            return FamilyGroupInfo.fromSupabaseRow(groupRow);
          }
        }
      }

      final safeName =
          displayName.trim().isEmpty ? 'あなた' : displayName.trim();
      final created = await client
          .rpc<dynamic>(
            'create_default_family_group',
            params: <String, dynamic>{
              'p_group_name': 'マイ家族グループ',
              'p_display_name': safeName,
              'p_avatar': '🙂',
            },
          )
          .abortSignal(_disposeCompleter.future);
      if (created is Map) {
        return FamilyGroupInfo.fromSupabaseRow(
          Map<String, dynamic>.from(created),
        );
      }
      if (created != null) {
        final groupRow = await client
            .from('family_groups')
            .select()
            .eq('id', created.toString())
            .maybeSingle()
            .abortSignal(_disposeCompleter.future);
        if (groupRow != null) {
          return FamilyGroupInfo.fromSupabaseRow(groupRow);
        }
      }
      return null;
    } catch (e) {
      appLog('MAMO 家族グループ取得/作成エラー: $e');
      rethrow;
    }
  }

  @override
  Future<FamilyGroupInfo?> joinFamilyGroupByCode({
    required String inviteCode,
    required String displayName,
  }) async {
    final client = _resolveClient();
    if (client == null) return null;
    try {
      final groupId = await client
          .rpc<dynamic>(
            'join_family_group_by_code',
            params: <String, dynamic>{
              'p_invite_code': inviteCode.trim(),
              'p_display_name':
                  displayName.trim().isEmpty ? 'あなた' : displayName.trim(),
            },
          )
          .abortSignal(_disposeCompleter.future);
      if (groupId == null) return null;
      final groupRow = await client
          .from('family_groups')
          .select()
          .eq('id', groupId.toString())
          .maybeSingle()
          .abortSignal(_disposeCompleter.future);
      if (groupRow == null) return null;
      return FamilyGroupInfo.fromSupabaseRow(groupRow);
    } on PostgrestException catch (e) {
      if (e.message.toLowerCase().contains('family group not found')) {
        return null;
      }
      appLog('MAMO 家族グループ参加エラー: $e');
      rethrow;
    } catch (e) {
      appLog('MAMO 家族グループ参加エラー: $e');
      rethrow;
    }
  }

  @override
  Future<List<FamilyMember>> fetchFamilyMembers(
    String groupId, {
    String? currentUserId,
  }) async {
    final client = _resolveClient();
    if (client == null) return const [];
    try {
      final rows = await client
          .from('family_members')
          .select()
          .eq('group_id', groupId)
          .order('joined_at', ascending: true)
          .abortSignal(_disposeCompleter.future);
      return rows
          .map(
            (row) => FamilyMember.fromSupabaseRow(
              Map<String, dynamic>.from(row),
              currentUserId: currentUserId,
            ),
          )
          .toList();
    } catch (e) {
      appLog('MAMO 家族メンバー取得エラー: $e');
      rethrow;
    }
  }

  @override
  Stream<List<FamilyMember>> subscribeFamilyMembers(
    String groupId, {
    String? currentUserId,
  }) {
    final client = _resolveClient();
    if (client == null) return const Stream.empty();
    final prevChannel = _familyChannel;
    final prevController = _familyController;

    final controller = StreamController<List<FamilyMember>>.broadcast();
    _familyController = controller;
    RealtimeChannel? channel;
    var cleanedPrev = false;

    try {
      channel = client.channel('mamo-family-$groupId');
      _familyChannel = channel;
      if (prevChannel != null || prevController != null) {
        cleanedPrev = true;
        unawaited(
          _cleanupChannelResources(client, prevChannel, prevController),
        );
      }
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'family_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'group_id',
              value: groupId,
            ),
            callback: (_) async {
              if (_disposed || controller.isClosed) return;
              try {
                final latest = await fetchFamilyMembers(
                  groupId,
                  currentUserId: currentUserId,
                );
                if (!_disposed && !controller.isClosed) {
                  controller.add(latest);
                }
              } catch (e) {
                appLog('MAMO 家族メンバー更新取得エラー: $e');
              }
            },
          )
          .subscribe();

      controller.onCancel = () {
        if (!_disposed &&
            !controller.hasListener &&
            identical(_familyController, controller)) {
          final ch = _familyChannel;
          _familyChannel = null;
          _familyController = null;
          unawaited(_cleanupChannelResources(client, ch, controller));
        }
      };
    } catch (e) {
      appLog('MAMO 家族メンバー購読エラー: $e');
      if (identical(_familyChannel, channel)) _familyChannel = null;
      if (identical(_familyController, controller)) _familyController = null;
      unawaited(_cleanupChannelResources(client, channel, controller));
      if (!cleanedPrev && (prevChannel != null || prevController != null)) {
        unawaited(
          _cleanupChannelResources(client, prevChannel, prevController),
        );
      }
    }
    return controller.stream;
  }

  @override
  Future<List<CitizenMessage>> fetchMessages({
    String? groupId,
    String? currentUserId,
  }) async {
    final client = _resolveClient();
    if (client == null) return const [];
    final safeGroupId = _sanitizeGroupId(groupId);
    try {
      final base = client.from('messages').select();
      final filtered = safeGroupId != null
          ? base.or(
              'kind.eq.municipality_notice,and(kind.eq.family_thread,group_id.eq.$safeGroupId)',
            )
          : base.eq('kind', 'municipality_notice');
      final rows = await filtered
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(100)
          .abortSignal(_disposeCompleter.future);
      return rows
          .map(
            (row) => CitizenMessage.fromSupabaseRow(
              Map<String, dynamic>.from(row),
              currentUserId: currentUserId,
            ),
          )
          .toList()
          .reversed
          .toList();
    } catch (e) {
      appLog('MAMO メッセージ取得エラー: $e');
      rethrow;
    }
  }

  @override
  Stream<CitizenMessage> subscribeMessages({
    String? groupId,
    String? currentUserId,
  }) {
    final client = _resolveClient();
    if (client == null) return const Stream.empty();
    final safeGroupId = _sanitizeGroupId(groupId);
    final prevChannel = _messagesChannel;
    final prevController = _messagesController;

    final controller = StreamController<CitizenMessage>.broadcast();
    _messagesController = controller;
    RealtimeChannel? channel;
    var cleanedPrev = false;

    try {
      channel = client.channel('mamo-messages-${safeGroupId ?? 'public'}');
      _messagesChannel = channel;
      if (prevChannel != null || prevController != null) {
        cleanedPrev = true;
        unawaited(
          _cleanupChannelResources(client, prevChannel, prevController),
        );
      }

      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'kind',
          value: 'municipality_notice',
        ),
        callback: (payload) {
          if (_disposed || controller.isClosed) return;
          final row = Map<String, dynamic>.from(payload.newRecord);
          if (row['kind']?.toString() != 'municipality_notice') return;
          controller.add(
            CitizenMessage.fromSupabaseRow(
              row,
              currentUserId: currentUserId,
            ),
          );
        },
      );

      if (safeGroupId != null) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: safeGroupId,
          ),
          callback: (payload) {
            if (_disposed || controller.isClosed) return;
            final row = Map<String, dynamic>.from(payload.newRecord);
            if (row['kind']?.toString() != 'family_thread' ||
                row['group_id']?.toString() != safeGroupId) {
              return;
            }
            controller.add(
              CitizenMessage.fromSupabaseRow(
                row,
                currentUserId: currentUserId,
              ),
            );
          },
        );
      }

      channel.subscribe();

      controller.onCancel = () {
        if (!_disposed &&
            !controller.hasListener &&
            identical(_messagesController, controller)) {
          final ch = _messagesChannel;
          _messagesChannel = null;
          _messagesController = null;
          unawaited(_cleanupChannelResources(client, ch, controller));
        }
      };
    } catch (e) {
      appLog('MAMO メッセージ購読エラー: $e');
      if (identical(_messagesChannel, channel)) _messagesChannel = null;
      if (identical(_messagesController, controller)) _messagesController = null;
      unawaited(_cleanupChannelResources(client, channel, controller));
      if (!cleanedPrev && (prevChannel != null || prevController != null)) {
        unawaited(
          _cleanupChannelResources(client, prevChannel, prevController),
        );
      }
    }
    return controller.stream;
  }

  @override
  Future<CitizenMessage?> sendMessage({
    required CitizenMessageKind kind,
    required String senderName,
    required String body,
    String? groupId,
    String? senderId,
    String avatar = '🙂',
    bool isImportant = false,
  }) async {
    final client = _resolveClient();
    if (client == null) return null;
    try {
      final dbKind = kind == CitizenMessageKind.familyThread
          ? 'family_thread'
          : 'municipality_notice';
      final payload = <String, dynamic>{
        'kind': dbKind,
        'sender_name': senderName,
        'avatar': avatar,
        'body': body,
        'is_important': isImportant,
      };
      if (groupId != null) payload['group_id'] = groupId;
      if (senderId != null) payload['sender_id'] = senderId;

      final row = await client
          .from('messages')
          .insert(payload)
          .select()
          .maybeSingle()
          .abortSignal(_disposeCompleter.future);
      if (row == null) return null;
      return CitizenMessage.fromSupabaseRow(
        Map<String, dynamic>.from(row),
        currentUserId: senderId,
      );
    } catch (e) {
      appLog('MAMO メッセージ送信エラー: $e');
      rethrow;
    }
  }

  @override
  Future<List<CitizenShelter>> fetchShelters() async {
    final client = _resolveClient();
    if (client == null) return const [];
    try {
      final rows = await client
          .from('shelters')
          .select()
          .order('id', ascending: true)
          .abortSignal(_disposeCompleter.future);
      return rows
          .map(
            (r) => CitizenShelter.fromSupabaseRow(Map<String, dynamic>.from(r)),
          )
          .toList();
    } catch (e) {
      appLog('MAMO 避難所取得エラー: $e');
      rethrow;
    }
  }

  @override
  Stream<List<CitizenShelter>> subscribeShelters() {
    final client = _resolveClient();
    if (client == null) return const Stream.empty();
    final prevChannel = _sheltersChannel;
    final prevController = _sheltersController;

    final controller = StreamController<List<CitizenShelter>>.broadcast();
    _sheltersController = controller;
    RealtimeChannel? channel;
    var cleanedPrev = false;

    try {
      channel = client.channel('mamo-shelters');
      _sheltersChannel = channel;
      if (prevChannel != null || prevController != null) {
        cleanedPrev = true;
        unawaited(
          _cleanupChannelResources(client, prevChannel, prevController),
        );
      }
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shelters',
            callback: (_) async {
              if (_disposed || controller.isClosed) return;
              try {
                final latest = await fetchShelters();
                if (!_disposed && !controller.isClosed) {
                  controller.add(latest);
                }
              } catch (e) {
                appLog('MAMO 避難所更新取得エラー: $e');
              }
            },
          )
          .subscribe();

      controller.onCancel = () {
        if (!_disposed &&
            !controller.hasListener &&
            identical(_sheltersController, controller)) {
          final ch = _sheltersChannel;
          _sheltersChannel = null;
          _sheltersController = null;
          unawaited(_cleanupChannelResources(client, ch, controller));
        }
      };
    } catch (e) {
      appLog('MAMO 避難所購読エラー: $e');
      if (identical(_sheltersChannel, channel)) _sheltersChannel = null;
      if (identical(_sheltersController, controller)) _sheltersController = null;
      unawaited(_cleanupChannelResources(client, channel, controller));
      if (!cleanedPrev && (prevChannel != null || prevController != null)) {
        unawaited(
          _cleanupChannelResources(client, prevChannel, prevController),
        );
      }
    }
    return controller.stream;
  }

  @override
  Future<List<CitizenHazardSpot>> fetchHazardSpots() async {
    final client = _resolveClient();
    if (client == null) return const [];
    try {
      final rows = await client
          .from('hazard_spots')
          .select()
          .eq('is_active', true)
          .order('id', ascending: true)
          .abortSignal(_disposeCompleter.future);
      return rows
          .map(
            (r) =>
                CitizenHazardSpot.fromSupabaseRow(Map<String, dynamic>.from(r)),
          )
          .toList();
    } catch (e) {
      appLog('MAMO 危険箇所取得エラー: $e');
      rethrow;
    }
  }

  Future<void> _cleanupChannelResources(
    SupabaseClient? client,
    RealtimeChannel? channel,
    StreamController<dynamic>? controller,
  ) async {
    if (channel != null) {
      try {
        final targetClient = client ?? _injectedClient ?? _ownedClient ?? _activeClient;
        if (targetClient != null) {
          await targetClient.removeChannel(channel);
        } else {
          await channel.unsubscribe();
        }
      } catch (e) {
        appLog('SupabaseCitizenDataSource channel cleanup error: $e');
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

    final controllers = <StreamController<dynamic>?>[
      _familyController,
      _messagesController,
      _sheltersController,
    ];
    _familyController = null;
    _messagesController = null;
    _sheltersController = null;
    for (final c in controllers) {
      if (c != null && !c.isClosed) {
        unawaited(c.close());
      }
    }

    final channels = <RealtimeChannel>[
      ?_familyChannel,
      ?_messagesChannel,
      ?_sheltersChannel,
    ];
    _familyChannel = null;
    _messagesChannel = null;
    _sheltersChannel = null;

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

    for (final channel in channels) {
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
        appLog('SupabaseCitizenDataSource channel cleanup error: $e');
      }
    }

    if (owned != null) {
      try {
        await owned.dispose();
      } catch (e) {
        appLog('SupabaseCitizenDataSource dispose error: $e');
      }
    }
  }
}
