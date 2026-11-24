import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/config/supabase_config.dart';
import 'package:mamo_cross/main.dart';
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
import 'package:mamo_cross/widgets/app_sidebar.dart';
import 'package:material_ui/material_ui.dart';

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
    test('keeps pure local 5 requests when dataSource is null', () {
      final store = RescueStore(startClock: false);
      addTearDown(store.dispose);

      expect(store.requests.length, 5);
      expect(store.requests.first.id, 'mamo-0005');
      expect(store.requests.last.id, 'mamo-0001');
      expect(store.selectedId, 'mamo-0005');
      expect(store.newCount, 3);
      expect(store.workingCount, 2);
      expect(store.doneCount, 0);
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
      expect(store.requests.length, 7);
      // rows.reversed を先頭挿入するため最新(102)が先頭、重複101はスキップ、末尾にローカル5件
      expect(store.requests[0].id, 'MAMO-102');
      expect(store.requests[1].dbId, '101');
      expect(store.requests[2].id, 'mamo-0005');
      expect(store.requests.last.id, 'mamo-0001');
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

    test('handles Realtime UPDATE for matching dbId without touching local items', () async {
      final ds = FakeRescueDataSource(
        initialRows: [
          {
            'id': 300,
            'request_id': 'MAMO-300',
            'requester_name': '更新対象',
            'location_text': '山口市吉敷',
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
        store.requests.firstWhere((r) => r.id == 'mamo-0005').status,
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

      // ローカル初期項目は dbId == null なので updateStatus を呼ばない
      await store.changeStatus('mamo-0005', RequestStatus.working);
      expect(
        store.requests.firstWhere((r) => r.id == 'mamo-0005').status,
        RequestStatus.working,
      );
      expect(store.selectedId, 'mamo-0005');
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

      // ローカル5件で稼働継続しクラッシュしない
      expect(store.requests.length, 5);
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

    test('uses real Yamaguchi Prefecture addresses and municipality name by default', () {
      final store = RescueStore(startClock: false);
      addTearDown(store.dispose);

      expect(store.municipalityName, '山口県 災害対策本部');
      expect(store.requests.length, 5);
      for (final req in store.requests) {
        expect(req.location, contains('山口県'));
        expect(req.location, isNot(contains('○○')));
      }
    });

    test('replaces matching local initial requests on DB sync without duplicating ids', () async {
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

      final localSnapshot = {
        for (final r in store.requests) r.id: r,
      };

      await store.initializeRealtime();

      expect(store.requests.length, 5);
      expect(
        store.requests.map((r) => r.id).toList(),
        ['mamo-0005', 'mamo-0004', 'mamo-0003', 'mamo-0002', 'mamo-0001'],
      );
      expect(store.selectedId, 'mamo-0005');

      for (final req in store.requests) {
        final local = localSnapshot[req.id]!;
        expect(req.dbId, isNotNull);
        expect(req.latPercent, local.latPercent);
        expect(req.topPercent, local.topPercent);
        expect(req.age, local.age);
        expect(req.gender, local.gender);
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
        ],
      );

      await tester.pumpWidget(
        MamoApp(
          dataSource: ds,
          startClock: false,
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
      await tester.pumpWidget(MamoApp(dataSource: ds, startClock: false));
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
      await tester.pumpWidget(MamoApp(dataSource: ds, startClock: false));
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

      final ds = FakeRescueDataSource();
      await tester.pumpWidget(MamoApp(dataSource: ds, startClock: false));
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
      await tester.pumpWidget(MamoApp(dataSource: ds, startClock: false));
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
      await tester.pumpWidget(MamoApp(dataSource: ds, startClock: false));
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

    testWidgets('RequestsView highlights exactly one item when DB returns matching initial request_ids', (
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

      await tester.pumpWidget(MamoApp(dataSource: ds, startClock: false));
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
  });
}
