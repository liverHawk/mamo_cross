import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mamo_cross/main.dart';
import 'package:mamo_cross/models/app_mode.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/state/rescue_store.dart';
import 'package:mamo_cross/views/dashboard_view.dart';
import 'package:mamo_cross/views/status_view.dart';

import 'e2e_test_helpers.dart';

void main() {
  // =========================================================================
  // Area 1: 起動時モード選択ポータル (PortalPage) — 6 tests
  // =========================================================================
  group('Area 1: 起動時モード選択ポータル (Tier 1)', () {
    testWidgets('T1-F01-01: デフォルト起動時にポータル画面が表示される', (tester) async {
      await pumpMamoApp(tester);

      expect(find.textContaining('MAMO'), findsAtLeastNWidgets(1));
      expect(find.text('ダッシュボード'), findsNothing);
      expect(find.text('ゲストモードではじめる'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T1-F01-02: ポータルに利用者（住民・スマホ）モード導線が表示される', (tester) async {
      await pumpMamoApp(tester);

      expect(find.textContaining('利用者'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F01-03: ポータルに自治体管理システムモード導線が表示される', (tester) async {
      await pumpMamoApp(tester);

      expect(find.textContaining('自治体'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F01-04: 利用者モード選択で #login 画面へ遷移する', (tester) async {
      await pumpMamoApp(tester);
      await openCitizenFromPortal(tester);

      expect(find.text('MAMO'), findsAtLeastNWidgets(1));
      expect(find.text('マモ'), findsOneWidget);
      expect(find.text('新規登録'), findsOneWidget);
      expect(find.text('ログイン'), findsOneWidget);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
    });

    testWidgets('T1-F01-05: 自治体モード選択で自治体ダッシュボードへ遷移する', (tester) async {
      await pumpMamoApp(tester);
      await openMunicipalityFromPortal(tester);

      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));
      expect(find.text('新規救助要請'), findsOneWidget);
      expect(find.text('救助要請一覧'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F01-06: MamoAppMode 列挙値と store/dataSource 注入後方互換が機能する', (
      tester,
    ) async {
      expect(
        MamoAppMode.values,
        containsAll([
          MamoAppMode.portal,
          MamoAppMode.citizen,
          MamoAppMode.municipality,
        ]),
      );

      // store のみ注入ケース
      final store = RescueStore(startClock: false);
      addTearDown(store.dispose);
      store.addDbRequest({
        'id': 11,
        'request_id': 'MAMO-STORE-11',
        'requester_name': 'ストア注入住民',
        'request_type': '救急',
        'rescue_details': 'ストア注入確認',
        'location_text': '山口市中央',
        'status': '未対応',
      });

      setDesktopViewport(tester);
      await tester.pumpWidget(
        MamoApp(
          store: store,
          startClock: false,
          autoConnect: false,
        ),
      );
      await tester.pumpAndSettle();

      await openCitizenFromPortal(tester);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
      await switchCitizenToMunicipality(tester);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));
      expect(find.textContaining('ストア注入住民'), findsAtLeastNWidgets(1));

      // dataSource のみ注入ケース
      final fakeDs = FakeRescueDataSource(
        initialRows: [
          {
            'id': 22,
            'request_id': 'MAMO-DS-22',
            'created_at': '2024-06-05T09:00:00Z',
            'requester_name': 'データソース注入住民',
            'request_type': '消防',
            'rescue_details': 'データソース注入確認',
            'location_text': '防府市中央',
            'status': '未対応',
          },
        ],
      );
      addTearDown(fakeDs.dispose);

      await tester.pumpWidget(
        MamoApp(
          dataSource: fakeDs,
          startClock: false,
          autoConnect: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeDs.fetchCallCount, greaterThanOrEqualTo(1));
      await openMunicipalityFromPortal(tester);
      expect(find.textContaining('データソース注入住民'), findsAtLeastNWidgets(1));
    });
  });

  // =========================================================================
  // Area 2: 相互モード切替導線 (Portal <-> Citizen <-> Municipality) — 6 tests
  // =========================================================================
  group('Area 2: 相互モード切替導線 (Tier 1)', () {
    testWidgets('T1-F02-01: 利用者モードからポータルへ戻れる', (tester) async {
      await pumpMamoApp(tester, navigateTo: MamoAppMode.citizen);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);

      await switchCitizenToPortal(tester);

      expect(find.text('ゲストモードではじめる'), findsNothing);
      expect(find.textContaining('利用者'), findsAtLeastNWidgets(1));
      expect(find.textContaining('自治体'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F02-02: 利用者モードから自治体モードへ切替できる', (tester) async {
      await pumpMamoApp(tester, navigateTo: MamoAppMode.citizen);
      await loginAsGuest(tester);

      await switchCitizenToMunicipality(tester);

      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));
      expect(find.text('救助要請一覧'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F02-03: 自治体モード AppHeader からポータルへ戻れる', (tester) async {
      await pumpMamoApp(tester, navigateTo: MamoAppMode.municipality);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));

      await switchMunicipalityToPortal(tester);

      expect(find.text('ダッシュボード'), findsNothing);
      expect(find.textContaining('利用者'), findsAtLeastNWidgets(1));
      expect(find.textContaining('自治体'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F02-04: 自治体モード AppHeader から利用者モードへ切替できる', (tester) async {
      await pumpMamoApp(tester, navigateTo: MamoAppMode.municipality);

      await switchMunicipalityToCitizen(tester);

      expect(find.text('新規登録'), findsOneWidget);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
    });

    testWidgets('T1-F02-05: Portal -> Citizen -> Municipality -> Portal 全往復遷移が動作する', (
      tester,
    ) async {
      await pumpMamoApp(tester);

      await openCitizenFromPortal(tester);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);

      await switchCitizenToMunicipality(tester);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));

      await switchMunicipalityToPortal(tester);
      expect(find.textContaining('利用者'), findsAtLeastNWidgets(1));
      expect(find.textContaining('自治体'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T1-F02-06: モード往復後も共有 RescueStore の設定名が保持される', (tester) async {
      await pumpMamoApp(tester, navigateTo: MamoAppMode.municipality);

      await navigateMunicipalityView(tester, '設定');
      final textField = find.byType(TextField).first;
      await scrollAndEnterText(tester, textField, '山口市 テスト対策本部');
      await scrollAndTap(tester, find.text('保存する'), settle: false);
      await pumpPastSnackBars(tester);

      await switchMunicipalityToCitizen(tester);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);

      await switchCitizenToMunicipality(tester);
      expect(find.textContaining('山口市 テスト対策本部'), findsAtLeastNWidgets(1));
    });
  });

  // =========================================================================
  // Area 3: モバイル想定幅フレーム (MobilePreviewFrame) — 6 tests
  // =========================================================================
  group('Area 3: モバイル想定幅フレーム (Tier 1)', () {
    testWidgets('T1-F03-01: デスクトップ広幅 (1280x800) で市民画面が 390px 枠内に収まる', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      expect(find.text('9:41'), findsOneWidget);
      final citizenScaffoldWidth = tester.getSize(find.byType(Scaffold).last).width;
      expect(citizenScaffoldWidth, lessThanOrEqualTo(390.0));
      expect(citizenScaffoldWidth, greaterThanOrEqualTo(250.0));

      final regButton = findPrimaryButtonWithText('新規登録');
      expect(regButton, findsOneWidget);
      final regButtonWidth = tester.getSize(regButton).width;
      expect(regButtonWidth, lessThanOrEqualTo(390.0));
      expect(regButtonWidth, greaterThanOrEqualTo(250.0));
    });

    testWidgets('T1-F03-02: デスクトップ広幅 (1280x800) で擬似ステータスバー (9:41) が表示される', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      expect(find.text('9:41'), findsOneWidget);
      expect(find.textContaining('●'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F03-03: モバイル幅 (390x844) で擬似ステータスバーなしで全画面幅 (390px) 表示される', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('9:41'), findsNothing);
      final citizenScaffoldWidth = tester.getSize(find.byType(Scaffold).last).width;
      expect(citizenScaffoldWidth, equals(390.0));
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
    });

    testWidgets('T1-F03-04: 狭幅モバイル (320x568) でオーバーフローせず全幅描画される', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kNarrowViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      expect(tester.takeException(), isNull);
      final btnBox = tester.getRect(find.text('新規登録'));
      expect(btnBox.right, lessThanOrEqualTo(320.0));
    });

    testWidgets('T1-F03-05: モバイルフレームは市民 7 画面遷移全体を通じて維持される', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      // #login
      expect(find.text('9:41'), findsOneWidget);
      // #reg1
      await scrollAndTap(tester, find.text('新規登録'));
      expect(find.text('9:41'), findsOneWidget);
      // #reg2
      await scrollAndTap(tester, find.text('次へ'));
      expect(find.text('9:41'), findsOneWidget);
      // #reg3
      await scrollAndTap(tester, find.text('次へ'));
      expect(find.text('9:41'), findsOneWidget);
      // #home
      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);
      expect(find.text('9:41'), findsOneWidget);
      // #rescue
      await scrollAndTap(tester, find.text('救助要請'));
      expect(find.text('9:41'), findsOneWidget);
      // #rescueSent
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);
      expect(find.text('9:41'), findsOneWidget);
    });

    testWidgets('T1-F03-06: モバイルフレーム内の市民画面から自治体モードへ切替えると全幅に戻る', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      expect(find.text('9:41'), findsOneWidget);

      await switchCitizenToMunicipality(tester);

      final scaffoldSize = tester.getSize(find.byType(Scaffold).last);
      expect(scaffoldSize.width, equals(1280.0));
    });
  });

  // =========================================================================
  // Area 4: 利用者 #login 画面 — 6 tests
  // =========================================================================
  group('Area 4: 利用者 #login 画面 (Tier 1)', () {
    testWidgets('T1-F04-01: ブランド表示・ロゴ・タグラインが正しく表示される', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      expect(find.text('MAMO'), findsAtLeastNWidgets(1));
      expect(find.text('マモ'), findsOneWidget);
      expect(find.textContaining('いつでも、どこでも、'), findsOneWidget);
      expect(find.textContaining('つながる安心を。'), findsOneWidget);
      expect(find.byType(Image), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F04-02: 3 つの開始導線ボタンが表示される', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      expect(find.text('新規登録'), findsOneWidget);
      expect(find.text('ログイン'), findsOneWidget);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
    });

    testWidgets('T1-F04-03: 新規登録タップで #reg1 へ即遷移する', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      await scrollAndTap(tester, find.text('新規登録'));

      expect(find.text('① 本人確認'), findsOneWidget);
      expect(find.text('顔写真を登録'), findsOneWidget);
      expect(find.text('公的身分証の登録'), findsOneWidget);
    });

    testWidgets('T1-F04-04: ログインタップでトースト表示後 450ms で #home へ遷移する', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      await scrollAndTap(tester, find.text('ログイン'), settle: false);
      expect(find.textContaining('デモログインしました'), findsAtLeastNWidgets(1));

      await pumpTransition(tester);
      await pumpPastToasts(tester);

      expect(find.text('家族グループ'), findsOneWidget);
      expect(find.textContaining('震度5強'), findsOneWidget);
    });

    testWidgets('T1-F04-05: ゲストモードではじめるタップでトースト表示後 #home へ遷移する', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      await loginAsGuest(tester);

      expect(find.text('家族グループ'), findsOneWidget);
      expect(find.text('避難所情報'), findsOneWidget);
    });

    testWidgets('T1-F04-06: #reg1 の戻る (‹) や #home の ☰ から #login へ戻れる', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      await scrollAndTap(tester, find.text('新規登録'));
      expect(find.text('① 本人確認'), findsOneWidget);

      await scrollAndTap(tester, find.text('‹'));
      expect(find.text('ゲストモードではじめる'), findsOneWidget);

      await loginAsGuest(tester);
      await scrollAndTap(tester, find.text('☰'));
      expect(find.text('新規登録'), findsOneWidget);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 5: 利用者 #reg1 本人確認画面 — 6 tests
  // =========================================================================
  group('Area 5: 利用者 #reg1 本人確認画面 (Tier 1)', () {
    Future<void> openReg1(WidgetTester tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
    }

    testWidgets('T1-F05-01: Topbar・見出し・注記文言が表示される', (tester) async {
      await openReg1(tester);

      expect(find.text('‹'), findsOneWidget);
      expect(find.text('① 本人確認'), findsOneWidget);
      expect(find.text('MAMO'), findsAtLeastNWidgets(1));
      expect(find.text('本人確認'), findsAtLeastNWidgets(1));
      expect(
        find.text('デモでは実際の本人確認・身分証送信は行いません。'),
        findsOneWidget,
      );
    });

    testWidgets('T1-F05-02: 顔写真アップロード枠タップでデモトーストが表示される', (tester) async {
      await openReg1(tester);

      await scrollAndTap(tester, find.text('顔写真を登録'), settle: false);
      await expectToastAndDrain(tester, 'デモ：写真アップロード画面を想定しています');
    });

    testWidgets('T1-F05-03: 公的身分証カードと身分証を選択タップでデモトーストが表示される', (
      tester,
    ) async {
      await openReg1(tester);

      expect(find.text('公的身分証の登録'), findsOneWidget);
      expect(find.text('運転免許証・マイナンバーカード等を想定'), findsOneWidget);
      expect(find.textContaining('デモでは画像を保存・送信しません'), findsOneWidget);

      await scrollAndTap(tester, find.text('身分証を選択'), settle: false);
      await expectToastAndDrain(tester, 'デモ：身分証選択');
    });

    testWidgets('T1-F05-04: 3 段階ステッパー (1/3) が表示される', (tester) async {
      await openReg1(tester);

      await tester.ensureVisible(find.text('次へ'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('本人確認'), findsAtLeastNWidgets(1));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('基本情報'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('救助情報'), findsOneWidget);
    });

    testWidgets('T1-F05-05: 次へタップで #reg2 へ遷移する', (tester) async {
      await openReg1(tester);

      await scrollAndTap(tester, find.text('次へ'));
      expect(find.text('② 基本情報の入力'), findsOneWidget);
    });

    testWidgets('T1-F05-06: ‹ タップで #login へ戻る', (tester) async {
      await openReg1(tester);

      await scrollAndTap(tester, find.text('‹'));
      expect(find.text('新規登録'), findsOneWidget);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 6: 利用者 #reg2 基本情報入力画面 — 6 tests
  // =========================================================================
  group('Area 6: 利用者 #reg2 基本情報入力画面 (Tier 1)', () {
    Future<void> openReg2(WidgetTester tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
    }

    testWidgets('T1-F06-01: Topbar・全セクション見出し・ラベル・ステッパー (2/3) が表示される', (
      tester,
    ) async {
      await openReg2(tester);

      expect(find.text('‹'), findsOneWidget);
      expect(find.text('② 基本情報の入力'), findsOneWidget);
      expect(find.text('基本情報の入力'), findsOneWidget);
      expect(find.text('名前（必須）'), findsOneWidget);
      expect(find.text('生年月日（必須）'), findsOneWidget);
      expect(find.text('血液型（必須）'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('性別'));
      expect(find.textContaining('性別'), findsAtLeastNWidgets(1));
      await tester.ensureVisible(find.text('住所（必須）'));
      expect(find.text('住所（必須）'), findsOneWidget);
      await tester.ensureVisible(find.text('救助情報'));
      expect(find.text('救助情報'), findsOneWidget);
    });

    testWidgets('T1-F06-02: 名前入力欄 (例）山田 太郎) にテキスト入力できる', (tester) async {
      await openReg2(tester);

      await enterFieldByHint(tester, '山田 太郎', '山田 太郎');
      expect(find.text('山田 太郎'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F06-03: 血液型ドロップダウン (A型/B型/O型/AB型) を選択できる', (
      tester,
    ) async {
      await openReg2(tester);

      await selectDropdownOption(tester, find.text('選択してください'), 'O型');
      expect(find.text('O型'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F06-04: 性別選択 (男性/女性/その他) が非推奨 API なしで動作する', (
      tester,
    ) async {
      await openReg2(tester);

      await selectRadioOption(tester, '女性');
      expect(tester.takeException(), isNull);
      expect(find.text('男性'), findsOneWidget);
      expect(find.text('女性'), findsOneWidget);
      expect(find.text('その他'), findsOneWidget);
      expect(find.byType(RadioGroup<String>), findsOneWidget);
      expect(
        tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue,
        equals('女性'),
      );
    });

    testWidgets('T1-F06-05: 住所欄（郵便番号・都道府県ドロップダウン・市区町村番地）を入力/選択できる', (
      tester,
    ) async {
      await openReg2(tester);

      await enterFieldByHint(tester, '郵便番号', '753-8501');
      await selectDropdownOption(tester, find.text('都道府県を選択'), '山口県');
      await enterFieldByHint(tester, '市区町村', '山口市滝町1-1');

      expect(find.text('753-8501'), findsAtLeastNWidgets(1));
      expect(find.text('山口県'), findsAtLeastNWidgets(1));
      expect(find.text('山口市滝町1-1'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F06-06: 生年月日入力と次へタップで #reg3 へ遷移する', (tester) async {
      await openReg2(tester);

      await enterBirthDate(tester, '1990-01-01');
      expect(find.text('1990-01-01'), findsAtLeastNWidgets(1));

      await scrollAndTap(tester, find.text('次へ'));
      expect(find.text('③ 救助要請時の情報'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 7: 利用者 #reg3 配慮事項登録画面 — 6 tests
  // =========================================================================
  group('Area 7: 利用者 #reg3 配慮事項登録画面 (Tier 1)', () {
    Future<void> openReg3(WidgetTester tester, {String? name}) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
      if (name != null) {
        await enterFieldByHint(tester, '山田 太郎', name);
      }
      await scrollAndTap(tester, find.text('次へ'));
    }

    testWidgets('T1-F07-01: Topbar・見出し・注記・免責ボックス・ステッパー (3/3) が表示される', (
      tester,
    ) async {
      await openReg3(tester);

      expect(find.text('‹'), findsOneWidget);
      expect(find.text('③ 救助要請時の情報'), findsOneWidget);
      expect(find.textContaining('救助時の配慮事項'), findsAtLeastNWidgets(1));
      expect(find.textContaining('（任意）'), findsAtLeastNWidgets(1));
      expect(find.text('救助・医療対応時に知っておいてほしいこと'), findsOneWidget);
      await tester.ensureVisible(find.text('登録する'));
      expect(find.textContaining('実在の本名'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('T1-F07-02: 5 つの配慮チェックボックスすべてが初期未チェックで表示される', (
      tester,
    ) async {
      await openReg3(tester);

      for (final label in const [
        'ホルモン治療中',
        '人工呼吸器を使用',
        '妊娠中',
        'オストメイト',
        '医療的ケアが必要',
      ]) {
        expect(find.textContaining(label), findsAtLeastNWidgets(1));
      }
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      expect(checkboxes.length, greaterThanOrEqualTo(5));
      for (final cb in checkboxes) {
        expect(cb.value, isFalse);
      }
    });

    testWidgets('T1-F07-03: 複数チェックボックスの ON / OFF トグルが機能する', (tester) async {
      await openReg3(tester);

      await scrollAndTap(tester, find.textContaining('ホルモン治療中').first);
      await scrollAndTap(tester, find.textContaining('医療的ケアが必要').first);
      await scrollAndTap(tester, find.textContaining('ホルモン治療中').first);

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes.first.value, isFalse);
      expect(checkboxes[4].value, isTrue);
    });

    testWidgets('T1-F07-04: その他（自由入力）欄に複数行テキスト入力できる', (tester) async {
      await openReg3(tester);

      await enterFieldByHint(tester, 'アレルギー', 'ピーナッツアレルギー\nインスリン常備');
      expect(find.text('ピーナッツアレルギー\nインスリン常備'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F07-05: 登録するで名前を保存し #home 遷移＋完了トーストが表示される', (tester) async {
      await openReg3(tester, name: '佐藤 花子');

      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await expectToastAndDrain(tester, '登録が完了しました（デモ）');

      expect(find.text('家族グループ'), findsOneWidget);
      await scrollAndTap(tester, find.text('救助要請'));
      expect(find.text('佐藤 花子'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F07-06: Topbar ‹ タップで #reg2 へ戻る', (tester) async {
      await openReg3(tester);

      await scrollAndTap(tester, find.text('‹'));
      expect(find.text('② 基本情報の入力'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 8: 利用者 #home ホームタブ画面 — 6 tests
  // =========================================================================
  group('Area 8: 利用者 #home ホームタブ画面 (Tier 1)', () {
    testWidgets('T1-F08-01: Topbar・災害警報バナーが表示される', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      expect(find.text('☰'), findsOneWidget);
      expect(find.text('ホーム'), findsAtLeastNWidgets(2));
      expect(find.text('♧'), findsOneWidget);
      expect(find.textContaining('〇〇地区'), findsAtLeastNWidgets(1));
      expect(find.textContaining('震度5強'), findsOneWidget);
    });

    testWidgets('T1-F08-02: 安否登録見出しと 3 列安否ボタンが表示される', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      expect(find.text('あなたの安否を登録してください'), findsOneWidget);
      expect(findSafetyStatusButton('無事'), findsAtLeastNWidgets(1));
      expect(findSafetyStatusButton('被害あり'), findsAtLeastNWidgets(1));
      expect(findSafetyStatusButton('救助要請'), findsAtLeastNWidgets(1));
      expect(find.textContaining('SOS'), findsAtLeastNWidgets(1));
      expect(find.textContaining('救助要請'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F08-03: 無事・被害ありボタンタップで対応トーストが表示される', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await scrollAndTap(
        tester,
        findSafetyStatusButton('無事').first,
        settle: false,
      );
      await expectToastAndDrain(tester, '無事として登録しました');

      await scrollAndTap(
        tester,
        findSafetyStatusButton('被害あり').first,
        settle: false,
      );
      await expectToastAndDrain(tester, '被害ありとして登録しました');
    });

    testWidgets('T1-F08-04: SOS 救助要請タップで #rescue へ遷移する', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await scrollAndTap(tester, find.text('救助要請'));
      expect(find.textContaining('救助要請を行います'), findsOneWidget);
      expect(find.text('現在の状況を確認'), findsOneWidget);
    });

    testWidgets('T1-F08-05: 家族グループ 4 名と初期ステータスバッジが表示される', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await tester.ensureVisible(find.text('家族グループ'));
      expect(find.text('家族グループ'), findsOneWidget);
      expect(find.text('お母さん'), findsOneWidget);
      expect(find.text('お父さん'), findsOneWidget);
      expect(find.text('お姉ちゃん'), findsOneWidget);
      expect(find.text('あなた'), findsOneWidget);
    });

    testWidgets('T1-F08-06: 避難所情報カード表示および ☰ タップで #login 復帰', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await tester.ensureVisible(find.text('避難所情報'));
      expect(find.text('避難所情報'), findsOneWidget);
      expect(find.textContaining('150m先'), findsOneWidget);
      expect(find.textContaining('〇〇小学校'), findsOneWidget);
      expect(find.textContaining('避難所開設'), findsOneWidget);

      await scrollAndTap(tester, find.text('☰'));
      expect(find.text('新規登録'), findsOneWidget);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 9: 利用者 #rescue 救助要請画面 — 6 tests
  // =========================================================================
  group('Area 9: 利用者 #rescue 救助要請画面 (Tier 1)', () {
    Future<void> openRescue(
      WidgetTester tester, {
      FakeRescueDataSource? dataSource,
    }) async {
      await pumpMamoApp(
        tester,
        dataSource: dataSource,
        autoConnect: dataSource != null,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);
      await scrollAndTap(tester, find.text('救助要請'));
    }

    testWidgets('T1-F09-01: Topbar・赤アラートバナーが表示される', (tester) async {
      await openRescue(tester);

      expect(find.text('‹'), findsOneWidget);
      expect(find.text('救助要請'), findsAtLeastNWidgets(1));
      expect(find.text('MAMO'), findsAtLeastNWidgets(1));
      expect(find.textContaining('救助要請を行います'), findsOneWidget);
    });

    testWidgets('T1-F09-02: 状況確認フォーム 3 項目と現在地デモボックスが表示される', (tester) async {
      await openRescue(tester);

      expect(find.text('現在の状況を確認'), findsOneWidget);
      expect(find.text('お名前'), findsOneWidget);
      expect(find.text('あなた'), findsAtLeastNWidgets(1));
      expect(find.text('救助内容'), findsOneWidget);
      expect(find.text('救助時の配慮事項'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('デモ位置情報'));
      expect(find.textContaining('デモ位置情報（〇〇地区付近）'), findsOneWidget);
      expect(find.textContaining('距離：自治体側で受信時に表示'), findsOneWidget);
    });

    testWidgets('T1-F09-03: 送信される情報 5 項目リストが表示される', (tester) async {
      await openRescue(tester);

      await tester.ensureVisible(find.text('送信される情報'));
      expect(find.text('送信される情報'), findsOneWidget);
      expect(find.textContaining('救助要請時刻'), findsOneWidget);
      expect(find.textContaining('登録者名'), findsOneWidget);
      expect(find.textContaining('現在地／位置情報'), findsOneWidget);
      expect(find.textContaining('救助内容'), findsAtLeastNWidgets(1));
      expect(find.textContaining('救助時の配慮事項'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F09-04: キャンセルタップで送信せず #home に戻る', (tester) async {
      final fakeDs = FakeRescueDataSource();
      addTearDown(fakeDs.dispose);
      await openRescue(tester, dataSource: fakeDs);

      await scrollAndTap(tester, find.text('キャンセル'));
      expect(find.text('家族グループ'), findsOneWidget);
      expect(fakeDs.insertedPayloads, isEmpty);
    });

    testWidgets('T1-F09-05: Topbar ‹ タップで送信せず #home に戻る', (tester) async {
      final fakeDs = FakeRescueDataSource();
      addTearDown(fakeDs.dispose);
      await openRescue(tester, dataSource: fakeDs);

      await scrollAndTap(tester, find.text('‹'));
      expect(find.text('家族グループ'), findsOneWidget);
      expect(fakeDs.insertedPayloads, isEmpty);
    });

    testWidgets('T1-F09-06: カスタム内容入力＋救助要請を送信で #rescueSent へ遷移する', (tester) async {
      final fakeDs = FakeRescueDataSource();
      addTearDown(fakeDs.dispose);
      await openRescue(tester, dataSource: fakeDs);

      await enterFieldByHint(tester, '登録した名前', '高橋 一郎');
      await enterFieldByHint(tester, '建物内に閉じ込め', '2階に閉じ込め');
      await enterFieldByHint(tester, '登録済みの配慮事項', '喘息あり');
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);

      expect(find.text('救助要請を送信しました'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 10: 利用者 #rescueSent 送信完了画面 — 6 tests
  // =========================================================================
  group('Area 10: 利用者 #rescueSent 送信完了画面 (Tier 1)', () {
    Future<void> sendSosAndReachSent(
      WidgetTester tester, {
      FakeRescueDataSource? dataSource,
      String? name,
      String? detail,
      bool drainToast = true,
    }) async {
      await pumpMamoApp(
        tester,
        dataSource: dataSource,
        autoConnect: dataSource != null,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);
      await scrollAndTap(tester, find.text('救助要請'));
      if (name != null) {
        await enterFieldByHint(tester, '登録した名前', name);
      }
      if (detail != null) {
        await enterFieldByHint(tester, '建物内に閉じ込め', detail);
      }
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      if (drainToast) {
        await pumpPastToasts(tester);
      }
    }

    testWidgets('T1-F10-01: 完了アイコン (✓)・見出し・説明文が表示される', (tester) async {
      await sendSosAndReachSent(tester);

      expect(find.text('✓'), findsOneWidget);
      expect(find.text('救助要請を送信しました'), findsOneWidget);
      expect(find.textContaining('自治体のMAMO管理画面へ'), findsOneWidget);
      expect(find.textContaining('救助要請が届く想定です。'), findsOneWidget);
    });

    testWidgets('T1-F10-02: 受付内容カードに全 5 項目（受付番号・時刻・名前・場所・内容）が表示される', (
      tester,
    ) async {
      await sendSosAndReachSent(tester);

      expect(find.text('受付内容'), findsOneWidget);
      expect(find.textContaining('MAMO-'), findsOneWidget);
      expect(find.textContaining('〇〇地区付近'), findsOneWidget);
      expect(find.textContaining('あなた'), findsAtLeastNWidgets(1));
      expect(find.textContaining('救助が必要です'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F10-03: カスタム送信内容が受付カードに正確に反映される', (tester) async {
      await sendSosAndReachSent(tester, name: '中村 健', detail: '屋根上で待機');

      expect(find.textContaining('中村 健'), findsAtLeastNWidgets(1));
      expect(find.textContaining('屋根上で待機'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F10-04: 空欄送信時のフォールバック値が受付カードに反映される', (tester) async {
      await sendSosAndReachSent(tester, name: '', detail: '');

      expect(find.textContaining('あなた'), findsAtLeastNWidgets(1));
      expect(find.textContaining('救助が必要です'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F10-05: ホームへ戻るタップで #home に戻る', (tester) async {
      await sendSosAndReachSent(tester);

      await scrollAndTap(tester, find.text('ホームへ戻る'));
      expect(find.text('家族グループ'), findsOneWidget);
      expect(find.text('避難所情報'), findsOneWidget);
    });

    testWidgets('T1-F10-06: オフライン時はデモ送信トースト、オンライン成功時は送信完了トーストが表示される', (
      tester,
    ) async {
      // オフライン (dataSource: null)
      await sendSosAndReachSent(tester, drainToast: false);
      await expectToastAndDrain(tester, 'デモ送信（Supabase未接続）');

      // オンライン成功
      final fakeDs = FakeRescueDataSource();
      addTearDown(fakeDs.dispose);
      await sendSosAndReachSent(tester, dataSource: fakeDs, drainToast: false);
      await expectToastAndDrain(tester, '自治体へ救助要請を送信しました');
    });
  });

  // =========================================================================
  // Area 11: 下部 5 タブ (ホーム/マップ/安否/メッセージ/設定) — 6 tests
  // =========================================================================
  group('Area 11: 下部 5 タブ切替・各タブ機能 (Tier 1)', () {
    Future<void> enterHome(WidgetTester tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);
    }

    testWidgets('T1-F11-01: 下部ナビに 5 タブすべてのラベルが表示され初期選択はホームである', (
      tester,
    ) async {
      await enterHome(tester);

      expect(find.text('ホーム'), findsAtLeastNWidgets(2));
      expect(find.text('マップ'), findsOneWidget);
      expect(find.text('安否'), findsOneWidget);
      expect(find.text('メッセージ'), findsOneWidget);
      expect(find.text('設定'), findsOneWidget);
      expect(find.text('家族グループ'), findsOneWidget);
    });

    testWidgets('T1-F11-02: マップタブへ切替すると防災・避難所マップ画面が表示される', (tester) async {
      await enterHome(tester);

      await tapCitizenBottomTab(tester, 'マップ');

      expect(find.text('家族グループ'), findsNothing);
      expect(find.text('避難所情報'), findsNothing);
      expect(find.textContaining('〇〇小学校'), findsAtLeastNWidgets(1));
      expect(find.textContaining('現在地'), findsAtLeastNWidgets(1));
      expect(find.textContaining('避難所'), findsAtLeastNWidgets(1));
      expect(find.textContaining('危険'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F11-03: 安否タブへ切替すると本人・家族安否管理画面が表示される', (tester) async {
      await enterHome(tester);

      await tapCitizenBottomTab(tester, '安否');

      expect(find.text('避難所情報'), findsNothing);
      expect(findSafetyStatusButton('無事'), findsAtLeastNWidgets(1));
      expect(findSafetyStatusButton('被害あり'), findsAtLeastNWidgets(1));
      expect(find.text('お母さん'), findsOneWidget);
      expect(find.text('お父さん'), findsOneWidget);
      expect(find.text('お姉ちゃん'), findsOneWidget);
      expect(find.text('あなた'), findsOneWidget);
      expect(find.textContaining('確認'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F11-04: メッセージタブへ切替しお知らせ・家族連絡・メッセージ送信ができる', (
      tester,
    ) async {
      await enterHome(tester);

      await tapCitizenBottomTab(tester, 'メッセージ');
      expect(find.text('家族グループ'), findsNothing);
      expect(find.textContaining('お知らせ'), findsAtLeastNWidgets(1));

      final input = find.byType(TextField);
      expect(input, findsAtLeastNWidgets(1));
      await scrollAndEnterText(tester, input.first, '無事です、小学校に向かいます');

      final sendTrigger = findSendMessageTrigger();
      expect(sendTrigger, findsAtLeastNWidgets(1));
      await scrollAndTap(tester, sendTrigger.first, settle: false);
      await pumpPastToasts(tester);

      expect(find.textContaining('無事です、小学校に向かいます'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T1-F11-05: 設定タブへ切替すると登録情報・通知設定・ログアウト等が表示される', (
      tester,
    ) async {
      await enterHome(tester);

      await tapCitizenBottomTab(tester, '設定');

      expect(find.text('家族グループ'), findsNothing);
      expect(find.byType(Switch), findsAtLeastNWidgets(1));
      expect(find.textContaining('ログアウト'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F11-06: 5 タブ全巡回でタブ固有コンテンツが切り替わりナビバーが維持される', (tester) async {
      await enterHome(tester);

      for (final tab in const ['マップ', '安否', 'メッセージ', '設定', 'ホーム']) {
        await tapCitizenBottomTab(tester, tab);
        expect(find.text('マップ'), findsAtLeastNWidgets(1));
        expect(find.text('安否'), findsAtLeastNWidgets(1));
        expect(find.text('メッセージ'), findsAtLeastNWidgets(1));
        expect(find.text('設定'), findsAtLeastNWidgets(1));

        if (tab == 'ホーム') {
          expect(find.text('家族グループ'), findsOneWidget);
          expect(find.text('避難所情報'), findsOneWidget);
        } else {
          expect(find.text('家族グループ'), findsNothing);
          expect(find.text('避難所情報'), findsNothing);
          switch (tab) {
            case 'マップ':
              expect(find.textContaining('現在地'), findsAtLeastNWidgets(1));
            case '安否':
              expect(find.textContaining('確認'), findsAtLeastNWidgets(1));
            case 'メッセージ':
              expect(find.byType(TextField), findsAtLeastNWidgets(1));
            case '設定':
              expect(find.byType(Switch), findsAtLeastNWidgets(1));
          }
        }
      }
    });
  });

  // =========================================================================
  // Area 12: 市民 SOS -> 自治体反映 & オフライン/Supabase 15列連携 — 6 tests
  // =========================================================================
  group('Area 12: 市民 SOS -> 自治体反映 & 15列連携 (Tier 1)', () {
    Future<void> sendCitizenSos(
      WidgetTester tester, {
      FakeRescueDataSource? dataSource,
      required String name,
      required String detail,
      String considerations = '',
    }) async {
      await pumpMamoApp(
        tester,
        dataSource: dataSource,
        autoConnect: dataSource != null,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);
      await scrollAndTap(tester, find.text('救助要請'));
      await enterFieldByHint(tester, '登録した名前', name);
      await enterFieldByHint(tester, '建物内に閉じ込め', detail);
      if (considerations.isNotEmpty) {
        await enterFieldByHint(tester, '登録済みの配慮事項', considerations);
      }
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);
    }

    testWidgets('T1-F12-01: オフライン (dataSource: null) 市民 SOS が自治体側へ即時反映される', (
      tester,
    ) async {
      await sendCitizenSos(tester, name: '山田 太郎', detail: '家具の下敷き');

      await switchCitizenToMunicipality(tester);

      final dashboard = find.byType(DashboardView);
      expect(dashboard, findsOneWidget);
      expect(
        find.descendant(of: dashboard, matching: find.text('新規救助要請')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dashboard, matching: find.text('1')),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.descendant(of: dashboard, matching: find.textContaining('山田 太郎')),
        findsAtLeastNWidgets(1),
      );

      await navigateMunicipalityView(tester, '救助要請一覧');
      expect(find.textContaining('山田 太郎'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F12-02: 自治体詳細パネルに市民入力の全フィールドと既定位置・機関が表示される', (
      tester,
    ) async {
      await sendCitizenSos(
        tester,
        name: '佐藤 次郎',
        detail: '屋根上避難',
        considerations: 'インスリン必要',
      );

      await switchCitizenToMunicipality(tester);
      await navigateMunicipalityView(tester, '救助要請一覧');
      await selectMunicipalityRequest(tester, '佐藤 次郎');

      expect(find.text('救急要請'), findsAtLeastNWidgets(1));
      expect(find.text('未対応'), findsAtLeastNWidgets(1));
      expect(find.text('〇〇地区付近'), findsAtLeastNWidgets(1));
      expect(find.textContaining('約150m先（デモ）'), findsAtLeastNWidgets(1));
      expect(find.textContaining('佐藤 次郎'), findsAtLeastNWidgets(1));
      expect(find.textContaining('MAMO-'), findsAtLeastNWidgets(1));
      expect(find.text('屋根上避難'), findsAtLeastNWidgets(1));
      expect(find.text('インスリン必要'), findsAtLeastNWidgets(1));
    });

    testWidgets('T1-F12-03: FakeRescueDataSource 接続時に insertRequest が正確な 15 カラムで呼ばれる', (
      tester,
    ) async {
      final fakeDs = FakeRescueDataSource();
      addTearDown(fakeDs.dispose);

      await sendCitizenSos(
        tester,
        dataSource: fakeDs,
        name: '田中 三郎',
        detail: '停電中',
        considerations: '酸素吸入',
      );

      expect(fakeDs.insertedPayloads, hasLength(1));
      expectValid15ColPayload(
        fakeDs.insertedPayloads.single,
        expectedName: '田中 三郎',
        expectedDetail: '停電中',
        expectedConsiderations: '酸素吸入',
      );
    });

    testWidgets('T1-F12-04: 15 カラムペイロードに禁止列 (age, gender, latPercent, topPercent) が含まれない', (
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
      await enterFieldByHint(tester, '山田 太郎', '高橋 愛');
      await selectRadioOption(tester, '女性');
      await scrollAndTap(tester, find.text('次へ'));
      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);

      await scrollAndTap(tester, find.text('救助要請'));
      await enterFieldByHint(tester, '建物内に閉じ込め', '玄関が歪み脱出困難');
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);

      expect(fakeDs.insertedPayloads, hasLength(1));
      expectValid15ColPayload(
        fakeDs.insertedPayloads.single,
        expectedName: '高橋 愛',
        expectedDetail: '玄関が歪み脱出困難',
        expectedConsiderations: 'なし',
      );
    });

    testWidgets('T1-F12-05: 自治体側で市民 SOS のステータスを未対応 -> 対応中 -> 対応済みへ更新し DB 同期する', (
      tester,
    ) async {
      final fakeDs = FakeRescueDataSource(startingDbId: 101);
      addTearDown(fakeDs.dispose);

      await sendCitizenSos(
        tester,
        dataSource: fakeDs,
        name: 'ステータス更新者',
        detail: '支援要請',
      );
      await switchCitizenToMunicipality(tester);
      await navigateMunicipalityView(tester, '救助要請一覧');
      await selectMunicipalityRequest(tester, 'ステータス更新者');

      await scrollAndTap(tester, find.text('対応開始'), settle: false);
      await pumpPastSnackBars(tester);
      expect(fakeDs.updatedStatuses, hasLength(1));
      expect(fakeDs.updatedStatuses.last.dbId, '101');
      expect(fakeDs.updatedStatuses.last.status, RequestStatus.working);

      await scrollAndTap(tester, find.text('対応完了'), settle: false);
      await pumpPastSnackBars(tester);
      expect(fakeDs.updatedStatuses, hasLength(2));
      expect(fakeDs.updatedStatuses.last.dbId, '101');
      expect(fakeDs.updatedStatuses.last.status, RequestStatus.done);
    });

    testWidgets('T1-F12-06: 市民 SOS が自治体の位置情報マップおよび対応状況画面にも反映される', (
      tester,
    ) async {
      await sendCitizenSos(tester, name: 'マップ確認太郎', detail: '屋外待機');
      await switchCitizenToMunicipality(tester);

      await navigateMunicipalityView(tester, '位置情報マップ');
      expect(find.textContaining('1件'), findsAtLeastNWidgets(1));
      expect(findMapPinTooltip('マップ確認太郎', statusLabel: '未対応'), findsOneWidget);

      await navigateMunicipalityView(tester, '対応状況');
      final statusView = find.byType(StatusView);
      expect(statusView, findsOneWidget);
      expect(
        find.descendant(of: statusView, matching: find.text('マップ確認太郎')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: statusView, matching: find.text('救急')),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.descendant(of: statusView, matching: find.text('〇〇地区付近')),
        findsOneWidget,
      );
    });
  });
}
