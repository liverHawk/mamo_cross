import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/citizen_models.dart';
import '../models/rescue_request.dart';
import '../services/auth_service.dart';
import '../services/citizen_data_source.dart';
import 'rescue_store.dart';
import '../utils/app_logger.dart';

enum _CitizenProfileField {
  photoSelected,
  idDocSelected,
  name,
  birthDate,
  bloodType,
  gender,
  postalCode,
  prefecture,
  addressDetail,
  considerations,
  otherConsideration,
}

/// 利用者（住民・スマホ）側の状態管理ストア
class CitizenStore extends ChangeNotifier {
  CitizenStore({
    this.dataSource,
    this.authService,
    bool autoInitialize = true,
  })  : _familyMembers = createInitialFamilyMembers(),
        _shelters = List<CitizenShelter>.of(kInitialCitizenShelters),
        _hazardSpots = List<CitizenHazardSpot>.of(kInitialCitizenHazards),
        _messages = createInitialCitizenMessages() {
    if (dataSource != null && autoInitialize) {
      unawaited(initializeRemote());
    }
  }

  final CitizenDataSource? dataSource;
  final AuthService? authService;

  CitizenScreen _currentScreen = CitizenScreen.login;
  CitizenTab _currentTab = CitizenTab.home;
  CitizenRegistrationProfile _profile = const CitizenRegistrationProfile();
  CitizenRegistrationProfile _lastSyncedProfile =
      const CitizenRegistrationProfile();
  bool _isLoggedIn = false;

  CitizenSafetyStatus _mySafety = CitizenSafetyStatus.safe;
  CitizenSafetyStatus _lastSyncedSafety = CitizenSafetyStatus.safe;
  FamilyGroupInfo? _familyGroup;
  List<FamilyMember> _familyMembers;
  CitizenSafetyStatus? _familyStatusFilter;
  bool _familyCheckInSent = false;

  List<CitizenShelter> _shelters;
  CitizenShelter? _selectedShelter;
  List<CitizenHazardSpot> _hazardSpots;
  bool _showHazardsOnMap = true;

  List<CitizenMessage> _messages;
  CitizenMessageKind _activeMessageKind =
      CitizenMessageKind.municipalityNotice;

  bool _notificationsEnabled = true;

  String _rescueNameDraft = 'あなた';
  String _rescueDetailDraft = '';
  String _rescueCareDraft = '';
  RescueSummary? _latestRescueSummary;

  String? _toastMessage;
  Timer? _toastTimer;
  Timer? _demoLoginTimer;
  StreamSubscription<List<FamilyMember>>? _familySub;
  StreamSubscription<CitizenMessage>? _messagesSub;
  StreamSubscription<List<CitizenShelter>>? _sheltersSub;
  Future<void> _authOpChain = Future<void>.value();
  int _authRevision = 0;
  int _messageSubEpoch = 0;
  int _safetyRequestSeq = 0;
  int _profileRequestSeq = 0;
  final Map<_CitizenProfileField, int> _fieldDirtySeq =
      <_CitizenProfileField, int>{};
  bool _disposed = false;

  CitizenScreen get currentScreen => _currentScreen;
  CitizenTab get currentTab => _currentTab;
  CitizenRegistrationProfile get profile => _profile;
  String get registeredName => _profile.effectiveDisplayName;
  bool get isLoggedIn => _isLoggedIn;

  CitizenSafetyStatus get mySafety => _mySafety;
  List<FamilyMember> get familyMembers => List.unmodifiable(_familyMembers);
  CitizenSafetyStatus? get familyStatusFilter => _familyStatusFilter;
  List<FamilyMember> get filteredFamilyMembers {
    if (_familyStatusFilter == null) {
      return List.unmodifiable(_familyMembers);
    }
    return List.unmodifiable(
      _familyMembers.where((m) => m.status == _familyStatusFilter),
    );
  }

  bool get familyCheckInSent => _familyCheckInSent;
  String? get familyInviteCode => _familyGroup?.inviteCode;
  String? get familyGroupName => _familyGroup?.name;
  bool get isRemoteConnected => dataSource != null;

  List<CitizenShelter> get shelters => List.unmodifiable(_shelters);
  CitizenShelter get nearestShelter => _shelters.first;
  CitizenShelter? get selectedShelter => _selectedShelter;
  List<CitizenHazardSpot> get hazardSpots => List.unmodifiable(_hazardSpots);
  bool get showHazardsOnMap => _showHazardsOnMap;

  List<CitizenMessage> get messages => List.unmodifiable(_messages);
  List<CitizenMessage> get municipalityNotices => List.unmodifiable(
        _messages
            .where((m) => m.kind == CitizenMessageKind.municipalityNotice),
      );
  List<CitizenMessage> get familyMessages => List.unmodifiable(
        _messages.where((m) => m.kind == CitizenMessageKind.familyThread),
      );
  CitizenMessageKind get activeMessageKind => _activeMessageKind;
  List<String> get quickReplyOptions => kCitizenQuickReplies;

  bool get notificationsEnabled => _notificationsEnabled;

  String get rescueNameDraft => _rescueNameDraft;
  String get rescueDetailDraft => _rescueDetailDraft;
  String get rescueCareDraft => _rescueCareDraft;
  RescueSummary? get latestRescueSummary => _latestRescueSummary;

  String? get toastMessage => _toastMessage;

  Future<T> _enqueueAuthOp<T>(Future<T> Function() op) {
    final next = _authOpChain.then((_) => op(), onError: (_) => op());
    _authOpChain = next.then((_) {}, onError: (_) {});
    return next;
  }

  bool get _isPublicMessagesSuperseded =>
      (authService != null && _isLoggedIn) ||
      authService?.currentUserId != null ||
      _familyGroup != null;

  CitizenRegistrationProfile _mergeProfile({
    required CitizenRegistrationProfile base,
    required CitizenRegistrationProfile overlay,
    required Iterable<_CitizenProfileField> overlayFields,
  }) {
    final fields = overlayFields.toSet();
    if (fields.isEmpty) return base;
    return base.copyWith(
      photoSelected: fields.contains(_CitizenProfileField.photoSelected)
          ? overlay.photoSelected
          : null,
      idDocSelected: fields.contains(_CitizenProfileField.idDocSelected)
          ? overlay.idDocSelected
          : null,
      name: fields.contains(_CitizenProfileField.name) ? overlay.name : null,
      birthDate: fields.contains(_CitizenProfileField.birthDate)
          ? overlay.birthDate
          : null,
      bloodType: fields.contains(_CitizenProfileField.bloodType)
          ? overlay.bloodType
          : null,
      gender:
          fields.contains(_CitizenProfileField.gender) ? overlay.gender : null,
      postalCode: fields.contains(_CitizenProfileField.postalCode)
          ? overlay.postalCode
          : null,
      prefecture: fields.contains(_CitizenProfileField.prefecture)
          ? overlay.prefecture
          : null,
      addressDetail: fields.contains(_CitizenProfileField.addressDetail)
          ? overlay.addressDetail
          : null,
      considerations: fields.contains(_CitizenProfileField.considerations)
          ? overlay.considerations
          : null,
      otherConsideration:
          fields.contains(_CitizenProfileField.otherConsideration)
              ? overlay.otherConsideration
              : null,
    );
  }

  void _clearDirtyFieldsUpTo(int maxSeq) {
    _fieldDirtySeq.removeWhere((_, seq) => seq <= maxSeq);
  }

  void _clearDirtyFieldsAtExactSeq(int exactSeq) {
    _fieldDirtySeq.removeWhere((_, seq) => seq == exactSeq);
  }

  void _rollbackFailedProfileSave(int reqSeq) {
    _clearDirtyFieldsAtExactSeq(reqSeq);
    _profile = _mergeProfile(
      base: _lastSyncedProfile,
      overlay: _profile,
      overlayFields: _fieldDirtySeq.keys,
    );
    if (_profileRequestSeq == reqSeq) {
      showToast('登録情報の保存に失敗しました');
    } else {
      notifyListeners();
    }
  }

  void goToScreen(CitizenScreen screen) {
    if (_disposed) return;
    if (_currentScreen == screen) return;
    _currentScreen = screen;
    notifyListeners();
  }

  void selectTab(CitizenTab tab) {
    if (_disposed) return;
    final changed =
        _currentTab != tab || _currentScreen != CitizenScreen.home;
    _currentTab = tab;
    _currentScreen = CitizenScreen.home;
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> initializeRemote() async {
    final ds = dataSource;
    if (_disposed || ds == null) return;
    final rev = _authRevision;
    final initMsgEpoch = _messageSubEpoch;

    await Future.wait(<Future<void>>[
      () async {
        try {
          final remoteShelters = await ds.fetchShelters();
          if (_disposed || _authRevision != rev) return;
          if (remoteShelters.isNotEmpty) {
            _shelters = remoteShelters;
            notifyListeners();
          }
        } catch (e) {
          appLog('MAMO 避難所初期取得エラー: $e');
        }
      }(),
      () async {
        try {
          final remoteHazards = await ds.fetchHazardSpots();
          if (_disposed || _authRevision != rev) return;
          if (remoteHazards.isNotEmpty) {
            _hazardSpots = remoteHazards;
            notifyListeners();
          }
        } catch (e) {
          appLog('MAMO 危険箇所初期取得エラー: $e');
        }
      }(),
      () async {
        try {
          final remoteMessages =
              await ds.fetchMessages(currentUserId: authService?.currentUserId);
          if (_disposed ||
              _authRevision != rev ||
              _messageSubEpoch != initMsgEpoch ||
              _familyGroup != null) {
            return;
          }
          if (remoteMessages.isNotEmpty) {
            _messages = remoteMessages;
            notifyListeners();
          }
        } catch (e) {
          appLog('MAMO メッセージ初期取得エラー: $e');
        }
      }(),
    ]);

    if (_disposed || _authRevision != rev) return;

    try {
      await _sheltersSub?.cancel();
      if (_disposed || _authRevision != rev) return;
      _sheltersSub = ds.subscribeShelters().listen(
        (shelters) {
          if (_disposed || shelters.isEmpty) return;
          _shelters = shelters;
          notifyListeners();
        },
        onError: (Object e) {
          appLog('MAMO 避難所購読エラー: $e');
        },
      );
    } catch (e) {
      appLog('MAMO 避難所購読開始エラー: $e');
    }

    if (_disposed ||
        _authRevision != rev ||
        _messageSubEpoch != initMsgEpoch ||
        _familyGroup != null ||
        (authService != null && _isLoggedIn)) {
      return;
    }

    final uid = authService?.currentUserId;
    if (uid != null) {
      await _enqueueAuthOp(() async {
        if (_disposed ||
            _authRevision != rev ||
            _messageSubEpoch != initMsgEpoch ||
            _familyGroup != null ||
            (authService != null && _isLoggedIn)) {
          return;
        }
        try {
          await _syncAuthenticatedUser(uid, expectedRevision: rev);
        } catch (e) {
          appLog('MAMO 認証ユーザー初期同期エラー: $e');
        }
      });
    } else {
      try {
        await _subscribeMessagesStream(
          groupId: null,
          userId: null,
          expectedRevision: rev,
        );
      } catch (e) {
        appLog('MAMO 公開メッセージ購読エラー: $e');
      }
    }
  }

  Future<void> _authenticateAndSync({bool forceUpsertProfile = false}) {
    final rev = _authRevision;
    return _enqueueAuthOp(() async {
      final ds = dataSource;
      final auth = authService;
      if (_disposed || _authRevision != rev || ds == null || auth == null) {
        return;
      }

      try {
        final uid = await auth.ensureAnonymousSession();
        if (_disposed || _authRevision != rev || uid == null) return;
        await _syncAuthenticatedUser(
          uid,
          forceUpsertProfile: forceUpsertProfile,
          expectedRevision: rev,
        );
      } catch (e) {
        appLog('MAMO 認証同期エラー: $e');
      }
    });
  }

  Future<void> _syncAuthenticatedUser(
    String userId, {
    bool forceUpsertProfile = false,
    int? expectedRevision,
  }) async {
    final ds = dataSource;
    if (_disposed ||
        ds == null ||
        (expectedRevision != null && _authRevision != expectedRevision)) {
      return;
    }

    if (forceUpsertProfile) {
      final reqSeqAtStart = _profileRequestSeq;
      final targetProfile = _profile;
      final targetSafety = _mySafety;
      await ds.upsertProfile(
        userId: userId,
        profile: targetProfile,
        safetyStatus: targetSafety,
      );
      if (_disposed ||
          (expectedRevision != null && _authRevision != expectedRevision)) {
        return;
      }
      _lastSyncedProfile = targetProfile;
      _lastSyncedSafety = targetSafety;
      _clearDirtyFieldsUpTo(reqSeqAtStart);
    } else {
      final safetySeqBeforeFetch = _safetyRequestSeq;
      final existing = await ds.fetchProfile(userId);
      if (_disposed ||
          (expectedRevision != null && _authRevision != expectedRevision)) {
        return;
      }
      if (existing != null) {
        _lastSyncedProfile = existing.profile;
        if (_fieldDirtySeq.isEmpty) {
          _profile = existing.profile;
        } else {
          _profile = _mergeProfile(
            base: existing.profile,
            overlay: _profile,
            overlayFields: _fieldDirtySeq.keys,
          );
        }
        _lastSyncedSafety = existing.safety;
        if (_safetyRequestSeq == safetySeqBeforeFetch) {
          _mySafety = existing.safety;
        }
      } else {
        final reqSeqAtStart = _profileRequestSeq;
        final targetProfile = _profile;
        final targetSafety = _mySafety;
        await ds.upsertProfile(
          userId: userId,
          profile: targetProfile,
          safetyStatus: targetSafety,
        );
        if (_disposed ||
            (expectedRevision != null && _authRevision != expectedRevision)) {
          return;
        }
        _lastSyncedProfile = targetProfile;
        _lastSyncedSafety = targetSafety;
        _clearDirtyFieldsUpTo(reqSeqAtStart);
      }
    }

    if (_disposed ||
        (expectedRevision != null && _authRevision != expectedRevision)) {
      return;
    }
    final group = await ds.fetchOrCreateDefaultFamilyGroup(
      userId: userId,
      displayName: _profile.effectiveDisplayName,
    );
    if (_disposed ||
        (expectedRevision != null && _authRevision != expectedRevision)) {
      return;
    }
    _familyGroup = group;

    if (group != null) {
      await _loadAndSubscribeFamily(
        group.id,
        userId,
        expectedRevision: expectedRevision,
      );
    }
    await _subscribeMessagesStream(
      groupId: group?.id,
      userId: userId,
      expectedRevision: expectedRevision,
    );
    if (_disposed ||
        (expectedRevision != null && _authRevision != expectedRevision)) {
      return;
    }
    notifyListeners();
  }

  Future<void> _loadAndSubscribeFamily(
    String groupId,
    String userId, {
    int? expectedRevision,
  }) async {
    final ds = dataSource;
    if (_disposed ||
        ds == null ||
        (expectedRevision != null && _authRevision != expectedRevision)) {
      return;
    }

    final members = await ds.fetchFamilyMembers(
      groupId,
      currentUserId: userId,
    );
    if (_disposed ||
        (expectedRevision != null && _authRevision != expectedRevision)) {
      return;
    }
    if (members.isNotEmpty) {
      _familyMembers = members;
    }

    final prevFamilySub = _familySub;
    _familySub = null;
    await prevFamilySub?.cancel();
    if (_disposed ||
        (expectedRevision != null && _authRevision != expectedRevision)) {
      return;
    }
    _familySub = ds
        .subscribeFamilyMembers(groupId, currentUserId: userId)
        .listen(
      (updated) {
        if (_disposed ||
            updated.isEmpty ||
            (expectedRevision != null && _authRevision != expectedRevision)) {
          return;
        }
        _familyMembers = updated;
        notifyListeners();
      },
      onError: (Object e) {
        appLog('MAMO 家族メンバー購読エラー: $e');
      },
    );
  }

  Future<void> _subscribeMessagesStream({
    required String? groupId,
    required String? userId,
    int? expectedRevision,
  }) async {
    final ds = dataSource;
    final isUnauthenticatedPublic = groupId == null && userId == null;
    if (_disposed ||
        ds == null ||
        (expectedRevision != null && _authRevision != expectedRevision) ||
        (isUnauthenticatedPublic && _isPublicMessagesSuperseded)) {
      return;
    }
    final msgEpoch = ++_messageSubEpoch;

    final fetched = await ds.fetchMessages(
      groupId: groupId,
      currentUserId: userId,
    );
    if (_disposed ||
        (expectedRevision != null && _authRevision != expectedRevision) ||
        _messageSubEpoch != msgEpoch ||
        (isUnauthenticatedPublic && _isPublicMessagesSuperseded)) {
      return;
    }
    if (fetched.isNotEmpty) {
      _messages = fetched;
      notifyListeners();
    }

    final prevSub = _messagesSub;
    _messagesSub = null;
    await prevSub?.cancel();
    if (_disposed ||
        (expectedRevision != null && _authRevision != expectedRevision) ||
        _messageSubEpoch != msgEpoch ||
        (isUnauthenticatedPublic && _isPublicMessagesSuperseded)) {
      return;
    }
    _messagesSub = ds
        .subscribeMessages(groupId: groupId, currentUserId: userId)
        .listen(
      (msg) {
        if (_disposed ||
            (expectedRevision != null && _authRevision != expectedRevision) ||
            _messageSubEpoch != msgEpoch) {
          return;
        }
        final alreadyExists = _messages.any((m) => m.id == msg.id);
        if (alreadyExists) return;
        // 直前にローカル楽観追加した同一メッセージとの重複を回避
        final optimisticIdx = _messages.indexWhere(
          (m) =>
              m.id.startsWith('msg-') &&
              m.isMine &&
              msg.isMine &&
              m.kind == msg.kind &&
              m.body == msg.body,
        );
        if (optimisticIdx != -1) {
          final next = List<CitizenMessage>.of(_messages);
          next[optimisticIdx] = msg;
          _messages = next;
        } else {
          _messages = <CitizenMessage>[..._messages, msg];
        }
        notifyListeners();
      },
      onError: (Object e) {
        appLog('MAMO メッセージ購読エラー: $e');
      },
    );
  }

  Future<bool> joinFamilyGroup(String inviteCode) async {
    final ds = dataSource;
    final trimmed = inviteCode.trim().toUpperCase();
    if (_disposed || trimmed.isEmpty) return false;
    if (ds == null) {
      showToast('オフラインのため家族グループに参加できません');
      return false;
    }
    final rev = _authRevision;

    return _enqueueAuthOp(() async {
      if (_disposed || _authRevision != rev) return false;
      final uid = authService?.currentUserId ??
          await authService?.ensureAnonymousSession();
      if (_disposed || _authRevision != rev) return false;
      if (uid == null) {
        showToast('認証に失敗したため家族グループに参加できませんでした');
        return false;
      }

      try {
        final group = await ds.joinFamilyGroupByCode(
          inviteCode: trimmed,
          displayName: _profile.effectiveDisplayName,
        );
        if (_disposed || _authRevision != rev) return false;
        if (group == null) {
          showToast('招待コードが見つかりませんでした');
          return false;
        }
        _familyGroup = group;
        await _loadAndSubscribeFamily(group.id, uid, expectedRevision: rev);
        await _subscribeMessagesStream(
          groupId: group.id,
          userId: uid,
          expectedRevision: rev,
        );
        if (_disposed || _authRevision != rev) return false;
        showToast('家族グループに参加しました');
        return true;
      } catch (e) {
        appLog('MAMO 家族グループ参加エラー: $e');
        if (!_disposed && _authRevision == rev) {
          showToast('家族グループへの参加に失敗しました（通信状況をご確認ください）');
        }
        return false;
      }
    });
  }

  void demoLogin({Duration delay = const Duration(milliseconds: 450)}) {
    if (_disposed) return;
    _demoLoginTimer?.cancel();
    _demoLoginTimer = null;
    _isLoggedIn = true;
    showToast(dataSource != null ? 'ログインしました' : 'デモログインしました');
    unawaited(_authenticateAndSync());
    if (delay <= Duration.zero) {
      _currentScreen = CitizenScreen.home;
      _currentTab = CitizenTab.home;
      notifyListeners();
      return;
    }
    _demoLoginTimer = Timer(delay, () {
      _demoLoginTimer = null;
      if (_disposed) return;
      _currentScreen = CitizenScreen.home;
      _currentTab = CitizenTab.home;
      notifyListeners();
    });
  }

  void logout() {
    _resetLocalSessionState(signOutRemote: true);
  }

  void selectPhotoDemo() {
    if (_disposed) return;
    final seq = ++_profileRequestSeq;
    _fieldDirtySeq[_CitizenProfileField.photoSelected] = seq;
    _profile = _profile.copyWith(photoSelected: true);
    showToast('デモ：写真アップロード画面を想定しています');
  }

  void selectIdDocDemo() {
    if (_disposed) return;
    final seq = ++_profileRequestSeq;
    _fieldDirtySeq[_CitizenProfileField.idDocSelected] = seq;
    _profile = _profile.copyWith(idDocSelected: true);
    showToast('デモ：身分証選択');
  }

  void updateBasicInfo({
    String? name,
    String? birthDate,
    String? bloodType,
    String? gender,
    String? postalCode,
    String? prefecture,
    String? addressDetail,
  }) {
    if (_disposed) return;
    final seq = ++_profileRequestSeq;
    if (name != null) _fieldDirtySeq[_CitizenProfileField.name] = seq;
    if (birthDate != null) {
      _fieldDirtySeq[_CitizenProfileField.birthDate] = seq;
    }
    if (bloodType != null) {
      _fieldDirtySeq[_CitizenProfileField.bloodType] = seq;
    }
    if (gender != null) _fieldDirtySeq[_CitizenProfileField.gender] = seq;
    if (postalCode != null) {
      _fieldDirtySeq[_CitizenProfileField.postalCode] = seq;
    }
    if (prefecture != null) {
      _fieldDirtySeq[_CitizenProfileField.prefecture] = seq;
    }
    if (addressDetail != null) {
      _fieldDirtySeq[_CitizenProfileField.addressDetail] = seq;
    }
    _profile = _profile.copyWith(
      name: name,
      birthDate: birthDate,
      bloodType: bloodType,
      gender: gender,
      postalCode: postalCode,
      prefecture: prefecture,
      addressDetail: addressDetail,
    );
    notifyListeners();
  }

  /// 設定タブのプロフィール編集をローカル反映し、接続時は Supabase `profiles` へ保存する
  Future<bool> saveProfileEdits({
    String? name,
    String? addressDetail,
  }) async {
    if (_disposed) return false;
    final reqSeq = ++_profileRequestSeq;
    if (name != null) {
      _fieldDirtySeq[_CitizenProfileField.name] = reqSeq;
    }
    if (addressDetail != null) {
      _fieldDirtySeq[_CitizenProfileField.addressDetail] = reqSeq;
    }
    _profile = _profile.copyWith(
      name: name,
      addressDetail: addressDetail,
    );

    final ds = dataSource;
    if (ds == null) {
      _lastSyncedProfile = _profile;
      _clearDirtyFieldsUpTo(reqSeq);
      showToast('登録情報を保存しました');
      return true;
    }

    notifyListeners();
    final rev = _authRevision;
    return _enqueueAuthOp(() async {
      if (_disposed || _authRevision != rev) return false;
      var uid = authService?.currentUserId;
      if (uid == null && _isLoggedIn && authService != null) {
        uid = await authService!.ensureAnonymousSession();
      }
      if (_disposed || _authRevision != rev) return false;
      if (uid == null) {
        _rollbackFailedProfileSave(reqSeq);
        return false;
      }

      final priorDirtyFields = _fieldDirtySeq.entries
          .where((e) => e.value < reqSeq)
          .map((e) => e.key);
      final base = _mergeProfile(
        base: _lastSyncedProfile,
        overlay: _profile,
        overlayFields: priorDirtyFields,
      );
      final targetProfile = base.copyWith(
        name: name,
        addressDetail: addressDetail,
      );

      try {
        await ds.upsertProfile(
          userId: uid,
          profile: targetProfile,
          safetyStatus: _lastSyncedSafety,
        );
        if (_disposed || _authRevision != rev) return false;
        _lastSyncedProfile = targetProfile;
        _clearDirtyFieldsUpTo(reqSeq);
        if (_profileRequestSeq == reqSeq) {
          _profile = targetProfile;
          showToast('登録情報を保存しました');
        } else {
          _profile = _mergeProfile(
            base: _lastSyncedProfile,
            overlay: _profile,
            overlayFields: _fieldDirtySeq.keys,
          );
          notifyListeners();
        }
        return true;
      } catch (e) {
        appLog('MAMO プロフィール保存エラー: $e');
        if (_disposed || _authRevision != rev) return false;
        _rollbackFailedProfileSave(reqSeq);
        return false;
      }
    });
  }

  void toggleConsideration(String option) {
    if (_disposed) return;
    final seq = ++_profileRequestSeq;
    _fieldDirtySeq[_CitizenProfileField.considerations] = seq;
    final next = Set<String>.from(_profile.considerations);
    if (!next.add(option)) {
      next.remove(option);
    }
    _profile = _profile.copyWith(considerations: next);
    notifyListeners();
  }

  void updateOtherConsideration(String text) {
    if (_disposed) return;
    final seq = ++_profileRequestSeq;
    _fieldDirtySeq[_CitizenProfileField.otherConsideration] = seq;
    _profile = _profile.copyWith(otherConsideration: text);
    notifyListeners();
  }

  void completeRegistration() {
    if (_disposed) return;
    final seq = ++_profileRequestSeq;
    _fieldDirtySeq[_CitizenProfileField.name] = seq;
    _profile = _profile.copyWith(name: _profile.name.trim());
    _isLoggedIn = true;
    _currentScreen = CitizenScreen.home;
    _currentTab = CitizenTab.home;
    unawaited(_authenticateAndSync(forceUpsertProfile: true));
    showToast(dataSource != null ? '登録が完了しました' : '登録が完了しました（デモ）');
  }

  void _applyLocalSafetyStatus(CitizenSafetyStatus status) {
    _mySafety = status;
    _familyMembers = _familyMembers
        .map(
          (m) => (m.isSelf || m.id == 'self')
              ? m.copyWith(status: status, lastUpdated: 'たった今')
              : m,
        )
        .toList();
  }

  void updateMySafety(
    CitizenSafetyStatus status, {
    bool showFeedbackToast = true,
  }) {
    if (_disposed) return;
    final reqSeq = ++_safetyRequestSeq;
    final rev = _authRevision;

    _applyLocalSafetyStatus(status);
    if (showFeedbackToast) {
      showToast(status.toastMessage);
    } else {
      notifyListeners();
    }

    final ds = dataSource;
    if (ds == null) {
      _lastSyncedSafety = status;
      return;
    }

    unawaited(
      _enqueueAuthOp(() async {
        if (_disposed ||
            _authRevision != rev ||
            _safetyRequestSeq != reqSeq) {
          return;
        }
        var uid = authService?.currentUserId;
        if (uid == null && authService != null) {
          uid = await authService!.ensureAnonymousSession();
        }
        if (_disposed ||
            _authRevision != rev ||
            _safetyRequestSeq != reqSeq) {
          return;
        }
        if (uid == null) {
          _applyLocalSafetyStatus(_lastSyncedSafety);
          showToast('安否ステータスの更新に失敗しました');
          return;
        }
        try {
          await ds.updateSafetyStatus(userId: uid, status: status);
          if (_disposed || _authRevision != rev) return;
          _lastSyncedSafety = status;
          if (_safetyRequestSeq == reqSeq) {
            _applyLocalSafetyStatus(status);
            notifyListeners();
          }
        } catch (e) {
          appLog('MAMO 安否更新エラー: $e');
          if (_disposed ||
              _authRevision != rev ||
              _safetyRequestSeq != reqSeq) {
            return;
          }
          _applyLocalSafetyStatus(_lastSyncedSafety);
          showToast('安否ステータスの更新に失敗しました');
        }
      }),
    );
  }

  void setFamilyStatusFilter(CitizenSafetyStatus? filter) {
    if (_disposed) return;
    if (_familyStatusFilter == filter) return;
    _familyStatusFilter = filter;
    notifyListeners();
  }

  void sendFamilySafetyCheck() {
    if (_disposed) return;
    _familyCheckInSent = true;
    showToast('家族に安否確認通知を送信しました（デモ）');
  }

  void selectShelter(CitizenShelter? shelter) {
    if (_disposed) return;
    _selectedShelter = shelter;
    notifyListeners();
  }

  void selectShelterById(String? id) {
    if (_disposed) return;
    if (id == null) {
      _selectedShelter = null;
      notifyListeners();
      return;
    }
    for (final s in _shelters) {
      if (s.id == id) {
        _selectedShelter = s;
        notifyListeners();
        return;
      }
    }
  }

  void toggleHazardsOnMap() {
    if (_disposed) return;
    _showHazardsOnMap = !_showHazardsOnMap;
    notifyListeners();
  }

  void setActiveMessageKind(CitizenMessageKind kind) {
    if (_disposed) return;
    if (_activeMessageKind == kind) return;
    _activeMessageKind = kind;
    notifyListeners();
  }

  void sendMessage(
    String body, {
    CitizenMessageKind kind = CitizenMessageKind.familyThread,
  }) {
    if (_disposed) return;
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final tempId = 'msg-${now.microsecondsSinceEpoch}';
    _messages = <CitizenMessage>[
      ..._messages,
      CitizenMessage(
        id: tempId,
        kind: kind,
        sender: _profile.effectiveDisplayName,
        avatar: '🙂',
        body: trimmed,
        time: _formatHHmm(now),
        isMine: true,
      ),
    ];
    _activeMessageKind = kind;
    final ds = dataSource;
    if (ds != null) {
      notifyListeners();
      unawaited(
        _sendRemoteMessage(
          ds: ds,
          tempId: tempId,
          kind: kind,
          senderName: _profile.effectiveDisplayName,
          body: trimmed,
          expectedRevision: _authRevision,
        ),
      );
    } else {
      showToast('メッセージを送信しました（デモ）');
    }
  }

  void _removeOptimisticMessage(String tempId) {
    _messages = _messages.where((m) => m.id != tempId).toList();
  }

  Future<void> _sendRemoteMessage({
    required CitizenDataSource ds,
    required String tempId,
    required CitizenMessageKind kind,
    required String senderName,
    required String body,
    required int expectedRevision,
  }) async {
    try {
      final sent = await _enqueueAuthOp(() async {
        if (_disposed || _authRevision != expectedRevision) return null;
        var uid = authService?.currentUserId;
        if (uid == null && kind == CitizenMessageKind.familyThread) {
          uid = await authService?.ensureAnonymousSession();
        }
        if (_disposed || _authRevision != expectedRevision) return null;
        var groupId = _familyGroup?.id;
        if (groupId == null &&
            kind == CitizenMessageKind.familyThread &&
            uid != null) {
          final group = await ds.fetchOrCreateDefaultFamilyGroup(
            userId: uid,
            displayName: senderName,
          );
          if (!_disposed &&
              _authRevision == expectedRevision &&
              group != null) {
            _familyGroup = group;
            groupId = group.id;
            await _loadAndSubscribeFamily(
              group.id,
              uid,
              expectedRevision: expectedRevision,
            );
            await _subscribeMessagesStream(
              groupId: group.id,
              userId: uid,
              expectedRevision: expectedRevision,
            );
          }
        }
        if (_disposed || _authRevision != expectedRevision) return null;
        if (kind == CitizenMessageKind.familyThread &&
            (uid == null || groupId == null)) {
          return null;
        }
        return ds.sendMessage(
          kind: kind,
          senderName: senderName,
          body: body,
          groupId: kind == CitizenMessageKind.familyThread ? groupId : null,
          senderId: uid,
        );
      });

      if (_disposed || _authRevision != expectedRevision) return;
      if (sent == null) {
        _removeOptimisticMessage(tempId);
        showToast('メッセージの送信に失敗しました');
        return;
      }

      final next = List<CitizenMessage>.of(_messages);
      final tempIdx = next.indexWhere((m) => m.id == tempId);
      final realIdx = next.indexWhere((m) => m.id == sent.id);
      if (realIdx != -1) {
        if (tempIdx != -1 && tempIdx != realIdx) {
          next.removeAt(tempIdx);
        }
      } else if (tempIdx != -1) {
        next[tempIdx] = sent;
      } else {
        next.add(sent);
      }
      _messages = next;
      showToast('メッセージを送信しました');
    } catch (e) {
      appLog('MAMO メッセージ送信エラー: $e');
      if (_disposed || _authRevision != expectedRevision) return;
      _removeOptimisticMessage(tempId);
      showToast('メッセージの送信に失敗しました');
    }
  }

  void sendQuickReply(String reply) {
    sendMessage(reply, kind: CitizenMessageKind.familyThread);
  }

  void openRescue() {
    if (_disposed) return;
    _rescueNameDraft = _profile.effectiveDisplayName;
    _rescueDetailDraft = '';
    _rescueCareDraft = _profile.formattedConsiderations;
    _currentScreen = CitizenScreen.rescue;
    notifyListeners();
  }

  void updateRescueDraft({
    String? name,
    String? detail,
    String? care,
  }) {
    if (_disposed) return;
    if (name != null) _rescueNameDraft = name;
    if (detail != null) _rescueDetailDraft = detail;
    if (care != null) _rescueCareDraft = care;
    notifyListeners();
  }

  Future<RescueRequest>? _inflightRescue;
  String? _inflightRescueKey;

  /// 二重送信防止: 同一内容の送信処理中の再呼び出し（連打）は同一の送信結果を共有する
  Future<RescueRequest> submitRescue(
    RescueStore rescueStore, {
    String? name,
    String? detail,
    String? care,
    String locationText = '〇〇地区付近',
    String distanceText = '約150m先（デモ）',
  }) {
    final key = [name ?? _rescueNameDraft, detail ?? _rescueDetailDraft, care ?? _rescueCareDraft, locationText].join('\u0000');
    final inflight = _inflightRescue;
    if (inflight != null && _inflightRescueKey == key) return inflight;
    final future = _submitRescueImpl(
      rescueStore,
      name: name,
      detail: detail,
      care: care,
      locationText: locationText,
      distanceText: distanceText,
    );
    late final Future<RescueRequest> guarded;
    guarded = future.whenComplete(() {
      if (identical(_inflightRescue, guarded)) {
        _inflightRescue = null;
        _inflightRescueKey = null;
      }
    });
    _inflightRescue = guarded;
    _inflightRescueKey = key;
    return guarded;
  }

  Future<RescueRequest> _submitRescueImpl(
    RescueStore rescueStore, {
    String? name,
    String? detail,
    String? care,
    String locationText = '〇〇地区付近',
    String distanceText = '約150m先（デモ）',
  }) async {
    final rawName = name ?? _rescueNameDraft;
    final rawDetail = detail ?? _rescueDetailDraft;
    final rawCare = care ?? _rescueCareDraft;

    final resolvedName = rawName.trim().isEmpty
        ? _profile.effectiveDisplayName
        : rawName.trim();
    final resolvedDetail =
        rawDetail.trim().isEmpty ? '救助が必要です' : rawDetail.trim();
    final resolvedCare =
        rawCare.trim().isEmpty ? 'なし' : rawCare.trim();
    final resolvedLocation =
        locationText.trim().isEmpty ? '〇〇地区付近' : locationText.trim();

    if (!_disposed) {
      updateMySafety(CitizenSafetyStatus.rescueNeeded, showFeedbackToast: false);
    }

    final previousHeadId =
        rescueStore.requests.isNotEmpty ? rescueStore.requests.first.id : null;
    final future = rescueStore.submitCitizenRequest(
      requesterName: resolvedName,
      rescueDetails: resolvedDetail,
      considerations: resolvedCare,
      locationText: resolvedLocation,
      distanceText: distanceText,
    );

    String? immediateId;
    if (!_disposed) {
      final immediate = (rescueStore.requests.isNotEmpty &&
              rescueStore.requests.first.id != previousHeadId)
          ? rescueStore.requests.first
          : null;
      immediateId =
          immediate?.id ?? 'MAMO-${DateTime.now().millisecondsSinceEpoch}';
      _latestRescueSummary = RescueSummary(
        requestId: immediateId,
        time: immediate?.time ?? _formatHHmm(DateTime.now()),
        requesterName: immediate?.name ?? resolvedName,
        locationText: immediate?.location ?? resolvedLocation,
        detail: immediate?.content ?? resolvedDetail,
        considerations: immediate?.consideration ?? resolvedCare,
        syncedToRemote: immediate?.dbId != null,
      );
      _currentScreen = CitizenScreen.rescueSent;
      notifyListeners();
    }

    final submitted = await future;
    if (_disposed ||
        immediateId == null ||
        _latestRescueSummary?.requestId != immediateId) {
      return submitted;
    }

    _latestRescueSummary = _latestRescueSummary?.copyWith(
      requestId: submitted.id,
      time: submitted.time,
      requesterName: submitted.name,
      locationText: submitted.location,
      detail: submitted.content,
      considerations: submitted.consideration,
      syncedToRemote: submitted.dbId != null,
    );

    if (rescueStore.dataSource == null) {
      showToast('デモ送信（Supabase未接続）');
    } else if (submitted.dbId != null) {
      showToast('自治体へ救助要請を送信しました');
    } else {
      showToast('デモ送信（ローカル反映・未接続）');
    }

    return submitted;
  }

  void setNotificationsEnabled(bool enabled) {
    if (_disposed) return;
    _notificationsEnabled = enabled;
    showToast(enabled ? '災害通知をオンにしました' : '災害通知をオフにしました');
  }

  void resetDemo() {
    _resetLocalSessionState(signOutRemote: true);
  }

  void _resetLocalSessionState({required bool signOutRemote}) {
    if (_disposed) return;
    final rev = ++_authRevision;
    _messageSubEpoch++;
    _safetyRequestSeq++;
    _profileRequestSeq++;
    _fieldDirtySeq.clear();

    _toastTimer?.cancel();
    _toastTimer = null;
    _demoLoginTimer?.cancel();
    _demoLoginTimer = null;

    _currentScreen = CitizenScreen.login;
    _currentTab = CitizenTab.home;
    _profile = const CitizenRegistrationProfile();
    _lastSyncedProfile = const CitizenRegistrationProfile();
    _isLoggedIn = false;
    _mySafety = CitizenSafetyStatus.safe;
    _lastSyncedSafety = CitizenSafetyStatus.safe;
    _familyMembers = createInitialFamilyMembers();
    _familyGroup = null;
    unawaited(_familySub?.cancel());
    _familySub = null;
    unawaited(_messagesSub?.cancel());
    _messagesSub = null;
    _familyStatusFilter = null;
    _familyCheckInSent = false;
    _selectedShelter = null;
    _showHazardsOnMap = true;
    _messages = createInitialCitizenMessages();
    _activeMessageKind = CitizenMessageKind.municipalityNotice;
    _notificationsEnabled = true;
    _rescueNameDraft = 'あなた';
    _rescueDetailDraft = '';
    _rescueCareDraft = '';
    _latestRescueSummary = null;
    _toastMessage = null;
    notifyListeners();

    if (signOutRemote && authService != null) {
      unawaited(
        _enqueueAuthOp(() async {
          if (_disposed || _authRevision != rev) return;
          try {
            await authService!.signOut();
          } catch (e) {
            appLog('MAMO サインアウトエラー: $e');
          }
          if (_disposed || _authRevision != rev || _isPublicMessagesSuperseded) {
            return;
          }
          if (dataSource != null) {
            try {
              await _subscribeMessagesStream(
                groupId: null,
                userId: null,
                expectedRevision: rev,
              );
            } catch (e) {
              appLog('MAMO ログアウト後メッセージ再購読エラー: $e');
            }
          }
        }),
      );
    }
  }

  void showToast(
    String message, {
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    if (_disposed) return;
    _toastTimer?.cancel();
    _toastTimer = null;
    _toastMessage = message;
    notifyListeners();

    if (duration > Duration.zero) {
      _toastTimer = Timer(duration, () {
        _toastTimer = null;
        if (_disposed) return;
        _toastMessage = null;
        notifyListeners();
      });
    }
  }

  void clearToast() {
    _toastTimer?.cancel();
    _toastTimer = null;
    if (_disposed) return;
    if (_toastMessage != null) {
      _toastMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _authRevision++;
    _messageSubEpoch++;
    _safetyRequestSeq++;
    _profileRequestSeq++;
    _fieldDirtySeq.clear();
    _toastTimer?.cancel();
    _toastTimer = null;
    _demoLoginTimer?.cancel();
    _demoLoginTimer = null;
    unawaited(_familySub?.cancel());
    unawaited(_messagesSub?.cancel());
    unawaited(_sheltersSub?.cancel());
    if (dataSource != null) {
      unawaited(dataSource!.dispose());
    }
    authService?.dispose();
    super.dispose();
  }

  static String _formatHHmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
