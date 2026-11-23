import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/rescue_request.dart';

/// 初期デモデータ（mamo/app/composables/useRescueData.ts と同一）
const List<RescueRequest> _initialRequests = [
  RescueRequest(
    id: 'mamo-0005',
    time: '10:24:35',
    name: '山田 太郎',
    age: 32,
    gender: '男性',
    agency: AgencyType.emergency,
    location: '○○市○○町1-2-3付近',
    distance: '約120m先',
    content: '転倒して足を痛めて動けません。意識はあります。早急に救助をお願いします。',
    consideration: 'ホルモン治療中',
    latPercent: 24,
    topPercent: 28,
    status: RequestStatus.pending,
  ),
  RescueRequest(
    id: 'mamo-0004',
    time: '10:21:18',
    name: '佐藤 花子',
    age: 45,
    gender: '女性',
    agency: AgencyType.fire,
    location: '○○市○○町4-5付近',
    distance: '約550m先',
    content: '建物内に取り残されています。',
    consideration: '医療的ケアが必要',
    latPercent: 48,
    topPercent: 55,
    status: RequestStatus.pending,
  ),
  RescueRequest(
    id: 'mamo-0003',
    time: '10:18:59',
    name: '鈴木 一郎',
    age: 28,
    gender: '男性',
    agency: AgencyType.sdf,
    location: '○○市○○町2-1付近',
    distance: '約1.2km先',
    content: '道路が塞がれて移動できません。',
    consideration: 'なし',
    latPercent: 67,
    topPercent: 31,
    status: RequestStatus.pending,
  ),
  RescueRequest(
    id: 'mamo-0002',
    time: '10:15:42',
    name: '田中 美咲',
    age: 36,
    gender: '女性',
    agency: AgencyType.police,
    location: '○○市○○町3-7付近',
    distance: '約2.5km先',
    content: '家族と連絡が取れず避難場所から動けません。',
    consideration: '妊娠中',
    latPercent: 37,
    topPercent: 72,
    status: RequestStatus.working,
  ),
  RescueRequest(
    id: 'mamo-0001',
    time: '10:10:08',
    name: '高橋 健',
    age: 52,
    gender: '男性',
    agency: AgencyType.fire,
    location: '○○市○○町5-8付近',
    distance: '約3.8km先',
    content: '自宅周辺が浸水しています。救助をお願いします。',
    consideration: '人工呼吸器使用',
    latPercent: 78,
    topPercent: 60,
    status: RequestStatus.working,
  ),
];

/// MAMO アプリ全体の状態管理ストア
class RescueStore extends ChangeNotifier {
  RescueStore({bool startClock = true})
      : _requests = List<RescueRequest>.of(_initialRequests) {
    _updateClockValue();
    if (startClock) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateClockValue();
        notifyListeners();
      });
    }
  }

  MamoView _currentView = MamoView.dashboard;
  AgencyType? _currentAgencyFilter;
  RequestStatus? _statusFilter;
  final List<RescueRequest> _requests;
  String _selectedId = 'mamo-0005';
  String _municipalityName = '○○市 災害対策本部';
  bool _realtimeNotification = true;
  String _currentTime = '';
  Timer? _clockTimer;

  MamoView get currentView => _currentView;
  AgencyType? get currentAgencyFilter => _currentAgencyFilter;
  RequestStatus? get statusFilter => _statusFilter;
  List<RescueRequest> get requests => List.unmodifiable(_requests);
  String get selectedId => _selectedId;
  String get municipalityName => _municipalityName;
  bool get realtimeNotification => _realtimeNotification;
  String get currentTime => _currentTime;

  int get newCount =>
      _requests.where((r) => r.status == RequestStatus.pending).length;

  int get workingCount =>
      _requests.where((r) => r.status == RequestStatus.working).length;

  int get doneCount =>
      _requests.where((r) => r.status == RequestStatus.done).length;

  List<RescueRequest> get filteredRequests {
    return _requests.where((r) {
      final matchStatus = _statusFilter == null || r.status == _statusFilter;
      final matchAgency =
          _currentAgencyFilter == null || r.agency == _currentAgencyFilter;
      return matchStatus && matchAgency;
    }).toList();
  }

  RescueRequest? get selectedRequest {
    if (_requests.isEmpty) return null;
    for (final r in _requests) {
      if (r.id == _selectedId) return r;
    }
    return _requests.first;
  }

  void setView(MamoView view) {
    if (_currentView == view) return;
    _currentView = view;
    notifyListeners();
  }

  void setStatusFilter(RequestStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
  }

  void setAgencyFilter(AgencyType? agency) {
    if (_currentAgencyFilter == agency) return;
    _currentAgencyFilter = agency;
    notifyListeners();
  }

  void selectRequest(String id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void selectFromMap(String id) {
    _selectedId = id;
    _currentView = MamoView.requests;
    notifyListeners();
  }

  void changeStatus(String id, RequestStatus newStatus) {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index == -1) return;
    _requests[index] = _requests[index].copyWith(status: newStatus);
    notifyListeners();
  }

  void filterAgency(AgencyType agency) {
    _currentAgencyFilter = agency;
    _statusFilter = null;
    _currentView = MamoView.requests;
    notifyListeners();
  }

  void updateSettings({
    required String municipalityName,
    required bool realtimeNotification,
  }) {
    final trimmed = municipalityName.trim();
    if (trimmed.isNotEmpty) {
      _municipalityName = trimmed;
    }
    _realtimeNotification = realtimeNotification;
    notifyListeners();
  }

  void _updateClockValue() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    _currentTime = '$h:$m:$s';
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}
