import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mamo_cross/models/app_mode.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/views/dashboard_view.dart';
import 'package:mamo_cross/views/status_view.dart';
import 'package:mamo_cross/widgets/app_sidebar.dart';

import 'e2e_test_helpers.dart';

void main() {
  group('Tier 3: クロス機能組み合わせ・ペアワイズ検証 (16 tests)', () {
    testWidgets(
      'T3-01: 登録情報 (#reg2 氏名 + #reg3 配慮事項) -> SOS送信 -> 自治体4画面横断反映 -> 利用者復帰',
      (tester) async {
        final fakeDs = FakeRescueDataSource();
        addTearDown(fakeDs.dispose);

        await pumpMamoApp(
          tester,
          dataSource: fakeDs,
          autoConnect: true,
          viewport: kDesktopViewportSize,
          navigateTo: MamoAppMode.citizen,
        );

        await scrollAndTap(tester, find.text('新規登録'));
        await scrollAndTap(tester, find.text('次へ'));
        await enterFieldByHint(tester, '山田 太郎', '高橋 蓮');
        await selectDropdownOption(tester, find.text('選択してください'), 'O型');
        await selectRadioOption(tester, '男性');
        await enterFieldByHint(tester, '郵便番号', '753-0001');
        await enterFieldByHint(tester, '市区町村', '山口市滝町1-1');
        await scrollAndTap(tester, find.text('次へ'));

        await scrollAndTap(tester, find.textContaining('人工呼吸器を使用').first);
        await scrollAndTap(tester, find.textContaining('医療的ケアが必要').first);
        await enterFieldByHint(tester, 'アレルギー', '気管切開あり');
        await scrollAndTap(tester, find.text('登録する'), settle: false);
        await pumpPastToasts(tester);

        await scrollAndTap(tester, find.text('救助要請'));
        expect(find.text('高橋 蓮'), findsAtLeastNWidgets(1));
        await enterRescueDetail(tester, '2階に孤立');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);

        expect(find.textContaining('MAMO-'), findsOneWidget);
        expect(fakeDs.insertedPayloads, hasLength(1));
        final payload = fakeDs.insertedPayloads.single;
        expect(payload['requester_name'], '高橋 蓮');
        expect(payload['rescue_details'], '2階に孤立');
        final considerations = payload['considerations'].toString();
        expect(considerations, contains('人工呼吸器を使用'));
        expect(considerations, contains('医療的ケアが必要'));
        expect(considerations, contains('気管切開あり'));

        await switchCitizenToMunicipality(tester);
        expect(find.textContaining('高橋 蓮'), findsAtLeastNWidgets(1));

        await navigateMunicipalityView(tester, '救助要請一覧');
        expect(find.textContaining('高橋 蓮'), findsAtLeastNWidgets(1));
        expect(find.text('救急要請'), findsAtLeastNWidgets(1));
        expect(find.text('未対応'), findsAtLeastNWidgets(1));

        await navigateMunicipalityView(tester, '位置情報マップ');
        expect(findMapPinTooltip('高橋 蓮', statusLabel: '未対応'), findsOneWidget);

        await navigateMunicipalityView(tester, '対応状況');
        final statusView = find.byType(StatusView);
        expect(statusView, findsOneWidget);
        expect(
          find.descendant(of: statusView, matching: find.text('高橋 蓮')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: statusView, matching: find.text('救急')),
          findsAtLeastNWidgets(1),
        );

        await switchMunicipalityToCitizen(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('救助要請を送信しました'), findsOneWidget);
      },
    );

    testWidgets(
      'T3-02: #reg2 空名 + #reg3 未入力 -> #rescue 空送信フォールバック x 15列ペイロード検証',
      (tester) async {
        final fakeDs = FakeRescueDataSource();
        addTearDown(fakeDs.dispose);

        await pumpMamoApp(
          tester,
          dataSource: fakeDs,
          autoConnect: true,
          viewport: kDesktopViewportSize,
          navigateTo: MamoAppMode.citizen,
        );

        await scrollAndTap(tester, find.text('新規登録'));
        await scrollAndTap(tester, find.text('次へ'));
        await scrollAndTap(tester, find.text('次へ'));
        await scrollAndTap(tester, find.text('登録する'), settle: false);
        await pumpPastToasts(tester);

        await scrollAndTap(tester, find.text('救助要請'));
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);

        expect(fakeDs.insertedPayloads, hasLength(1));
        expectValid15ColPayload(
          fakeDs.insertedPayloads.single,
          expectedName: 'あなた',
          expectedDetail: '救助が必要です',
          expectedConsiderations: 'なし',
        );
        expect(find.textContaining('あなた'), findsAtLeastNWidgets(1));
        expect(find.textContaining('山口県山口市亀山町付近'), findsOneWidget);

        await switchCitizenToMunicipality(tester);
        await navigateMunicipalityView(tester, '救助要請一覧');
        expect(find.textContaining('あなた'), findsAtLeastNWidgets(1));
        expect(find.text('救助が必要です'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('T3-03: #home 安否3ボタン <-> 安否タブ更新 <-> ホーム家族リスト あなた バッジ双方向同期', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await scrollAndTap(
        tester,
        findSafetyStatusButton('被害あり').first,
        settle: false,
      );
      await expectToastAndDrain(tester, '被害ありとして登録しました');
      expect(find.textContaining('被害あり'), findsAtLeastNWidgets(3));
      expectAtMostNWidgets(find.textContaining('無事'), 3);

      await tapCitizenBottomTab(tester, '安否');
      final safeBtn = findSafetyStatusButton('無事');
      expect(safeBtn, findsAtLeastNWidgets(1));
      await scrollAndTap(tester, safeBtn.first, settle: false);
      await pumpPastToasts(tester);

      await tapCitizenBottomTab(tester, 'ホーム');
      expect(find.text('家族グループ'), findsOneWidget);
      expect(find.textContaining('無事'), findsAtLeastNWidgets(4));
      expectAtMostNWidgets(find.textContaining('被害あり'), 2);
    });

    testWidgets('T3-04: 安否タブ家族確認操作 x ホーム状態 x モード往復時の状態保持', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await tapCitizenBottomTab(tester, '安否');
      expect(find.text('避難所情報'), findsNothing);
      expect(find.text('お姉ちゃん'), findsOneWidget);
      final notifyBtn = findInteractiveWithText('確認');
      expect(notifyBtn, findsAtLeastNWidgets(1));
      await scrollAndTap(tester, notifyBtn.first, settle: false);
      await expectToastAndDrain(tester, 'しました');

      await switchCitizenToMunicipality(tester);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));

      await switchMunicipalityToCitizen(tester);
      await tapCitizenBottomTab(tester, 'ホーム');
      expect(find.text('お母さん'), findsOneWidget);
      expect(find.text('お父さん'), findsOneWidget);
      expect(find.text('お姉ちゃん'), findsOneWidget);
      expect(find.text('あなた'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T3-05: 設定タブでの登録プロフィール表示・編集 <-> #rescue プリフィル連動', (
      tester,
    ) async {
      final fakeDs = FakeRescueDataSource();
      addTearDown(fakeDs.dispose);

      await pumpMamoApp(
        tester,
        dataSource: fakeDs,
        autoConnect: true,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
      await enterFieldByHint(tester, '山田 太郎', '佐藤 誠');
      await scrollAndTap(tester, find.text('次へ'));
      await scrollAndTap(tester, find.textContaining('妊娠中').first);
      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);

      await tapCitizenBottomTab(tester, '設定');
      expect(find.textContaining('佐藤 誠'), findsAtLeastNWidgets(1));

      final editBtn = findInteractiveWithText('編集');
      expect(editBtn, findsAtLeastNWidgets(1));
      await scrollAndTap(tester, editBtn.first);
      final fields = find.byType(TextField);
      expect(fields, findsAtLeastNWidgets(1));
      await scrollAndEnterText(tester, fields.first, '佐藤 誠（更新）');
      final saveBtn = findInteractiveWithText('保存');
      expect(saveBtn, findsAtLeastNWidgets(1));
      await scrollAndTap(tester, saveBtn.first, settle: false);
      await pumpPastToasts(tester);
      expect(find.textContaining('佐藤 誠（更新）'), findsAtLeastNWidgets(1));

      await tapCitizenBottomTab(tester, 'ホーム');
      await scrollAndTap(tester, find.text('救助要請'));
      expect(find.text('佐藤 誠（更新）'), findsAtLeastNWidgets(1));
    });

    testWidgets('T3-06: 設定タブの通知スイッチ切替 + 自治体切替往復保持 + ログアウト -> #login 復帰', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await tapCitizenBottomTab(tester, '設定');
      final switchBefore = tester.widget<Switch>(find.byType(Switch).first).value;
      await scrollAndTap(tester, find.byType(Switch).first, settle: false);
      await pumpPastToasts(tester);
      expect(
        tester.widget<Switch>(find.byType(Switch).first).value,
        !switchBefore,
      );

      await switchCitizenToMunicipality(tester);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));

      await switchMunicipalityToCitizen(tester);
      expect(
        tester.widget<Switch>(find.byType(Switch).first).value,
        !switchBefore,
      );

      await scrollAndTap(tester, find.textContaining('ログアウト').first);
      expect(find.text('MAMO'), findsAtLeastNWidgets(1));
      expect(find.text('新規登録'), findsOneWidget);
      expect(find.text('ログイン'), findsOneWidget);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
    });

    testWidgets('T3-07: ログアウト後ゲスト再ログイン x 共有 RescueStore 内 SOS 履歴の独立性検証', (
      tester,
    ) async {
      final fakeDs = FakeRescueDataSource();
      addTearDown(fakeDs.dispose);

      await pumpMamoApp(
        tester,
        dataSource: fakeDs,
        autoConnect: true,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
      await enterFieldByHint(tester, '山田 太郎', '田中 一郎');
      await scrollAndTap(tester, find.text('次へ'));
      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);

      await scrollAndTap(tester, find.text('救助要請'));
      await enterRescueDetail(tester, '停電で支援要請');
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);
      await scrollAndTap(tester, find.text('ホームへ戻る'));

      await tapCitizenBottomTab(tester, '設定');
      await scrollAndTap(tester, find.textContaining('ログアウト').first);
      await loginAsGuest(tester);

      await scrollAndTap(tester, find.text('救助要請'));
      expect(find.text('田中 一郎'), findsNothing);

      await switchCitizenToMunicipality(tester);
      await navigateMunicipalityView(tester, '救助要請一覧');
      expect(find.text('すべて 1'), findsOneWidget);
      expect(find.textContaining('田中 一郎'), findsAtLeastNWidgets(1));
    });

    testWidgets('T3-08: マップタブ <-> メッセージタブ操作とモード往復時の状態保持', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await tapCitizenBottomTab(tester, 'マップ');
      expect(find.text('家族グループ'), findsNothing);
      expect(find.textContaining('大殿小学校'), findsAtLeastNWidgets(1));
      expect(find.textContaining('現在地'), findsAtLeastNWidgets(1));

      await tapCitizenBottomTab(tester, 'メッセージ');
      final msgField = find.byType(TextField);
      expect(msgField, findsAtLeastNWidgets(1));
      await scrollAndEnterText(tester, msgField.first, '避難所へ向かいます');
      final sendTrigger = findSendMessageTrigger();
      expect(sendTrigger, findsAtLeastNWidgets(1));
      await scrollAndTap(tester, sendTrigger.first, settle: false);
      await pumpPastToasts(tester);

      await switchCitizenToMunicipality(tester);
      await switchMunicipalityToPortal(tester);
      await openCitizenFromPortal(tester);

      expect(find.textContaining('避難所へ向かいます'), findsAtLeastNWidgets(1));
      await tapCitizenBottomTab(tester, 'ホーム');
      expect(find.text('家族グループ'), findsOneWidget);
      await tapCitizenBottomTab(tester, 'マップ');
      expect(find.text('家族グループ'), findsNothing);
      expect(find.textContaining('大殿小学校'), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'T3-09: 連続複数 SOS 送信 + 自治体側ステータス段階遷移 (未対応->対応中->対応済み) x 横断ビュー反映',
      (tester) async {
        final fakeDs = FakeRescueDataSource();
        addTearDown(fakeDs.dispose);

        await pumpMamoApp(
          tester,
          dataSource: fakeDs,
          autoConnect: true,
          viewport: kDesktopViewportSize,
          navigateTo: MamoAppMode.citizen,
        );
        await loginAsGuest(tester);

        await scrollAndTap(tester, find.text('救助要請'));
        await enterFieldByHint(tester, '登録した名前', '伊藤 健');
        await enterRescueDetail(tester, '停電で医療機器停止');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);
        await scrollAndTap(tester, find.text('ホームへ戻る'));
        await tester.pump(const Duration(milliseconds: 20));

        await scrollAndTap(tester, find.text('救助要請'));
        await enterFieldByHint(tester, '登録した名前', '渡辺 美香');
        await enterRescueDetail(tester, '浸水で玄関開かず');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);

        await switchCitizenToMunicipality(tester);
        await navigateMunicipalityView(tester, '救助要請一覧');
        await selectMunicipalityRequest(tester, '伊藤 健');
        await scrollAndTap(tester, find.text('対応開始'), settle: false);
        await pumpPastSnackBars(tester);
        await scrollAndTap(tester, find.text('対応完了'), settle: false);
        await pumpPastSnackBars(tester);

        await scrollAndTap(tester, find.text('対応済み 1'));
        expect(find.textContaining('伊藤 健'), findsAtLeastNWidgets(1));

        await navigateMunicipalityView(tester, 'ダッシュボード');
        final dashboard = find.byType(DashboardView);
        expect(dashboard, findsOneWidget);
        expect(
          find.descendant(of: dashboard, matching: find.text('新規救助要請')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dashboard, matching: find.text('1')),
          findsAtLeastNWidgets(2),
        );

        await navigateMunicipalityView(tester, '対応状況');
        final statusView = find.byType(StatusView);
        expect(statusView, findsOneWidget);
        expect(
          find.descendant(of: statusView, matching: find.text('伊藤 健')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: statusView, matching: find.text('渡辺 美香')),
          findsOneWidget,
        );

        await navigateMunicipalityView(tester, '統計・履歴');
        expect(find.text('統計・履歴'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'T3-10: オンライン insertRequest + updateStatus の dbId 連携 + Realtime 同一 request_id 重複排除',
      (tester) async {
        final fakeDs = FakeRescueDataSource(startingDbId: 1001);
        addTearDown(fakeDs.dispose);

        await pumpMamoApp(
          tester,
          dataSource: fakeDs,
          autoConnect: true,
          viewport: kDesktopViewportSize,
          navigateTo: MamoAppMode.citizen,
        );
        await loginAsGuest(tester);

        await scrollAndTap(tester, find.text('救助要請'));
        await enterFieldByHint(tester, '登録した名前', '木村 拓');
        await enterRescueDetail(tester, '転倒負傷');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);

        fakeDs.emitInsert({...fakeDs.insertedPayloads.single, 'id': 1001});
        await pumpPastToasts(tester);

        await switchCitizenToMunicipality(tester);
        await navigateMunicipalityView(tester, '救助要請一覧');
        expect(find.text('すべて 1'), findsOneWidget);

        await scrollAndTap(tester, find.text('対応開始'), settle: false);
        await pumpPastSnackBars(tester);
        expect(fakeDs.updatedStatuses, hasLength(1));
        expect(fakeDs.updatedStatuses.single.dbId, '1001');
        expect(fakeDs.updatedStatuses.single.status, RequestStatus.working);
      },
    );

    testWidgets('T3-11: オフライン (offlineNull) および通信例外 (throwError) 時の SOS 送信＋ローカル反映', (
      tester,
    ) async {
      final fakeDs = FakeRescueDataSource(
        insertBehavior: FakeInsertBehavior.offlineNull,
      );
      addTearDown(fakeDs.dispose);

      await pumpMamoApp(
        tester,
        dataSource: fakeDs,
        autoConnect: true,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await scrollAndTap(tester, find.text('救助要請'));
      await enterFieldByHint(tester, '登録した名前', 'オフライン市民');
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);
      expect(find.text('救助要請を送信しました'), findsOneWidget);

      await scrollAndTap(tester, find.text('ホームへ戻る'));
      fakeDs.insertBehavior = FakeInsertBehavior.throwError;
      await scrollAndTap(tester, find.text('救助要請'));
      await enterFieldByHint(tester, '登録した名前', 'エラー耐性市民');
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);
      expect(find.text('救助要請を送信しました'), findsOneWidget);

      expect(tester.takeException(), isNull);
      expect(fakeDs.attemptedPayloads, hasLength(2));
      expect(fakeDs.insertedPayloads, isEmpty);
      await switchCitizenToMunicipality(tester);
      await navigateMunicipalityView(tester, '救助要請一覧');
      expect(find.text('すべて 2'), findsOneWidget);
      expect(find.textContaining('オフライン市民'), findsAtLeastNWidgets(1));
      expect(find.textContaining('エラー耐性市民'), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'T3-12: 動的ビューポートリサイズ横断 (1280x800 モバイル枠 -> 390x844 全画面 -> 自治体 Drawer -> 1280x800)',
      (tester) async {
        await pumpMamoApp(
          tester,
          viewport: kDesktopViewportSize,
          navigateTo: MamoAppMode.citizen,
        );
        expect(find.text('9:41'), findsOneWidget);
        await loginAsGuest(tester);

        await resizeViewportAndSettle(tester, 390, 844);
        expect(tester.takeException(), isNull);
        expect(find.text('家族グループ'), findsOneWidget);

        await switchCitizenToMunicipality(tester);
        expect(find.byType(AppSidebar), findsNothing);
        expect(find.byTooltip('メニューを開く'), findsOneWidget);

        await resizeViewportAndSettle(tester, 1280, 800);
        expect(tester.takeException(), isNull);
        expect(find.byType(AppSidebar), findsOneWidget);
        expect(tester.getSize(find.byType(AppSidebar)).width, equals(218.0));
      },
    );

    testWidgets(
      'T3-13: 狭幅モバイル (480x800) での相互モード切替 + 自治体 Drawer 経由の SOS 確認',
      (tester) async {
        await pumpMamoApp(
          tester,
          viewport: const Size(480, 800),
          navigateTo: MamoAppMode.citizen,
        );
        await loginAsGuest(tester);

        await scrollAndTap(tester, find.text('救助要請'));
        await enterFieldByHint(tester, '登録した名前', '狭幅 送信者');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);
        expect(find.text('救助要請を送信しました'), findsOneWidget);

        await switchCitizenToMunicipality(tester);
        expect(find.byType(AppSidebar), findsNothing);

        await navigateMunicipalityView(tester, '救助要請一覧');
        expect(find.textContaining('狭幅 送信者'), findsAtLeastNWidgets(1));

        await navigateMunicipalityView(tester, '対応状況');
        final statusView = find.byType(StatusView);
        expect(statusView, findsOneWidget);
        expect(
          find.descendant(of: statusView, matching: find.text('狭幅 送信者')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('T3-14: #reg1 デモ操作 -> #reg2 入力 -> ‹ 戻る往復時の入力保持 -> #reg3 -> #home', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('顔写真を登録'), settle: false);
      await expectToastAndDrain(tester, 'デモ：写真アップロード画面を想定しています');
      await scrollAndTap(tester, find.text('身分証を選択'), settle: false);
      await expectToastAndDrain(tester, 'デモ：身分証選択');
      await scrollAndTap(tester, find.text('次へ'));

      await enterFieldByHint(tester, '山田 太郎', '小林 舞');
      await selectDropdownOption(tester, find.text('選択してください'), 'AB型');
      await selectRadioOption(tester, 'その他');
      await scrollAndTap(tester, find.text('次へ'));
      expect(find.text('③ 救助要請時の情報'), findsOneWidget);

      await scrollAndTap(tester, find.text('‹'));
      expect(find.text('小林 舞'), findsAtLeastNWidgets(1));
      expect(find.text('AB型'), findsAtLeastNWidgets(1));

      await scrollAndTap(tester, find.text('‹'));
      expect(find.text('① 本人確認'), findsOneWidget);
      await scrollAndTap(tester, find.text('次へ'));
      expect(find.text('小林 舞'), findsAtLeastNWidgets(1));
      await scrollAndTap(tester, find.text('次へ'));
      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);

      expect(find.text('家族グループ'), findsOneWidget);
    });

    testWidgets(
      'T3-15: 自治体 PartnersView (救急フィルタ) + RequestsView フィルタ x 市民 SOS 連携',
      (tester) async {
        final fakeDs = FakeRescueDataSource();
        addTearDown(fakeDs.dispose);

        await pumpMamoApp(
          tester,
          dataSource: fakeDs,
          autoConnect: true,
          viewport: kDesktopViewportSize,
          navigateTo: MamoAppMode.municipality,
        );

        await navigateMunicipalityView(tester, '関係機関連携');
        await scrollAndTap(tester, find.text('救急要請を見る'));
        expect(find.text('救助要請一覧'), findsAtLeastNWidgets(1));

        await switchMunicipalityToCitizen(tester);
        await loginAsGuest(tester);
        await scrollAndTap(tester, find.text('救助要請'));
        await enterFieldByHint(tester, '登録した名前', '救急フィルタ確認');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);

        await switchCitizenToMunicipality(tester);
        expect(find.textContaining('救急フィルタ確認'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('T3-16: #home 上部メニュー ☰ -> #login 復帰 x ログイン 450ms 遷移 x モード切替整合性', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await scrollAndTap(tester, find.text('☰'));
      expect(find.text('新規登録'), findsOneWidget);

      await scrollAndTap(tester, find.text('ログイン'), settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('デモログインしました'), findsAtLeastNWidgets(1));
      await pumpTransition(tester);
      await pumpPastToasts(tester);
      expect(find.text('家族グループ'), findsOneWidget);

      await switchCitizenToMunicipality(tester);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));
      await switchMunicipalityToPortal(tester);
      expect(find.textContaining('利用者'), findsAtLeastNWidgets(1));
    });
  });
}
