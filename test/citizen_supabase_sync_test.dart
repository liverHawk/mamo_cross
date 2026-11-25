import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/models/citizen_models.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/services/auth_service.dart';
import 'package:mamo_cross/services/citizen_data_source.dart';
import 'package:mamo_cross/state/citizen_store.dart';

class _MockAuthService implements AuthService {
  String? _userId;
  int signInCalls = 0;
  int signOutCalls = 0;
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
    _userId ??= 'anon-user-1';
    _controller.add(_userId);
    return _userId;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _userId = null;
    _controller.add(null);
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
    storedProfile = (profile: profile, safety: safetyStatus);
  }

  @override
  Future<void> updateSafetyStatus({
    required String userId,
    required CitizenSafetyStatus status,
    String? locationNote,
  }) async {
    updatedSafetyHistory.add(status);
  }

  @override
  Future<FamilyGroupInfo?> fetchOrCreateDefaultFamilyGroup({
    required String userId,
    required String displayName,
  }) async {
    return defaultGroup;
  }

  @override
  Future<FamilyGroupInfo?> joinFamilyGroupByCode({
    required String inviteCode,
    required String displayName,
  }) async {
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

    store.dispose();
  });
}
