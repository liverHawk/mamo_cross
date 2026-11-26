import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/config/supabase_config.dart';
import 'package:mamo_cross/main.dart';
import 'package:mamo_cross/models/citizen_models.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/pages/citizen/citizen_shell_page.dart';
import 'package:mamo_cross/services/auth_service.dart';
import 'package:mamo_cross/services/citizen_data_source.dart';
import 'package:mamo_cross/services/supabase_citizen_data_source.dart';
import 'package:mamo_cross/state/citizen_store.dart';
import 'package:mamo_cross/state/rescue_store.dart';
import 'package:mamo_cross/views/citizen/citizen_safety_tab.dart';
import 'package:material_ui/material_ui.dart';

class _MockAuthService implements AuthService {
  String? _userId;
  int signInCalls = 0;
  int signOutCalls = 0;
  bool returnNullOnSignIn = false;
  Completer<void>? signOutCompleter;
  final List<String> eventLog = <String>[];
  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();

  @override
  String? get currentUserId => _userId;

  @override
  bool get isAuthenticated => _userId != null;

  @override
  Stream<String?> get userIdChanges => _controller.stream;

  @override
  Future<String?> ensureAnonymousSession() async {
    signInCalls++;
    eventLog.add('signIn');
    if (returnNullOnSignIn) {
      return null;
    }
    _userId ??= 'anon-user-1';
    _controller.add(_userId);
    return _userId;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    eventLog.add('signOut_start');
    if (signOutCompleter != null) {
      await signOutCompleter!.future;
    }
    _userId = null;
    _controller.add(null);
    eventLog.add('signOut_end');
  }

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}

class _MockCitizenDataSource implements CitizenDataSource {
  final StreamController<List<FamilyMember>> familyController =
      StreamController<List<FamilyMember>>.broadcast();
  final StreamController<CitizenMessage> messageController =
      StreamController<CitizenMessage>.broadcast();
  final StreamController<List<CitizenShelter>> shelterController =
      StreamController<List<CitizenShelter>>.broadcast();

  ({CitizenRegistrationProfile profile, CitizenSafetyStatus safety})?
      storedProfile;
  final List<CitizenSafetyStatus> updatedSafetyHistory = [];
  final List<Map<String, dynamic>> sentMessages = [];
  final List<String> joinedCodes = [];

  Object? upsertProfileError;
  Future<void> Function(CitizenRegistrationProfile profile)? onUpsertProfile;
  Object? updateSafetyError;
  Object? sendMessageError;
  bool returnNullOnSendMessage = false;
  Object? joinGroupError;
  Object? fetchSheltersError;
  Completer<void>? defaultGroupCompleter;
  Completer<void>? fetchProfileCompleter;
  Object? fetchProfileError;
  Future<void> Function(String? groupId, String? currentUserId)? onFetchMessages;
  final List<String?> subscribeMessagesGroupIds = <String?>[];
  List<CitizenMessage> Function(String? groupId)? fetchMessagesResponder;

  FamilyGroupInfo defaultGroup = const FamilyGroupInfo(
    id: 'group-1',
    name: 'マイ家族グループ',
    inviteCode: 'MAMO99',
  );
  List<FamilyMember> membersToReturn = const [
    FamilyMember(
      id: 'fm-1',
      name: 'テスト太郎',
      avatar: '🙂',
      status: CitizenSafetyStatus.safe,
      isSelf: true,
      lastUpdated: '10:00',
    ),
  ];

  @override
  Future<({CitizenRegistrationProfile profile, CitizenSafetyStatus safety})?>
      fetchProfile(String userId) async {
    if (fetchProfileCompleter != null) {
      await fetchProfileCompleter!.future;
    }
    if (fetchProfileError != null) {
      throw fetchProfileError!;
    }
    return storedProfile;
  }

  @override
  Future<void> upsertProfile({
    required String userId,
    required CitizenRegistrationProfile profile,
    required CitizenSafetyStatus safetyStatus,
    String locationNote = '〇〇地区付近',
  }) async {
    if (onUpsertProfile != null) {
      await onUpsertProfile!(profile);
    }
    if (upsertProfileError != null) {
      throw upsertProfileError!;
    }
    storedProfile = (profile: profile, safety: safetyStatus);
  }

  @override
  Future<void> updateSafetyStatus({
    required String userId,
    required CitizenSafetyStatus status,
    String? locationNote,
  }) async {
    if (updateSafetyError != null) {
      throw updateSafetyError!;
    }
    updatedSafetyHistory.add(status);
  }

  @override
  Future<FamilyGroupInfo?> fetchOrCreateDefaultFamilyGroup({
    required String userId,
    required String displayName,
  }) async {
    if (defaultGroupCompleter != null) {
      await defaultGroupCompleter!.future;
    }
    return defaultGroup;
  }

  @override
  Future<FamilyGroupInfo?> joinFamilyGroupByCode({
    required String inviteCode,
    required String displayName,
  }) async {
    joinedCodes.add(inviteCode);
    if (joinGroupError != null) {
      throw joinGroupError!;
    }
    if (inviteCode == 'JOIN77') {
      return const FamilyGroupInfo(
        id: 'group-2',
        name: '招待された家族',
        inviteCode: 'JOIN77',
      );
    }
    return null;
  }

  @override
  Future<List<FamilyMember>> fetchFamilyMembers(
    String groupId, {
    String? currentUserId,
  }) async {
    return membersToReturn;
  }

  @override
  Stream<List<FamilyMember>> subscribeFamilyMembers(
    String groupId, {
    String? currentUserId,
  }) =>
      familyController.stream;

  @override
  Future<List<CitizenMessage>> fetchMessages({
    String? groupId,
    String? currentUserId,
  }) async {
    if (onFetchMessages != null) {
      await onFetchMessages!(groupId, currentUserId);
    }
    if (fetchMessagesResponder != null) {
      return fetchMessagesResponder!(groupId);
    }
    return const [
      CitizenMessage(
        id: 'notice-db-1',
        kind: CitizenMessageKind.municipalityNotice,
        sender: '山口県 災害対策本部',
        avatar: '🏛️',
        body: 'DBからの避難情報テスト',
        time: '09:30',
        isImportant: true,
      ),
    ];
  }

  @override
  Stream<CitizenMessage> subscribeMessages({
    String? groupId,
    String? currentUserId,
  }) {
    subscribeMessagesGroupIds.add(groupId);
    return messageController.stream;
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
    if (sendMessageError != null) {
      throw sendMessageError!;
    }
    if (returnNullOnSendMessage) {
      return null;
    }
    sentMessages.add({
      'kind': kind,
      'senderName': senderName,
      'body': body,
      'groupId': groupId,
      'senderId': senderId,
    });
    return CitizenMessage(
      id: 'db-msg-${sentMessages.length}',
      kind: kind,
      sender: senderName,
      avatar: avatar,
      body: body,
      time: '09:35',
      isMine: true,
    );
  }

  @override
  Future<List<CitizenShelter>> fetchShelters() async {
    if (fetchSheltersError != null) {
      throw fetchSheltersError!;
    }
    return const [
      CitizenShelter(
        id: 'shelter-db-1',
        name: 'DB避難所A',
        distanceText: '100m先',
        statusText: '開設中',
        isOpen: true,
        address: '山口市1-1',
        capacity: 200,
        occupied: 40,
        facilities: ['給水'],
        xPercent: 0.4,
        yPercent: 0.6,
      ),
    ];
  }

  @override
  Stream<List<CitizenShelter>> subscribeShelters() => shelterController.stream;

  @override
  Future<List<CitizenHazardSpot>> fetchHazardSpots() async {
    return const [
      CitizenHazardSpot(
        id: 'hazard-db-1',
        title: 'DB危険箇所',
        description: '通行止め',
        xPercent: 0.3,
        yPercent: 0.7,
      ),
    ];
  }

  @override
  Future<void> dispose() async {
    await familyController.close();
    await messageController.close();
    await shelterController.close();
  }
}

void main() {
  test('Supabase model mappers parse coordinates, profile, family, and messages', () {
    final rescue = RescueRequest.fromSupabaseRow({
      'id': 42,
      'request_id': 'MAMO-42',
      'requester_name': '山田花子',
      'assigned_agency': '消防',
      'request_type': '救急',
      'lat_percent': 32.5,
      'top_percent': 71.0,
      'status': '対応中',
    });
    expect(rescue.agency, AgencyType.fire);
    expect(rescue.latPercent, 32.5);
    expect(rescue.topPercent, 71.0);
    expect(rescue.status, RequestStatus.working);

    final profile = CitizenRegistrationProfile.fromSupabaseRow({
      'display_name': '佐藤一郎',
      'blood_type': 'A型',
      'considerations': ['🟢 オストメイト'],
      'other_consideration': '階段移動が困難',
    });
    expect(profile.effectiveDisplayName, '佐藤一郎');
    expect(profile.bloodType, 'A型');
    expect(profile.considerations, contains('🟢 オストメイト'));
    expect(profile.otherConsideration, '階段移動が困難');

    final member = FamilyMember.fromSupabaseRow(
      {
        'id': 'm-1',
        'user_id': 'uid-1',
        'display_name': 'お母さん',
        'safety_status': 'damaged',
        'location_note': '小学校',
      },
      currentUserId: 'uid-1',
    );
    expect(member.isSelf, isTrue);
    expect(member.status, CitizenSafetyStatus.damaged);
    expect(member.locationNote, '小学校');
  });

  test('CitizenStore syncs auth, profile, safety, family, messages, and shelters', () async {
    final auth = _MockAuthService();
    final ds = _MockCitizenDataSource();
    final store = CitizenStore(
      dataSource: ds,
      authService: auth,
      autoInitialize: false,
    );
    addTearDown(store.dispose);

    await store.initializeRemote();
    expect(store.shelters.first.name, 'DB避難所A');
    expect(store.hazardSpots.first.title, 'DB危険箇所');
    expect(store.municipalityNotices.first.body, 'DBからの避難情報テスト');

    store.updateBasicInfo(name: '山口太郎');
    store.completeRegistration();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(auth.signInCalls, 1);
    expect(ds.storedProfile?.profile.name, '山口太郎');
    expect(store.familyInviteCode, 'MAMO99');
    expect(store.familyMembers.first.name, 'テスト太郎');

    store.updateMySafety(CitizenSafetyStatus.damaged);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(ds.updatedSafetyHistory, contains(CitizenSafetyStatus.damaged));

    store.sendMessage('無事です', kind: CitizenMessageKind.familyThread);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(ds.sentMessages, hasLength(1));
    expect(ds.sentMessages.first['groupId'], 'group-1');

    final joined = await store.joinFamilyGroup('join77');
    expect(joined, isTrue);
    expect(store.familyInviteCode, 'JOIN77');
  });

  group('initializeSupabaseSafely resilience', () {
    test('skips empty config, catches exceptions, and guards against timeout', () async {
      var called = false;
      await initializeSupabaseSafely(
        config: SupabaseConfig.empty,
        initializer: (_) async {
          called = true;
        },
      );
      expect(called, isFalse);

      await expectLater(
        initializeSupabaseSafely(
          config: const SupabaseConfig(
            url: 'https://example.supabase.co',
            publishableKey: 'sb_publishable_test',
          ),
          initializer: (_) async => throw StateError('init failed'),
        ),
        completes,
      );

      final neverCompletes = Completer<void>();
      await expectLater(
        initializeSupabaseSafely(
          config: const SupabaseConfig(
            url: 'https://example.supabase.co',
            publishableKey: 'sb_publishable_test',
          ),
          timeout: const Duration(milliseconds: 20),
          initializer: (_) => neverCompletes.future,
        ),
        completes,
      );
    });
  });

  group('CitizenStore auth serialization, rollback & error handling', () {
    test('initializeRemote tolerates partial fetch failure', () async {
      final auth = _MockAuthService();
      final ds = _MockCitizenDataSource()
        ..fetchSheltersError = StateError('shelters unavailable');
      final store = CitizenStore(
        dataSource: ds,
        authService: auth,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      await store.initializeRemote();
      // 避難所取得が失敗しても初期データ保持・他データ（危険箇所・お知らせ）は取得される
      expect(store.shelters.first.name, kInitialCitizenShelters.first.name);
      expect(store.hazardSpots.first.title, 'DB危険箇所');
      expect(store.municipalityNotices.first.body, 'DBからの避難情報テスト');
    });

    test('logout and resetDemo signOut, cancel subscriptions, clear state, and serialize re-login', () async {
      final auth = _MockAuthService();
      final ds = _MockCitizenDataSource();
      final store = CitizenStore(
        dataSource: ds,
        authService: auth,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      store.updateBasicInfo(name: 'テスト利用者');
      store.completeRegistration();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.familyInviteCode, 'MAMO99');

      // logout() 実行時、signOut 完了前に demoLogin() を呼んでも signOut -> signIn の順に直列化される
      auth.signOutCompleter = Completer<void>();
      store.logout();
      expect(store.isLoggedIn, isFalse);
      expect(store.familyInviteCode, isNull);
      expect(store.registeredName, 'あなた');
      expect(store.familyMembers, hasLength(4));

      // 旧購読が解除されているため、familyController へのイベント投入で上書きされない
      ds.familyController.add(const [
        FamilyMember(
          id: 'stale',
          name: '古いデータ',
          avatar: '👩',
          status: CitizenSafetyStatus.damaged,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(store.familyMembers.any((m) => m.id == 'stale'), isFalse);

      store.demoLogin(delay: Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(auth.eventLog, ['signIn', 'signOut_start']);

      auth.signOutCompleter!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        auth.eventLog,
        ['signIn', 'signOut_start', 'signOut_end', 'signIn'],
      );

      // resetDemo() も同様に signOut() と購読解除を実行する
      auth.signOutCompleter = null;
      store.resetDemo();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(auth.signOutCalls, 2);
      expect(store.isLoggedIn, isFalse);
      expect(store.familyInviteCode, isNull);
    });

    test('saveProfileEdits syncs to DB and rolls back on failure', () async {
      final auth = _MockAuthService();
      final ds = _MockCitizenDataSource();
      final store = CitizenStore(
        dataSource: ds,
        authService: auth,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      store.updateBasicInfo(name: '初期太郎', addressDetail: '山口市1-1');
      store.completeRegistration();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ok = await store.saveProfileEdits(
        name: '変更太郎',
        addressDetail: '山口市2-2',
      );
      expect(ok, isTrue);
      expect(ds.storedProfile?.profile.name, '変更太郎');
      expect(ds.storedProfile?.profile.addressDetail, '山口市2-2');
      expect(store.toastMessage, '登録情報を保存しました');

      ds.upsertProfileError = StateError('db error');
      final failed = await store.saveProfileEdits(
        name: '失敗名',
        addressDetail: '失敗住所',
      );
      expect(failed, isFalse);
      expect(store.profile.name, '変更太郎');
      expect(store.profile.addressDetail, '山口市2-2');
      expect(store.toastMessage, '登録情報の保存に失敗しました');
    });

    test('updateMySafety establishes session if needed and rolls back on error', () async {
      final auth = _MockAuthService();
      final ds = _MockCitizenDataSource();
      final store = CitizenStore(
        dataSource: ds,
        authService: auth,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      // 未認証状態でも ensureAnonymousSession() を経て DB 同期される
      expect(auth.currentUserId, isNull);
      store.updateMySafety(CitizenSafetyStatus.damaged);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(auth.signInCalls, 1);
      expect(ds.updatedSafetyHistory, [CitizenSafetyStatus.damaged]);

      // DB 失敗時は直前ステータスへロールバック
      ds.updateSafetyError = StateError('update failed');
      store.updateMySafety(CitizenSafetyStatus.safe);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.mySafety, CitizenSafetyStatus.damaged);
      expect(
        store.familyMembers.firstWhere((m) => m.isSelf).status,
        CitizenSafetyStatus.damaged,
      );
      expect(store.toastMessage, '安否ステータスの更新に失敗しました');
    });

    test('sendMessage rolls back optimistic item on failure and deduplicates Realtime delivery', () async {
      final auth = _MockAuthService();
      final ds = _MockCitizenDataSource();
      final store = CitizenStore(
        dataSource: ds,
        authService: auth,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      store.completeRegistration();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final initialCount = store.familyMessages.length;

      // 失敗時は楽観追加メッセージが削除され失敗トーストが出る
      ds.sendMessageError = StateError('network error');
      store.sendMessage('失敗テスト');
      expect(store.familyMessages.length, initialCount + 1);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.familyMessages.length, initialCount);
      expect(store.toastMessage, 'メッセージの送信に失敗しました');

      // 成功時・Realtime 重複到着時も重複しない
      ds.sendMessageError = null;
      store.sendMessage('成功テスト');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.familyMessages.length, initialCount + 1);
      expect(store.familyMessages.last.id, 'db-msg-1');
      expect(store.toastMessage, 'メッセージを送信しました');

      ds.messageController.add(const CitizenMessage(
        id: 'db-msg-1',
        kind: CitizenMessageKind.familyThread,
        sender: 'あなた',
        avatar: '🙂',
        body: '成功テスト',
        time: '09:35',
        isMine: true,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(store.familyMessages.length, initialCount + 1);
    });

    test('joinFamilyGroup distinguishes not-found vs communication error', () async {
      final auth = _MockAuthService();
      final ds = _MockCitizenDataSource();
      final store = CitizenStore(
        dataSource: ds,
        authService: auth,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      final notFound = await store.joinFamilyGroup('NONE00');
      expect(notFound, isFalse);
      expect(store.toastMessage, '招待コードが見つかりませんでした');

      ds.joinGroupError = StateError('timeout');
      final errored = await store.joinFamilyGroup('JOIN77');
      expect(errored, isFalse);
      expect(
        store.toastMessage,
        '家族グループへの参加に失敗しました（通信状況をご確認ください）',
      );
    });

    test(
      'updateMySafety rolls back to last synced status rather than skipped intermediate status on rapid taps',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        // 初期確定状態 safe から、DB 失敗中に damaged -> rescueNeeded を連打
        ds.updateSafetyError = StateError('network error');
        store.updateMySafety(CitizenSafetyStatus.damaged);
        store.updateMySafety(CitizenSafetyStatus.rescueNeeded);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(store.mySafety, CitizenSafetyStatus.safe);
        expect(
          store.familyMembers.firstWhere((m) => m.isSelf).status,
          CitizenSafetyStatus.safe,
        );
        expect(store.toastMessage, '安否ステータスの更新に失敗しました');

        // 1回目 damaged が成功確定した後の連打失敗では、確定済み damaged に戻る
        ds.updateSafetyError = null;
        store.updateMySafety(CitizenSafetyStatus.damaged);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(store.mySafety, CitizenSafetyStatus.damaged);

        ds.updateSafetyError = StateError('network error');
        store.updateMySafety(CitizenSafetyStatus.rescueNeeded);
        store.updateMySafety(CitizenSafetyStatus.safe);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(store.mySafety, CitizenSafetyStatus.damaged);
        expect(
          store.familyMembers.firstWhere((m) => m.isSelf).status,
          CitizenSafetyStatus.damaged,
        );
      },
    );

    test(
      'saveProfileEdits preserves snapshot per request and avoids stale rollback overwriting newer edits',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.updateBasicInfo(name: '初期太郎');
        store.completeRegistration();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // 1) f1 (失敗) + f2 (成功) の並列実行 → f2 が DB・store 双方に残る
        final upsertedNames = <String>[];
        ds.onUpsertProfile = (profile) async {
          if (profile.name == '名前1') {
            throw StateError('first edit failed');
          }
          upsertedNames.add(profile.name);
        };

        final f1 = store.saveProfileEdits(name: '名前1');
        final f2 = store.saveProfileEdits(name: '名前2');
        final results = await Future.wait([f1, f2]);

        expect(results, [false, true]);
        expect(upsertedNames, ['名前2']);
        expect(ds.storedProfile?.profile.name, '名前2');
        expect(store.profile.name, '名前2');
        expect(store.toastMessage, '登録情報を保存しました');

        // 2) f3 (成功) + f4 (失敗) の並列実行 → f3 が確定した値 '名前3' へ戻る
        ds.onUpsertProfile = (profile) async {
          if (profile.name == '名前4') {
            throw StateError('second edit failed');
          }
        };
        final f3 = store.saveProfileEdits(name: '名前3');
        final f4 = store.saveProfileEdits(name: '名前4');
        final results2 = await Future.wait([f3, f4]);

        expect(results2, [true, false]);
        expect(ds.storedProfile?.profile.name, '名前3');
        expect(store.profile.name, '名前3');
        expect(store.toastMessage, '登録情報の保存に失敗しました');
      },
    );

    test(
      'logout and resetDemo notify listeners when async message resubscription updates messages',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.completeRegistration();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        var notifyCountAfterLogout = 0;
        var listening = false;
        store.addListener(() {
          if (listening) {
            notifyCountAfterLogout++;
          }
        });

        auth.signOutCompleter = Completer<void>();
        store.logout();
        // logout 直後は同期的にデモメッセージ 5 件へリセットされている
        expect(store.messages, hasLength(5));

        listening = true;
        auth.signOutCompleter!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(notifyCountAfterLogout, greaterThan(0));
        expect(store.messages, hasLength(1));
        expect(store.messages.single.id, 'notice-db-1');

        // resetDemo でも同様に非同期再購読後に通知・更新される
        listening = false;
        auth.signOutCompleter = Completer<void>();
        store.resetDemo();
        expect(store.messages, hasLength(5));
        notifyCountAfterLogout = 0;
        listening = true;
        auth.signOutCompleter!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(notifyCountAfterLogout, greaterThan(0));
        expect(store.messages, hasLength(1));
        expect(store.messages.single.id, 'notice-db-1');
      },
    );

    test(
      'offline CitizenStore (SupabaseConfig.empty + real SupabaseAuthService) logout and resetDemo complete without LateInitializationError',
      () async {
        final originalDebugPrint = debugPrint;
        final loggedMessages = <String>[];
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) {
            loggedMessages.add(message);
          }
        };
        addTearDown(() => debugPrint = originalDebugPrint);

        final ds = SupabaseCitizenDataSource(config: SupabaseConfig.empty);
        final auth = SupabaseAuthService(clientResolver: () => ds.sharedClient);
        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.demoLogin(delay: Duration.zero);
        await pumpEventQueue(times: 20);
        expect(store.isLoggedIn, isTrue);

        store.logout();
        await pumpEventQueue(times: 20);

        store.resetDemo();
        await pumpEventQueue(times: 20);

        expect(store.isLoggedIn, isFalse);
        expect(store.currentScreen, CitizenScreen.login);
        expect(
          loggedMessages.where(
            (m) =>
                m.contains('LateInitializationError') ||
                m.contains('サインアウトエラー'),
          ),
          isEmpty,
        );

        // 再ログインも阻害されずに正常完了すること
        store.demoLogin(delay: Duration.zero);
        await pumpEventQueue(times: 20);
        expect(store.isLoggedIn, isTrue);
        expect(store.currentScreen, CitizenScreen.home);
      },
    );

    test(
      'CitizenStore.initializeRemote and auth-dependent actions survive throwing clientResolver without crashing',
      () async {
        final originalDebugPrint = debugPrint;
        final loggedMessages = <String>[];
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) {
            loggedMessages.add(message);
          }
        };
        addTearDown(() => debugPrint = originalDebugPrint);

        final ds = _MockCitizenDataSource();
        final auth = SupabaseAuthService(
          clientResolver: () => throw StateError('resolver crash'),
        );
        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(() {
          store.dispose();
          auth.dispose();
        });

        expect(auth.currentUserId, isNull);
        expect(auth.isAuthenticated, isFalse);

        await expectLater(store.initializeRemote(), completes);
        expect(store.shelters.first.name, 'DB避難所A');
        expect(store.hazardSpots.first.title, 'DB危険箇所');
        expect(store.municipalityNotices.first.body, 'DBからの避難情報テスト');

        expect(await store.saveProfileEdits(name: 'テスト'), isFalse);
        store.updateMySafety(CitizenSafetyStatus.damaged);
        await pumpEventQueue(times: 20);
        expect(await store.joinFamilyGroup('JOIN77'), isFalse);
        store.sendMessage('テスト送信');
        await pumpEventQueue(times: 20);

        expect(
          loggedMessages.any((m) => m.contains('MAMO 認証クライアント解決エラー')),
          isTrue,
        );
      },
    );
  });

  group('RescueStore.applyRemoteUpdate', () {
    test('updates assigned_agency, lat_percent, and top_percent', () {
      final store = RescueStore(startClock: false);
      addTearDown(store.dispose);

      store.addDbRequest(<String, dynamic>{
        'id': 501,
        'request_id': 'MAMO-501',
        'requester_name': 'テスト太郎',
        'request_type': '救急',
        'lat_percent': 50.0,
        'top_percent': 50.0,
        'status': '未対応',
      });

      store.applyRemoteUpdate(<String, dynamic>{
        'id': 501,
        'assigned_agency': '自衛隊',
        'request_type': '救急',
        'lat_percent': 24.5,
        'top_percent': 68.0,
        'status': '対応中',
      });

      final updated = store.requests.single;
      expect(updated.agency, AgencyType.sdf);
      expect(updated.latPercent, 24.5);
      expect(updated.topPercent, 68.0);
      expect(updated.status, RequestStatus.working);
    });
  });

  group('CitizenSafetyTab _FamilyGroupCard widget tests', () {
    testWidgets('shows unauth/logged-in guides, enforces maxLength 6, and joins on submit', (tester) async {
      final auth = _MockAuthService();
      final ds = _MockCitizenDataSource();
      final store = CitizenStore(
        dataSource: ds,
        authService: auth,
        autoInitialize: false,
      );
      addTearDown(() async {
        store.dispose();
        await tester.pump(const Duration(seconds: 3));
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitizenSafetyTab(store: store),
          ),
        ),
      );

      // 未ログイン・未取得時の案内
      expect(find.text('ログイン・登録後に招待コードが発行されます'), findsOneWidget);

      // ログイン済み・招待コード未取得時の案内（グループ取得完了前）
      ds.defaultGroupCompleter = Completer<void>();
      store.demoLogin(delay: Duration.zero);
      await tester.pump();
      expect(find.text('招待コードを取得中または未発行です'), findsOneWidget);
      ds.defaultGroupCompleter!.complete();
      ds.defaultGroupCompleter = null;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('招待コード: MAMO99'), findsOneWidget);

      // TextField maxLength=6 & onSubmitted 連携
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.maxLength, 6);
      expect(textField.textInputAction, TextInputAction.done);

      await tester.enterText(textFieldFinder, 'join77');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();

      expect(ds.joinedCodes, contains('JOIN77'));
      expect(store.familyInviteCode, 'JOIN77');
      expect(find.text('招待コード: JOIN77'), findsOneWidget);
      expect(find.text('参加'), findsOneWidget);
      expect(tester.widget<TextField>(textFieldFinder).controller?.text, isEmpty);

      // トーストタイマー消化
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Challenge 1 regression tests (fetchProfile vs local profile edit races)', () {
    test(
      'Regression 1 (Probe 4A): saveProfileEdits during delayed fetchProfile preserves untouched DB fields, syncs UI, and updates openRescue draft',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        ds.storedProfile = (
          profile: CitizenRegistrationProfile(
            name: 'DB旧ユーザー',
            birthDate: '1985-04-01',
            bloodType: 'B型',
            gender: '男性',
            postalCode: '753-0001',
            prefecture: '山口県',
            addressDetail: '山口市旧1-1',
            considerations: Set<String>.unmodifiable(
              const <String>{'🩺 医療的ケアが必要'},
            ),
            otherConsideration: '持病あり',
          ),
          safety: CitizenSafetyStatus.safe,
        );
        ds.fetchProfileCompleter = Completer<void>();

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.demoLogin(delay: Duration.zero);
        final saveFuture = store.saveProfileEdits(
          name: '最新 太郎',
          addressDetail: '山口県山口市新規2-2',
        );
        await pumpEventQueue();
        ds.fetchProfileCompleter!.complete();
        expect(await saveFuture, isTrue);

        expect(ds.storedProfile?.profile.name, '最新 太郎');
        expect(store.profile.name, '最新 太郎');
        expect(
          ds.storedProfile?.profile.addressDetail,
          '山口県山口市新規2-2',
        );
        expect(store.profile.addressDetail, '山口県山口市新規2-2');
        expect(ds.storedProfile?.profile.birthDate, '1985-04-01');
        expect(ds.storedProfile?.profile.bloodType, 'B型');
        expect(ds.storedProfile?.profile.gender, '男性');
        expect(
          ds.storedProfile?.profile.considerations,
          const <String>{'🩺 医療的ケアが必要'},
        );
        expect(ds.storedProfile?.profile.otherConsideration, '持病あり');

        store.openRescue();
        expect(store.rescueNameDraft, '最新 太郎');
        expect(store.rescueCareDraft, '🩺 医療的ケアが必要、持病あり');
      },
    );

    test(
      'Regression 2 (Probe 4A rollback): failed saveProfileEdits after delayed fetchProfile rolls back to fetched DB profile',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        ds.storedProfile = (
          profile: const CitizenRegistrationProfile(
            name: 'DB旧ユーザー',
            birthDate: '1985-04-01',
            bloodType: 'B型',
          ),
          safety: CitizenSafetyStatus.safe,
        );
        ds.fetchProfileCompleter = Completer<void>();
        ds.upsertProfileError = StateError('save failed');

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.demoLogin(delay: Duration.zero);
        final saveFuture = store.saveProfileEdits(name: '失敗名');
        await pumpEventQueue();
        ds.fetchProfileCompleter!.complete();

        expect(await saveFuture, isFalse);
        expect(store.profile.name, 'DB旧ユーザー');
        expect(store.profile.birthDate, '1985-04-01');
        expect(store.toastMessage, '登録情報の保存に失敗しました');
      },
    );

    test(
      'Regression 3 (Probe 4B): updateBasicInfo, toggleConsideration, updateOtherConsideration, and completeRegistration survive delayed fetchProfile',
      () async {
        // Case A: 編集中のローカル項目を保持しつつ未編集項目を DB 値で補完
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        ds.storedProfile = (
          profile: CitizenRegistrationProfile(
            name: '旧サーバー名',
            birthDate: '1980-01-01',
            bloodType: 'A型',
            considerations: Set<String>.unmodifiable(
              <String>{kCitizenConsiderationOptions[4]},
            ),
            otherConsideration: '旧メモ',
          ),
          safety: CitizenSafetyStatus.safe,
        );
        ds.fetchProfileCompleter = Completer<void>();

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.demoLogin(delay: Duration.zero);
        store.updateBasicInfo(name: '新ユーザー', bloodType: 'O型');
        store.toggleConsideration(kCitizenConsiderationOptions[2]);
        store.updateOtherConsideration('新規配慮');
        ds.fetchProfileCompleter!.complete();
        await pumpEventQueue(times: 20);

        expect(store.profile.name, '新ユーザー');
        expect(store.profile.bloodType, 'O型');
        expect(
          store.profile.considerations,
          <String>{kCitizenConsiderationOptions[2]},
        );
        expect(store.profile.otherConsideration, '新規配慮');
        expect(store.profile.birthDate, '1980-01-01');

        // Case B: fetchProfile 完了前に completeRegistration を実行しても旧値で上書きされない
        final auth2 = _MockAuthService();
        final ds2 = _MockCitizenDataSource();
        ds2.storedProfile = ds.storedProfile;
        ds2.fetchProfileCompleter = Completer<void>();

        final store2 = CitizenStore(
          dataSource: ds2,
          authService: auth2,
          autoInitialize: false,
        );
        addTearDown(store2.dispose);

        store2.demoLogin(delay: Duration.zero);
        store2.updateBasicInfo(name: '登録完了太郎', bloodType: 'AB型');
        store2.completeRegistration();
        ds2.fetchProfileCompleter!.complete();
        await pumpEventQueue(times: 20);

        expect(ds2.storedProfile?.profile.name, '登録完了太郎');
        expect(ds2.storedProfile?.profile.bloodType, 'AB型');
        expect(store2.profile.name, '登録完了太郎');
      },
    );

    test(
      'Regression 4: handles null/error fetchProfile before saveProfileEdits and aborts cleanly on resetDemo',
      () async {
        // 1) storedProfile == null
        final auth1 = _MockAuthService();
        final ds1 = _MockCitizenDataSource();
        ds1.fetchProfileCompleter = Completer<void>();
        final store1 = CitizenStore(
          dataSource: ds1,
          authService: auth1,
          autoInitialize: false,
        );
        addTearDown(store1.dispose);

        store1.demoLogin(delay: Duration.zero);
        final f1 = store1.saveProfileEdits(name: '新規太郎');
        await pumpEventQueue();
        ds1.fetchProfileCompleter!.complete();
        expect(await f1, isTrue);
        expect(ds1.storedProfile?.profile.name, '新規太郎');
        expect(store1.profile.name, '新規太郎');

        // 2) fetchProfile throws error
        final auth2 = _MockAuthService();
        final ds2 = _MockCitizenDataSource();
        ds2.fetchProfileCompleter = Completer<void>();
        ds2.fetchProfileError = StateError('network');
        final store2 = CitizenStore(
          dataSource: ds2,
          authService: auth2,
          autoInitialize: false,
        );
        addTearDown(store2.dispose);

        store2.demoLogin(delay: Duration.zero);
        final f2 = store2.saveProfileEdits(name: '復旧太郎');
        await pumpEventQueue();
        ds2.fetchProfileCompleter!.complete();
        expect(await f2, isTrue);
        expect(ds2.storedProfile?.profile.name, '復旧太郎');
        expect(store2.profile.name, '復旧太郎');

        // 3) immediate resetDemo cancels in-flight saveProfileEdits via _authRevision
        final auth3 = _MockAuthService();
        final ds3 = _MockCitizenDataSource();
        ds3.fetchProfileCompleter = Completer<void>();
        final store3 = CitizenStore(
          dataSource: ds3,
          authService: auth3,
          autoInitialize: false,
        );
        addTearDown(store3.dispose);

        store3.demoLogin(delay: Duration.zero);
        final f3 = store3.saveProfileEdits(name: '破棄予定');
        store3.resetDemo();
        ds3.fetchProfileCompleter!.complete();
        expect(await f3, isFalse);
        expect(store3.isLoggedIn, isFalse);
        expect(store3.registeredName, 'あなた');
        expect(ds3.storedProfile?.profile.name, isNot('破棄予定'));
      },
    );

    testWidgets(
      'Regression 5 (UI flow): CitizenSettingsTab partial edit during delayed fetchProfile preserves address and birthDate through CitizenRescueView',
      (tester) async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        ds.storedProfile = (
          profile: const CitizenRegistrationProfile(
            name: 'DB旧ユーザー',
            birthDate: '1985-04-01',
            addressDetail: '山口市旧住所',
          ),
          safety: CitizenSafetyStatus.safe,
        );
        ds.fetchProfileCompleter = Completer<void>();

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        final rescueStore = RescueStore(startClock: false);
        addTearDown(() async {
          store.dispose();
          rescueStore.dispose();
          await tester.pump(const Duration(seconds: 3));
        });

        await tester.pumpWidget(
          MaterialApp(
            home: CitizenShellPage(
              citizenStore: store,
              rescueStore: rescueStore,
            ),
          ),
        );

        store.demoLogin(delay: Duration.zero);
        await tester.pump();

        await tester.tap(find.text('設定'));
        await tester.pump();
        await tester.tap(find.text('編集'));
        await tester.pump();

        // お名前のみ編集（住所欄は未変更のまま）
        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.at(0), '最新 太郎');
        await tester.pump();
        await tester.tap(find.text('保存'));
        await tester.pump();

        ds.fetchProfileCompleter!.complete();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();

        expect(find.text('最新 太郎'), findsOneWidget);
        expect(find.text('山口市旧住所'), findsOneWidget);
        expect(find.text('1985-04-01'), findsOneWidget);
        expect(ds.storedProfile?.profile.name, '最新 太郎');
        expect(ds.storedProfile?.profile.addressDetail, '山口市旧住所');
        expect(ds.storedProfile?.profile.birthDate, '1985-04-01');

        // ホーム -> 救助要請画面でも最新名が引き継がれること
        await tester.tap(find.text('ホーム'));
        await tester.pump();
        await tester.tap(find.text('救助要請'));
        await tester.pump();

        final rescueNameField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(rescueNameField.controller?.text, '最新 太郎');

        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Regression 6 (UI sync): CitizenReg2View and CitizenReg3View sync untouched TextFields when delayed fetchProfile completes',
      (tester) async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        ds.storedProfile = (
          profile: CitizenRegistrationProfile(
            name: 'DB太郎',
            birthDate: '1985-04-01',
            bloodType: 'B型',
            gender: '男性',
            postalCode: '753-0001',
            prefecture: '山口県',
            addressDetail: '山口市1-2-3',
            considerations: Set<String>.unmodifiable(
              <String>{kCitizenConsiderationOptions[1]},
            ),
            otherConsideration: '喘息あり',
          ),
          safety: CitizenSafetyStatus.safe,
        );
        ds.fetchProfileCompleter = Completer<void>();

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        final rescueStore = RescueStore(startClock: false);
        addTearDown(() async {
          store.dispose();
          rescueStore.dispose();
          await tester.pump(const Duration(seconds: 3));
        });

        await tester.pumpWidget(
          MaterialApp(
            home: CitizenShellPage(
              citizenStore: store,
              rescueStore: rescueStore,
            ),
          ),
        );

        store.demoLogin(delay: Duration.zero);
        store.goToScreen(CitizenScreen.reg2);
        await tester.pump();

        // reg2 で名前のみローカル入力した状態で fetchProfile が後着完了する
        final reg2Fields = find.byType(TextField);
        expect(reg2Fields, findsNWidgets(4));
        await tester.enterText(reg2Fields.at(0), '入力中ユーザー');
        await tester.pump();

        ds.fetchProfileCompleter!.complete();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();

        // 入力中の名前は維持され、未編集の TextField と Dropdown/Radio が DB 値へ追従する
        expect(
          tester.widget<TextField>(reg2Fields.at(0)).controller?.text,
          '入力中ユーザー',
        );
        expect(
          tester.widget<TextField>(reg2Fields.at(1)).controller?.text,
          '1985-04-01',
        );
        expect(
          tester.widget<TextField>(reg2Fields.at(2)).controller?.text,
          '753-0001',
        );
        expect(
          tester.widget<TextField>(reg2Fields.at(3)).controller?.text,
          '山口市1-2-3',
        );
        expect(find.text('B型'), findsOneWidget);
        expect(find.text('山口県'), findsOneWidget);

        // #reg3 を表示した状態で外部同期（fetchProfile 相当）が後着しても未編集のその他欄が追従する
        final ds3 = _MockCitizenDataSource();
        ds3.storedProfile = ds.storedProfile;
        ds3.fetchProfileCompleter = Completer<void>();
        final auth3 = _MockAuthService();
        final store3 = CitizenStore(
          dataSource: ds3,
          authService: auth3,
          autoInitialize: false,
        );
        addTearDown(store3.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: CitizenShellPage(
              citizenStore: store3,
              rescueStore: rescueStore,
            ),
          ),
        );

        store3.demoLogin(delay: Duration.zero);
        store3.goToScreen(CitizenScreen.reg3);
        await tester.pump();

        ds3.fetchProfileCompleter!.complete();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();

        final reg3OtherField = tester.widget<TextField>(find.byType(TextField));
        expect(reg3OtherField.controller?.text, '喘息あり');
        expect(store3.profile.considerations, <String>{
          kCitizenConsiderationOptions[1],
        });

        await tester.pump(const Duration(seconds: 3));
      },
    );

    test(
      'Regression 7 (R2-1D): failed saveProfileEdits preserves prior dirty fields and persists them on subsequent save',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        ds.storedProfile = (
          profile: const CitizenRegistrationProfile(
            name: 'DB旧名',
            birthDate: '1980-01-01',
            bloodType: 'A型',
            addressDetail: 'DB旧住所',
          ),
          safety: CitizenSafetyStatus.safe,
        );

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.demoLogin(delay: Duration.zero);
        await pumpEventQueue(times: 20);

        store.updateBasicInfo(
          birthDate: '1995-05-05',
          bloodType: 'O型',
          gender: '女性',
          postalCode: '753-0001',
          prefecture: '山口県',
        );
        store.toggleConsideration(kCitizenConsiderationOptions[0]);
        store.updateOtherConsideration('喘息あり');
        store.selectPhotoDemo();
        store.selectIdDocDemo();

        ds.upsertProfileError = StateError('save failed');
        final failed = await store.saveProfileEdits(name: '失敗名');

        expect(failed, isFalse);
        expect(store.profile.name, 'DB旧名');
        expect(store.profile.addressDetail, 'DB旧住所');
        expect(store.profile.birthDate, '1995-05-05');
        expect(store.profile.bloodType, 'O型');
        expect(store.profile.gender, '女性');
        expect(store.profile.postalCode, '753-0001');
        expect(store.profile.prefecture, '山口県');
        expect(
          store.profile.considerations,
          <String>{kCitizenConsiderationOptions[0]},
        );
        expect(store.profile.otherConsideration, '喘息あり');
        expect(store.profile.photoSelected, isTrue);
        expect(store.profile.idDocSelected, isTrue);
        expect(store.toastMessage, '登録情報の保存に失敗しました');

        ds.upsertProfileError = null;
        final succeeded = await store.saveProfileEdits(addressDetail: '新住所');
        expect(succeeded, isTrue);
        expect(ds.storedProfile?.profile.name, 'DB旧名');
        expect(ds.storedProfile?.profile.addressDetail, '新住所');
        expect(ds.storedProfile?.profile.birthDate, '1995-05-05');
        expect(ds.storedProfile?.profile.bloodType, 'O型');
        expect(ds.storedProfile?.profile.gender, '女性');
        expect(ds.storedProfile?.profile.postalCode, '753-0001');
        expect(ds.storedProfile?.profile.prefecture, '山口県');
        expect(
          ds.storedProfile?.profile.considerations,
          <String>{kCitizenConsiderationOptions[0]},
        );
        expect(ds.storedProfile?.profile.otherConsideration, '喘息あり');
      },
    );

    test(
      'Regression 8 (R2-1D same-field edge): prior updateBasicInfo(name) overwritten by failed saveProfileEdits(name) rolls back name to _lastSyncedProfile while keeping other prior dirty fields',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        ds.storedProfile = (
          profile: const CitizenRegistrationProfile(
            name: 'DB旧名',
            birthDate: '1980-01-01',
          ),
          safety: CitizenSafetyStatus.safe,
        );

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.demoLogin(delay: Duration.zero);
        await pumpEventQueue(times: 20);

        store.updateBasicInfo(name: '途中名', birthDate: '1995-05-05');
        ds.upsertProfileError = StateError('save failed');
        final ok = await store.saveProfileEdits(name: '失敗名');

        expect(ok, isFalse);
        expect(store.profile.name, 'DB旧名');
        expect(store.profile.birthDate, '1995-05-05');
        expect(store.toastMessage, '登録情報の保存に失敗しました');
      },
    );

    test(
      'Regression 9 (R2-1D-uidNull): saveProfileEdits failing with uid == null rolls back only passed fields and preserves prior dirty fields',
      () async {
        final auth = _MockAuthService()..returnNullOnSignIn = true;
        final ds = _MockCitizenDataSource();
        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.updateBasicInfo(
          birthDate: '1995-05-05',
          bloodType: 'O型',
          addressDetail: '未保存住所',
        );
        final ok = await store.saveProfileEdits(name: '失敗名');

        expect(ok, isFalse);
        expect(store.profile.name, '');
        expect(store.profile.birthDate, '1995-05-05');
        expect(store.profile.bloodType, 'O型');
        expect(store.profile.addressDetail, '未保存住所');
        expect(store.toastMessage, '登録情報の保存に失敗しました');
      },
    );

    testWidgets(
      'Regression 10 (R2-1D-UI): CitizenReg2View/CitizenReg3View inputs survive failed CitizenSettingsTab saveProfileEdits and remain intact across views',
      (tester) async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        ds.storedProfile = (
          profile: const CitizenRegistrationProfile(
            name: 'DB旧ユーザー',
            birthDate: '1985-04-01',
            prefecture: '山口県',
            addressDetail: '山口市旧1-1',
          ),
          safety: CitizenSafetyStatus.safe,
        );

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        final rescueStore = RescueStore(startClock: false);
        addTearDown(() async {
          store.dispose();
          rescueStore.dispose();
          await tester.pump(const Duration(seconds: 3));
        });

        await tester.pumpWidget(
          MaterialApp(
            home: CitizenShellPage(
              citizenStore: store,
              rescueStore: rescueStore,
            ),
          ),
        );

        store.demoLogin(delay: Duration.zero);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();

        // reg2 で生年月日・郵便番号を入力
        store.goToScreen(CitizenScreen.reg2);
        await tester.pump();
        final reg2Fields = find.byType(TextField);
        expect(reg2Fields, findsNWidgets(4));
        await tester.enterText(reg2Fields.at(1), '1995-05-05');
        await tester.enterText(reg2Fields.at(2), '753-0001');
        await tester.pump();

        // reg3 で配慮事項・自由入力を入力
        store.goToScreen(CitizenScreen.reg3);
        await tester.pump();
        await tester.tap(find.text(kCitizenConsiderationOptions[1]));
        await tester.enterText(find.byType(TextField), '喘息あり');
        await tester.pump();

        // home -> 設定 -> 編集 -> 名前のみ変更して保存失敗
        store.goToScreen(CitizenScreen.home);
        await tester.pump();
        await tester.tap(find.text('設定'));
        await tester.pump();
        await tester.tap(find.text('編集'));
        await tester.pump();

        final settingsFields = find.byType(TextField);
        expect(settingsFields, findsNWidgets(2));
        await tester.enterText(settingsFields.at(0), '失敗名');
        await tester.pump();

        ds.upsertProfileError = StateError('save failed');
        await tester.tap(find.text('保存'));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();

        expect(find.text('DB旧ユーザー'), findsOneWidget);
        expect(find.text('1995-05-05'), findsOneWidget);
        expect(find.text('〒753-0001 山口県 山口市旧1-1'), findsOneWidget);
        expect(find.textContaining('喘息あり'), findsOneWidget);
        expect(find.textContaining(kCitizenConsiderationOptions[1]), findsOneWidget);

        // 「基本情報登録画面を開く ›」で reg2 へ戻っても先行入力値が維持されていること
        final openReg2Btn = find.text('基本情報登録画面を開く ›');
        await tester.ensureVisible(openReg2Btn);
        await tester.tap(openReg2Btn);
        await tester.pump();

        final reg2FieldsAfter = find.byType(TextField);
        expect(
          tester.widget<TextField>(reg2FieldsAfter.at(0)).controller?.text,
          'DB旧ユーザー',
        );
        expect(
          tester.widget<TextField>(reg2FieldsAfter.at(1)).controller?.text,
          '1995-05-05',
        );
        expect(
          tester.widget<TextField>(reg2FieldsAfter.at(2)).controller?.text,
          '753-0001',
        );
        expect(
          tester.widget<TextField>(reg2FieldsAfter.at(3)).controller?.text,
          '山口市旧1-1',
        );

        await tester.pump(const Duration(seconds: 3));
      },
    );

    test(
      'Regression 11 (R2-1D concurrent): prior dirty birthDate survives parallel saveProfileEdits where one fails and another succeeds',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        ds.storedProfile = (
          profile: const CitizenRegistrationProfile(
            name: 'DB旧名',
            birthDate: '1980-01-01',
            addressDetail: 'DB旧住所',
          ),
          safety: CitizenSafetyStatus.safe,
        );

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.demoLogin(delay: Duration.zero);
        await pumpEventQueue(times: 20);

        store.updateBasicInfo(birthDate: '1995-05-05');
        ds.onUpsertProfile = (profile) async {
          if (profile.name == '失敗名') {
            throw StateError('first failed');
          }
        };

        final f1 = store.saveProfileEdits(name: '失敗名');
        final f2 = store.saveProfileEdits(addressDetail: '成功住所');
        final results = await Future.wait([f1, f2]);

        expect(results, [false, true]);
        expect(store.profile.name, 'DB旧名');
        expect(store.profile.addressDetail, '成功住所');
        expect(store.profile.birthDate, '1995-05-05');
        expect(ds.storedProfile?.profile.birthDate, '1995-05-05');
        expect(ds.storedProfile?.profile.addressDetail, '成功住所');
      },
    );
  });

  group('Challenge 4 regression tests (initializeRemote vs auth/message subscription races)', () {
    test(
      'R2-1F-2: demoLogin completing while initializeRemote public fetchMessages(groupId: null) is pending is not overwritten by stale public subscription',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        final publicSubFetchCompleter = Completer<void>();
        var publicFetchCalls = 0;

        ds.onFetchMessages = (groupId, currentUserId) async {
          if (groupId == null && currentUserId == null) {
            publicFetchCalls++;
            if (publicFetchCalls == 2) {
              await publicSubFetchCompleter.future;
            }
          }
        };
        ds.fetchMessagesResponder = (groupId) {
          if (groupId == null) {
            return const [
              CitizenMessage(
                id: 'stale-public',
                kind: CitizenMessageKind.municipalityNotice,
                sender: '自治体',
                avatar: '🏛️',
                body: '古い公開メッセージ',
                time: '09:00',
              ),
            ];
          }
          return const [
            CitizenMessage(
              id: 'fam-init-1',
              kind: CitizenMessageKind.familyThread,
              sender: '家族',
              avatar: '👩',
              body: '家族スレッド初期メッセージ',
              time: '10:00',
            ),
          ];
        };

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        final initFuture = store.initializeRemote();
        await pumpEventQueue(times: 10);
        expect(publicFetchCalls, 2);

        // 公開 fetchMessages 完了前でも demoLogin はブロックされず家族購読へ移行できること
        store.demoLogin(delay: Duration.zero);
        await pumpEventQueue(times: 20);
        expect(store.isLoggedIn, isTrue);
        expect(store.familyInviteCode, 'MAMO99');
        expect(ds.subscribeMessagesGroupIds, ['group-1']);

        // 遅延していた公開 fetchMessages が後から完了しても家族購読・メッセージを上書きしないこと
        publicSubFetchCompleter.complete();
        await initFuture;

        expect(ds.subscribeMessagesGroupIds, ['group-1']);
        expect(store.messages.any((m) => m.id == 'stale-public'), isFalse);
        expect(store.familyMessages.any((m) => m.id == 'fam-init-1'), isTrue);

        ds.messageController.add(const CitizenMessage(
          id: 'fam-live-1',
          kind: CitizenMessageKind.familyThread,
          sender: 'お母さん',
          avatar: '👩',
          body: '無事に着きました',
          time: '10:05',
        ));
        await pumpEventQueue();
        expect(store.familyMessages.any((m) => m.id == 'fam-live-1'), isTrue);
      },
    );

    test(
      'initializeRemote Future.wait completing after demoLogin and joinFamilyGroup(JOIN77) does not revert family group or messages',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        final futureWaitCompleter = Completer<void>();

        ds.onFetchMessages = (groupId, currentUserId) async {
          if (groupId == null) {
            await futureWaitCompleter.future;
          }
        };
        ds.fetchMessagesResponder = (groupId) {
          if (groupId == 'group-2') {
            return const [
              CitizenMessage(
                id: 'group2-msg-1',
                kind: CitizenMessageKind.familyThread,
                sender: '招待家族',
                avatar: '👨',
                body: 'グループ2メッセージ',
                time: '10:10',
              ),
            ];
          }
          if (groupId == 'group-1') {
            return const [
              CitizenMessage(
                id: 'group1-msg-1',
                kind: CitizenMessageKind.familyThread,
                sender: '初期家族',
                avatar: '👩',
                body: 'グループ1メッセージ',
                time: '10:05',
              ),
            ];
          }
          return const [
            CitizenMessage(
              id: 'stale-public-wait',
              kind: CitizenMessageKind.municipalityNotice,
              sender: '自治体',
              avatar: '🏛️',
              body: '遅延した公開お知らせ',
              time: '09:00',
            ),
          ];
        };

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        final initFuture = store.initializeRemote();
        await pumpEventQueue(times: 5);

        store.demoLogin(delay: Duration.zero);
        final joined = await store.joinFamilyGroup('JOIN77');
        expect(joined, isTrue);
        expect(store.familyInviteCode, 'JOIN77');
        expect(ds.subscribeMessagesGroupIds, ['group-1', 'group-2']);

        futureWaitCompleter.complete();
        await initFuture;

        expect(store.familyInviteCode, 'JOIN77');
        expect(ds.subscribeMessagesGroupIds.last, 'group-2');
        expect(store.messages.any((m) => m.id == 'stale-public-wait'), isFalse);
        expect(store.messages.any((m) => m.id == 'group2-msg-1'), isTrue);
      },
    );

    test(
      'logout during in-flight group-1 fetchMessages discards stale family subscription and restores public groupId: null subscription',
      () async {
        final auth = _MockAuthService();
        final ds = _MockCitizenDataSource();
        final groupFetchCompleter = Completer<void>();

        ds.onFetchMessages = (groupId, currentUserId) async {
          if (groupId == 'group-1') {
            await groupFetchCompleter.future;
          }
        };
        ds.fetchMessagesResponder = (groupId) {
          if (groupId == 'group-1') {
            return const [
              CitizenMessage(
                id: 'stale-family-1',
                kind: CitizenMessageKind.familyThread,
                sender: '家族',
                avatar: '👩',
                body: '古い家族メッセージ',
                time: '10:00',
              ),
            ];
          }
          return const [
            CitizenMessage(
              id: 'notice-public-1',
              kind: CitizenMessageKind.municipalityNotice,
              sender: '山口県 災害対策本部',
              avatar: '🏛️',
              body: '公開お知らせ復帰',
              time: '10:15',
            ),
          ];
        };

        final store = CitizenStore(
          dataSource: ds,
          authService: auth,
          autoInitialize: false,
        );
        addTearDown(store.dispose);

        store.demoLogin(delay: Duration.zero);
        await pumpEventQueue(times: 10);

        // group-1 の fetchMessages 待機中に logout() を実行
        store.logout();
        expect(store.isLoggedIn, isFalse);
        expect(store.familyGroupName, isNull);

        groupFetchCompleter.complete();
        await pumpEventQueue(times: 20);

        expect(store.isLoggedIn, isFalse);
        expect(store.familyGroupName, isNull);
        expect(ds.subscribeMessagesGroupIds, [null]);
        expect(store.familyMessages, isEmpty);
        expect(store.messages.any((m) => m.id == 'stale-family-1'), isFalse);
        expect(store.municipalityNotices.single.id, 'notice-public-1');
      },
    );
  });
}
