import 'package:material_ui/material_ui.dart';

import '../theme/mamo_theme.dart';

/// 利用者（住民・スマホ）側の 7 画面（mamo-main/index.html 準拠）
enum CitizenScreen {
  login('ログイン'),
  reg1('① 本人確認'),
  reg2('② 基本情報の入力'),
  reg3('③ 救助要請時の情報'),
  home('ホーム'),
  rescue('救助要請'),
  rescueSent('送信完了');

  const CitizenScreen(this.title);

  final String title;
}

/// 利用者ホーム画面の下部 5 タブ
enum CitizenTab {
  home('ホーム', '⌂', Icons.home_outlined, Icons.home),
  map('マップ', '⌖', Icons.place_outlined, Icons.place),
  safety('安否', '◎', Icons.verified_user_outlined, Icons.verified_user),
  messages('メッセージ', '•••', Icons.chat_bubble_outline, Icons.chat_bubble),
  settings('設定', '⚙', Icons.settings_outlined, Icons.settings);

  const CitizenTab(this.label, this.symbol, this.icon, this.activeIcon);

  final String label;
  final String symbol;
  final IconData icon;
  final IconData activeIcon;
}

/// 利用者の安否ステータス
enum CitizenSafetyStatus {
  safe(
    label: '無事',
    symbol: '●',
    badgeText: '● 無事',
    buttonColor: MamoColors.citizenSafeGreen,
    badgeColor: Color(0xFF07945F),
    toastMessage: '無事として登録しました',
  ),
  damaged(
    label: '被害あり',
    symbol: '▲',
    badgeText: '▲ 被害あり',
    buttonColor: MamoColors.citizenWarnYellow,
    badgeColor: MamoColors.citizenWarnText,
    toastMessage: '被害ありとして登録しました',
  ),
  rescueNeeded(
    label: '救助要請',
    symbol: 'SOS',
    badgeText: '🚨 救助要請',
    buttonColor: MamoColors.citizenHelpRed,
    badgeColor: MamoColors.citizenHelpRed,
    toastMessage: '救助要請として登録しました',
  );

  const CitizenSafetyStatus({
    required this.label,
    required this.symbol,
    required this.badgeText,
    required this.buttonColor,
    required this.badgeColor,
    required this.toastMessage,
  });

  final String label;
  final String symbol;
  final String badgeText;
  final Color buttonColor;
  final Color badgeColor;
  final String toastMessage;
}

/// 血液型選択肢（#reg2）
const List<String> kCitizenBloodTypes = <String>[
  '選択してください',
  'A型',
  'B型',
  'O型',
  'AB型',
];

/// 性別選択肢（#reg2）
const List<String> kCitizenGenders = <String>[
  '男性',
  '女性',
  'その他',
];

/// 都道府県選択肢（#reg2）
const List<String> kCitizenPrefectures = <String>[
  '都道府県を選択',
  '東京都',
  '大阪府',
  '神奈川県',
  '山口県',
  'その他',
];

/// 救助要請時の配慮事項 5 選択肢（#reg3）
const List<String> kCitizenConsiderationOptions = <String>[
  '💉 ホルモン治療中',
  '🫁 人工呼吸器を使用',
  '🤰 妊娠中',
  '🟢 オストメイト',
  '🩺 医療的ケアが必要',
];

/// メッセージタブの定型クイック返信
const List<String> kCitizenQuickReplies = <String>[
  '無事です、避難所に向かっています',
  '自宅待機しています',
  '水・食料は確保済みです',
  '連絡ありがとう！',
];

/// デフォルトのデモ位置情報（山口県山口市）
const String kDefaultCitizenLocationNote = '山口県山口市亀山町付近';

/// ホーム画面の緊急災害警報バナー文言
const String kCitizenAlertBannerText = '⚠　山口市大殿地区　震度5強';

/// 利用者登録プロフィール（#reg1〜#reg3）
class CitizenRegistrationProfile {
  const CitizenRegistrationProfile({
    this.photoSelected = false,
    this.idDocSelected = false,
    this.name = '',
    this.birthDate = '',
    this.bloodType = '',
    this.gender = '',
    this.postalCode = '',
    this.prefecture = '',
    this.addressDetail = '',
    this.considerations = const <String>{},
    this.otherConsideration = '',
  });

  final bool photoSelected;
  final bool idDocSelected;
  final String name;
  final String birthDate;
  final String bloodType;
  final String gender;
  final String postalCode;
  final String prefecture;
  final String addressDetail;
  final Set<String> considerations;
  final String otherConsideration;

  /// 表示名（未設定・空白のみの場合は `'あなた'`）
  String get effectiveDisplayName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'あなた' : trimmed;
  }

  /// 登録済み配慮事項の結合文字列（未設定時は空文字 `''`）
  String get formattedConsiderations {
    final items = <String>[];
    for (final option in kCitizenConsiderationOptions) {
      if (considerations.contains(option)) {
        items.add(option);
      }
    }
    for (final extra in considerations) {
      if (!kCitizenConsiderationOptions.contains(extra) &&
          extra.trim().isNotEmpty) {
        items.add(extra.trim());
      }
    }
    final other = otherConsideration.trim();
    if (other.isNotEmpty) {
      items.add(other);
    }
    return items.join('、');
  }

  /// 住所まとめ表示
  String get fullAddress {
    final parts = <String>[];
    final post = postalCode.trim();
    if (post.isNotEmpty) {
      parts.add('〒$post');
    }
    final pref = prefecture.trim();
    if (pref.isNotEmpty && pref != '都道府県を選択') {
      parts.add(pref);
    }
    final detail = addressDetail.trim();
    if (detail.isNotEmpty) {
      parts.add(detail);
    }
    return parts.join(' ');
  }

  CitizenRegistrationProfile copyWith({
    bool? photoSelected,
    bool? idDocSelected,
    String? name,
    String? birthDate,
    String? bloodType,
    String? gender,
    String? postalCode,
    String? prefecture,
    String? addressDetail,
    Set<String>? considerations,
    String? otherConsideration,
  }) {
    return CitizenRegistrationProfile(
      photoSelected: photoSelected ?? this.photoSelected,
      idDocSelected: idDocSelected ?? this.idDocSelected,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      bloodType: bloodType ?? this.bloodType,
      gender: gender ?? this.gender,
      postalCode: postalCode ?? this.postalCode,
      prefecture: prefecture ?? this.prefecture,
      addressDetail: addressDetail ?? this.addressDetail,
      considerations: considerations != null
          ? Set<String>.unmodifiable(considerations)
          : this.considerations,
      otherConsideration: otherConsideration ?? this.otherConsideration,
    );
  }

  factory CitizenRegistrationProfile.fromSupabaseRow(Map<String, dynamic> row) {
    final rawConsiderations = row['considerations'];
    final considerationSet = <String>{};
    if (rawConsiderations is Iterable) {
      for (final item in rawConsiderations) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty) considerationSet.add(s);
      }
    }
    return CitizenRegistrationProfile(
      name: (row['display_name'] ?? '').toString(),
      birthDate: (row['birth_date'] ?? '').toString(),
      bloodType: (row['blood_type'] ?? '').toString(),
      gender: (row['gender'] ?? '').toString(),
      postalCode: (row['postal_code'] ?? '').toString(),
      prefecture: (row['prefecture'] ?? '').toString(),
      addressDetail: (row['address_detail'] ?? '').toString(),
      considerations: Set<String>.unmodifiable(considerationSet),
      otherConsideration: (row['other_consideration'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toSupabaseUpsert(
    String userId, {
    required CitizenSafetyStatus safetyStatus,
    String locationNote = kDefaultCitizenLocationNote,
  }) {
    return <String, dynamic>{
      'id': userId,
      'display_name': effectiveDisplayName,
      'birth_date': birthDate.trim(),
      'blood_type': bloodType.trim(),
      'gender': gender.trim(),
      'postal_code': postalCode.trim(),
      'prefecture': prefecture.trim(),
      'address_detail': addressDetail.trim(),
      'considerations': considerations.toList(),
      'other_consideration': otherConsideration.trim(),
      'safety_status': safetyStatus.name,
      'location_note': locationNote.trim().isEmpty
          ? kDefaultCitizenLocationNote
          : locationNote.trim(),
      'safety_updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

/// 家族グループ情報
class FamilyGroupInfo {
  const FamilyGroupInfo({
    required this.id,
    required this.name,
    required this.inviteCode,
  });

  final String id;
  final String name;
  final String inviteCode;

  factory FamilyGroupInfo.fromSupabaseRow(Map<String, dynamic> row) {
    return FamilyGroupInfo(
      id: (row['id'] ?? '').toString(),
      name: (row['name'] ?? 'マイ家族グループ').toString(),
      inviteCode: (row['invite_code'] ?? '').toString(),
    );
  }
}

/// 家族グループメンバー
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.avatar,
    required this.status,
    this.isSelf = false,
    this.lastUpdated = '',
    this.locationNote = '',
  });

  final String id;
  final String name;
  final String avatar;
  final CitizenSafetyStatus status;
  final bool isSelf;
  final String lastUpdated;
  final String locationNote;

  FamilyMember copyWith({
    String? id,
    String? name,
    String? avatar,
    CitizenSafetyStatus? status,
    bool? isSelf,
    String? lastUpdated,
    String? locationNote,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      status: status ?? this.status,
      isSelf: isSelf ?? this.isSelf,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      locationNote: locationNote ?? this.locationNote,
    );
  }

  factory FamilyMember.fromSupabaseRow(
    Map<String, dynamic> row, {
    String? currentUserId,
  }) {
    final uid = (row['user_id'] ?? '').toString();
    final isSelf = currentUserId != null && uid == currentUserId;
    final rawStatus = (row['safety_status'] ?? 'safe').toString();
    final status = CitizenSafetyStatus.values.firstWhere(
      (s) => s.name == rawStatus,
      orElse: () => CitizenSafetyStatus.safe,
    );
    return FamilyMember(
      id: (row['id'] ?? uid).toString(),
      name: (row['display_name'] ?? (isSelf ? 'あなた' : '家族')).toString(),
      avatar: (row['avatar'] ?? '🙂').toString(),
      status: status,
      isSelf: isSelf,
      lastUpdated: _formatCitizenTime(row['safety_updated_at']),
      locationNote: (row['location_note'] ?? '').toString(),
    );
  }
}

/// 初期家族メンバー 4 名（mamo-main/index.html 準拠）
List<FamilyMember> createInitialFamilyMembers() => <FamilyMember>[
      const FamilyMember(
        id: 'mom',
        name: 'お母さん',
        avatar: '👩',
        status: CitizenSafetyStatus.safe,
        lastUpdated: '14:15',
        locationNote: '大殿小学校 避難所',
      ),
      const FamilyMember(
        id: 'dad',
        name: 'お父さん',
        avatar: '👨',
        status: CitizenSafetyStatus.safe,
        lastUpdated: '14:18',
        locationNote: '職場付近',
      ),
      const FamilyMember(
        id: 'sister',
        name: 'お姉ちゃん',
        avatar: '🧑',
        status: CitizenSafetyStatus.damaged,
        lastUpdated: '14:20',
        locationNote: '自宅付近（周辺停電）',
      ),
      const FamilyMember(
        id: 'self',
        name: 'あなた',
        avatar: '🙂',
        status: CitizenSafetyStatus.safe,
        isSelf: true,
        lastUpdated: 'たった今',
        locationNote: kDefaultCitizenLocationNote,
      ),
    ];

/// 避難所情報モデル
class CitizenShelter {
  const CitizenShelter({
    required this.id,
    required this.name,
    required this.distanceText,
    required this.statusText,
    required this.isOpen,
    required this.address,
    required this.capacity,
    required this.occupied,
    required this.facilities,
    required this.xPercent,
    required this.yPercent,
  });

  final String id;
  final String name;
  final String distanceText;
  final String statusText;
  final bool isOpen;
  final String address;
  final int capacity;
  final int occupied;
  final List<String> facilities;
  final double xPercent;
  final double yPercent;

  factory CitizenShelter.fromSupabaseRow(Map<String, dynamic> row) {
    final rawFacilities = row['facilities'];
    final facilities = <String>[];
    if (rawFacilities is Iterable) {
      for (final f in rawFacilities) {
        final s = f?.toString().trim() ?? '';
        if (s.isNotEmpty) facilities.add(s);
      }
    }
    return CitizenShelter(
      id: (row['id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      distanceText: (row['distance_text'] ?? '').toString(),
      statusText: (row['status_text'] ?? '').toString(),
      isOpen: row['is_open'] is bool ? row['is_open'] as bool : true,
      address: (row['address'] ?? '').toString(),
      capacity: (row['capacity'] is num)
          ? (row['capacity'] as num).toInt()
          : int.tryParse('${row['capacity'] ?? 100}') ?? 100,
      occupied: (row['occupied'] is num)
          ? (row['occupied'] as num).toInt()
          : int.tryParse('${row['occupied'] ?? 0}') ?? 0,
      facilities: facilities,
      xPercent: (row['x_percent'] is num)
          ? (row['x_percent'] as num).toDouble()
          : 0.5,
      yPercent: (row['y_percent'] is num)
          ? (row['y_percent'] as num).toDouble()
          : 0.5,
    );
  }
}

/// 初期避難所リスト（最寄りは `大殿地区 大殿小学校` `150m先`）
const List<CitizenShelter> kInitialCitizenShelters = <CitizenShelter>[
  CitizenShelter(
    id: 'shelter_1',
    name: '大殿地区 大殿小学校',
    distanceText: '150m先',
    statusText: '避難所開設',
    isOpen: true,
    address: '山口県山口市大殿大路120',
    capacity: 300,
    occupied: 128,
    facilities: <String>['給水', '非常電源', '医療救護', 'バリアフリー'],
    xPercent: 0.62,
    yPercent: 0.36,
  ),
  CitizenShelter(
    id: 'shelter_2',
    name: '湯田地域交流センター（福祉避難所）',
    distanceText: '420m先',
    statusText: '避難所開設（要配慮者優先）',
    isOpen: true,
    address: '山口県山口市湯田温泉5-5-15',
    capacity: 120,
    occupied: 54,
    facilities: <String>['福祉対応', '授乳室', '車椅子対応', '非常電源'],
    xPercent: 0.28,
    yPercent: 0.58,
  ),
  CitizenShelter(
    id: 'shelter_3',
    name: '亀山公園（一時避難場所）',
    distanceText: '650m先',
    statusText: '広域避難場所・給水車待機',
    isOpen: true,
    address: '山口県山口市亀山町2-1',
    capacity: 800,
    occupied: 210,
    facilities: <String>['給水車', '仮設トイレ', 'ヘリポート'],
    xPercent: 0.78,
    yPercent: 0.72,
  ),
];

/// マップ上の危険箇所情報
class CitizenHazardSpot {
  const CitizenHazardSpot({
    required this.id,
    required this.title,
    required this.description,
    required this.xPercent,
    required this.yPercent,
  });

  final String id;
  final String title;
  final String description;
  final double xPercent;
  final double yPercent;

  factory CitizenHazardSpot.fromSupabaseRow(Map<String, dynamic> row) {
    return CitizenHazardSpot(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      xPercent: (row['x_percent'] is num)
          ? (row['x_percent'] as num).toDouble()
          : 0.5,
      yPercent: (row['y_percent'] is num)
          ? (row['y_percent'] as num).toDouble()
          : 0.5,
    );
  }
}

/// 初期危険箇所リスト
const List<CitizenHazardSpot> kInitialCitizenHazards = <CitizenHazardSpot>[
  CitizenHazardSpot(
    id: 'hazard_1',
    title: 'ブロック塀倒壊のおそれ',
    description: '大殿小学校西側の通学路沿い・迂回推奨',
    xPercent: 0.44,
    yPercent: 0.28,
  ),
  CitizenHazardSpot(
    id: 'hazard_2',
    title: '一部道路冠水・通行止め',
    description: '一の坂川沿いアンダーパス通行不可',
    xPercent: 0.72,
    yPercent: 0.55,
  ),
];

/// メッセージ種別
enum CitizenMessageKind {
  municipalityNotice('自治体お知らせ'),
  familyThread('家族連絡');

  const CitizenMessageKind(this.label);

  final String label;
}

/// メッセージ項目
class CitizenMessage {
  const CitizenMessage({
    required this.id,
    required this.kind,
    required this.sender,
    required this.avatar,
    required this.body,
    required this.time,
    this.isMine = false,
    this.isImportant = false,
  });

  final String id;
  final CitizenMessageKind kind;
  final String sender;
  final String avatar;
  final String body;
  final String time;
  final bool isMine;
  final bool isImportant;

  factory CitizenMessage.fromSupabaseRow(
    Map<String, dynamic> row, {
    String? currentUserId,
  }) {
    final rawKind = (row['kind'] ?? '').toString();
    final kind = rawKind == 'family_thread'
        ? CitizenMessageKind.familyThread
        : CitizenMessageKind.municipalityNotice;
    final senderId = row['sender_id']?.toString();
    final isMine =
        currentUserId != null && senderId != null && senderId == currentUserId;
    return CitizenMessage(
      id: (row['id'] ?? '').toString(),
      kind: kind,
      sender: (row['sender_name'] ?? '不明').toString(),
      avatar: (row['avatar'] ?? (kind == CitizenMessageKind.municipalityNotice ? '🏛️' : '🙂')).toString(),
      body: (row['body'] ?? '').toString(),
      time: _formatCitizenTime(row['created_at']),
      isMine: isMine,
      isImportant: row['is_important'] is bool ? row['is_important'] as bool : false,
    );
  }
}

String _formatCitizenTime(Object? raw) {
  if (raw == null) return '';
  final dt = raw is DateTime
      ? raw.toLocal()
      : DateTime.tryParse(raw.toString().trim())?.toLocal();
  if (dt == null) return '';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// 初期メッセージ一覧（自治体お知らせ + 家族連絡）
List<CitizenMessage> createInitialCitizenMessages() => <CitizenMessage>[
      const CitizenMessage(
        id: 'notice_1',
        kind: CitizenMessageKind.municipalityNotice,
        sender: '山口市 災害対策本部',
        avatar: '🏛️',
        body: '【緊急】山口市大殿地区で震度5強を観測しました。大殿地区 大殿小学校ほか2箇所の避難所を開設しています。',
        time: '14:05',
        isImportant: true,
      ),
      const CitizenMessage(
        id: 'notice_2',
        kind: CitizenMessageKind.municipalityNotice,
        sender: '山口市 防災無線',
        avatar: '📢',
        body: '大殿小学校にて給水および非常電源の提供を開始しました。余震にご注意ください。',
        time: '14:16',
      ),
      const CitizenMessage(
        id: 'family_1',
        kind: CitizenMessageKind.familyThread,
        sender: 'お母さん',
        avatar: '👩',
        body: '地震大きかったね。お母さんは大殿小学校に着きました。みんなは無事？',
        time: '14:15',
      ),
      const CitizenMessage(
        id: 'family_2',
        kind: CitizenMessageKind.familyThread,
        sender: 'お父さん',
        avatar: '👨',
        body: 'こちらは無事です。交通機関が止まっているので徒歩で向かいます。',
        time: '14:18',
      ),
      const CitizenMessage(
        id: 'family_3',
        kind: CitizenMessageKind.familyThread,
        sender: 'お姉ちゃん',
        avatar: '🧑',
        body: '自宅周辺が停電していて塀が一部崩れています。合流できそうなタイミングで移動します。',
        time: '14:20',
      ),
    ];

/// `#rescueSent` で表示する受付内容サマリ
class RescueSummary {
  const RescueSummary({
    required this.requestId,
    required this.time,
    required this.requesterName,
    required this.locationText,
    required this.detail,
    this.considerations = 'なし',
    this.syncedToRemote = false,
  });

  final String requestId;
  final String time;
  final String requesterName;
  final String locationText;
  final String detail;
  final String considerations;
  final bool syncedToRemote;

  RescueSummary copyWith({
    String? requestId,
    String? time,
    String? requesterName,
    String? locationText,
    String? detail,
    String? considerations,
    bool? syncedToRemote,
  }) {
    return RescueSummary(
      requestId: requestId ?? this.requestId,
      time: time ?? this.time,
      requesterName: requesterName ?? this.requesterName,
      locationText: locationText ?? this.locationText,
      detail: detail ?? this.detail,
      considerations: considerations ?? this.considerations,
      syncedToRemote: syncedToRemote ?? this.syncedToRemote,
    );
  }
}

/// `mamo-main/supabase_setup.sql` 準拠の厳密な 15 カラム INSERT ペイロードを生成する。
///
/// `age`, `gender`, `latPercent`, `topPercent`, `id` は含めない。
Map<String, dynamic> buildCitizenRescuePayload({
  required String requestId,
  required DateTime createdAt,
  required String requesterName,
  required String rescueDetails,
  required String considerations,
  String locationText = kDefaultCitizenLocationNote,
  String distanceText = '約150m先（デモ）',
  String requestType = '救助要請',
  String status = '未対応',
}) {
  final safeName =
      requesterName.trim().isEmpty ? 'あなた' : requesterName.trim();
  final safeDetail =
      rescueDetails.trim().isEmpty ? '救助が必要です' : rescueDetails.trim();
  final safeCare =
      considerations.trim().isEmpty ? 'なし' : considerations.trim();
  final safeLocation = locationText.trim().isEmpty
      ? kDefaultCitizenLocationNote
      : locationText.trim();
  final safeDistance =
      distanceText.trim().isEmpty ? '約150m先（デモ）' : distanceText.trim();

  return <String, dynamic>{
    'request_id': requestId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'user_name': safeName,
    'requester_name': safeName,
    'request_type': requestType,
    'detail': safeDetail,
    'rescue_details': safeDetail,
    'health_condition': safeCare,
    'consideration': safeCare,
    'considerations': safeCare,
    'location': safeLocation,
    'location_text': safeLocation,
    'distance': safeDistance,
    'distance_text': safeDistance,
    'status': status,
  };
}
