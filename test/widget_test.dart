import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/config/supabase_config.dart';
import 'package:mamo_cross/main.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/services/rescue_data_source.dart';
import 'package:mamo_cross/services/supabase_rescue_data_source.dart';
import 'package:mamo_cross/state/rescue_store.dart';
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
      expect(find.text('○○市 災害対策本部 ▾'), findsOneWidget);
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
      expect(find.text('○○市 災害対策本部 ▾'), findsNothing);
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
  });
}
