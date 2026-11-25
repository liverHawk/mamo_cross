import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/citizen_models.dart';
import '../models/rescue_request.dart';
import '../services/rescue_data_source.dart';
import '../utils/app_logger.dart';

/// MAMO アプリ全体の状態管理ストア
class RescueStore extends ChangeNotifier {
  RescueStore({
    bool startClock = true,
    this.dataSource,
    bool autoInitialize = true,
  }) : _requests = <RescueRequest>[] {
    _updateClockValue();
    if (startClock) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_disposed) return;
        _updateClockValue();
        notifyListeners();
      });
    }
    if (dataSource != null && autoInitialize) {
      unawaited(initializeRealtime());
    }
  }

  final RescueDataSource? dataSource;
  MamoView _currentView = MamoView.dashboard;
  AgencyType? _currentAgencyFilter;
  RequestStatus? _statusFilter;
  final List<RescueRequest> _requests;
  String _selectedId = '';
  String _municipalityName = '山口県 災害対策本部';
  bool _realtimeNotification = true;
  String _currentTime = '';
  bool _isRealtimeConnected = false;
  bool _disposed = false;
  Timer? _clockTimer;
  Future<void>? _initFuture;
  StreamSubscription<RescueRealtimeEvent>? _realtimeSubscription;
  final StreamController<RescueRequest> _incomingAlertController =
      StreamController<RescueRequest>.broadcast();

  static RescueRequest dbRowToRequest(Map<String, dynamic> row) =>
      RescueRequest.fromSupabaseRow(row);

  MamoView get currentView => _currentView;
  AgencyType? get currentAgencyFilter => _currentAgencyFilter;
  RequestStatus? get statusFilter => _statusFilter;
  List<RescueRequest> get requests => List.unmodifiable(_requests);
  String get selectedId => _selectedId;
  String get municipalityName => _municipalityName;
  bool get realtimeNotification => _realtimeNotification;
  String get currentTime => _currentTime;
  bool get isRealtimeConnected => _isRealtimeConnected;
  Stream<RescueRequest> get incomingAlerts => _incomingAlertController.stream;

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
    if (_disposed || _currentView == view) return;
    _currentView = view;
    notifyListeners();
  }

  void setStatusFilter(RequestStatus? status) {
    if (_disposed || _statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
  }

  void setAgencyFilter(AgencyType? agency) {
    if (_disposed || _currentAgencyFilter == agency) return;
    _currentAgencyFilter = agency;
    notifyListeners();
  }

  void selectRequest(String id) {
    if (_disposed || _selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void selectFromMap(String id) {
    if (_disposed) return;
    _selectedId = id;
    _currentView = MamoView.requests;
    notifyListeners();
  }

  Future<void> initializeRealtime() {
    if (_disposed || dataSource == null) {
      return Future.value();
    }
    return _initFuture ??= _performInitializeRealtime();
  }

  Future<void> _performInitializeRealtime() async {
    final ds = dataSource;
    if (_disposed || ds == null) return;

    try {
      final rows = await ds.fetchInitialRequests(limit: 50);
      if (_disposed) return;
      for (final row in rows.reversed) {
        addDbRequest(row, notifyAlert: false);
      }
    } catch (e) {
      appLog('MAMO DB取得エラー: $e');
    }

    if (_disposed) return;

    try {
      await _realtimeSubscription?.cancel();
      if (_disposed) return;
      _realtimeSubscription = ds
          .subscribeRequests(
            onConnectionChanged: (connected) {
              if (_disposed) return;
              if (_isRealtimeConnected != connected) {
                _isRealtimeConnected = connected;
                notifyListeners();
              }
            },
          )
          .listen(
            (event) {
              if (_disposed) return;
              switch (event) {
                case RescueInsertedEvent(:final row):
                  addDbRequest(row, notifyAlert: true);
                case RescueUpdatedEvent(:final row):
                  applyRemoteUpdate(row);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              appLog('MAMO Realtimeエラー: $error');
              if (_disposed) return;
              if (_isRealtimeConnected) {
                _isRealtimeConnected = false;
                notifyListeners();
              }
            },
          );
    } catch (e) {
      appLog('MAMO Realtime購読エラー: $e');
      if (!_disposed && _isRealtimeConnected) {
        _isRealtimeConnected = false;
        notifyListeners();
      }
    }
  }

  bool addDbRequest(Map<String, dynamic> row, {bool notifyAlert = false}) {
    if (_disposed) return false;
    final req = dbRowToRequest(row);
    if (req.dbId != null &&
        _requests.any((v) => v.dbId != null && v.dbId == req.dbId)) {
      return false;
    }

    final rawRequestId = row['request_id']?.toString().trim() ?? '';
    if (rawRequestId.isNotEmpty &&
        req.dbId == null &&
        _requests.any((v) => v.id == req.id)) {
      return false;
    }

    if (req.dbId != null && rawRequestId.isNotEmpty) {
      final localIndex = _requests.indexWhere(
        (v) => v.dbId == null && v.id == req.id,
      );
      if (localIndex != -1) {
        final localReq = _requests[localIndex];
        final parsedCoords = RescueRequest.parseCoordinates(row);
        _requests[localIndex] = localReq.copyWith(
          dbId: req.dbId,
          latitude: parsedCoords?.latitude,
          longitude: parsedCoords?.longitude,
        );
        notifyListeners();
        final ds = dataSource;
        if (ds != null && localReq.status != req.status) {
          unawaited(
            Future<void>.sync(
              () => ds.updateStatus(dbId: req.dbId!, status: localReq.status),
            ).catchError((Object e) {
              appLog('MAMO追送ステータス更新エラー: $e');
            }),
          );
        }
        return false;
      }
    }

    var nextReq = req;
    if (req.dbId != null && _requests.any((v) => v.id == nextReq.id)) {
      nextReq = nextReq.copyWith(id: '${nextReq.id}#${req.dbId}');
    }

    _requests.insert(0, nextReq);
    _selectedId = nextReq.id;
    notifyListeners();
    if (notifyAlert &&
        _realtimeNotification &&
        !_incomingAlertController.isClosed) {
      _incomingAlertController.add(nextReq);
    }
    return true;
  }

  void applyRemoteUpdate(Map<String, dynamic> row) {
    if (_disposed) return;
    final rawDbId = row['id']?.toString().trim();
    if (rawDbId == null || rawDbId.isEmpty) return;
    final index =
        _requests.indexWhere((v) => v.dbId != null && v.dbId == rawDbId);
    if (index == -1) return;

    final existing = _requests[index];
    final rawStatus = row['status']?.toString().trim();
    final nextStatus = (rawStatus != null && rawStatus.isNotEmpty)
        ? RescueRequest.parseStatus(rawStatus)
        : existing.status;
    final nextName = _pickUpdatedText(
      [row['requester_name'], row['user_name']],
      existing.name,
    );
    final rawAgency = _pickUpdatedText(
      [row['assigned_agency'], row['request_type']],
      '',
    );
    final nextAgency = rawAgency.isNotEmpty
        ? RescueRequest.parseAgency(rawAgency)
        : existing.agency;
    final nextLocation = _pickUpdatedText(
      [row['location_text'], row['location']],
      existing.location,
    );
    final nextDistance = _pickUpdatedText(
      [row['distance_text'], row['distance']],
      existing.distance,
    );
    final nextContent = _pickUpdatedText(
      [row['rescue_details'], row['detail']],
      existing.content,
    );
    final nextConsideration = _pickUpdatedText(
      [row['considerations'], row['health_condition'], row['consideration']],
      existing.consideration,
    );
    final nextLatPercent = _parseRemotePercent(
      row['lat_percent'],
      existing.latPercent,
    );
    final nextTopPercent = _parseRemotePercent(
      row['top_percent'],
      existing.topPercent,
    );
    final nextCoords = RescueRequest.parseCoordinates(row);

    _requests[index] = existing.copyWith(
      status: nextStatus,
      name: nextName,
      agency: nextAgency,
      location: nextLocation,
      distance: nextDistance,
      content: nextContent,
      consideration: nextConsideration,
      latPercent: nextLatPercent,
      topPercent: nextTopPercent,
      latitude: nextCoords?.latitude,
      longitude: nextCoords?.longitude,
    );
    notifyListeners();
  }

  static double _parseRemotePercent(Object? value, double fallback) {
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    if (value != null) {
      final parsed = double.tryParse(value.toString().trim());
      if (parsed != null && parsed.isFinite) {
        return parsed;
      }
    }
    return fallback;
  }

  static String _pickUpdatedText(List<Object?> candidates, String fallback) {
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final text = candidate.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  Future<void> changeStatus(String id, RequestStatus newStatus) async {
    if (_disposed) return;
    final index = _requests.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final target = _requests[index];
    _requests[index] = target.copyWith(status: newStatus);
    _selectedId = id;
    notifyListeners();

    final dbId = target.dbId;
    final ds = dataSource;
    if (dbId != null && ds != null) {
      try {
        await ds.updateStatus(dbId: dbId, status: newStatus);
      } catch (e) {
        appLog('ステータス更新エラー: $e');
      }
    }
  }

  void filterAgency(AgencyType agency) {
    if (_disposed) return;
    _currentAgencyFilter = agency;
    _statusFilter = null;
    _currentView = MamoView.requests;
    notifyListeners();
  }

  void updateSettings({
    required String municipalityName,
    required bool realtimeNotification,
  }) {
    if (_disposed) return;
    final trimmed = municipalityName.trim();
    if (trimmed.isNotEmpty) {
      _municipalityName = trimmed;
    }
    _realtimeNotification = realtimeNotification;
    notifyListeners();
  }

  void _updateClockValue() {
    if (_disposed) return;
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    _currentTime = '$h:$m:$s';
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clockTimer?.cancel();
    final ds = dataSource;
    if (ds != null) {
      unawaited(ds.dispose());
    }
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_incomingAlertController.close());
    super.dispose();
  }

  /// 利用者（住民・スマホ）側から送信された救助要請を即時ローカル反映し、
  /// 設定済み・オンライン時は Supabase (`public.rescue_requests`) へ登録する。
  Future<RescueRequest> submitCitizenRequest({
    required String requesterName,
    required String rescueDetails,
    required String considerations,
    String locationText = '〇〇地区付近',
    String distanceText = '約150m先（デモ）',
  }) async {
    final now = DateTime.now();
    final normalizedName =
        requesterName.trim().isEmpty ? 'あなた' : requesterName.trim();
    final normalizedDetails =
        rescueDetails.trim().isEmpty ? '救助が必要です' : rescueDetails.trim();
    final normalizedConsiderations =
        considerations.trim().isEmpty ? 'なし' : considerations.trim();
    final normalizedLocation =
        locationText.trim().isEmpty ? '〇〇地区付近' : locationText.trim();
    final normalizedDistance =
        distanceText.trim().isEmpty ? '約150m先（デモ）' : distanceText.trim();

    final requestId = _nextCitizenRequestId(now);
    final resolvedCoords =
        RescueRequest.resolveCoordinatesFromLocation(normalizedLocation);
    final localRequest = RescueRequest(
      id: requestId,
      time: _formatClockTime(now),
      name: normalizedName,
      age: 0,
      gender: '',
      agency: AgencyType.emergency,
      location: normalizedLocation,
      distance: normalizedDistance,
      content: normalizedDetails,
      consideration: normalizedConsiderations,
      latPercent: 50.0,
      topPercent: 50.0,
      latitude: resolvedCoords.latitude,
      longitude: resolvedCoords.longitude,
      status: RequestStatus.pending,
    );

    if (_disposed) return localRequest;

    _requests.insert(0, localRequest);
    _selectedId = localRequest.id;
    notifyListeners();

    final ds = dataSource;
    if (ds == null) {
      return localRequest;
    }

    final payload = buildCitizenRescuePayload(
      requestId: requestId,
      createdAt: now,
      requesterName: normalizedName,
      rescueDetails: normalizedDetails,
      considerations: normalizedConsiderations,
      locationText: normalizedLocation,
      distanceText: normalizedDistance,
      requestType: '救助要請',
      status: RequestStatus.pending.label,
    );

    Map<String, dynamic>? insertedRow;
    try {
      insertedRow = await ds.insertRequest(payload);
    } catch (e) {
      appLog('MAMO市民救助要請送信エラー: $e');
    }

    if (_disposed || insertedRow == null) {
      return localRequest;
    }

    final rawDbId = insertedRow['id']?.toString().trim();
    final insertedDbId =
        (rawDbId != null && rawDbId.isNotEmpty) ? rawDbId : null;
    if (insertedDbId == null) {
      return localRequest;
    }

    final index = _requests.indexWhere(
      (v) => v.id == requestId || v.dbId == insertedDbId,
    );
    if (index == -1) {
      return localRequest;
    }

    final current = _requests[index];
    final parsedInsertedCoords = RescueRequest.parseCoordinates(insertedRow);
    if (current.dbId == null) {
      final reconciled = current.copyWith(
        dbId: insertedDbId,
        latitude: parsedInsertedCoords?.latitude,
        longitude: parsedInsertedCoords?.longitude,
      );
      _requests[index] = reconciled;
      notifyListeners();
      final remoteStatus = insertedRow['status'] != null
          ? RescueRequest.parseStatus(insertedRow['status'])
          : RequestStatus.pending;
      if (reconciled.status != remoteStatus) {
        try {
          await ds.updateStatus(dbId: insertedDbId, status: reconciled.status);
        } catch (e) {
          appLog('MAMO追送ステータス更新エラー: $e');
        }
      }
      return reconciled;
    }
    if (parsedInsertedCoords != null &&
        (current.latitude != parsedInsertedCoords.latitude ||
            current.longitude != parsedInsertedCoords.longitude)) {
      final updated = current.copyWith(
        latitude: parsedInsertedCoords.latitude,
        longitude: parsedInsertedCoords.longitude,
      );
      _requests[index] = updated;
      notifyListeners();
      return updated;
    }
    return current;
  }

  String _nextCitizenRequestId(DateTime now) {
    var ms = now.millisecondsSinceEpoch;
    while (_requests.any((r) => r.id == 'MAMO-$ms')) {
      ms++;
    }
    return 'MAMO-$ms';
  }

  static String _formatClockTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
