import '../models/citizen_models.dart';

/// 利用者側データ（プロフィール・安否・家族・メッセージ・避難所・危険箇所）の抽象データソース
abstract interface class CitizenDataSource {
  Future<({CitizenRegistrationProfile profile, CitizenSafetyStatus safety})?>
      fetchProfile(String userId);

  Future<void> upsertProfile({
    required String userId,
    required CitizenRegistrationProfile profile,
    required CitizenSafetyStatus safetyStatus,
    String locationNote = kDefaultCitizenLocationNote,
  });

  Future<void> updateSafetyStatus({
    required String userId,
    required CitizenSafetyStatus status,
    String? locationNote,
  });

  Future<FamilyGroupInfo?> fetchOrCreateDefaultFamilyGroup({
    required String userId,
    required String displayName,
  });

  Future<FamilyGroupInfo?> joinFamilyGroupByCode({
    required String inviteCode,
    required String displayName,
  });

  Future<List<FamilyMember>> fetchFamilyMembers(
    String groupId, {
    String? currentUserId,
  });

  Stream<List<FamilyMember>> subscribeFamilyMembers(
    String groupId, {
    String? currentUserId,
  });

  Future<List<CitizenMessage>> fetchMessages({
    String? groupId,
    String? currentUserId,
  });

  Stream<CitizenMessage> subscribeMessages({
    String? groupId,
    String? currentUserId,
  });

  Future<CitizenMessage?> sendMessage({
    required CitizenMessageKind kind,
    required String senderName,
    required String body,
    String? groupId,
    String? senderId,
    String avatar = '🙂',
    bool isImportant = false,
  });

  Future<List<CitizenShelter>> fetchShelters();

  Stream<List<CitizenShelter>> subscribeShelters();

  Future<List<CitizenHazardSpot>> fetchHazardSpots();

  Future<void> dispose();
}
