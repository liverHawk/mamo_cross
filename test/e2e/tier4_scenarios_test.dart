import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mamo_cross/config/supabase_config.dart';
import 'package:mamo_cross/models/app_mode.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/services/supabase_rescue_data_source.dart';
import 'package:mamo_cross/views/status_view.dart';
import 'package:mamo_cross/widgets/app_sidebar.dart';

import 'e2e_test_helpers.dart';

void main() {
  group('Tier 4: 実運用・展示ショーケースシナリオ (6 scenarios)', () {
    testWidgets(
      'Scenario 1: 被災住民の新規登録（医療配慮事項あり）-> SOS送信 -> 自治体受付・ステータス更新 -> 利用者復帰',
      (tester) async {
        final fakeDs = FakeRescueDataSource(startingDbId: 2001);
        addTearDown(fakeDs.dispose);

        await pumpMamoApp(
          tester,
          dataSource: fakeDs,
          autoConnect: true,
          viewport: kDesktopViewportSize,
        );

        // 1. ポータルから利用者モードを開く（モバイル枠表示）
        expect(find.textContaining('利用者'), findsAtLeastNWidgets(1));
        expect(find.textContaining('自治体'), findsAtLeastNWidgets(1));
        await openCitizenFromPortal(tester);
        expect(find.text('9:41'), findsOneWidget);

        // 2. #login -> #reg1 デモ本人確認
        await scrollAndTap(tester, find.text('新規登録'));
        await scrollAndTap(tester, find.text('顔写真を登録'), settle: false);
        await expectToastAndDrain(tester, 'デモ：写真アップロード画面を想定しています');
        await scrollAndTap(tester, find.text('身分証を選択'), settle: false);
        await expectToastAndDrain(tester, 'デモ：身分証選択');
        await scrollAndTap(tester, find.text('次へ'));

        // 3. #reg2 基本情報入力
        await enterFieldByHint(tester, '山田 太郎', '山口 花子');
        await selectDropdownOption(tester, find.text('選択してください'), 'A型');
        await selectRadioOption(tester, '女性');
        await enterFieldByHint(tester, '郵便番号', '753-0001');
        await selectDropdownOption(tester, find.text('都道府県を選択'), '山口県');
        await enterFieldByHint(tester, '市区町村', '山口市滝町1-1');
        await scrollAndTap(tester, find.text('次へ'));

        // 4. #reg3 医療配慮事項登録
        await scrollAndTap(tester, find.textContaining('ホルモン治療中').first);
        await scrollAndTap(tester, find.textContaining('医療的ケアが必要').first);
        await enterFieldByHint(tester, 'アレルギー', 'インスリン持参必要');
        await scrollAndTap(tester, find.text('登録する'), settle: false);
        await expectToastAndDrain(tester, '登録が完了しました（デモ）');

        // 5. #home 災害警報・安否更新 -> SOS 起動
        expect(find.textContaining('震度5強'), findsOneWidget);
        expect(find.text('家族グループ'), findsOneWidget);
        expect(find.text('避難所情報'), findsOneWidget);
        await scrollAndTap(
          tester,
          findSafetyStatusButton('被害あり').first,
          settle: false,
        );
        await expectToastAndDrain(tester, '被害ありとして登録しました');
        await scrollAndTap(tester, find.text('救助要請'));

        // 6. #rescue 入力・送信
        expect(find.text('山口 花子'), findsAtLeastNWidgets(1));
        await enterFieldByHint(tester, '建物内に閉じ込め', '自宅1階で家具に挟まれ動けません');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await expectToastAndDrain(tester, '自治体へ救助要請を送信しました');

        // 7. #rescueSent 確認 -> ホーム復帰
        expect(find.text('✓'), findsOneWidget);
        expect(find.textContaining('MAMO-'), findsOneWidget);
        expect(find.textContaining('山口 花子'), findsAtLeastNWidgets(1));
        expect(find.textContaining('山口県山口市滝町1-1'), findsOneWidget);
        expect(fakeDs.insertedPayloads, hasLength(1));
        expectValid15ColPayload(
          fakeDs.insertedPayloads.single,
          expectedName: '山口 花子',
          expectedDetail: '自宅1階で家具に挟まれ動けません',
          expectedLocation: '山口県山口市滝町1-1',
          expectedConsiderationSubstrings: const [
            'ホルモン治療中',
            '医療的ケアが必要',
            'インスリン持参必要',
          ],
        );
        await scrollAndTap(tester, find.text('ホームへ戻る'));

        // 8. 自治体モードへ切替し、受付確認・対応開始・マップ/状況反映を検証
        await switchCitizenToMunicipality(tester);
        expect(find.text('新規救助要請'), findsOneWidget);
        expect(find.textContaining('山口 花子'), findsAtLeastNWidgets(1));

        await navigateMunicipalityView(tester, '救助要請一覧');
        await selectMunicipalityRequest(tester, '山口 花子');
        await scrollAndTap(tester, find.text('対応開始'), settle: false);
        await pumpPastSnackBars(tester);
        expect(fakeDs.updatedStatuses, hasLength(1));
        expect(fakeDs.updatedStatuses.single.dbId, '2001');
        expect(fakeDs.updatedStatuses.single.status, RequestStatus.working);

        await navigateMunicipalityView(tester, '位置情報マップ');
        expect(findMapPinTooltip('山口 花子', statusLabel: '対応中'), findsOneWidget);

        await navigateMunicipalityView(tester, '対応状況');
        final statusView = find.byType(StatusView);
        expect(statusView, findsOneWidget);
        expect(
          find.descendant(of: statusView, matching: find.text('山口 花子')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: statusView, matching: find.text('対応中')),
          findsAtLeastNWidgets(1),
        );

        // 9. 利用者モードへ復帰
        await switchMunicipalityToCitizen(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('家族グループ'), findsOneWidget);
      },
    );

    testWidgets(
      'Scenario 2: ゲストモード開始 -> 安否登録・安否タブで家族確認 -> マップ/メッセージタブ確認 -> 自治体側へ切替',
      (tester) async {
        await pumpMamoApp(
          tester,
          viewport: kMobileViewportSize,
          navigateTo: MamoAppMode.citizen,
        );

        // 1-2. ゲストログイン
        await scrollAndTap(
          tester,
          find.text('ゲストモードではじめる'),
          settle: false,
        );
        await expectToastAndDrain(tester, 'デモログインしました');
        expect(find.text('家族グループ'), findsOneWidget);

        // 3. ホームで「無事」登録 & 家族・避難所確認
        await scrollAndTap(
          tester,
          findSafetyStatusButton('無事').first,
          settle: false,
        );
        await expectToastAndDrain(tester, '無事として登録しました');
        expect(find.text('お母さん'), findsOneWidget);
        expect(find.text('お父さん'), findsOneWidget);
        expect(find.text('お姉ちゃん'), findsOneWidget);
        expect(find.text('あなた'), findsOneWidget);
        expect(find.textContaining('〇〇小学校'), findsAtLeastNWidgets(1));

        // 4. 安否タブ操作
        await tapCitizenBottomTab(tester, '安否');
        expect(find.text('避難所情報'), findsNothing);
        expect(find.text('お姉ちゃん'), findsOneWidget);
        final injuredBtn = findSafetyStatusButton('被害あり');
        expect(injuredBtn, findsAtLeastNWidgets(1));
        await scrollAndTap(tester, injuredBtn.first, settle: false);
        await pumpPastToasts(tester);

        // 5. マップタブで避難所確認
        await tapCitizenBottomTab(tester, 'マップ');
        expect(find.text('家族グループ'), findsNothing);
        expect(find.textContaining('〇〇小学校'), findsAtLeastNWidgets(1));

        // 6. メッセージタブで連絡送信
        await tapCitizenBottomTab(tester, 'メッセージ');
        final msgField = find.byType(TextField);
        expect(msgField, findsAtLeastNWidgets(1));
        await scrollAndEnterText(tester, msgField.first, '〇〇小学校へ避難します');
        final sendTrigger = findSendMessageTrigger();
        expect(sendTrigger, findsAtLeastNWidgets(1));
        await scrollAndTap(tester, sendTrigger.first, settle: false);
        await pumpPastToasts(tester);
        expect(find.textContaining('〇〇小学校へ避難します'), findsAtLeastNWidgets(1));

        // 7. ホームへ戻り同期確認後、自治体側へ切替して Drawer 操作確認
        await tapCitizenBottomTab(tester, 'ホーム');
        expect(find.text('家族グループ'), findsOneWidget);
        expect(find.textContaining('被害あり'), findsAtLeastNWidgets(3));
        expectAtMostNWidgets(find.textContaining('無事'), 3);

        await switchCitizenToMunicipality(tester);
        expect(find.byType(AppSidebar), findsNothing);
        await navigateMunicipalityView(tester, '設定');
        expect(find.text('自治体名'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Scenario 3: オフライン展示会場デモ（Supabase未接続・空設定の双方で空状態->SOS送信->自治体即時反映）',
      (tester) async {
        // Sub-case A: dataSource == null, autoConnect == false
        await pumpMamoApp(tester, viewport: kDesktopViewportSize);
        await openMunicipalityFromPortal(tester);
        expect(find.text('受信した救助要請はありません。'), findsOneWidget);

        await switchMunicipalityToCitizen(tester);
        await loginAsGuest(tester);
        await scrollAndTap(tester, find.text('救助要請'));
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await expectToastAndDrain(tester, 'デモ送信（Supabase未接続）');

        expect(find.textContaining('あなた'), findsAtLeastNWidgets(1));
        expect(find.textContaining('〇〇地区付近'), findsOneWidget);
        expect(find.textContaining('救助が必要です'), findsAtLeastNWidgets(1));
        await scrollAndTap(tester, find.text('ホームへ戻る'));

        await switchCitizenToMunicipality(tester);
        expect(find.text('受信した救助要請はありません。'), findsNothing);
        expect(find.textContaining('あなた'), findsAtLeastNWidgets(1));

        await navigateMunicipalityView(tester, '救助要請一覧');
        expect(find.text('すべて 1'), findsOneWidget);

        await navigateMunicipalityView(tester, '位置情報マップ');
        expect(findMapPinTooltip('あなた', statusLabel: '未対応'), findsOneWidget);

        await navigateMunicipalityView(tester, '対応状況');
        final statusView = find.byType(StatusView);
        expect(statusView, findsOneWidget);
        expect(
          find.descendant(of: statusView, matching: find.text('あなた')),
          findsOneWidget,
        );

        // Sub-case B: SupabaseRescueDataSource(config: SupabaseConfig.empty)
        final emptyDs = SupabaseRescueDataSource(config: SupabaseConfig.empty);
        addTearDown(emptyDs.dispose);
        await pumpMamoApp(
          tester,
          dataSource: emptyDs,
          autoConnect: true,
          viewport: kDesktopViewportSize,
          navigateTo: MamoAppMode.citizen,
        );
        await loginAsGuest(tester);
        await scrollAndTap(tester, find.text('救助要請'));
        await enterFieldByHint(tester, '登録した名前', '空設定フォールバック市民');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);
        expect(find.text('救助要請を送信しました'), findsOneWidget);

        await switchCitizenToMunicipality(tester);
        await navigateMunicipalityView(tester, '救助要請一覧');
        expect(find.textContaining('空設定フォールバック市民'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Scenario 4: デスクトップ広幅画面での二面デモ（モバイル枠住民操作 <-> 全幅自治体システム往復と動的リサイズ）',
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

        // 1. デスクトップ枠内に 390px モバイル枠と 9:41 が表示される
        expect(find.text('9:41'), findsOneWidget);
        final citizenScaffoldWidth = tester.getSize(find.byType(Scaffold).last).width;
        expect(citizenScaffoldWidth, lessThanOrEqualTo(390.0));
        expect(citizenScaffoldWidth, greaterThanOrEqualTo(250.0));

        // 2. モバイル枠内でマップ・メッセージ確認後 SOS 送信
        await loginAsGuest(tester);
        await tapCitizenBottomTab(tester, 'マップ');
        await tapCitizenBottomTab(tester, 'メッセージ');
        final msgField = find.byType(TextField);
        expect(msgField, findsAtLeastNWidgets(1));
        await scrollAndEnterText(tester, msgField.first, '展示デモ連絡');
        final sendTrigger = findSendMessageTrigger();
        expect(sendTrigger, findsAtLeastNWidgets(1));
        await scrollAndTap(tester, sendTrigger.first, settle: false);
        await pumpPastToasts(tester);
        await tapCitizenBottomTab(tester, 'ホーム');
        await scrollAndTap(tester, find.text('救助要請'));
        await enterFieldByHint(tester, '登録した名前', '展示 来場者A');
        await enterFieldByHint(tester, '建物内に閉じ込め', '避難支援希望');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);

        // 3. 自治体モードへ切替し全幅 (1280px) + 常設左サイドバー (>= 200px) 確認
        await switchCitizenToMunicipality(tester);
        expect(tester.getSize(find.byType(Scaffold).last).width, 1280.0);
        expect(
          tester.getSize(find.byType(AppSidebar)).width,
          greaterThanOrEqualTo(200.0),
        );
        await navigateMunicipalityView(tester, '救助要請一覧');
        expect(find.textContaining('展示 来場者A'), findsAtLeastNWidgets(1));

        // 4. 利用者モード復帰・状態保持確認
        await switchMunicipalityToCitizen(tester);
        expect(find.text('9:41'), findsOneWidget);

        // 5. 狭幅スマホ (390x844) へ動的リサイズし 5 タブ操作可能を検証
        await resizeViewportAndSettle(tester, 390, 844);
        await scrollAndTap(tester, find.text('ホームへ戻る'));
        await tapCitizenBottomTab(tester, 'メッセージ');
        expect(find.textContaining('展示デモ連絡'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Scenario 5: 複数世帯/連続 SOS 受付＋設定タブ情報確認・ログアウト再登録シナリオ',
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

        // 1. 1世帯目: 佐藤 健太
        await scrollAndTap(tester, find.text('新規登録'));
        await scrollAndTap(tester, find.text('次へ'));
        await enterFieldByHint(tester, '山田 太郎', '佐藤 健太');
        await scrollAndTap(tester, find.text('次へ'));
        await scrollAndTap(tester, find.textContaining('人工呼吸器を使用').first);
        await scrollAndTap(tester, find.text('登録する'), settle: false);
        await pumpPastToasts(tester);

        await scrollAndTap(tester, find.text('救助要請'));
        await enterFieldByHint(tester, '建物内に閉じ込め', '電源喪失の恐れ');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);
        await scrollAndTap(tester, find.text('ホームへ戻る'));

        // 2-3. 設定タブでプロフィール確認・通知OFF・ログアウト
        await tapCitizenBottomTab(tester, '設定');
        expect(find.textContaining('佐藤 健太'), findsAtLeastNWidgets(1));
        await scrollAndTap(tester, find.byType(Switch).first, settle: false);
        await pumpPastToasts(tester);
        await scrollAndTap(tester, find.textContaining('ログアウト').first);
        expect(find.text('新規登録'), findsOneWidget);

        // 4. 2世帯目: 鈴木 美咲
        await scrollAndTap(tester, find.text('新規登録'));
        await scrollAndTap(tester, find.text('次へ'));
        await enterFieldByHint(tester, '山田 太郎', '鈴木 美咲');
        await scrollAndTap(tester, find.text('次へ'));
        await scrollAndTap(tester, find.textContaining('妊娠中').first);
        await scrollAndTap(tester, find.text('登録する'), settle: false);
        await pumpPastToasts(tester);

        await scrollAndTap(tester, find.text('救助要請'));
        await enterFieldByHint(tester, '建物内に閉じ込め', '破水の兆候あり、搬送希望');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);

        // 5-6. 自治体モードで2件の分離表示・15列ペイロード検証
        await switchCitizenToMunicipality(tester);
        await navigateMunicipalityView(tester, '救助要請一覧');
        expect(find.text('すべて 2'), findsOneWidget);
        expect(find.text('未対応 2'), findsOneWidget);

        await selectMunicipalityRequest(tester, '鈴木 美咲');
        expect(find.text('破水の兆候あり、搬送希望'), findsAtLeastNWidgets(1));
        await selectMunicipalityRequest(tester, '佐藤 健太');
        expect(find.text('電源喪失の恐れ'), findsAtLeastNWidgets(1));

        expect(fakeDs.insertedPayloads, hasLength(2));
        expectValid15ColPayload(
          fakeDs.insertedPayloads[0],
          expectedName: '佐藤 健太',
          expectedDetail: '電源喪失の恐れ',
          expectedConsiderationSubstrings: const ['人工呼吸器を使用'],
        );
        expectValid15ColPayload(
          fakeDs.insertedPayloads[1],
          expectedName: '鈴木 美咲',
          expectedDetail: '破水の兆候あり、搬送希望',
          expectedConsiderationSubstrings: const ['妊娠中'],
        );
      },
    );

    testWidgets(
      'Scenario 6: 自治体管理者による対応完了処理と市民側ホーム/設定・ポータル帰還連携実演',
      (tester) async {
        final fakeDs = FakeRescueDataSource(
          startingDbId: 501,
          initialRows: [
            {
              'id': 500,
              'request_id': 'MAMO-SEED-500',
              'created_at': '2024-06-05T09:00:00Z',
              'requester_name': '既存 要請者',
              'user_name': '既存 要請者',
              'request_type': '消防',
              'rescue_details': '倒壊家屋確認',
              'detail': '倒壊家屋確認',
              'considerations': 'なし',
              'consideration': 'なし',
              'health_condition': 'なし',
              'location_text': '山口市中央',
              'location': '山口市中央',
              'distance_text': '300m先',
              'distance': '300m先',
              'status': '未対応',
            },
          ],
        );
        addTearDown(fakeDs.dispose);

        await pumpMamoApp(
          tester,
          dataSource: fakeDs,
          autoConnect: true,
          viewport: kDesktopViewportSize,
          navigateTo: MamoAppMode.citizen,
        );

        // 1-2. 市民側ゲストログイン -> メッセージ確認 -> 新規 SOS 送信
        await loginAsGuest(tester);
        await tapCitizenBottomTab(tester, 'メッセージ');
        final msgField = find.byType(TextField);
        expect(msgField, findsAtLeastNWidgets(1));
        await scrollAndEnterText(tester, msgField.first, '了解しました');
        final sendTrigger = findSendMessageTrigger();
        expect(sendTrigger, findsAtLeastNWidgets(1));
        await scrollAndTap(tester, sendTrigger.first, settle: false);
        await pumpPastToasts(tester);
        expect(find.textContaining('了解しました'), findsAtLeastNWidgets(1));

        await tapCitizenBottomTab(tester, 'ホーム');
        await scrollAndTap(tester, find.text('救助要請'));
        await enterFieldByHint(tester, '登録した名前', '新規 市民B');
        await enterFieldByHint(tester, '建物内に閉じ込め', '落下物で負傷');
        await scrollAndTap(
          tester,
          find.textContaining('救助要請を送信'),
          settle: false,
        );
        await pumpPastToasts(tester);
        await scrollAndTap(tester, find.text('ホームへ戻る'));

        // 3-4. 自治体側で2件確認 -> 新規 市民B を未対応 -> 対応中 -> 対応済みへ段階更新
        await switchCitizenToMunicipality(tester);
        await navigateMunicipalityView(tester, '救助要請一覧');
        expect(find.text('すべて 2'), findsOneWidget);
        expect(find.textContaining('既存 要請者'), findsAtLeastNWidgets(1));
        expect(find.textContaining('新規 市民B'), findsAtLeastNWidgets(1));

        await selectMunicipalityRequest(tester, '新規 市民B');
        await scrollAndTap(tester, find.text('対応開始'), settle: false);
        await pumpPastSnackBars(tester);
        await scrollAndTap(tester, find.text('対応完了'), settle: false);
        await pumpPastSnackBars(tester);

        expect(fakeDs.updatedStatuses, hasLength(2));
        expect(fakeDs.updatedStatuses[0].dbId, '501');
        expect(fakeDs.updatedStatuses[0].status, RequestStatus.working);
        expect(fakeDs.updatedStatuses[1].dbId, '501');
        expect(fakeDs.updatedStatuses[1].status, RequestStatus.done);

        await navigateMunicipalityView(tester, '対応状況');
        final statusView = find.byType(StatusView);
        expect(statusView, findsOneWidget);
        expect(
          find.descendant(of: statusView, matching: find.text('新規 市民B')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: statusView, matching: find.text('対応済み')),
          findsAtLeastNWidgets(1),
        );

        // 5. 自治体名変更保存
        await navigateMunicipalityView(tester, '設定');
        await scrollAndEnterText(
          tester,
          find.byType(TextField).first,
          '防府市 災害対策本部',
        );
        await scrollAndTap(tester, find.text('保存する'), settle: false);
        await pumpPastSnackBars(tester);
        expect(find.textContaining('防府市 災害対策本部'), findsAtLeastNWidgets(1));

        // 6. 利用者モード復帰 -> ポータルへ帰還
        await switchMunicipalityToCitizen(tester);
        await scrollAndTap(
          tester,
          findSafetyStatusButton('無事').first,
          settle: false,
        );
        await expectToastAndDrain(tester, '無事として登録しました');
        await tapCitizenBottomTab(tester, '設定');
        await switchCitizenToPortal(tester);
        expect(find.textContaining('利用者'), findsAtLeastNWidgets(1));
        expect(find.textContaining('自治体'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
