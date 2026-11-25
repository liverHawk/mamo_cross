import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/citizen_models.dart';
import 'citizen_data_source.dart';

/// Supabase に対する利用者側データソース実装
class SupabaseCitizenDataSource implements CitizenDataSource {
  SupabaseCitizenDataSource({
    this.config = SupabaseConfig.fromEnvironment,
    SupabaseClient? client,
  }) : _injectedClient = client;

  final SupabaseConfig config;
  final SupabaseClient? _injectedClient;

  SupabaseClient? _ownedClient;
  RealtimeChannel? _familyChannel;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _sheltersChannel;
  bool _disposed = false;

  SupabaseClient? _resolveClient() {
    if (_disposed) return null;
    if (_injectedClient != null) return _injectedClient;
    if (!config.isConfigured) return null;
    try {
      if (config.url == SupabaseConfig.fromEnvironment.url &&
          config.publishableKey ==
              SupabaseConfig.fromEnvironment.publishableKey &&
          Supabase.instance.isInitialized) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return _ownedClient ??= SupabaseClient(
      config.url,
      config.publishableKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      realtimeClientOptions: const RealtimeClientOptions(
        connectionCloseTimeout: Duration.zero,
      ),
    );
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
          .maybeSingle();
      if (row == null) return null;
      final profile = CitizenRegistrationProfile.fromSupabaseRow(row);
      final rawSafety = (row['safety_status'] ?? 'safe').toString();
      final safety = CitizenSafetyStatus.values.firstWhere(
        (s) => s.name == rawSafety,
        orElse: () => CitizenSafetyStatus.safe,
      );
      return (profile: profile, safety: safety);
    } catch (e) {
      debugPrint('MAMO プロフィール取得エラー: $e');
      return null;
    }
  }

  @override
  Future<void> upsertProfile({
    required String userId,
    required CitizenRegistrationProfile profile,
    required CitizenSafetyStatus safetyStatus,
    String locationNote = '〇〇地区付近',
  }) async {
    final client = _resolveClient();
    if (client == null) return;
    try {
      await client.from('profiles').upsert(
            profile.toSupabaseUpsert(
              userId,
              safetyStatus: safetyStatus,
              locationNote: locationNote,
            ),
          );
    } catch (e) {
      debugPrint('MAMO プロフィール保存エラー: $e');
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
      await client.from('profiles').upsert(payload);
    } catch (e) {
      debugPrint('MAMO 安否更新エラー: $e');
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
          .limit(1);
      if (memberships.isNotEmpty) {
        final groupId = memberships.first['group_id']?.toString();
        if (groupId != null && groupId.isNotEmpty) {
          final groupRow = await client
              .from('family_groups')
              .select()
              .eq('id', groupId)
              .maybeSingle();
          if (groupRow != null) {
            return FamilyGroupInfo.fromSupabaseRow(groupRow);
          }
        }
      }

      final inviteCode = _generateInviteCode();
      final createdGroup = await client
          .from('family_groups')
          .insert(<String, dynamic>{
            'name': 'マイ家族グループ',
            'invite_code': inviteCode,
            'created_by': userId,
          })
          .select()
          .single();
      final groupInfo = FamilyGroupInfo.fromSupabaseRow(createdGroup);
      await client.from('family_members').upsert(<String, dynamic>{
        'group_id': groupInfo.id,
        'user_id': userId,
        'display_name': displayName.trim().isEmpty ? 'あなた' : displayName.trim(),
        'avatar': '🙂',
        'role': 'owner',
        'location_note': '〇〇地区付近',
      });
      return groupInfo;
    } catch (e) {
      debugPrint('MAMO 家族グループ取得/作成エラー: $e');
      return null;
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
      final groupId = await client.rpc<dynamic>(
        'join_family_group_by_code',
        params: <String, dynamic>{
          'p_invite_code': inviteCode.trim(),
          'p_display_name': displayName.trim().isEmpty ? 'あなた' : displayName.trim(),
        },
      );
      if (groupId == null) return null;
      final groupRow = await client
          .from('family_groups')
          .select()
          .eq('id', groupId.toString())
          .maybeSingle();
      if (groupRow == null) return null;
      return FamilyGroupInfo.fromSupabaseRow(groupRow);
    } catch (e) {
      debugPrint('MAMO 家族グループ参加エラー: $e');
      return null;
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
          .order('joined_at', ascending: true);
      return rows
          .map(
            (row) => FamilyMember.fromSupabaseRow(
              Map<String, dynamic>.from(row),
              currentUserId: currentUserId,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('MAMO 家族メンバー取得エラー: $e');
      return const [];
    }
  }

  @override
  Stream<List<FamilyMember>> subscribeFamilyMembers(
    String groupId, {
    String? currentUserId,
  }) {
    final client = _resolveClient();
    if (client == null) return const Stream.empty();
    final controller = StreamController<List<FamilyMember>>.broadcast();
    final prev = _familyChannel;
    if (prev != null) {
      unawaited(client.removeChannel(prev));
    }

    final channel = client.channel('mamo-family-$groupId');
    _familyChannel = channel;
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
            final latest = await fetchFamilyMembers(
              groupId,
              currentUserId: currentUserId,
            );
            if (!_disposed && !controller.isClosed) {
              controller.add(latest);
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      if (identical(_familyChannel, channel)) {
        _familyChannel = null;
        unawaited(client.removeChannel(channel));
      }
    };
    return controller.stream;
  }

  @override
  Future<List<CitizenMessage>> fetchMessages({
    String? groupId,
    String? currentUserId,
  }) async {
    final client = _resolveClient();
    if (client == null) return const [];
    try {
      final rows = await client
          .from('messages')
          .select()
          .order('created_at', ascending: true)
          .limit(100);
      return rows
          .map(
            (row) => CitizenMessage.fromSupabaseRow(
              Map<String, dynamic>.from(row),
              currentUserId: currentUserId,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('MAMO メッセージ取得エラー: $e');
      return const [];
    }
  }

  @override
  Stream<CitizenMessage> subscribeMessages({
    String? groupId,
    String? currentUserId,
  }) {
    final client = _resolveClient();
    if (client == null) return const Stream.empty();
    final controller = StreamController<CitizenMessage>.broadcast();
    final prev = _messagesChannel;
    if (prev != null) {
      unawaited(client.removeChannel(prev));
    }

    final channel = client.channel('mamo-messages-${groupId ?? 'public'}');
    _messagesChannel = channel;
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            if (_disposed || controller.isClosed) return;
            final row = Map<String, dynamic>.from(payload.newRecord);
            controller.add(
              CitizenMessage.fromSupabaseRow(
                row,
                currentUserId: currentUserId,
              ),
            );
          },
        )
        .subscribe();

    controller.onCancel = () {
      if (identical(_messagesChannel, channel)) {
        _messagesChannel = null;
        unawaited(client.removeChannel(channel));
      }
    };
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
          .maybeSingle();
      if (row == null) return null;
      return CitizenMessage.fromSupabaseRow(
        Map<String, dynamic>.from(row),
        currentUserId: senderId,
      );
    } catch (e) {
      debugPrint('MAMO メッセージ送信エラー: $e');
      return null;
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
          .order('id', ascending: true);
      return rows
          .map((r) => CitizenShelter.fromSupabaseRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('MAMO 避難所取得エラー: $e');
      return const [];
    }
  }

  @override
  Stream<List<CitizenShelter>> subscribeShelters() {
    final client = _resolveClient();
    if (client == null) return const Stream.empty();
    final controller = StreamController<List<CitizenShelter>>.broadcast();
    final prev = _sheltersChannel;
    if (prev != null) {
      unawaited(client.removeChannel(prev));
    }

    final channel = client.channel('mamo-shelters');
    _sheltersChannel = channel;
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shelters',
          callback: (_) async {
            if (_disposed || controller.isClosed) return;
            final latest = await fetchShelters();
            if (!_disposed && !controller.isClosed) {
              controller.add(latest);
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      if (identical(_sheltersChannel, channel)) {
        _sheltersChannel = null;
        unawaited(client.removeChannel(channel));
      }
    };
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
          .order('id', ascending: true);
      return rows
          .map((r) => CitizenHazardSpot.fromSupabaseRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('MAMO 危険箇所取得エラー: $e');
      return const [];
    }
  }

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final client = _injectedClient ?? _ownedClient;
    if (client != null) {
      if (_familyChannel != null) unawaited(client.removeChannel(_familyChannel!));
      if (_messagesChannel != null) unawaited(client.removeChannel(_messagesChannel!));
      if (_sheltersChannel != null) unawaited(client.removeChannel(_sheltersChannel!));
    }
    _familyChannel = null;
    _messagesChannel = null;
    _sheltersChannel = null;

    final owned = _ownedClient;
    _ownedClient = null;
    if (owned != null) {
      try {
        await owned.dispose();
      } catch (e) {
        debugPrint('SupabaseCitizenDataSource dispose error: $e');
      }
    }
  }
}
