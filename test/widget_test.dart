import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/config/supabase_config.dart';
import 'package:mamo_cross/main.dart';
import 'package:mamo_cross/models/app_mode.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/pages/mamo_shell_page.dart';
import 'package:mamo_cross/services/rescue_data_source.dart';
import 'package:mamo_cross/services/supabase_rescue_data_source.dart';
import 'package:mamo_cross/state/rescue_store.dart';
import 'package:mamo_cross/theme/mamo_theme.dart';
import 'package:mamo_cross/views/dashboard_view.dart';
import 'package:mamo_cross/views/history_view.dart';
import 'package:mamo_cross/views/map_view.dart';
import 'package:mamo_cross/views/partners_view.dart';
import 'package:mamo_cross/views/requests_view.dart';
import 'package:mamo_cross/views/settings_view.dart';
import 'package:mamo_cross/views/status_view.dart';
import 'package:mamo_cross/widgets/app_header.dart';
import 'package:mamo_cross/widgets/app_sidebar.dart';
import 'package:mamo_cross/widgets/gsi_map_view.dart';
import 'package:material_ui/material_ui.dart';

const List<int> _testTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

class _FakeMemoryTileProvider extends TileProvider {
  _FakeMemoryTileProvider()
      : _image = MemoryImage(Uint8List.fromList(_testTransparentPng));

  final ImageProvider _image;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _image;
  }
}

class _CountingTileProvider extends TileProvider {
  _CountingTileProvider()
      : _image = MemoryImage(Uint8List.fromList(_testTransparentPng));

  final ImageProvider _image;
  int disposeCount = 0;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _image;
  }

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

class _CoordinateFakeRescueDataSource extends FakeRescueDataSource {
  _CoordinateFakeRescueDataSource({
    this.onInsert,
  });

  final Future<Map<String, dynamic>?> Function(Map<String, dynamic> payload)?
      onInsert;
  final List<Map<String, dynamic>> insertedPayloads = [];

  @override
  Future<Map<String, dynamic>?> insertRequest(
    Map<String, dynamic> payload,
  ) async {
    insertedPayloads.add(Map<String, dynamic>.from(payload));
    if (onInsert != null) {
      return onInsert!(payload);
    }
    return null;
  }
}

class FakeRescueDataSource implements RescueDataSource {
  FakeRescueDataSource({
    this.initialRows = const [],
    this.fetchError,
    this.updateError,
    this.subscribeError,
    this.connectOnSubscribe = true,
  });

  final List<Map<String, dynamic>> initialRows;
  final Object? fetchError;
  final Object? updateError;
  final Object? subscribeError;
  final bool connectOnSubscribe;

  final List<int> fetchLimits = [];
  int subscribeCalls = 0;
  final List<({String dbId, RequestStatus status})> updateCalls = [];
  final StreamController<RescueRealtimeEvent> _controller =
      StreamController<RescueRealtimeEvent>.broadcast();

  void Function(bool connected)? _onConnectionChanged;
  bool disposed = false;

  @override
  Future<List<Map<String, dynamic>>> fetchInitialRequests({
    int limit = 50,
  }) async {
    fetchLimits.add(limit);
    if (fetchError != null) {
      throw fetchError!;
    }
    return initialRows
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Stream<RescueRealtimeEvent> subscribeRequests({
    void Function(bool connected)? onConnectionChanged,
  }) {
    subscribeCalls++;
    _onConnectionChanged = onConnectionChanged;
    if (subscribeError != null) {
      onConnectionChanged?.call(false);
      return Stream<RescueRealtimeEvent>.error(subscribeError!);
    }
    if (connectOnSubscribe) {
      onConnectionChanged?.call(true);
    }
    return _controller.stream;
  }

  void emitInsert(Map<String, dynamic> row) {
    _controller.add(RescueInsertedEvent(row));
  }

  void emitUpdate(Map<String, dynamic> row) {
    _controller.add(RescueUpdatedEvent(row));
  }

  void setConnected(bool connected) {
    _onConnectionChanged?.call(connected);
  }

  @override
  Future<void> updateStatus({
    required String dbId,
    required RequestStatus status,
  }) async {
    updateCalls.add((dbId: dbId, status: status));
    if (updateError != null) {
      throw updateError!;
    }
  }

  @override
  Future<Map<String, dynamic>?> insertRequest(
    Map<String, dynamic> payload,
  ) async =>
      null;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}

void main() {
  group('RescueRequest.fromSupabaseRow & RescueStore.dbRowToRequest', () {
    test('maps primary columns, agency keywords, status, and local HH:mm:ss', () {
      const createdAtUtc = '2026-11-23T15:05:09Z';
      final local = DateTime.parse(createdAtUtc).toLocal();
      final expectedTime =
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}:'
          '${local.second.toString().padLeft(2, '0')}';

      final req = RescueStore.dbRowToRequest({
        'id': 42,
        'request_id': 'MAMO-42',
        'created_at': createdAtUtc,
        'requester_name': '優先 氏名',
        'user_name': '予備 氏名',
        'age': '39',
        'gender': '女性',
        'request_type': '消防出動要請',
        'location_text': '山口市中央1-1',
        'location': '旧位置',
        'distance_text': '約300m',
        'distance': '999m',
        'rescue_details': '建物から煙',
        'detail': '旧詳細',
        'considerations': '喘息あり',
        'health_condition': '旧健康状態',
        'consideration': '旧配慮',
        'status': '対応中',
      });

      expect(req.id, 'MAMO-42');
      expect(req.dbId, '42');
      expect(req.time, expectedTime);
      expect(req.name, '優先 氏名');
      expect(req.age, 39);
      expect(req.gender, '女性');
      expect(req.agency, AgencyType.fire);
      expect(req.location, '山口市中央1-1');
      expect(req.distance, '約300m');
      expect(req.content, '建物から煙');
      expect(req.consideration, '喘息あり');
      expect(req.latPercent, 50.0);
      expect(req.topPercent, 50.0);
      expect(req.status, RequestStatus.working);
    });

    test('applies fallback columns and defaults when fields are missing or empty', () {
      final req = RescueRequest.fromSupabaseRow({
        'id': 7,
        'request_id': '',
        'user_name': 'フォールバック太郎',
        'request_type': '救助要請',
        'location': '防府市駅北',
        'distance': '約1.5km',
        'detail': '道路冠水',
        'health_condition': '透析中',
        'status': '対応済み',
      });

      expect(req.id, 'DB-7');
      expect(req.dbId, '7');
      expect(RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(req.time), isTrue);
      expect(req.name, 'フォールバック太郎');
      expect(req.age, 0);
      expect(req.gender, '');
      expect(req.agency, AgencyType.emergency);
      expect(req.location, '防府市駅北');
      expect(req.distance, '約1.5km');
      expect(req.content, '道路冠水');
      expect(req.consideration, '透析中');
      expect(req.status, RequestStatus.done);

      final emptyReq = RescueRequest.fromSupabaseRow({});
      expect(emptyReq.dbId, isNull);
      expect(emptyReq.id, 'DB-');
      expect(emptyReq.name, '不明');
      expect(emptyReq.location, '位置情報');
      expect(emptyReq.distance, '');
      expect(emptyReq.content, '救助要請');
      expect(emptyReq.consideration, 'なし');
      expect(emptyReq.agency, AgencyType.emergency);
      expect(emptyReq.status, RequestStatus.pending);
    });

    test('parses police and sdf agencies cleanly', () {
      expect(
        RescueRequest.parseAgency('警察への通報'),
        AgencyType.police,
      );
      expect(
        RescueRequest.parseAgency('自衛隊派遣要請'),
        AgencyType.sdf,
      );
      expect(
        RescueRequest.parseStatus('未知のステータス'),
        RequestStatus.pending,
      );
    });
  });

  group('RescueStore local and FakeRescueDataSource sync', () {
    test('starts empty with Yamaguchi Prefecture municipality when dataSource is null', () {
      final store = RescueStore(startClock: false);
      addTearDown(store.dispose);

      expect(store.requests, isEmpty);
      expect(store.selectedId, '');
      expect(store.selectedRequest, isNull);
      expect(store.newCount, 0);
      expect(store.workingCount, 0);
      expect(store.doneCount, 0);
      expect(store.municipalityName, '山口県 災害対策本部');
      expect(store.isRealtimeConnected, isFalse);
    });

    test('fetches initial 50 rows in newest-first order with deduplication', () async {
      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 102,
            'request_id': 'MAMO-102',
            'requester_name': '最新さん',
            'status': '未対応',
          },
          {
            'id': 101,
            'request_id': 'MAMO-101',
            'requester_name': '一つ前さん',
            'status': '対応中',
          },
          // 重複 dbId（既に101が先頭追加されるため重複側はスキップされる）
          {
            'id': '101',
            'request_id': 'MAMO-101-DUP',
            'requester_name': '重複さん',
          },
        ],
      );
      final store = RescueStore(
        startClock: false,
        dataSource: ds,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      final alerts = <RescueRequest>[];
      final sub = store.incomingAlerts.listen(alerts.add);
      addTearDown(sub.cancel);

      await store.initializeRealtime();

      expect(ds.fetchLimits, [50]);
      expect(store.isRealtimeConnected, isTrue);
      expect(store.requests.length, 2);
      // rows.reversed を先頭挿入するため最新(102)が先頭、重複101はスキップされる
      expect(store.requests[0].id, 'MAMO-102');
      expect(store.requests[1].dbId, '101');
      expect(store.selectedId, 'MAMO-102');
      expect(alerts, isEmpty);
    });

    test('handles Realtime INSERT with dedup and realtimeNotification flag', () async {
      final ds = FakeRescueDataSource();
      final store = RescueStore(startClock: false, dataSource: ds);
      addTearDown(store.dispose);

      final alerts = <RescueRequest>[];
      final sub = store.incomingAlerts.listen(alerts.add);
      addTearDown(sub.cancel);

      await store.initializeRealtime();

      ds.emitInsert({
        'id': 200,
        'request_id': 'MAMO-200',
        'requester_name': '新規通報者',
        'distance_text': '約80m先',
        'status': '未対応',
      });
      await pumpEventQueue();

      expect(store.requests.first.id, 'MAMO-200');
      expect(store.selectedId, 'MAMO-200');
      expect(alerts.length, 1);
      expect(alerts.single.name, '新規通報者');

      // 同一 dbId の再挿入は無視
      ds.emitInsert({
        'id': 200,
        'request_id': 'MAMO-200-AGAIN',
        'requester_name': '重複通報者',
      });
      await pumpEventQueue();
      expect(store.requests.where((r) => r.dbId == '200').length, 1);
      expect(alerts.length, 1);

      // 通知オフ時は incomingAlerts に流さないが一覧へは追加する
      store.updateSettings(
        municipalityName: '山口市 災害対策本部',
        realtimeNotification: false,
      );
      ds.emitInsert({
        'id': 201,
        'request_id': 'MAMO-201',
        'requester_name': '通知オフ通報者',
      });
      await pumpEventQueue();
      expect(store.requests.first.id, 'MAMO-201');
      expect(alerts.length, 1);
    });

    test('handles Realtime UPDATE for matching dbId without touching other items', () async {
      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 300,
            'request_id': 'MAMO-300',
            'requester_name': '更新対象',
            'location_text': '山口市吉敷',
            'status': '未対応',
          },
          {
            'id': 301,
            'request_id': 'MAMO-301',
            'requester_name': '無関係さん',
            'status': '未対応',
          },
        ],
      );
      final store = RescueStore(startClock: false, dataSource: ds);
      addTearDown(store.dispose);
      await store.initializeRealtime();

      ds.emitUpdate({'id': 300, 'status': '対応済み'});
      // 存在しない dbId は無視
      ds.emitUpdate({'id': 9999, 'status': '対応済み'});
      await pumpEventQueue();

      final updated = store.requests.firstWhere((r) => r.dbId == '300');
      expect(updated.status, RequestStatus.done);
      expect(updated.name, '更新対象');
      expect(updated.location, '山口市吉敷');
      expect(
        store.requests.firstWhere((r) => r.dbId == '301').status,
        RequestStatus.pending,
      );
    });

    test('changeStatus updates locally and syncs only when dbId != null', () async {
      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 400,
            'request_id': 'MAMO-400',
            'requester_name': 'DB要請',
            'status': '未対応',
          },
        ],
      );
      final store = RescueStore(startClock: false, dataSource: ds);
      addTearDown(store.dispose);
      await store.initializeRealtime();

      // dbId == null の項目はローカル更新のみで updateStatus を呼ばない
      store.addDbRequest({'request_id': 'LOCAL-1', 'status': '未対応'});
      await store.changeStatus('LOCAL-1', RequestStatus.working);
      expect(
        store.requests.firstWhere((r) => r.id == 'LOCAL-1').status,
        RequestStatus.working,
      );
      expect(store.selectedId, 'LOCAL-1');
      expect(ds.updateCalls, isEmpty);

      // DB 由来項目はローカル即時反映＋ updateStatus 呼び出し
      await store.changeStatus('MAMO-400', RequestStatus.done);
      expect(
        store.requests.firstWhere((r) => r.id == 'MAMO-400').status,
        RequestStatus.done,
      );
      expect(store.selectedId, 'MAMO-400');
      expect(ds.updateCalls, [(dbId: '400', status: RequestStatus.done)]);
    });

    test('survives fetchError, updateError, subscribeError, and empty SupabaseConfig', () async {
      final failingDs = FakeRescueDataSource(
        initialRows: [
          {'id': 500, 'request_id': 'MAMO-500', 'status': '未対応'},
        ],
        fetchError: Exception('network down'),
        subscribeError: Exception('ws down'),
        updateError: Exception('patch failed'),
      );
      final store = RescueStore(startClock: false, dataSource: failingDs);
      addTearDown(store.dispose);
      await store.initializeRealtime();
      await pumpEventQueue();

      // 取得失敗時は空状態のままクラッシュしない
      expect(store.requests, isEmpty);
      expect(store.selectedRequest, isNull);
      expect(store.isRealtimeConnected, isFalse);

      // updateError でもローカル状態は維持
      store.addDbRequest({'id': 501, 'request_id': 'MAMO-501', 'status': '未対応'});
      await store.changeStatus('MAMO-501', RequestStatus.working);
      expect(
        store.requests.firstWhere((r) => r.id == 'MAMO-501').status,
        RequestStatus.working,
      );

      // 空設定の SupabaseRescueDataSource でも例外を出さない
      final emptySource = SupabaseRescueDataSource(config: SupabaseConfig.empty);
      expect(await emptySource.fetchInitialRequests(), isEmpty);
      var connectedCallbackValue = true;
      final emptyStream = emptySource.subscribeRequests(
        onConnectionChanged: (connected) => connectedCallbackValue = connected,
      );
      expect(connectedCallbackValue, isFalse);
      expect(await emptyStream.isEmpty, isTrue);
      await emptySource.updateStatus(dbId: '1', status: RequestStatus.done);
      await emptySource.dispose();
    });

    test('dispose cancels subscription and disposes dataSource', () async {
      final ds = FakeRescueDataSource();
      final store = RescueStore(startClock: false, dataSource: ds);
      await store.initializeRealtime();

      store.dispose();
      await pumpEventQueue();

      expect(ds.disposed, isTrue);
    });

    test('mutators and changeStatus are safe no-ops after store.dispose()', () async {
      final ds = FakeRescueDataSource(
        initialRows: [
          {'id': 600, 'request_id': 'MAMO-600', 'status': '未対応'},
        ],
      );
      final store = RescueStore(startClock: false, dataSource: ds);
      await store.initializeRealtime();
      store.dispose();

      // 破棄後の各種ミューテーション呼び出しで例外が発生しないこと
      await store.changeStatus('MAMO-600', RequestStatus.done);
      store.setView(MamoView.map);
      store.setStatusFilter(RequestStatus.working);
      store.setAgencyFilter(AgencyType.fire);
      store.selectRequest('mamo-0001');
      store.selectFromMap('mamo-0002');
      store.filterAgency(AgencyType.police);
      store.updateSettings(
        municipalityName: '破棄後市',
        realtimeNotification: false,
      );
      expect(ds.updateCalls, isEmpty);
    });

    test('concurrent initializeRealtime invokes fetch and subscribe only once', () async {
      final ds = FakeRescueDataSource(
        initialRows: [
          {'id': 610, 'request_id': 'MAMO-610', 'status': '未対応'},
        ],
      );
      final store = RescueStore(
        startClock: false,
        dataSource: ds,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      await Future.wait([
        store.initializeRealtime(),
        store.initializeRealtime(),
        store.initializeRealtime(),
      ]);

      expect(ds.fetchLimits, [50]);
      expect(ds.subscribeCalls, 1);
    });

    test('applyRemoteUpdate with empty or whitespace status preserves existing status', () async {
      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 620,
            'request_id': 'MAMO-620',
            'requester_name': '状態保持さん',
            'status': '対応中',
          },
        ],
      );
      final store = RescueStore(startClock: false, dataSource: ds);
      addTearDown(store.dispose);
      await store.initializeRealtime();

      ds.emitUpdate({'id': 620, 'status': ''});
      await pumpEventQueue();
      expect(
        store.requests.firstWhere((r) => r.dbId == '620').status,
        RequestStatus.working,
      );

      ds.emitUpdate({'id': 620, 'status': '   '});
      await pumpEventQueue();
      expect(
        store.requests.firstWhere((r) => r.dbId == '620').status,
        RequestStatus.working,
      );
    });

    test('loads DB requests cleanly without local fallback and updates status by dbId', () async {
      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 1,
            'request_id': 'mamo-0005',
            'user_name': '山田 太郎',
            'request_type': '救急',
            'location': '山口県山口市亀山町2-1付近',
            'distance': '約120m先',
            'detail': '転倒して足を痛めて動けません。意識はあります。早急に救助をお願いします。',
            'consideration': 'ホルモン治療中',
            'status': '未対応',
          },
          {
            'id': 2,
            'request_id': 'mamo-0004',
            'user_name': '佐藤 花子',
            'request_type': '消防',
            'location': '山口県下関市南部町1-1付近',
            'distance': '約550m先',
            'detail': '建物内に取り残されています。',
            'consideration': '医療的ケアが必要',
            'status': '未対応',
          },
          {
            'id': 3,
            'request_id': 'mamo-0003',
            'user_name': '鈴木 一郎',
            'request_type': '自衛隊',
            'location': '山口県萩市大字江向510付近',
            'distance': '約1.2km先',
            'detail': '道路が塞がれて移動できません。',
            'consideration': 'なし',
            'status': '未対応',
          },
          {
            'id': 4,
            'request_id': 'mamo-0002',
            'user_name': '田中 美咲',
            'request_type': '警察',
            'location': '山口県宇部市常盤町1-7-1付近',
            'distance': '約2.5km先',
            'detail': '家族と連絡が取れず避難場所から動けません。',
            'consideration': '妊娠中',
            'status': '対応中',
          },
          {
            'id': 5,
            'request_id': 'mamo-0001',
            'user_name': '高橋 健',
            'request_type': '消防',
            'location': '山口県岩国市今津町1-14-51付近',
            'distance': '約3.8km先',
            'detail': '自宅周辺が浸水しています。救助をお願いします。',
            'consideration': '人工呼吸器使用',
            'status': '対応中',
          },
        ],
      );
      final store = RescueStore(
        startClock: false,
        dataSource: ds,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      await store.initializeRealtime();

      expect(store.requests.length, 5);
      expect(
        store.requests.map((r) => r.id).toList(),
        ['mamo-0005', 'mamo-0004', 'mamo-0003', 'mamo-0002', 'mamo-0001'],
      );
      expect(store.selectedId, 'mamo-0005');

      for (final req in store.requests) {
        expect(req.dbId, isNotNull);
        expect(req.location, contains('山口県'));
        expect(req.location, isNot(contains('○○')));
      }

      await store.changeStatus('mamo-0005', RequestStatus.working);
      expect(ds.updateCalls, [(dbId: '1', status: RequestStatus.working)]);
    });

    test('disambiguates colliding request_id across distinct dbIds', () async {
      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 901,
            'request_id': 'MAMO-DUP',
            'requester_name': '先着さん',
            'status': '未対応',
          },
          {
            'id': 902,
            'request_id': 'MAMO-DUP',
            'requester_name': '後着さん',
            'status': '未対応',
          },
        ],
      );
      final store = RescueStore(
        startClock: false,
        dataSource: ds,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      await store.initializeRealtime();

      final dbItems = store.requests.where((r) => r.dbId != null).toList();
      expect(dbItems.length, 2);
      expect(dbItems.map((r) => r.id).toSet().length, 2);
      expect(dbItems.any((r) => r.id == 'MAMO-DUP'), isTrue);
      expect(dbItems.any((r) => r.id == 'MAMO-DUP#901'), isTrue);
    });
  });

  group('MamoApp Widget tests', () {
    void setTestViewport(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('navigates all 7 views and updates filters/status on desktop width', (
      tester,
    ) async {
      setTestViewport(tester, const Size(1280, 800));

      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 11,
            'request_id': 'MAMO-11',
            'requester_name': '山口 一子',
            'request_type': '救急',
            'location_text': '山口市亀山町1-1',
            'distance_text': '約150m先',
            'rescue_details': '転倒による負傷',
            'considerations': '配慮なし',
            'status': '未対応',
          },
          {
            'id': 12,
            'request_id': 'MAMO-12',
            'requester_name': '佐藤 花子',
            'request_type': '消防',
            'location_text': '山口県下関市南部町1-1付近',
            'distance_text': '約550m先',
            'rescue_details': '建物内に取り残されています。',
            'considerations': '医療的ケアが必要',
            'status': '未対応',
          },
        ],
      );

      await tester.pumpWidget(
        MamoApp(
          dataSource: ds,
          startClock: false,
          initialMode: MamoAppMode.municipality,
        ),
      );
      await tester.pumpAndSettle();

      // デスクトップヘッダー・常設サイドバー（218px）・自治体名・メニューアイコン非表示
      expect(find.text('MAMO'), findsOneWidget);
      expect(find.text('自治体管理システム'), findsOneWidget);
      expect(find.text('山口県 災害対策本部 ▾'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);
      final sidebar = tester.widget<AppSidebar>(find.byType(AppSidebar));
      expect(sidebar.width, 218.0);
      expect(find.byType(DashboardView), findsOneWidget);
      expect(find.textContaining('山口 一子'), findsWidgets);

      // 7ビュー遷移確認
      Future<void> tapSidebarLabel(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(AppSidebar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tapSidebarLabel('救助要請一覧');
      expect(find.byType(RequestsView), findsOneWidget);

      // ステータス更新（DB由来 MAMO-11 を対応中へ）
      await tester.ensureVisible(find.text('対応開始'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('対応開始'));
      await tester.pumpAndSettle();
      expect(ds.updateCalls, [(dbId: '11', status: RequestStatus.working)]);
      expect(find.text('「対応中」に変更しました（デモ）'), findsOneWidget);

      await tapSidebarLabel('位置情報マップ');
      expect(find.byType(MapView), findsOneWidget);

      await tapSidebarLabel('関係機関連携');
      expect(find.byType(PartnersView), findsOneWidget);

      await tapSidebarLabel('対応状況');
      expect(find.byType(StatusView), findsOneWidget);

      await tapSidebarLabel('統計・履歴');
      expect(find.byType(HistoryView), findsOneWidget);

      await tapSidebarLabel('設定');
      expect(find.byType(SettingsView), findsOneWidget);

      // 設定変更がヘッダー自治体名へ反映されること
      await tester.enterText(find.byType(TextField), '山口市 災害対策本部');
      await tester.tap(find.text('保存する'));
      await tester.pumpAndSettle();
      expect(find.text('山口市 災害対策本部 ▾'), findsOneWidget);

      // サイドバーの機関ショートカットフィルタで救助要請一覧へ遷移
      await tapSidebarLabel('消防');
      expect(find.byType(RequestsView), findsOneWidget);
      expect(find.textContaining('佐藤 花子'), findsWidgets);
    });

    testWidgets('uses 180px sidebar at tablet width (650..899px)', (
      tester,
    ) async {
      setTestViewport(tester, const Size(760, 800));

      final ds = FakeRescueDataSource();
      await tester.pumpWidget(
        MamoApp(
          dataSource: ds,
          startClock: false,
          initialMode: MamoAppMode.municipality,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.text('自治体管理システム'), findsOneWidget);
      expect(find.text('山口県 災害対策本部 ▾'), findsNothing);
      final sidebar = tester.widget<AppSidebar>(find.byType(AppSidebar));
      expect(sidebar.width, 180.0);
    });

    testWidgets('opens Drawer on mobile (<650px), closes on navigate, and shows realtime SnackBar', (
      tester,
    ) async {
      setTestViewport(tester, const Size(400, 800));

      final ds = FakeRescueDataSource();
      await tester.pumpWidget(
        MamoApp(
          dataSource: ds,
          startClock: false,
          initialMode: MamoAppMode.municipality,
        ),
      );
      await tester.pumpAndSettle();

      // モバイル時は常設サイドバーがなくメニューボタンが表示される
      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);

      // メニューボタンで Drawer が開き、項目タップで遷移して閉じる
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.byType(AppSidebar), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('対応状況'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(StatusView), findsOneWidget);

      // Realtime INSERT で SnackBar アラートが表示され件数が更新される
      ds.emitInsert({
        'id': 77,
        'request_id': 'MAMO-77',
        'requester_name': 'リアルタイム太郎',
        'distance_text': '約50m先',
        'status': '未対応',
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('🚨 新しい救助要請が届きました：リアルタイム太郎　約50m先'),
        findsOneWidget,
      );
      expect(find.textContaining('リアルタイム太郎'), findsWidgets);
    });

    testWidgets('header bell button filters to pending requests', (
      tester,
    ) async {
      setTestViewport(tester, const Size(1280, 800));

      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 1,
            'request_id': 'mamo-0005',
            'user_name': '山田 太郎',
            'request_type': '救急',
            'location': '山口県山口市亀山町2-1付近',
            'status': '未対応',
          },
          {
            'id': 4,
            'request_id': 'mamo-0002',
            'user_name': '田中 美咲',
            'request_type': '警察',
            'location': '山口県宇部市常盤町1-7-1付近',
            'status': '対応中',
          },
        ],
      );
      await tester.pumpWidget(
        MamoApp(
          dataSource: ds,
          startClock: false,
          initialMode: MamoAppMode.municipality,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notifications));
      await tester.pumpAndSettle();

      expect(find.byType(RequestsView), findsOneWidget);
      // 未対応の山田 太郎は表示され、対応中の田中 美咲は一覧から除外される
      expect(find.textContaining('山田 太郎'), findsWidgets);
      expect(find.textContaining('田中 美咲'), findsNothing);
    });

    testWidgets('MamoShellPage.didUpdateWidget swaps store and dataSource cleanly', (
      tester,
    ) async {
      setTestViewport(tester, const Size(1280, 800));

      final ds1 = FakeRescueDataSource();
      final store1 = RescueStore(startClock: false, dataSource: ds1);
      addTearDown(store1.dispose);
      await store1.initializeRealtime();

      final ds2 = FakeRescueDataSource(
        initialRows: [
          {
            'id': 801,
            'request_id': 'MAMO-801',
            'requester_name': '新ストア初期要請',
            'status': '未対応',
          },
        ],
      );
      final store2 = RescueStore(startClock: false, dataSource: ds2);
      addTearDown(store2.dispose);
      await store2.initializeRealtime();
      store2.updateSettings(
        municipalityName: '新ストア市本部',
        realtimeNotification: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MamoShellPage(store: store1, startClock: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('山口県 災害対策本部 ▾'), findsOneWidget);

      // store1 -> store2 差し替え
      await tester.pumpWidget(
        MaterialApp(
          home: MamoShellPage(store: store2, startClock: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('新ストア市本部 ▾'), findsOneWidget);

      // 旧ストアへの INSERT では SnackBar が発火せず、新ストアのみ反応する
      ds1.emitInsert({
        'id': 802,
        'request_id': 'MAMO-802',
        'requester_name': '旧ストア通知',
      });
      await tester.pump();
      expect(
        find.textContaining('旧ストア通知'),
        findsNothing,
      );

      ds2.emitInsert({
        'id': 803,
        'request_id': 'MAMO-803',
        'requester_name': '新ストア通知',
        'distance_text': '約40m先',
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('🚨 新しい救助要請が届きました：新ストア通知　約40m先'),
        findsOneWidget,
      );

      // store == null の状態で dataSource を差し替えると旧 owned store/dataSource が破棄される
      final ownedDs1 = FakeRescueDataSource();
      final ownedDs2 = FakeRescueDataSource(
        initialRows: [
          {
            'id': 804,
            'request_id': 'MAMO-804',
            'requester_name': '差し替え後要請',
            'status': '未対応',
          },
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MamoShellPage(dataSource: ownedDs1, startClock: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(ownedDs1.disposed, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: MamoShellPage(dataSource: ownedDs2, startClock: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(ownedDs1.disposed, isTrue);
      expect(ownedDs2.disposed, isFalse);
      expect(find.textContaining('差し替え後要請'), findsWidgets);
    });

    testWidgets('resizing from mobile with open Drawer to desktop and back leaves Drawer closed', (
      tester,
    ) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);

      final ds = FakeRescueDataSource();
      await tester.pumpWidget(
        MamoApp(
          dataSource: ds,
          startClock: false,
          initialMode: MamoAppMode.municipality,
        ),
      );
      await tester.pumpAndSettle();

      // モバイルで Drawer を開く
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);

      // デスクトップ幅へリサイズすると常設サイドバーに切り替わる
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(AppSidebar), findsOneWidget);

      // 再びモバイル幅へ戻しても Drawer が閉じたままになっていること
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('navigates all 7 views cleanly at tablet width (700x800)', (
      tester,
    ) async {
      setTestViewport(tester, const Size(700, 800));

      final ds = FakeRescueDataSource();
      await tester.pumpWidget(
        MamoApp(
          dataSource: ds,
          startClock: false,
          initialMode: MamoAppMode.municipality,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<AppSidebar>(find.byType(AppSidebar)).width, 180.0);

      Future<void> tapSidebarLabel(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(AppSidebar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }

      expect(find.byType(DashboardView), findsOneWidget);
      await tapSidebarLabel('救助要請一覧');
      expect(find.byType(RequestsView), findsOneWidget);
      await tapSidebarLabel('位置情報マップ');
      expect(find.byType(MapView), findsOneWidget);
      await tapSidebarLabel('関係機関連携');
      expect(find.byType(PartnersView), findsOneWidget);
      await tapSidebarLabel('対応状況');
      expect(find.byType(StatusView), findsOneWidget);
      await tapSidebarLabel('統計・履歴');
      expect(find.byType(HistoryView), findsOneWidget);
      await tapSidebarLabel('設定');
      expect(find.byType(SettingsView), findsOneWidget);
    });

    testWidgets('MamoApp with autoConnect: true disposes cleanly without pending timers', (
      tester,
    ) async {
      setTestViewport(tester, const Size(1280, 800));

      // 空設定での autoConnect: true
      await tester.pumpWidget(
        MamoApp(
          startClock: false,
          autoConnect: true,
          dataSource: SupabaseRescueDataSource(config: SupabaseConfig.empty),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());

      // デフォルト展示用設定 (autoConnect: true) でも 10s/6s タイマーがリークしないこと
      await tester.pumpWidget(
        const MamoApp(startClock: false, autoConnect: true),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());

      // 閉鎖エンドポイント指定でも未処理タイマーが残らないこと
      await tester.pumpWidget(
        MamoApp(
          startClock: false,
          autoConnect: true,
          dataSource: SupabaseRescueDataSource(
            config: const SupabaseConfig(
              url: 'http://127.0.0.1:1',
              publishableKey: 'sb_publishable_test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('renders empty state cleanly on DashboardView and RequestsView when no requests exist', (
      tester,
    ) async {
      setTestViewport(tester, const Size(1280, 800));

      final ds = FakeRescueDataSource();
      await tester.pumpWidget(
        MamoApp(
          dataSource: ds,
          startClock: false,
          initialMode: MamoAppMode.municipality,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DashboardView), findsOneWidget);
      expect(find.text('受信した救助要請はありません。'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AppSidebar),
          matching: find.text('救助要請一覧'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RequestsView), findsOneWidget);
      expect(find.text('すべて 0'), findsOneWidget);
      expect(find.text('該当する救助要請はありません。'), findsOneWidget);
    });

    testWidgets('RequestsView highlights exactly one item when DB loads requests and another is tapped', (
      tester,
    ) async {
      setTestViewport(tester, const Size(1280, 800));

      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 1,
            'request_id': 'mamo-0005',
            'user_name': '山田 太郎',
            'request_type': '救急',
            'location': '山口県山口市亀山町2-1付近',
            'distance': '約120m先',
            'detail': '転倒して足を痛めて動けません。意識はあります。早急に救助をお願いします。',
            'consideration': 'ホルモン治療中',
            'status': '未対応',
          },
          {
            'id': 2,
            'request_id': 'mamo-0004',
            'user_name': '佐藤 花子',
            'request_type': '消防',
            'location': '山口県下関市南部町1-1付近',
            'distance': '約550m先',
            'detail': '建物内に取り残されています。',
            'consideration': '医療的ケアが必要',
            'status': '未対応',
          },
          {
            'id': 3,
            'request_id': 'mamo-0003',
            'user_name': '鈴木 一郎',
            'request_type': '自衛隊',
            'location': '山口県萩市大字江向510付近',
            'distance': '約1.2km先',
            'detail': '道路が塞がれて移動できません。',
            'consideration': 'なし',
            'status': '未対応',
          },
          {
            'id': 4,
            'request_id': 'mamo-0002',
            'user_name': '田中 美咲',
            'request_type': '警察',
            'location': '山口県宇部市常盤町1-7-1付近',
            'distance': '約2.5km先',
            'detail': '家族と連絡が取れず避難場所から動けません。',
            'consideration': '妊娠中',
            'status': '対応中',
          },
          {
            'id': 5,
            'request_id': 'mamo-0001',
            'user_name': '高橋 健',
            'request_type': '消防',
            'location': '山口県岩国市今津町1-14-51付近',
            'distance': '約3.8km先',
            'detail': '自宅周辺が浸水しています。救助をお願いします。',
            'consideration': '人工呼吸器使用',
            'status': '対応中',
          },
        ],
      );

      await tester.pumpWidget(
        MamoApp(
          dataSource: ds,
          startClock: false,
          initialMode: MamoAppMode.municipality,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppSidebar),
          matching: find.text('救助要請一覧'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RequestsView), findsOneWidget);
      expect(find.text('すべて 5'), findsOneWidget);
      expect(find.text('すべて 10'), findsNothing);
      // OutlinedButton 内の Text.rich 含め一覧・詳細ともに重複していないこと
      expect(find.textContaining('佐藤 花子'), findsOneWidget);
      expect(find.text('山口県下関市南部町1-1付近'), findsOneWidget);

      Finder selectedListItems() {
        return find.byWidgetPredicate((widget) {
          if (widget is! Container) return false;
          final decoration = widget.decoration;
          if (decoration is! BoxDecoration) return false;
          final border = decoration.border;
          return decoration.color == MamoColors.selectedItemBg &&
              border is Border &&
              border.top.color == MamoColors.primaryBlue;
        });
      }

      expect(selectedListItems(), findsOneWidget);

      // 別項目（佐藤 花子）をタップしても常に1件のみフォーカスされること
      await tester.tap(find.text('山口県下関市南部町1-1付近'));
      await tester.pumpAndSettle();

      expect(selectedListItems(), findsOneWidget);
      expect(find.text('ID：mamo-0004'), findsOneWidget);
    });

    testWidgets('starts on PortalPage by default and switches between Citizen and Municipality modes', (
      tester,
    ) async {
      setTestViewport(tester, const Size(1280, 800));

      final ds = FakeRescueDataSource();
      await tester.pumpWidget(MamoApp(dataSource: ds, startClock: false));
      await tester.pumpAndSettle();

      // デフォルト起動はポータル
      expect(find.byType(DashboardView), findsNothing);
      expect(find.textContaining('利用者'), findsWidgets);
      expect(find.textContaining('自治体'), findsWidgets);

      // 自治体モードへ遷移
      await tester.tap(find.text('自治体モードを開く'));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardView), findsOneWidget);

      // ヘッダーから利用者モードへ切替
      await tester.tap(
        find.descendant(
          of: find.byType(AppHeader),
          matching: find.text('利用者'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ゲストモードではじめる'), findsOneWidget);

      // ポータルへ復帰
      await tester.tap(find.text('ポータル'));
      await tester.pumpAndSettle();
      expect(find.text('自治体モードを開く'), findsOneWidget);
    });
  });

  group('RescueRequest coordinates & RescueStore coordinate sync', () {
    test('parses latitude/longitude and lat/lng/lon from numbers or strings', () {
      final explicit = RescueRequest.fromSupabaseRow({
        'id': 10,
        'request_id': 'MAMO-10',
        'latitude': 34.0558,
        'longitude': 131.5646,
      });
      expect(explicit.latitude, closeTo(34.0558, 0.0001));
      expect(explicit.longitude, closeTo(131.5646, 0.0001));

      final stringLatLng = RescueRequest.fromSupabaseRow({
        'id': 11,
        'request_id': 'MAMO-11',
        'lat': '34.3747',
        'lng': '131.1835',
      });
      expect(stringLatLng.latitude, closeTo(34.3747, 0.0001));
      expect(stringLatLng.longitude, closeTo(131.1835, 0.0001));

      final withLon = RescueRequest.parseCoordinates({
        'lat': 33.95,
        'lon': '130.94',
      });
      expect(withLon, isNotNull);
      expect(withLon!.latitude, closeTo(33.95, 0.0001));
      expect(withLon.longitude, closeTo(130.94, 0.0001));

      // 範囲外や不正な座標は null になり住所フォールバックが使われる
      expect(
        RescueRequest.parseCoordinates({'latitude': 95.0, 'longitude': 131.0}),
        isNull,
      );
      expect(
        RescueRequest.parseCoordinates({'latitude': 34.0, 'longitude': -185.0}),
        isNull,
      );
      expect(
        RescueRequest.parseCoordinates({'latitude': 'abc', 'longitude': 131.0}),
        isNull,
      );
    });

    test('resolves coordinates from Yamaguchi city and town names with prefectural default fallback', () {
      final hofu = RescueRequest.fromSupabaseRow({
        'id': 12,
        'request_id': 'MAMO-12',
        'location_text': '山口県防府市寿町7-1',
      });
      expect(hofu.latitude, closeTo(34.0558, 0.0001));
      expect(hofu.longitude, closeTo(131.5646, 0.0001));

      const expectedTownCoords = <String, ({double lat, double lng})>{
        '周防大島町': (lat: 33.9276, lng: 132.1952),
        '和木町': (lat: 34.2024, lng: 132.2202),
        '上関町': (lat: 33.8309, lng: 132.1104),
        '田布施町': (lat: 33.9547, lng: 132.0414),
        '平生町': (lat: 33.9379, lng: 132.0732),
        '阿武町': (lat: 34.5033, lng: 131.4714),
      };
      for (final entry in expectedTownCoords.entries) {
        final resolved = RescueRequest.resolveCoordinatesFromLocation(
          '山口県${entry.key}役場付近',
        );
        expect(resolved.latitude, closeTo(entry.value.lat, 0.0001));
        expect(resolved.longitude, closeTo(entry.value.lng, 0.0001));

        final rowModel = RescueRequest.fromSupabaseRow({
          'id': 20,
          'request_id': 'MAMO-TOWN-${entry.key}',
          'location_text': '山口県${entry.key}1-1',
        });
        expect(rowModel.latitude, closeTo(entry.value.lat, 0.0001));
        expect(rowModel.longitude, closeTo(entry.value.lng, 0.0001));
      }

      final unknown = RescueRequest.fromSupabaseRow({
        'id': 13,
        'request_id': 'MAMO-13',
        'location_text': '詳細不明の地点',
      });
      expect(unknown.latitude, RescueRequest.defaultLatitude);
      expect(unknown.longitude, RescueRequest.defaultLongitude);
    });

    test('preserves local coordinates on DB merge without explicit coords and updates on remote coord change', () async {
      final completer1 = Completer<Map<String, dynamic>?>();
      final completer2 = Completer<Map<String, dynamic>?>();
      var callCount = 0;
      final ds = _CoordinateFakeRescueDataSource(
        onInsert: (_) {
          callCount++;
          return callCount == 1 ? completer1.future : completer2.future;
        },
      );
      final store = RescueStore(
        startClock: false,
        dataSource: ds,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      await store.initializeRealtime();

      // 1件目: 山口市の住所からローカル座標が解決される（dbId 未確定）
      final f1 = store.submitCitizenRequest(
        requesterName: '山田 太郎',
        rescueDetails: '救助要請1',
        considerations: 'なし',
        locationText: '山口県山口市亀山町2-1付近',
      );
      final localReq1 = store.requests.first;
      expect(localReq1.latitude, closeTo(34.1785, 0.0001));
      expect(localReq1.longitude, closeTo(131.4737, 0.0001));

      // 2件目: 下関市の住所からローカル座標が解決される
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final f2 = store.submitCitizenRequest(
        requesterName: '佐藤 花子',
        rescueDetails: '救助要請2',
        considerations: 'なし',
        locationText: '山口県下関市南部町1-1付近',
      );
      final localReq2 = store.requests.first;
      expect(localReq2.id, isNot(localReq1.id));

      // 1件目 Realtime INSERT（座標なし）→ ローカルの山口市座標を引き継ぐ
      ds.emitInsert({
        'id': 1,
        'request_id': localReq1.id,
        'user_name': '山田 太郎',
        'location': '住所テキストのみ',
        'status': '未対応',
      });
      // 2件目 Realtime INSERT（明示座標あり）→ DB座標を採用する
      ds.emitInsert({
        'id': 2,
        'request_id': localReq2.id,
        'user_name': '佐藤 花子',
        'latitude': 34.0123,
        'longitude': 131.1234,
        'status': '未対応',
      });
      await pumpEventQueue();

      completer1.complete({'id': 1, 'request_id': localReq1.id, 'status': '未対応'});
      completer2.complete({
        'id': 2,
        'request_id': localReq2.id,
        'latitude': 34.0123,
        'longitude': 131.1234,
        'status': '未対応',
      });
      await Future.wait([f1, f2]);

      final merged1 = store.requests.firstWhere((r) => r.id == localReq1.id);
      expect(merged1.dbId, '1');
      expect(merged1.latitude, closeTo(34.1785, 0.0001));
      expect(merged1.longitude, closeTo(131.4737, 0.0001));

      final merged2 = store.requests.firstWhere((r) => r.id == localReq2.id);
      expect(merged2.dbId, '2');
      expect(merged2.latitude, closeTo(34.0123, 0.0001));
      expect(merged2.longitude, closeTo(131.1234, 0.0001));

      // applyRemoteUpdate: 座標・assigned_agency・lat_percent・top_percent 更新、座標なし UPDATE で保持
      ds.emitUpdate({
        'id': 1,
        'latitude': 34.2222,
        'longitude': 131.5555,
        'assigned_agency': '消防',
        'lat_percent': 33.5,
        'top_percent': 44.5,
      });
      ds.emitUpdate({'id': 2, 'status': '対応中'});
      await pumpEventQueue();

      final updated1 = store.requests.firstWhere((r) => r.dbId == '1');
      expect(updated1.latitude, closeTo(34.2222, 0.0001));
      expect(updated1.longitude, closeTo(131.5555, 0.0001));
      expect(updated1.agency, AgencyType.fire);
      expect(updated1.latPercent, 33.5);
      expect(updated1.topPercent, 44.5);

      final updated2 = store.requests.firstWhere((r) => r.dbId == '2');
      expect(updated2.status, RequestStatus.working);
      expect(updated2.latitude, closeTo(34.0123, 0.0001));
      expect(updated2.longitude, closeTo(131.1234, 0.0001));
    });

    test('submitCitizenRequest resolves local coordinates, keeps 15-col payload, and syncs insertedRow coordinates', () async {
      // パス1: insertRequest が明示座標付き行を返却
      final ds = _CoordinateFakeRescueDataSource(
        onInsert: (payload) async => {
          'id': 99,
          'request_id': payload['request_id'],
          'latitude': 33.9301,
          'longitude': 132.2012,
          'status': '未対応',
        },
      );
      final store = RescueStore(
        startClock: false,
        dataSource: ds,
        autoInitialize: false,
      );
      addTearDown(store.dispose);

      final future = store.submitCitizenRequest(
        requesterName: '大島 太郎',
        rescueDetails: '浸水しています',
        considerations: 'なし',
        locationText: '山口県周防大島町小松付近',
      );

      // 即時ローカル反映時点で周防大島町の代表座標に解決されていること
      expect(store.requests, hasLength(1));
      expect(store.requests.first.latitude, closeTo(33.9276, 0.0001));
      expect(store.requests.first.longitude, closeTo(132.1952, 0.0001));

      final reconciled = await future;
      // buildCitizenRescuePayload の厳密 15 カラム契約を維持していること
      expect(ds.insertedPayloads, hasLength(1));
      final sentKeys = ds.insertedPayloads.first.keys.toSet();
      expect(sentKeys, hasLength(15));
      expect(sentKeys.contains('latitude'), isFalse);
      expect(sentKeys.contains('longitude'), isFalse);

      // insertedRow の明示座標へ同期されること
      expect(reconciled.dbId, '99');
      expect(reconciled.latitude, closeTo(33.9301, 0.0001));
      expect(reconciled.longitude, closeTo(132.2012, 0.0001));
      expect(store.requests.first.latitude, closeTo(33.9301, 0.0001));
      expect(store.requests.first.longitude, closeTo(132.2012, 0.0001));

      // パス2: Realtime INSERT（座標なし）先着後に insertedRow（座標あり）が返る経路
      final completer = Completer<Map<String, dynamic>?>();
      final dsRealtimeFirst = _CoordinateFakeRescueDataSource(
        onInsert: (_) => completer.future,
      );
      final store2 = RescueStore(
        startClock: false,
        dataSource: dsRealtimeFirst,
        autoInitialize: false,
      );
      addTearDown(store2.dispose);
      await store2.initializeRealtime();

      final f2 = store2.submitCitizenRequest(
        requesterName: '阿武 花子',
        rescueDetails: '救助要請',
        considerations: 'なし',
        locationText: '山口県阿武町奈古付近',
      );
      final reqId2 = store2.requests.first.id;
      dsRealtimeFirst.emitInsert({
        'id': 100,
        'request_id': reqId2,
        'user_name': '阿武 花子',
        'status': '未対応',
      });
      await pumpEventQueue();
      expect(store2.requests.first.dbId, '100');
      expect(store2.requests.first.latitude, closeTo(34.5033, 0.0001));

      completer.complete({
        'id': 100,
        'request_id': reqId2,
        'latitude': 34.5100,
        'longitude': 131.4800,
        'status': '未対応',
      });
      final synced2 = await f2;
      expect(synced2.latitude, closeTo(34.5100, 0.0001));
      expect(synced2.longitude, closeTo(131.4800, 0.0001));
    });

    test('parseCoordinates falls back on empty/blank primary keys while keeping 0 and rejecting invalid non-empty values', () {
      final emptyPrimary = RescueRequest.parseCoordinates({
        'latitude': '',
        'lat': 33.9578,
        'longitude': '',
        'lng': 130.9415,
      });
      expect(emptyPrimary, isNotNull);
      expect(emptyPrimary!.latitude, closeTo(33.9578, 0.0001));
      expect(emptyPrimary.longitude, closeTo(130.9415, 0.0001));

      final rowModel = RescueRequest.fromSupabaseRow({
        'id': 31,
        'request_id': 'MAMO-EMPTY-PRIMARY',
        'latitude': '',
        'lat': 33.9578,
        'longitude': '',
        'lng': 130.9415,
      });
      expect(rowModel.latitude, closeTo(33.9578, 0.0001));
      expect(rowModel.longitude, closeTo(130.9415, 0.0001));

      final whitespacePrimary = RescueRequest.parseCoordinates({
        'latitude': '   ',
        'lat': '34.4081',
        'longitude': '\t',
        'lon': '131.3991',
      });
      expect(whitespacePrimary, isNotNull);
      expect(whitespacePrimary!.latitude, closeTo(34.4081, 0.0001));
      expect(whitespacePrimary.longitude, closeTo(131.3991, 0.0001));

      final zeroCoords = RescueRequest.parseCoordinates({
        'latitude': 0,
        'longitude': 0.0,
      });
      expect(zeroCoords, isNotNull);
      expect(zeroCoords!.latitude, 0.0);
      expect(zeroCoords.longitude, 0.0);

      expect(
        RescueRequest.parseCoordinates({
          'latitude': 'abc',
          'lat': 33.9578,
          'longitude': 130.9415,
        }),
        isNull,
      );
      expect(
        RescueRequest.parseCoordinates({
          'latitude': 'NaN',
          'lat': 33.9578,
          'longitude': 130.9415,
        }),
        isNull,
      );
      expect(
        RescueRequest.parseCoordinates({
          'latitude': '',
          'lat': '   ',
          'longitude': '',
          'lng': '',
        }),
        isNull,
      );
    });

    test('submitCitizenRequest does not overwrite Realtime UPDATE coordinates when insertRequest completes late', () async {
      final completer = Completer<Map<String, dynamic>?>();
      final ds = _CoordinateFakeRescueDataSource(
        onInsert: (_) => completer.future,
      );
      final store = RescueStore(
        startClock: false,
        dataSource: ds,
        autoInitialize: false,
      );
      addTearDown(store.dispose);
      await store.initializeRealtime();

      final submitFuture = store.submitCitizenRequest(
        requesterName: '競合 太郎',
        rescueDetails: '救助要請',
        considerations: 'なし',
        locationText: '山口県山口市中央1-1',
      );
      final reqId = store.requests.single.id;
      expect(store.requests.single.latitude, closeTo(34.1785, 0.0001));
      expect(store.requests.single.longitude, closeTo(131.4737, 0.0001));

      // 1) Realtime INSERT 先着（dbId: 777 へ昇格）
      ds.emitInsert({
        'id': 777,
        'request_id': reqId,
        'latitude': 34.1785,
        'longitude': 131.4737,
        'status': '未対応',
      });
      await pumpEventQueue();
      expect(store.requests.single.dbId, '777');

      // 2) Realtime UPDATE 到着（精密座標と担当機関・ステータス更新）
      ds.emitUpdate({
        'id': 777,
        'status': '対応中',
        'assigned_agency': '消防',
        'latitude': 34.1950,
        'longitude': 131.4950,
      });
      await pumpEventQueue();
      expect(store.requests.single.status, RequestStatus.working);
      expect(store.requests.single.agency, AgencyType.fire);
      expect(store.requests.single.latitude, closeTo(34.1950, 0.0001));
      expect(store.requests.single.longitude, closeTo(131.4950, 0.0001));

      // 3) 座標なしの追加 Realtime UPDATE 到着後も最新座標を保持
      ds.emitUpdate({
        'id': 777,
        'status': '対応済み',
      });
      await pumpEventQueue();

      // 4) 遅延していた insertRequest が旧座標で完了しても巻き戻らない
      completer.complete({
        'id': 777,
        'request_id': reqId,
        'latitude': 34.1785,
        'longitude': 131.4737,
        'status': '未対応',
      });
      final synced = await submitFuture;
      expect(synced.status, RequestStatus.done);
      expect(synced.agency, AgencyType.fire);
      expect(synced.latitude, closeTo(34.1950, 0.0001));
      expect(synced.longitude, closeTo(131.4950, 0.0001));
      expect(store.requests.single.status, RequestStatus.done);
      expect(store.requests.single.agency, AgencyType.fire);
      expect(store.requests.single.latitude, closeTo(34.1950, 0.0001));
      expect(store.requests.single.longitude, closeTo(131.4950, 0.0001));
    });
  });

  group('GsiMapView Widget tests', () {
    testWidgets(
      'renders GSI pale tile URL, attribution, 5 pins, pin tap callback, and zoom/fit controls',
      (tester) async {
        final ds = FakeRescueDataSource(
          initialRows: [
            {
              'id': 5,
              'request_id': 'mamo-0001',
              'user_name': '高橋 健',
              'request_type': '消防',
              'location': '山口県岩国市今津町1-14-51付近',
              'status': '対応中',
            },
            {
              'id': 4,
              'request_id': 'mamo-0002',
              'user_name': '田中 美咲',
              'request_type': '警察',
              'location': '山口県宇部市常盤町1-7-1付近',
              'status': '対応中',
            },
            {
              'id': 3,
              'request_id': 'mamo-0003',
              'user_name': '鈴木 一郎',
              'request_type': '自衛隊',
              'location': '山口県萩市大字江向510付近',
              'status': '未対応',
            },
            {
              'id': 2,
              'request_id': 'mamo-0004',
              'user_name': '佐藤 花子',
              'request_type': '消防',
              'location': '山口県下関市南部町1-1付近',
              'status': '未対応',
            },
            {
              'id': 1,
              'request_id': 'mamo-0005',
              'user_name': '山田 太郎',
              'request_type': '救急',
              'location': '山口県山口市亀山町2-1付近',
              'status': '未対応',
            },
          ],
        );
        final store = RescueStore(
          startClock: false,
          dataSource: ds,
          autoInitialize: false,
        );
        addTearDown(store.dispose);
        await store.initializeRealtime();

        String? tappedId;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 500,
                child: GsiMapView(
                  requests: store.requests,
                  height: 500,
                  initialZoom: 8.5,
                  tileProvider: _FakeMemoryTileProvider(),
                  onPinTap: (id) => tappedId = id,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 国土地理院 淡色地図タイル URL・UA・エラーキャッシュ設定・出典表示の確認
        final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
        expect(tileLayer.urlTemplate, GsiMapView.gsiPaleTileUrl);
        expect(
          tileLayer.urlTemplate,
          'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png',
        );
        expect(
          tileLayer.tileProvider.headers['User-Agent'],
          'flutter_map (${GsiMapView.userAgentPackageName})',
        );
        expect(
          tileLayer.evictErrorTileStrategy,
          EvictErrorTileStrategy.notVisible,
        );
        expect(find.text('出典：国土地理院（地理院タイル・淡色地図）'), findsOneWidget);

        // 5件のマーカーが先端アライメントで描画され、タップで該当IDが通知されること
        final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
        expect(markerLayer.markers.length, 5);
        expect(markerLayer.markers.first.alignment, isNotNull);
        expect(markerLayer.markers.first.alignment!.y, lessThan(0));

        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is Tooltip && (w.message ?? '').startsWith('山田 太郎：'),
          ),
        );
        await tester.pump();
        expect(tappedId, 'mamo-0005');

        // 拡大・縮小・全体表示ボタンが動作しズーム値が変化すること
        final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        final controller = flutterMap.mapController!;
        expect(controller.camera.zoom, closeTo(8.5, 0.01));

        await tester.tap(find.byTooltip('拡大'));
        await tester.pumpAndSettle();
        expect(controller.camera.zoom, closeTo(9.5, 0.01));

        await tester.tap(find.byTooltip('縮小'));
        await tester.pumpAndSettle();
        expect(controller.camera.zoom, closeTo(8.5, 0.01));

        await tester.tap(find.byTooltip('全体を表示'));
        await tester.pumpAndSettle();
        expect(controller.camera.zoom, inInclusiveRange(GsiMapView.minZoom, 14.0));
      },
    );

    testWidgets('fit-all handles 0 requests, 1 request, and coincident requests safely', (
      tester,
    ) async {
      final base = RescueRequest.fromSupabaseRow({
        'id': 1,
        'request_id': 'mamo-0005',
        'user_name': '山田 太郎',
        'location': '山口県山口市亀山町2-1付近',
        'status': '未対応',
      });

      // 0件
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GsiMapView(
              requests: const [],
              height: 300,
              tileProvider: _FakeMemoryTileProvider(),
              onPinTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('全体を表示'));
      await tester.pumpAndSettle();

      // 1件
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GsiMapView(
              requests: [base],
              height: 300,
              tileProvider: _FakeMemoryTileProvider(),
              onPinTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('全体を表示'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera.zoom,
        closeTo(14.0, 0.01),
      );

      // 同一座標の複数件
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GsiMapView(
              requests: [
                base,
                base.copyWith(id: 'mamo-dup'),
              ],
              height: 300,
              tileProvider: _FakeMemoryTileProvider(),
              onPinTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('全体を表示'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera.zoom,
        closeTo(14.0, 0.01),
      );
    });

    testWidgets('tapping pin inside MapView navigates to RequestsView with selected item', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 2,
            'request_id': 'mamo-0004',
            'user_name': '佐藤 花子',
            'request_type': '消防',
            'location': '山口県下関市南部町1-1付近',
            'status': '未対応',
          },
          {
            'id': 1,
            'request_id': 'mamo-0005',
            'user_name': '山田 太郎',
            'request_type': '救急',
            'location': '山口県山口市亀山町2-1付近',
            'status': '未対応',
          },
        ],
      );
      await tester.pumpWidget(
        MamoApp(
          dataSource: ds,
          startClock: false,
          initialMode: MamoAppMode.municipality,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppSidebar),
          matching: find.text('位置情報マップ'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MapView), findsOneWidget);
      expect(find.byType(GsiMapView), findsOneWidget);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').startsWith('佐藤 花子：'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RequestsView), findsOneWidget);
      expect(find.text('ID：mamo-0004'), findsOneWidget);
    });

    testWidgets('reuses default NetworkTileProvider across parent rebuilds and switches tileProvider safely', (
      tester,
    ) async {
      final tick = ValueNotifier<int>(0);
      addTearDown(tick.dispose);

      Widget buildHarness({TileProvider? tileProvider}) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: ListenableBuilder(
                listenable: tick,
                builder: (context, _) {
                  return GsiMapView(
                    requests: const [],
                    height: 300,
                    tileProvider: tileProvider,
                    onPinTap: (_) {},
                  );
                },
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness(tileProvider: null));
      await tester.pump();

      final initialProvider =
          tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider;
      expect(initialProvider, isA<NetworkTileProvider>());

      // 毎秒クロック相当の親リビルドを 5 回発生させても同一インスタンスを維持すること
      for (var i = 1; i <= 5; i++) {
        tick.value = i;
        await tester.pump();
        final currentProvider =
            tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider;
        expect(identical(currentProvider, initialProvider), isTrue);
      }

      // 外部 TileProvider への切替 → null への復帰 → アンマウントで例外が起きないこと
      final externalProvider = _CountingTileProvider();
      await tester.pumpWidget(buildHarness(tileProvider: externalProvider));
      await tester.pump();
      expect(
        identical(
          tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider,
          externalProvider,
        ),
        isTrue,
      );
      expect(externalProvider.disposeCount, 0);

      await tester.pumpWidget(buildHarness(tileProvider: null));
      await tester.pump();
      final recreatedProvider =
          tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider;
      expect(recreatedProvider, isA<NetworkTileProvider>());
      expect(identical(recreatedProvider, initialProvider), isFalse);
      expect(externalProvider.disposeCount, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('guards invalid coordinates, invalid-only fit-all fallback, and zero-size layout', (
      tester,
    ) async {
      expect(GsiMapView.isValidCoordinate(34.18, 131.58), isTrue);
      expect(GsiMapView.isValidCoordinate(-90.0, 180.0), isTrue);
      expect(GsiMapView.isValidCoordinate(90.0, -180.0), isTrue);
      expect(GsiMapView.isValidCoordinate(double.nan, 131.58), isFalse);
      expect(GsiMapView.isValidCoordinate(34.18, double.infinity), isFalse);
      expect(GsiMapView.isValidCoordinate(90.1, 131.58), isFalse);
      expect(GsiMapView.isValidCoordinate(34.18, -180.1), isFalse);

      final base = RescueRequest.fromSupabaseRow({
        'id': 1,
        'request_id': 'mamo-valid',
        'user_name': '正常 太郎',
        'location': '山口県山口市亀山町2-1付近',
        'status': '未対応',
      });
      final invalidRequests = <RescueRequest>[
        base.copyWith(id: 'nan', latitude: double.nan),
        base.copyWith(id: 'inf', longitude: double.infinity),
        base.copyWith(id: 'lat-high', latitude: 95.0),
        base.copyWith(id: 'lng-low', longitude: -185.0),
      ];

      // 正常1件 + 異常4件混在でも正常ピンのみ描画し fitAll がクラッシュしないこと
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GsiMapView(
              requests: [base, ...invalidRequests],
              height: 300,
              tileProvider: _FakeMemoryTileProvider(),
              onPinTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(1),
      );
      await tester.tap(find.byTooltip('全体を表示'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera.zoom,
        closeTo(14.0, 0.01),
      );

      // 全件不正座標の場合はピン 0 件・全体表示で初期中心/初期ズームへフォールバック
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GsiMapView(
              requests: invalidRequests,
              height: 300,
              initialZoom: 8.5,
              tileProvider: _FakeMemoryTileProvider(),
              onPinTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        isEmpty,
      );
      await tester.tap(find.byTooltip('全体を表示'));
      await tester.pumpAndSettle();
      final fallbackCamera =
          tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;
      expect(fallbackCamera.center.latitude, closeTo(34.18, 0.01));
      expect(fallbackCamera.center.longitude, closeTo(131.58, 0.01));
      expect(fallbackCamera.zoom, closeTo(8.5, 0.01));

      // サイズ 0 のレイアウトでも例外が発生しないこと
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 0,
              height: 0,
              child: GsiMapView(
                requests: [base],
                tileProvider: _FakeMemoryTileProvider(),
                onPinTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
