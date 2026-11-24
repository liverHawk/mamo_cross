import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/config/supabase_config.dart';
import 'package:mamo_cross/models/citizen_models.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/services/rescue_data_source.dart';
import 'package:mamo_cross/services/supabase_rescue_data_source.dart';
import 'package:mamo_cross/state/citizen_store.dart';
import 'package:mamo_cross/state/rescue_store.dart';
import 'package:supabase/supabase.dart';

class _FakeRescueDataSource implements RescueDataSource {
  Completer<Map<String, dynamic>?>? insertCompleter;
  Future<Map<String, dynamic>?> Function(Map<String, dynamic> payload)?
      onInsert;
  final List<Map<String, dynamic>> insertedPayloads = <Map<String, dynamic>>[];
  final List<({String dbId, RequestStatus status})> statusUpdates =
      <({String dbId, RequestStatus status})>[];
  Map<String, dynamic>? nextInsertResult;
  Object? insertError;
  Object? updateStatusError;
  bool disposed = false;

  final StreamController<RescueRealtimeEvent> realtimeController =
      StreamController<RescueRealtimeEvent>.broadcast();

  void Function(bool connected)? _onConnectionChanged;

  @override
  Future<List<Map<String, dynamic>>> fetchInitialRequests({
    int limit = 50,
  }) async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Stream<RescueRealtimeEvent> subscribeRequests({
    void Function(bool connected)? onConnectionChanged,
  }) {
    _onConnectionChanged = onConnectionChanged;
    _onConnectionChanged?.call(true);
    return realtimeController.stream;
  }

  @override
  Future<void> updateStatus({
    required String dbId,
    required RequestStatus status,
  }) async {
    statusUpdates.add((dbId: dbId, status: status));
    if (updateStatusError != null) {
      throw updateStatusError!;
    }
  }

  @override
  Future<Map<String, dynamic>?> insertRequest(
    Map<String, dynamic> payload,
  ) async {
    insertedPayloads.add(Map<String, dynamic>.from(payload));
    if (insertError != null) {
      throw insertError!;
    }
    if (onInsert != null) {
      return onInsert!(payload);
    }
    if (insertCompleter != null) {
      return insertCompleter!.future;
    }
    return nextInsertResult;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await realtimeController.close();
  }
}

void main() {
  group('CitizenModels & 15-column Supabase payload', () {
    test('buildCitizenRescuePayload produces strictly 15 expected keys', () {
      final createdAt = DateTime.utc(2026, 11, 24, 5, 30, 0);
      final payload = buildCitizenRescuePayload(
        requestId: 'MAMO-123456',
        createdAt: createdAt,
        requesterName: '山田 太郎',
        rescueDetails: '1階から出られません',
        considerations: '🤰 妊娠中',
      );

      expect(
        payload.keys.toSet(),
        equals(<String>{
          'request_id',
          'created_at',
          'user_name',
          'requester_name',
          'request_type',
          'detail',
          'rescue_details',
          'health_condition',
          'consideration',
          'considerations',
          'location',
          'location_text',
          'distance',
          'distance_text',
          'status',
        }),
      );
      expect(payload.length, 15);
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('age'), isFalse);
      expect(payload.containsKey('gender'), isFalse);
      expect(payload.containsKey('latPercent'), isFalse);
      expect(payload.containsKey('topPercent'), isFalse);

      expect(payload['request_id'], 'MAMO-123456');
      expect(payload['created_at'], '2026-11-24T05:30:00.000Z');
      expect(payload['user_name'], '山田 太郎');
      expect(payload['requester_name'], '山田 太郎');
      expect(payload['request_type'], '救助要請');
      expect(payload['detail'], '1階から出られません');
      expect(payload['rescue_details'], '1階から出られません');
      expect(payload['health_condition'], '🤰 妊娠中');
      expect(payload['consideration'], '🤰 妊娠中');
      expect(payload['considerations'], '🤰 妊娠中');
      expect(payload['location'], '〇〇地区付近');
      expect(payload['location_text'], '〇〇地区付近');
      expect(payload['distance'], '約150m先（デモ）');
      expect(payload['distance_text'], '約150m先（デモ）');
      expect(payload['status'], '未対応');
    });

    test('buildCitizenRescuePayload normalizes blank fields to defaults', () {
      final payload = buildCitizenRescuePayload(
        requestId: 'MAMO-999',
        createdAt: DateTime.now(),
        requesterName: '   ',
        rescueDetails: '',
        considerations: '  ',
        locationText: '',
        distanceText: '  ',
      );

      expect(payload['user_name'], 'あなた');
      expect(payload['requester_name'], 'あなた');
      expect(payload['detail'], '救助が必要です');
      expect(payload['rescue_details'], '救助が必要です');
      expect(payload['health_condition'], 'なし');
      expect(payload['consideration'], 'なし');
      expect(payload['considerations'], 'なし');
      expect(payload['location'], '〇〇地区付近');
      expect(payload['location_text'], '〇〇地区付近');
      expect(payload['distance'], '約150m先（デモ）');
      expect(payload['distance_text'], '約150m先（デモ）');
    });
  });

  group('CitizenStore state, transitions, timers & disposal', () {
    test('initial state matches mamo-main demo specification', () {
      final store = CitizenStore();
      addTearDown(store.dispose);

      expect(store.currentScreen, CitizenScreen.login);
      expect(store.currentTab, CitizenTab.home);
      expect(store.isLoggedIn, isFalse);
      expect(store.registeredName, 'あなた');
      expect(store.mySafety, CitizenSafetyStatus.safe);
      expect(store.toastMessage, isNull);
      expect(store.latestRescueSummary, isNull);

      expect(store.familyMembers.length, 4);
      expect(store.familyMembers[0].name, 'お母さん');
      expect(store.familyMembers[0].status, CitizenSafetyStatus.safe);
      expect(store.familyMembers[1].name, 'お父さん');
      expect(store.familyMembers[1].status, CitizenSafetyStatus.safe);
      expect(store.familyMembers[2].name, 'お姉ちゃん');
      expect(store.familyMembers[2].status, CitizenSafetyStatus.damaged);
      expect(store.familyMembers[3].name, 'あなた');
      expect(store.familyMembers[3].isSelf, isTrue);
      expect(store.familyMembers[3].status, CitizenSafetyStatus.safe);

      expect(store.shelters, isNotEmpty);
      expect(store.nearestShelter.name, '〇〇地区 〇〇小学校');
      expect(store.nearestShelter.distanceText, '150m先');
      expect(store.nearestShelter.isOpen, isTrue);

      expect(store.municipalityNotices, isNotEmpty);
      expect(store.familyMessages, isNotEmpty);
    });

    test('screen navigation and 5 bottom tabs switch and notify', () {
      final store = CitizenStore();
      addTearDown(store.dispose);

      var notifications = 0;
      store.addListener(() => notifications++);

      for (final screen in CitizenScreen.values) {
        if (screen == CitizenScreen.login) continue;
        store.goToScreen(screen);
        expect(store.currentScreen, screen);
      }
      store.goToScreen(CitizenScreen.login);
      expect(store.currentScreen, CitizenScreen.login);
      expect(notifications, CitizenScreen.values.length);

      for (final tab in CitizenTab.values) {
        store.selectTab(tab);
        expect(store.currentScreen, CitizenScreen.home);
        expect(store.currentTab, tab);
      }
    });

    test('registration flow saves profile and carries considerations to rescue',
        () {
      final store = CitizenStore();
      addTearDown(store.dispose);

      store.selectPhotoDemo();
      expect(store.profile.photoSelected, isTrue);
      expect(store.toastMessage, 'デモ：写真アップロード画面を想定しています');

      store.selectIdDocDemo();
      expect(store.profile.idDocSelected, isTrue);
      expect(store.toastMessage, 'デモ：身分証選択');

      store.updateBasicInfo(
        name: '  山田 花子  ',
        birthDate: '1990-05-01',
        bloodType: 'A型',
        gender: '女性',
        postalCode: '753-0001',
        prefecture: '山口県',
        addressDetail: '山口市〇〇1-2',
      );
      expect(store.profile.birthDate, '1990-05-01');
      expect(store.profile.bloodType, 'A型');
      expect(store.profile.gender, '女性');
      expect(store.profile.fullAddress, '〒753-0001 山口県 山口市〇〇1-2');

      store.toggleConsideration(kCitizenConsiderationOptions[2]); // 🤰 妊娠中
      store.toggleConsideration(kCitizenConsiderationOptions[4]); // 🩺 医療的ケアが必要
      store.toggleConsideration(kCitizenConsiderationOptions[4]); // untoggle
      store.updateOtherConsideration('ピーナッツアレルギー');

      store.completeRegistration();
      expect(store.isLoggedIn, isTrue);
      expect(store.registeredName, '山田 花子');
      expect(store.currentScreen, CitizenScreen.home);
      expect(store.toastMessage, '登録が完了しました（デモ）');

      store.openRescue();
      expect(store.currentScreen, CitizenScreen.rescue);
      expect(store.rescueNameDraft, '山田 花子');
      expect(
        store.rescueCareDraft,
        '${kCitizenConsiderationOptions[2]}、ピーナッツアレルギー',
      );

      // Blank name falls back to 'あなた'
      store.updateBasicInfo(name: '   ');
      store.completeRegistration();
      expect(store.registeredName, 'あなた');
    });

    test('updateMySafety syncs self entry in familyMembers and filter works', () {
      final store = CitizenStore();
      addTearDown(store.dispose);

      store.updateMySafety(CitizenSafetyStatus.damaged);
      expect(store.mySafety, CitizenSafetyStatus.damaged);
      expect(store.toastMessage, '被害ありとして登録しました');

      final selfMember = store.familyMembers.firstWhere((m) => m.isSelf);
      expect(selfMember.status, CitizenSafetyStatus.damaged);
      expect(
        store.familyMembers.firstWhere((m) => m.id == 'mom').status,
        CitizenSafetyStatus.safe,
      );

      store.setFamilyStatusFilter(CitizenSafetyStatus.damaged);
      expect(store.filteredFamilyMembers.length, 2);
      expect(
        store.filteredFamilyMembers.map((m) => m.name),
        containsAll(<String>['お姉ちゃん', 'あなた']),
      );

      store.sendFamilySafetyCheck();
      expect(store.familyCheckInSent, isTrue);
      expect(store.toastMessage, '家族に安否確認通知を送信しました（デモ）');

      store.updateMySafety(CitizenSafetyStatus.safe);
      expect(
        store.familyMembers.firstWhere((m) => m.isSelf).status,
        CitizenSafetyStatus.safe,
      );
    });

    test('map selection, messages, settings and resetDemo work properly', () {
      final store = CitizenStore();
      addTearDown(store.dispose);

      store.selectShelterById('shelter_2');
      expect(store.selectedShelter?.name, '〇〇公民館（福祉避難所）');
      store.toggleHazardsOnMap();
      expect(store.showHazardsOnMap, isFalse);

      final beforeCount = store.familyMessages.length;
      store.sendMessage('   '); // ignored
      expect(store.familyMessages.length, beforeCount);

      store.sendMessage('駅前で合流できそうです');
      expect(store.familyMessages.length, beforeCount + 1);
      expect(store.familyMessages.last.body, '駅前で合流できそうです');
      expect(store.familyMessages.last.isMine, isTrue);

      store.sendQuickReply(kCitizenQuickReplies.first);
      expect(store.familyMessages.length, beforeCount + 2);
      expect(store.familyMessages.last.body, kCitizenQuickReplies.first);

      store.setNotificationsEnabled(false);
      expect(store.notificationsEnabled, isFalse);
      expect(store.toastMessage, '災害通知をオフにしました');

      store.updateBasicInfo(name: 'テスト');
      store.updateMySafety(CitizenSafetyStatus.damaged);
      store.selectTab(CitizenTab.settings);

      store.resetDemo();
      expect(store.currentScreen, CitizenScreen.login);
      expect(store.currentTab, CitizenTab.home);
      expect(store.registeredName, 'あなた');
      expect(store.mySafety, CitizenSafetyStatus.safe);
      expect(store.familyMembers.firstWhere((m) => m.isSelf).status,
          CitizenSafetyStatus.safe);
      expect(store.familyMessages.length, beforeCount);
      expect(store.notificationsEnabled, isTrue);
      expect(store.selectedShelter, isNull);
      expect(store.showHazardsOnMap, isTrue);
      expect(store.latestRescueSummary, isNull);
      expect(store.toastMessage, isNull);
    });

    testWidgets(
      'demoLogin transition, toast auto-dismiss, overwrite & dispose safety',
      (tester) async {
        final store = CitizenStore();

        store.demoLogin();
        expect(store.toastMessage, 'デモログインしました');
        expect(store.currentScreen, CitizenScreen.login);

        await tester.pump(const Duration(milliseconds: 449));
        expect(store.currentScreen, CitizenScreen.login);

        await tester.pump(const Duration(milliseconds: 1));
        expect(store.currentScreen, CitizenScreen.home);
        expect(store.isLoggedIn, isTrue);

        // Clear remaining toast timer (1800 - 450 = 1350ms)
        await tester.pump(const Duration(milliseconds: 1350));
        expect(store.toastMessage, isNull);

        // Toast auto-dismiss after 1800ms and overwrite test
        store.showToast('1つ目');
        expect(store.toastMessage, '1つ目');

        await tester.pump(const Duration(milliseconds: 1000));
        expect(store.toastMessage, '1つ目');

        store.showToast('2つ目');
        expect(store.toastMessage, '2つ目');

        await tester.pump(const Duration(milliseconds: 1000));
        expect(store.toastMessage, '2つ目');

        await tester.pump(const Duration(milliseconds: 800));
        expect(store.toastMessage, isNull);

        // Dispose while timers are active must not throw or leak pending timers
        store.demoLogin();
        store.showToast('破棄前トースト');
        store.dispose();

        // Calling methods after dispose is a safe no-op
        store.goToScreen(CitizenScreen.rescue);
        store.selectTab(CitizenTab.map);
        store.showToast('ignored');
        store.updateMySafety(CitizenSafetyStatus.damaged);

        await tester.pump(const Duration(seconds: 3));
      },
    );
  });

  group('RescueStore.submitCitizenRequest & Supabase integration', () {
    test('works offline with dataSource: null and applies defaults', () async {
      final store = RescueStore(startClock: false, dataSource: null);
      addTearDown(store.dispose);

      var notifyCount = 0;
      store.addListener(() => notifyCount++);

      final created = await store.submitCitizenRequest(
        requesterName: ' ',
        rescueDetails: '',
        considerations: '',
      );

      expect(created.id, startsWith('MAMO-'));
      expect(created.dbId, isNull);
      expect(created.name, 'あなた');
      expect(created.content, '救助が必要です');
      expect(created.consideration, 'なし');
      expect(created.location, '〇〇地区付近');
      expect(created.distance, '約150m先（デモ）');
      expect(created.status, RequestStatus.pending);
      expect(created.agency, AgencyType.emergency);
      expect(created.age, 0);
      expect(created.gender, '');
      expect(created.latPercent, 50.0);
      expect(created.topPercent, 50.0);

      expect(store.requests.length, 1);
      expect(store.requests.first.id, created.id);
      expect(store.newCount, 1);
      expect(store.selectedRequest?.id, created.id);
      expect(notifyCount, 1);

      // Rapid second submission inserts at index 0 with distinct ID
      final second = await store.submitCitizenRequest(
        requesterName: '佐藤 健',
        rescueDetails: '水が必要です',
        considerations: '🟢 オストメイト',
      );
      expect(store.requests.length, 2);
      expect(store.requests.first.id, second.id);
      expect(second.id, isNot(created.id));
    });

    test('works safely with unconfigured SupabaseConfig.empty', () async {
      final ds = SupabaseRescueDataSource(config: SupabaseConfig.empty);
      final store = RescueStore(startClock: false, dataSource: ds);
      addTearDown(store.dispose);

      final directResult = await ds.insertRequest(<String, dynamic>{
        'request_id': 'MAMO-DIRECT',
      });
      expect(directResult, isNull);

      final created = await store.submitCitizenRequest(
        requesterName: '鈴木 一郎',
        rescueDetails: '屋根の上で待機中',
        considerations: 'なし',
      );

      expect(store.requests.length, 1);
      expect(store.requests.single.id, created.id);
      expect(store.requests.single.dbId, isNull);
      expect(store.requests.single.name, '鈴木 一郎');
    });

    test('sends 15-column payload and reconciles dbId from insertRequest',
        () async {
      final fakeDs = _FakeRescueDataSource();
      final store = RescueStore(startClock: false, dataSource: fakeDs);
      addTearDown(store.dispose);

      await store.initializeRealtime();

      fakeDs.nextInsertResult = <String, dynamic>{
        'id': 777,
        'request_type': '救助要請',
        'requester_name': '田中 美咲',
        'rescue_details': '足首を負傷して動けません',
        'considerations': '🤰 妊娠中',
        'location_text': '〇〇地区付近',
        'distance_text': '約150m先（デモ）',
        'status': '未対応',
      };

      final created = await store.submitCitizenRequest(
        requesterName: '田中 美咲',
        rescueDetails: '足首を負傷して動けません',
        considerations: '🤰 妊娠中',
      );

      expect(fakeDs.insertedPayloads.length, 1);
      final sent = fakeDs.insertedPayloads.single;
      expect(sent.length, 15);
      expect(sent['request_id'], created.id);
      expect(sent.containsKey('age'), isFalse);
      expect(sent.containsKey('gender'), isFalse);
      expect(sent.containsKey('latPercent'), isFalse);
      expect(sent.containsKey('topPercent'), isFalse);

      expect(store.requests.length, 1);
      expect(store.requests.single.dbId, '777');
      expect(created.dbId, '777');

      await store.changeStatus(created.id, RequestStatus.working);
      expect(fakeDs.statusUpdates.length, 1);
      expect(fakeDs.statusUpdates.single.dbId, '777');
      expect(fakeDs.statusUpdates.single.status, RequestStatus.working);
    });

    test('falls back cleanly to local entry when insertRequest throws',
        () async {
      final fakeDs = _FakeRescueDataSource()
        ..insertError = StateError('network unreachable');
      final store = RescueStore(startClock: false, dataSource: fakeDs);
      addTearDown(store.dispose);

      final created = await store.submitCitizenRequest(
        requesterName: '高橋',
        rescueDetails: '停電で医療機器の電源が必要です',
        considerations: '🫁 人工呼吸器を使用',
      );

      expect(store.requests.length, 1);
      expect(store.requests.single.id, created.id);
      expect(store.requests.single.dbId, isNull);
    });

    test('deduplicates Realtime INSERT arriving AFTER insertRequest resolves',
        () async {
      final fakeDs = _FakeRescueDataSource();
      final store = RescueStore(startClock: false, dataSource: fakeDs);
      addTearDown(store.dispose);

      final alerts = <RescueRequest>[];
      final sub = store.incomingAlerts.listen(alerts.add);
      addTearDown(sub.cancel);

      await store.initializeRealtime();

      fakeDs.nextInsertResult = <String, dynamic>{
        'id': 801,
        'request_type': '救助要請',
        'requester_name': '伊藤',
        'rescue_details': '助けが必要です',
        'considerations': 'なし',
        'status': '未対応',
      };

      final created = await store.submitCitizenRequest(
        requesterName: '伊藤',
        rescueDetails: '助けが必要です',
        considerations: 'なし',
      );

      fakeDs.realtimeController.add(
        RescueInsertedEvent(<String, dynamic>{
          'id': 801,
          'request_id': created.id,
          'request_type': '救助要請',
          'requester_name': '伊藤',
          'rescue_details': '助けが必要です',
          'considerations': 'なし',
          'status': '未対応',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.requests.length, 1);
      expect(store.requests.single.id, created.id);
      expect(store.requests.single.dbId, '801');
      expect(alerts, isEmpty);
    });

    test('deduplicates Realtime INSERT arriving BEFORE insertRequest resolves',
        () async {
      final completer = Completer<Map<String, dynamic>?>();
      final fakeDs = _FakeRescueDataSource()..insertCompleter = completer;
      final store = RescueStore(startClock: false, dataSource: fakeDs);
      addTearDown(store.dispose);

      final alerts = <RescueRequest>[];
      final sub = store.incomingAlerts.listen(alerts.add);
      addTearDown(sub.cancel);

      await store.initializeRealtime();

      final submitFuture = store.submitCitizenRequest(
        requesterName: '佐藤',
        rescueDetails: '救助要請',
        considerations: 'なし',
      );

      // Immediate optimistic local insertion
      expect(store.requests.length, 1);
      expect(store.requests.single.dbId, isNull);
      final localRequestId = store.requests.single.id;
      expect(fakeDs.insertedPayloads.single['request_id'], localRequestId);

      // Realtime INSERT arrives BEFORE HTTP insertRequest completes
      fakeDs.realtimeController.add(
        RescueInsertedEvent(<String, dynamic>{
          'id': 905,
          'request_id': localRequestId,
          'request_type': '救助要請',
          'requester_name': '佐藤',
          'rescue_details': '救助要請',
          'considerations': 'なし',
          'status': '未対応',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.requests.length, 1);
      expect(store.requests.single.id, localRequestId);
      expect(store.requests.single.dbId, '905');
      expect(alerts, isEmpty);

      // Now HTTP insertRequest resolves
      completer.complete(<String, dynamic>{
        'id': 905,
        'request_id': localRequestId,
        'request_type': '救助要請',
        'requester_name': '佐藤',
        'rescue_details': '救助要請',
        'considerations': 'なし',
        'status': '未対応',
      });
      final resolved = await submitFuture;

      expect(store.requests.length, 1);
      expect(store.requests.single.id, localRequestId);
      expect(store.requests.single.dbId, '905');
      expect(resolved.dbId, '905');
      expect(alerts, isEmpty);
    });

    test(
        'preserves distinct dbId records sharing same request_id with #dbId suffix',
        () {
      final store = RescueStore(startClock: false);
      addTearDown(store.dispose);

      final added1 = store.addDbRequest(<String, dynamic>{
        'id': 10,
        'request_id': 'SAME-1',
        'requester_name': 'Aさん',
        'rescue_details': '要請A',
        'status': '未対応',
      });
      final added2 = store.addDbRequest(<String, dynamic>{
        'id': 11,
        'request_id': 'SAME-1',
        'requester_name': 'Bさん',
        'rescue_details': '要請B',
        'status': '未対応',
      });

      expect(added1, isTrue);
      expect(added2, isTrue);
      expect(store.requests.length, 2);
      expect(store.requests.map((r) => r.id), containsAll(<String>['SAME-1', 'SAME-1#11']));
    });

    test('CitizenStore.submitRescue updates summary, screen, safety & RescueStore',
        () async {
      final fakeDs = _FakeRescueDataSource()
        ..nextInsertResult = <String, dynamic>{
          'id': 42,
          'request_type': '救助要請',
          'requester_name': '山田 太郎',
          'rescue_details': '2階に取り残されています',
          'considerations': '🩺 医療的ケアが必要',
          'status': '未対応',
        };
      final rescueStore = RescueStore(startClock: false, dataSource: fakeDs);
      final citizenStore = CitizenStore();
      addTearDown(rescueStore.dispose);
      addTearDown(citizenStore.dispose);

      citizenStore.updateBasicInfo(name: '山田 太郎');
      citizenStore.toggleConsideration(kCitizenConsiderationOptions[4]);
      citizenStore.completeRegistration();
      citizenStore.openRescue();

      expect(citizenStore.rescueNameDraft, '山田 太郎');
      expect(citizenStore.rescueCareDraft, '🩺 医療的ケアが必要');

      citizenStore.updateRescueDraft(detail: '2階に取り残されています');

      final future = citizenStore.submitRescue(rescueStore);

      // Synchronous transition & local insertion
      expect(citizenStore.currentScreen, CitizenScreen.rescueSent);
      expect(citizenStore.mySafety, CitizenSafetyStatus.rescueNeeded);
      expect(
        citizenStore.familyMembers.firstWhere((m) => m.isSelf).status,
        CitizenSafetyStatus.rescueNeeded,
      );
      expect(rescueStore.requests.length, 1);
      expect(citizenStore.latestRescueSummary, isNotNull);
      expect(citizenStore.latestRescueSummary!.requesterName, '山田 太郎');
      expect(citizenStore.latestRescueSummary!.detail, '2階に取り残されています');

      final submitted = await future;
      expect(submitted.dbId, '42');
      expect(citizenStore.latestRescueSummary!.syncedToRemote, isTrue);
      expect(citizenStore.toastMessage, '自治体へ救助要請を送信しました');
    });
  });

  group('SupabaseRescueDataSource.insertRequest safety guards', () {
    test('returns null safely when unconfigured, errored, or disposed',
        () async {
      final unconfigured =
          SupabaseRescueDataSource(config: SupabaseConfig.empty);
      final payload = buildCitizenRescuePayload(
        requestId: 'MAMO-GUARD-1',
        createdAt: DateTime.utc(2026, 11, 24, 6, 0, 0),
        requesterName: '山口 花子',
        rescueDetails: '浸水で動けません',
        considerations: '🟢 オストメイト',
      );
      expect(await unconfigured.insertRequest(payload), isNull);
      await unconfigured.dispose();
      expect(await unconfigured.insertRequest(payload), isNull);

      final client = SupabaseClient(
        'http://127.0.0.1:59999',
        'test-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      );
      final ds = SupabaseRescueDataSource(client: client);
      addTearDown(() async {
        await ds.dispose();
        await client.dispose();
      });

      // Under TestWidgetsFlutterBinding, HTTP requests return 400; must return null safely
      expect(await ds.insertRequest(payload), isNull);

      await ds.dispose();
      expect(await ds.insertRequest(payload), isNull);
    });

    test('returns null cleanly when SupabaseConfig has an invalid URL',
        () async {
      final invalidUrlDs = SupabaseRescueDataSource(
        config: const SupabaseConfig(
          url: 'http://[::1',
          publishableKey: 'invalid-key',
        ),
      );
      addTearDown(invalidUrlDs.dispose);

      final payload = buildCitizenRescuePayload(
        requestId: 'MAMO-BAD-URL',
        createdAt: DateTime.utc(2026, 11, 24, 6, 10, 0),
        requesterName: '山口 花子',
        rescueDetails: '接続テスト',
        considerations: 'なし',
      );

      expect(await invalidUrlDs.insertRequest(payload), isNull);
    });
  });

  group('Iteration 2 regression guards', () {
    test(
        'syncs in-flight changeStatus to DB when insertRequest resolves first',
        () async {
      final completer = Completer<Map<String, dynamic>?>();
      final fakeDs = _FakeRescueDataSource()..insertCompleter = completer;
      final store = RescueStore(startClock: false, dataSource: fakeDs);
      addTearDown(store.dispose);

      await store.initializeRealtime();

      final submitFuture = store.submitCitizenRequest(
        requesterName: '田中',
        rescueDetails: '救助要請',
        considerations: 'なし',
      );

      final localId = store.requests.single.id;
      expect(store.requests.single.dbId, isNull);

      // Operator changes status before insertRequest finishes
      await store.changeStatus(localId, RequestStatus.working);
      expect(store.requests.single.status, RequestStatus.working);
      expect(fakeDs.statusUpdates, isEmpty);

      // insertRequest resolves with remote status '未対応'
      completer.complete(<String, dynamic>{
        'id': 777,
        'request_id': localId,
        'status': '未対応',
      });
      final resolved = await submitFuture;

      expect(resolved.dbId, '777');
      expect(resolved.status, RequestStatus.working);
      expect(store.requests.single.status, RequestStatus.working);
      expect(fakeDs.statusUpdates.length, 1);
      expect(fakeDs.statusUpdates.single.dbId, '777');
      expect(fakeDs.statusUpdates.single.status, RequestStatus.working);
    });

    test(
        'handles updateStatus failure gracefully during pre-dbId status sync',
        () async {
      final completer = Completer<Map<String, dynamic>?>();
      final fakeDs = _FakeRescueDataSource()
        ..insertCompleter = completer
        ..updateStatusError = StateError('patch failed');
      final store = RescueStore(startClock: false, dataSource: fakeDs);
      addTearDown(store.dispose);

      await store.initializeRealtime();

      final submitFuture = store.submitCitizenRequest(
        requesterName: '高橋',
        rescueDetails: '救助要請',
        considerations: 'なし',
      );
      final localId = store.requests.single.id;
      await store.changeStatus(localId, RequestStatus.done);

      completer.complete(<String, dynamic>{
        'id': 888,
        'request_id': localId,
        'status': '未対応',
      });
      final resolved = await submitFuture;

      expect(resolved.dbId, '888');
      expect(resolved.status, RequestStatus.done);
      expect(fakeDs.statusUpdates.length, 1);
    });

    test(
        'preserves local status and syncs to DB on Realtime-first promotion',
        () async {
      final completer = Completer<Map<String, dynamic>?>();
      final fakeDs = _FakeRescueDataSource()..insertCompleter = completer;
      final store = RescueStore(startClock: false, dataSource: fakeDs);
      addTearDown(store.dispose);

      await store.initializeRealtime();

      final submitFuture = store.submitCitizenRequest(
        requesterName: '鈴木',
        rescueDetails: '救助要請',
        considerations: 'なし',
      );
      final localId = store.requests.single.id;

      await store.changeStatus(localId, RequestStatus.working);
      expect(fakeDs.statusUpdates, isEmpty);

      // Realtime INSERT arrives BEFORE HTTP insertRequest resolves
      fakeDs.realtimeController.add(
        RescueInsertedEvent(<String, dynamic>{
          'id': 303,
          'request_id': localId,
          'requester_name': '鈴木',
          'rescue_details': '救助要請',
          'status': '未対応',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.requests.length, 1);
      expect(store.requests.single.dbId, '303');
      expect(store.requests.single.status, RequestStatus.working);
      expect(fakeDs.statusUpdates.length, 1);
      expect(fakeDs.statusUpdates.single.dbId, '303');
      expect(fakeDs.statusUpdates.single.status, RequestStatus.working);

      // HTTP insertRequest resolves afterwards: must not duplicate updateStatus
      completer.complete(<String, dynamic>{
        'id': 303,
        'request_id': localId,
        'status': '未対応',
      });
      final resolved = await submitFuture;

      expect(resolved.dbId, '303');
      expect(resolved.status, RequestStatus.working);
      expect(fakeDs.statusUpdates.length, 1);
    });

    test(
        'deduplicates addDbRequest when id is null and request_id matches existing',
        () async {
      final store = RescueStore(startClock: false);
      addTearDown(store.dispose);

      final alerts = <RescueRequest>[];
      final sub = store.incomingAlerts.listen(alerts.add);
      addTearDown(sub.cancel);

      final created = await store.submitCitizenRequest(
        requesterName: '佐々木',
        rescueDetails: '救助要請',
        considerations: 'なし',
      );

      final added = store.addDbRequest(
        <String, dynamic>{
          'id': null,
          'request_id': created.id,
          'requester_name': '佐々木',
          'rescue_details': '救助要請',
          'status': '未対応',
        },
        notifyAlert: true,
      );

      expect(added, isFalse);
      expect(store.requests.length, 1);
      expect(store.requests.single.id, created.id);
      await Future<void>.delayed(Duration.zero);
      expect(alerts, isEmpty);
    });

    test(
        'CitizenStore.submitRescue preserves newest summary on out-of-order completion and disposed RescueStore',
        () async {
      final completers = <Completer<Map<String, dynamic>?>>[];
      final fakeDs = _FakeRescueDataSource()
        ..onInsert = (_) {
          final c = Completer<Map<String, dynamic>?>();
          completers.add(c);
          return c.future;
        };
      final rescueStore = RescueStore(startClock: false, dataSource: fakeDs);
      final citizenStore = CitizenStore();
      addTearDown(rescueStore.dispose);
      addTearDown(citizenStore.dispose);

      final future1 = citizenStore.submitRescue(
        rescueStore,
        name: '本人A',
        detail: '1回目',
      );
      final id1 = citizenStore.latestRescueSummary!.requestId;

      final future2 = citizenStore.submitRescue(
        rescueStore,
        name: '本人B',
        detail: '2回目',
      );
      final id2 = citizenStore.latestRescueSummary!.requestId;
      expect(id2, isNot(id1));

      // Complete 2nd request first
      completers[1].complete(<String, dynamic>{
        'id': 202,
        'request_id': id2,
        'status': '未対応',
      });
      final sub2 = await future2;
      expect(sub2.dbId, '202');
      expect(citizenStore.latestRescueSummary!.requestId, id2);
      expect(citizenStore.latestRescueSummary!.syncedToRemote, isTrue);

      // Complete 1st request afterwards: must NOT overwrite latestRescueSummary
      completers[0].complete(<String, dynamic>{
        'id': 101,
        'request_id': id1,
        'status': '未対応',
      });
      final sub1 = await future1;
      expect(sub1.dbId, '101');
      expect(citizenStore.latestRescueSummary!.requestId, id2);
      expect(citizenStore.latestRescueSummary!.requesterName, '本人B');
      expect(citizenStore.latestRescueSummary!.detail, '2回目');

      // Disposed RescueStore with existing head must not leak existing entry into summary
      final disposedStore = RescueStore(startClock: false);
      disposedStore.addDbRequest(<String, dynamic>{
        'id': 55,
        'request_id': 'MAMO-EXISTING',
        'requester_name': '他人X',
        'rescue_details': '既存要請',
        'status': '未対応',
      });
      disposedStore.dispose();

      final citizenStore2 = CitizenStore();
      addTearDown(citizenStore2.dispose);
      final subDisposed = await citizenStore2.submitRescue(
        disposedStore,
        name: '本人C',
        detail: '破棄済みテスト',
      );
      expect(subDisposed.name, '本人C');
      expect(citizenStore2.latestRescueSummary!.requestId,
          isNot('MAMO-EXISTING'));
      expect(citizenStore2.latestRescueSummary!.requesterName, '本人C');
      expect(citizenStore2.latestRescueSummary!.detail, '破棄済みテスト');
    });
  });
}
