import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/citizen_models.dart';
import '../models/rescue_request.dart';
import 'rescue_store.dart';

/// 利用者（住民・スマホ）側の状態管理ストア
class CitizenStore extends ChangeNotifier {
  CitizenStore()
      : _familyMembers = createInitialFamilyMembers(),
        _messages = createInitialCitizenMessages();

  CitizenScreen _currentScreen = CitizenScreen.login;
  CitizenTab _currentTab = CitizenTab.home;
  CitizenRegistrationProfile _profile = const CitizenRegistrationProfile();
  bool _isLoggedIn = false;

  CitizenSafetyStatus _mySafety = CitizenSafetyStatus.safe;
  List<FamilyMember> _familyMembers;
  CitizenSafetyStatus? _familyStatusFilter;
  bool _familyCheckInSent = false;

  final List<CitizenShelter> _shelters = kInitialCitizenShelters;
  CitizenShelter? _selectedShelter;
  final List<CitizenHazardSpot> _hazardSpots = kInitialCitizenHazards;
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

  void demoLogin({Duration delay = const Duration(milliseconds: 450)}) {
    if (_disposed) return;
    _demoLoginTimer?.cancel();
    _demoLoginTimer = null;
    _isLoggedIn = true;
    showToast('デモログインしました');
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
    if (_disposed) return;
    _demoLoginTimer?.cancel();
    _demoLoginTimer = null;
    _isLoggedIn = false;
    _currentScreen = CitizenScreen.login;
    _currentTab = CitizenTab.home;
    notifyListeners();
  }

  void selectPhotoDemo() {
    if (_disposed) return;
    _profile = _profile.copyWith(photoSelected: true);
    showToast('デモ：写真アップロード画面を想定しています');
  }

  void selectIdDocDemo() {
    if (_disposed) return;
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

  void toggleConsideration(String option) {
    if (_disposed) return;
    final next = Set<String>.from(_profile.considerations);
    if (!next.add(option)) {
      next.remove(option);
    }
    _profile = _profile.copyWith(considerations: next);
    notifyListeners();
  }

  void updateOtherConsideration(String text) {
    if (_disposed) return;
    _profile = _profile.copyWith(otherConsideration: text);
    notifyListeners();
  }

  void completeRegistration() {
    if (_disposed) return;
    _profile = _profile.copyWith(name: _profile.name.trim());
    _isLoggedIn = true;
    _currentScreen = CitizenScreen.home;
    _currentTab = CitizenTab.home;
    showToast('登録が完了しました（デモ）');
  }

  void updateMySafety(
    CitizenSafetyStatus status, {
    bool showFeedbackToast = true,
  }) {
    if (_disposed) return;
    _mySafety = status;
    _familyMembers = _familyMembers
        .map(
          (m) => (m.isSelf || m.id == 'self')
              ? m.copyWith(status: status, lastUpdated: 'たった今')
              : m,
        )
        .toList();
    if (showFeedbackToast) {
      showToast(status.toastMessage);
    } else {
      notifyListeners();
    }
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
    _messages = <CitizenMessage>[
      ..._messages,
      CitizenMessage(
        id: 'msg-${now.microsecondsSinceEpoch}',
        kind: kind,
        sender: _profile.effectiveDisplayName,
        avatar: '🙂',
        body: trimmed,
        time: _formatHHmm(now),
        isMine: true,
      ),
    ];
    _activeMessageKind = kind;
    showToast('メッセージを送信しました（デモ）');
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

  Future<RescueRequest> submitRescue(
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
    if (_disposed) return;
    _toastTimer?.cancel();
    _toastTimer = null;
    _demoLoginTimer?.cancel();
    _demoLoginTimer = null;

    _currentScreen = CitizenScreen.login;
    _currentTab = CitizenTab.home;
    _profile = const CitizenRegistrationProfile();
    _isLoggedIn = false;
    _mySafety = CitizenSafetyStatus.safe;
    _familyMembers = createInitialFamilyMembers();
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
    _toastTimer?.cancel();
    _toastTimer = null;
    _demoLoginTimer?.cancel();
    _demoLoginTimer = null;
    super.dispose();
  }

  static String _formatHHmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
