import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/config/supabase_config.dart';
import 'package:mamo_cross/main.dart';
import 'package:mamo_cross/models/citizen_models.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/services/auth_service.dart';
import 'package:mamo_cross/services/citizen_data_source.dart';
import 'package:mamo_cross/state/citizen_store.dart';
import 'package:mamo_cross/state/rescue_store.dart';
import 'package:mamo_cross/views/citizen/citizen_safety_tab.dart';
import 'package:material_ui/material_ui.dart';

class _MockAuthService implements AuthService {
  String? _userId;
  int signInCalls = 0;
  int signOutCalls = 0;
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
  Object? updateSafetyError;
  Object? sendMessageError;
  bool returnNullOnSendMessage = false;
  Object? joinGroupError;
  Object? fetchSheltersError;
  Completer<void>? defaultGroupCompleter;

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
    return storedProfile;
  }

  @override
  Future<void> upsertProfile({
    required String userId,
    required CitizenRegistrationProfile profile,
    required CitizenSafetyStatus safetyStatus,
    String locationNote = '〇〇地区付近',
  }) async {
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
  }) =>
      messageController.stream;

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
}
