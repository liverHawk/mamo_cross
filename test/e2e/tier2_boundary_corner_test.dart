import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mamo_cross/models/app_mode.dart';
import 'package:mamo_cross/pages/mamo_shell_page.dart';
import 'package:mamo_cross/state/rescue_store.dart';
import 'package:mamo_cross/widgets/app_sidebar.dart';

import 'e2e_test_helpers.dart';

void main() {
  // =========================================================================
  // Area 1: 起動時モード選択ポータル — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 1: 起動時モード選択ポータル (Tier 2)', () {
    testWidgets('T2-F01-01: 狭幅モバイル (360x640) でオーバーフローなく全モード選択可能', (
      tester,
    ) async {
      await pumpMamoApp(tester, viewport: const Size(360, 640));

      expect(tester.takeException(), isNull);
      await openCitizenFromPortal(tester);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F01-02: 広幅デスクトップ (1440x900) でレイアウト崩れなく描画される', (
      tester,
    ) async {
      await pumpMamoApp(tester, viewport: const Size(1440, 900));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('利用者'), findsAtLeastNWidgets(1));
      expect(find.textContaining('自治体'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F01-03: 極小縦幅 (390x480) でもスクロールで自治体モードへ遷移できる', (
      tester,
    ) async {
      await pumpMamoApp(tester, viewport: const Size(390, 480));

      expect(tester.takeException(), isNull);
      await openMunicipalityFromPortal(tester);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F01-04: 利用者モードカードの連続ダブルタップで二重遷移・例外が起きない', (
      tester,
    ) async {
      await pumpMamoApp(tester);

      final citizenBtn = findModeActionTrigger('利用者');
      expect(citizenBtn, findsAtLeastNWidgets(1));
      await tester.ensureVisible(citizenBtn);
      await tester.tap(citizenBtn);
      await tester.pump(const Duration(milliseconds: 50));
      if (!tester.any(find.text('ゲストモードではじめる')) && tester.any(citizenBtn)) {
        await tester.tap(citizenBtn);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
    });

    testWidgets('T2-F01-05: テキスト拡大 (TextScaler.linear(1.5)) 下でオーバーフローしない', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpMamoApp(tester, viewport: kMobileViewportSize);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('利用者'), findsAtLeastNWidgets(1));
      expect(find.textContaining('自治体'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F01-06: 外部 RescueStore 注入時のポータル起動で既存データが保持される', (
      tester,
    ) async {
      final store = RescueStore(startClock: false);
      addTearDown(store.dispose);
      store.addDbRequest({
        'id': 42,
        'request_id': 'MAMO-PRE42',
        'requester_name': '事前登録者',
        'request_type': '救急',
        'rescue_details': '事前テスト要請',
        'location_text': '山口市中心部',
        'status': '未対応',
      });

      await pumpMamoApp(tester, store: store);
      expect(find.text('ダッシュボード'), findsNothing);

      await openMunicipalityFromPortal(tester);
      expect(find.textContaining('事前登録者'), findsAtLeastNWidgets(1));
    });
  });

  // =========================================================================
  // Area 2: 相互モード切替導線 — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 2: 相互モード切替導線 (Tier 2)', () {
    testWidgets('T2-F02-01: 狭幅 (375x812) の自治体モバイルレイアウトでもモード切替導線が操作できる', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: const Size(375, 812),
        navigateTo: MamoAppMode.municipality,
      );

      expect(tester.takeException(), isNull);
      await switchMunicipalityToCitizen(tester);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F02-02: AppHeader ブレークポイント境界 (649/650/899/900px) で切替UIが壊れない', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: const Size(649, 844),
        navigateTo: MamoAppMode.municipality,
      );
      expect(find.byType(AppSidebar), findsNothing);
      expect(find.text('自治体管理システム'), findsNothing);
      expect(tester.takeException(), isNull);

      await resizeViewportAndSettle(tester, 650, 844);
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.text('自治体管理システム'), findsOneWidget);
      expect(tester.getSize(find.byType(AppSidebar)).width, equals(180.0));

      await resizeViewportAndSettle(tester, 899, 844);
      expect(tester.getSize(find.byType(AppSidebar)).width, equals(180.0));

      await resizeViewportAndSettle(tester, 900, 844);
      expect(tester.getSize(find.byType(AppSidebar)).width, equals(218.0));

      await switchMunicipalityToPortal(tester);
      expect(find.textContaining('利用者'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F02-03: 市民オンボーディング途中 (#reg2 入力中) で自治体へ切替・復帰してもクラッシュしない', (
      tester,
    ) async {
      await pumpMamoApp(tester, navigateTo: MamoAppMode.citizen);
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
      await enterFieldByHint(tester, '山田 太郎', '田中 健');

      await switchCitizenToMunicipality(tester);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));

      await switchMunicipalityToCitizen(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('田中 健'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F02-04: demoLogin() の 450ms タイマー動作中にモード切替してもエラーにならない', (
      tester,
    ) async {
      await pumpMamoApp(tester, navigateTo: MamoAppMode.citizen);

      await scrollAndTap(tester, find.text('ログイン'), settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      await switchCitizenToMunicipality(tester);
      await pumpPastToasts(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F02-05: 高速連続モード切替（4回連続）が安定する', (tester) async {
      await pumpMamoApp(tester);

      await openCitizenFromPortal(tester);
      await switchCitizenToMunicipality(tester);
      await switchMunicipalityToPortal(tester);
      await openCitizenFromPortal(tester);
      await switchCitizenToMunicipality(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F02-06: MamoShellPage を onSelectMode なしで単独起動する既存互換が維持される', (
      tester,
    ) async {
      final store = RescueStore(startClock: false);
      addTearDown(store.dispose);
      setDesktopViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: MamoShellPage(
            store: store,
            startClock: false,
            autoConnect: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ダッシュボード'), findsAtLeastNWidgets(1));
    });
  });

  // =========================================================================
  // Area 3: モバイル想定幅フレーム — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 3: モバイル想定幅フレーム (Tier 2)', () {
    testWidgets('T2-F03-01: 下側境界値 width == 520.0 (<=520px) は擬似ステータスバーなしのフルスクリーンになる', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: const Size(520, 844),
        navigateTo: MamoAppMode.citizen,
      );

      expect(find.text('9:41'), findsNothing);
      final citizenScaffoldWidth = tester.getSize(find.byType(Scaffold).last).width;
      expect(citizenScaffoldWidth, greaterThan(390.0));
      expect(citizenScaffoldWidth, lessThanOrEqualTo(520.0));

      final regBtn = findPrimaryButtonWithText('新規登録');
      expect(regBtn, findsOneWidget);
      final regBtnWidth = tester.getSize(regBtn).width;
      expect(regBtnWidth, greaterThan(390.0));
      expect(regBtnWidth, lessThanOrEqualTo(520.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F03-02: 上側境界値 width == 521.0 (>520px) は 390px モバイル枠が有効になる', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: const Size(521, 844),
        navigateTo: MamoAppMode.citizen,
      );

      expect(find.text('9:41'), findsOneWidget);
      final citizenScaffoldWidth = tester.getSize(find.byType(Scaffold).last).width;
      expect(citizenScaffoldWidth, lessThanOrEqualTo(390.0));
      expect(citizenScaffoldWidth, greaterThanOrEqualTo(250.0));

      final regBtn = findPrimaryButtonWithText('新規登録');
      expect(regBtn, findsOneWidget);
      final regBtnWidth = tester.getSize(regBtn).width;
      expect(regBtnWidth, lessThanOrEqualTo(390.0));
      expect(regBtnWidth, greaterThanOrEqualTo(250.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F03-03: 動的リサイズ 800x844 -> 480x844 で現在画面・入力値を失わず全画面へ移行する', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: const Size(800, 844),
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
      await enterFieldByHint(tester, '山田 太郎', '境界テスト');

      await resizeViewportAndSettle(tester, 480, 844);

      expect(tester.takeException(), isNull);
      expect(find.text('② 基本情報の入力'), findsOneWidget);
      expect(find.text('境界テスト'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F03-04: 動的リサイズ 400x844 -> 1024x844 で 390px 枠へ切り替わり状態を保持する', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: const Size(400, 844),
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await resizeViewportAndSettle(tester, 1024, 844);

      expect(tester.takeException(), isNull);
      expect(find.text('9:41'), findsOneWidget);
      expect(find.text('家族グループ'), findsOneWidget);
      final citizenScaffoldWidth = tester.getSize(find.byType(Scaffold).last).width;
      expect(citizenScaffoldWidth, lessThanOrEqualTo(390.0));
      expect(citizenScaffoldWidth, greaterThanOrEqualTo(250.0));
    });

    testWidgets('T2-F03-05: 縦幅が短いデスクトップ (1280x600) でもモバイル枠が縦オーバーフローしない', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: const Size(1280, 600),
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await tester.ensureVisible(find.text('避難所情報'));
      expect(find.text('避難所情報'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F03-06: 極狭モバイル (280x653) で #home の 3 列ボタンと 5 タブが崩れない', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: const Size(280, 653),
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('無事'), findsAtLeastNWidgets(1));
      expect(find.textContaining('被害あり'), findsAtLeastNWidgets(1));
      expect(find.textContaining('救助要請'), findsAtLeastNWidgets(1));
      expect(find.text('マップ'), findsOneWidget);
      expect(find.text('設定'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 4: 利用者 #login 画面 — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 4: 利用者 #login 画面 (Tier 2)', () {
    testWidgets('T2-F04-01: demoLogin() 450ms 未満 (200ms 時点) ではトースト表示中で #home へ未遷移', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      await scrollAndTap(tester, find.text('ログイン'), settle: false);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('デモログインしました'), findsAtLeastNWidgets(1));
      expect(find.text('家族グループ'), findsNothing);

      await pumpTransition(tester);
      await pumpPastToasts(tester);
      expect(find.text('家族グループ'), findsOneWidget);
    });

    testWidgets('T2-F04-02: トーストが 1800ms で自動消滅する', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      await scrollAndTap(tester, find.text('ログイン'), settle: false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('デモログインしました'), findsAtLeastNWidgets(1));

      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pumpAndSettle();
      expect(find.textContaining('デモログインしました'), findsNothing);
    });

    testWidgets('T2-F04-03: ログインとゲストモードではじめるを 100ms 間隔で連続タップしても安全', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      await scrollAndTap(tester, find.text('ログイン'), settle: false);
      await tester.pump(const Duration(milliseconds: 100));
      final guestFinder = find.text('ゲストモードではじめる');
      expect(guestFinder, findsOneWidget);
      await tester.tap(guestFinder);
      await pumpPastToasts(tester, duration: const Duration(milliseconds: 2500));

      expect(tester.takeException(), isNull);
      expect(find.text('家族グループ'), findsOneWidget);
    });

    testWidgets('T2-F04-04: ログイン直後に新規登録をタップした場合の競合安全性', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      await scrollAndTap(tester, find.text('ログイン'), settle: false);
      await tester.pump(const Duration(milliseconds: 100));
      final regFinder = find.text('新規登録');
      expect(regFinder, findsOneWidget);
      await tester.tap(regFinder);
      await pumpPastToasts(tester, duration: const Duration(milliseconds: 2500));

      expect(tester.takeException(), isNull);
      final inReg1OrHome =
          tester.any(find.text('① 本人確認')) ||
          tester.any(find.text('家族グループ'));
      expect(inReg1OrHome, isTrue);
    });

    testWidgets('T2-F04-05: 低高さ (390x480) で最下部のゲストモードではじめるがスクロール到達できる', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: const Size(390, 480),
        navigateTo: MamoAppMode.citizen,
      );

      await loginAsGuest(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('家族グループ'), findsOneWidget);
    });

    testWidgets('T2-F04-06: ゲストログイン -> #home ☰ ログアウト -> 再び新規登録の遷移が正常動作する', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );

      await loginAsGuest(tester);
      await scrollAndTap(tester, find.text('☰'));
      await scrollAndTap(tester, find.text('新規登録'));

      expect(find.text('① 本人確認'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 5: 利用者 #reg1 本人確認画面 — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 5: 利用者 #reg1 本人確認画面 (Tier 2)', () {
    Future<void> openReg1(
      WidgetTester tester, {
      Size viewport = kMobileViewportSize,
    }) async {
      await pumpMamoApp(
        tester,
        viewport: viewport,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
    }

    testWidgets('T2-F05-01: 写真・身分証を一切タップせず未選択のまま次へで遷移できる', (tester) async {
      await openReg1(tester);

      await scrollAndTap(tester, find.text('次へ'));
      expect(find.text('② 基本情報の入力'), findsOneWidget);
    });

    testWidgets('T2-F05-02: 顔写真枠タップ直後に身分証を選択をタップするとトーストが上書きされる', (
      tester,
    ) async {
      await openReg1(tester);

      await scrollAndTap(tester, find.text('顔写真を登録'), settle: false);
      await tester.pump(const Duration(milliseconds: 200));
      await scrollAndTap(tester, find.text('身分証を選択'), settle: false);
      await expectToastAndDrain(tester, 'デモ：身分証選択');
    });

    testWidgets('T2-F05-03: トースト表示中に次へで #reg2 へ遷移しても例外・タイマー漏れしない', (
      tester,
    ) async {
      await openReg1(tester);

      await scrollAndTap(tester, find.text('身分証を選択'), settle: false);
      await tester.pump(const Duration(milliseconds: 100));
      await scrollAndTap(tester, find.text('次へ'), settle: false);
      await pumpPastToasts(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('② 基本情報の入力'), findsOneWidget);
    });

    testWidgets('T2-F05-04: #reg2 から ‹ で #reg1 に戻った際も全要素が再操作可能', (tester) async {
      await openReg1(tester);

      await scrollAndTap(tester, find.text('次へ'));
      await scrollAndTap(tester, find.text('‹'));
      await scrollAndTap(tester, find.text('顔写真を登録'), settle: false);
      await expectToastAndDrain(tester, 'デモ：写真アップロード画面を想定しています');
      await scrollAndTap(tester, find.text('次へ'));

      expect(find.text('② 基本情報の入力'), findsOneWidget);
    });

    testWidgets('T2-F05-05: 極狭画面 (320x568) で #reg1 がオーバーフローなくスクロール操作できる', (
      tester,
    ) async {
      await openReg1(tester, viewport: kNarrowViewportSize);

      await scrollAndTap(tester, find.text('身分証を選択'), settle: false);
      await pumpPastToasts(tester);
      await scrollAndTap(tester, find.text('次へ'));

      expect(tester.takeException(), isNull);
      expect(find.text('② 基本情報の入力'), findsOneWidget);
    });

    testWidgets('T2-F05-06: 顔写真枠を 3 回連打してもオーバーレイ多重生成やクラッシュしない', (tester) async {
      await openReg1(tester);

      for (var i = 0; i < 3; i++) {
        await scrollAndTap(tester, find.text('顔写真を登録'), settle: false);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await pumpPastToasts(tester);

      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Area 6: 利用者 #reg2 基本情報入力画面 — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 6: 利用者 #reg2 基本情報入力画面 (Tier 2)', () {
    Future<void> openReg2(
      WidgetTester tester, {
      Size viewport = kMobileViewportSize,
    }) async {
      await pumpMamoApp(
        tester,
        viewport: viewport,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
    }

    testWidgets('T2-F06-01: 全必須表記欄が空のままでもエラーなく #reg3 へ進める', (tester) async {
      await openReg2(tester);

      await scrollAndTap(tester, find.text('次へ'));
      expect(find.text('③ 救助要請時の情報'), findsOneWidget);
    });

    testWidgets('T2-F06-02: #reg2 -> #reg3 -> ‹ で戻った際に入力値が保持されている', (tester) async {
      await openReg2(tester);

      await enterFieldByHint(tester, '山田 太郎', '高橋 健太');
      await selectDropdownOption(tester, find.text('選択してください'), 'A型');
      await selectRadioOption(tester, '男性');
      await enterFieldByHint(tester, '郵便番号', '100-0001');
      await scrollAndTap(tester, find.text('次へ'));
      expect(find.text('③ 救助要請時の情報'), findsOneWidget);

      await scrollAndTap(tester, find.text('‹'));
      expect(find.text('高橋 健太'), findsAtLeastNWidgets(1));
      expect(find.text('A型'), findsAtLeastNWidgets(1));
      expect(find.text('100-0001'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F06-03: #reg2 -> ‹ (#reg1) -> 次へ (#reg2) でも入力値が失われない', (
      tester,
    ) async {
      await openReg2(tester);

      await enterFieldByHint(tester, '山田 太郎', '伊藤 美穂');
      await scrollAndTap(tester, find.text('‹'));
      expect(find.text('① 本人確認'), findsOneWidget);

      await scrollAndTap(tester, find.text('次へ'));
      expect(find.text('伊藤 美穂'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F06-04: 性別選択を 男性 -> 女性 -> その他 -> 男性 と切替できる', (tester) async {
      await openReg2(tester);

      expect(find.byType(RadioGroup<String>), findsOneWidget);
      for (final g in const ['男性', '女性', 'その他', '男性']) {
        await selectRadioOption(tester, g);
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue,
          equals(g),
        );
      }
    });

    testWidgets('T2-F06-05: 100 文字の超長文氏名および空白のみ氏名でオーバーフロー・クラッシュしない', (
      tester,
    ) async {
      await openReg2(tester);

      final longName = '山' * 100;
      await enterFieldByHint(tester, '山田 太郎', longName);
      await scrollAndTap(tester, find.text('次へ'));
      expect(tester.takeException(), isNull);
      expect(find.text('③ 救助要請時の情報'), findsOneWidget);

      await scrollAndTap(tester, find.text('‹'));
      await enterFieldByHint(tester, '山田 太郎', '   ');
      await scrollAndTap(tester, find.text('次へ'));
      expect(tester.takeException(), isNull);
      expect(find.text('③ 救助要請時の情報'), findsOneWidget);
    });

    testWidgets('T2-F06-06: 極狭画面 (320x568) で性別3択・住所欄・次へがオーバーフローしない', (
      tester,
    ) async {
      await openReg2(tester, viewport: kNarrowViewportSize);

      await enterFieldByHint(tester, '山田 太郎', '狭幅 テスト');
      await selectRadioOption(tester, 'その他');
      await enterFieldByHint(tester, '郵便番号', '753-0001');
      await scrollAndTap(tester, find.text('次へ'));

      expect(tester.takeException(), isNull);
      expect(find.text('③ 救助要請時の情報'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 7: 利用者 #reg3 配慮事項登録画面 — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 7: 利用者 #reg3 配慮事項登録画面 (Tier 2)', () {
    Future<void> openReg3WithName(WidgetTester tester, String name) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
      if (name.isNotEmpty) {
        await enterFieldByHint(tester, '山田 太郎', name);
      }
      await scrollAndTap(tester, find.text('次へ'));
    }

    testWidgets('T2-F07-01: #reg2 で名前未入力（空文字）のまま登録すると既定名 あなた にフォールバックする', (
      tester,
    ) async {
      await openReg3WithName(tester, '');

      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);
      await scrollAndTap(tester, find.text('救助要請'));

      expect(find.text('あなた'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F07-02: #reg2 で名前が空白のみの場合も あなた にフォールバックする', (tester) async {
      await openReg3WithName(tester, '   ');

      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);
      await scrollAndTap(tester, find.text('救助要請'));

      expect(find.text('あなた'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F07-03: 前後空白付き氏名 (  山田 太郎  ) はトリムされて保存される', (tester) async {
      await openReg3WithName(tester, '  山田 太郎  ');

      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);
      await scrollAndTap(tester, find.text('救助要請'));

      expect(find.text('山田 太郎'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F07-04: 5 項目全チェック＋200 文字以上の長文入力でも登録するへ到達できる', (
      tester,
    ) async {
      await openReg3WithName(tester, '長文 配慮');

      for (final label in const [
        'ホルモン治療中',
        '人工呼吸器を使用',
        '妊娠中',
        'オストメイト',
        '医療的ケアが必要',
      ]) {
        await scrollAndTap(tester, find.textContaining(label).first);
      }
      await enterFieldByHint(tester, 'アレルギー', 'あ' * 220);
      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('家族グループ'), findsOneWidget);
    });

    testWidgets('T2-F07-05: #reg3 -> ‹ (#reg2) -> 次へ (#reg3) で選択チェックと自由入力が保持される', (
      tester,
    ) async {
      await openReg3WithName(tester, '保持 テスト');

      await scrollAndTap(tester, find.textContaining('妊娠中').first);
      await enterFieldByHint(tester, 'アレルギー', '喘息');

      await scrollAndTap(tester, find.text('‹'));
      expect(find.text('② 基本情報の入力'), findsOneWidget);
      await scrollAndTap(tester, find.text('次へ'));

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes[2].value, isTrue);
      expect(find.text('喘息'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F07-06: 登録するのトースト 登録が完了しました（デモ） が 1800ms 後に自動消滅する', (
      tester,
    ) async {
      await openReg3WithName(tester, 'トースト確認');

      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('登録が完了しました（デモ）'), findsAtLeastNWidgets(1));

      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pumpAndSettle();
      expect(find.textContaining('登録が完了しました（デモ）'), findsNothing);
    });
  });

  // =========================================================================
  // Area 8: 利用者 #home ホームタブ画面 — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 8: 利用者 #home ホームタブ画面 (Tier 2)', () {
    testWidgets('T2-F08-01: 無事 -> 500ms 以内に被害あり連打でトーストが上書きされタイマー漏れしない', (
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
        findSafetyStatusButton('無事').first,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await scrollAndTap(
        tester,
        findSafetyStatusButton('被害あり').first,
        settle: false,
      );
      await expectToastAndDrain(tester, '被害ありとして登録しました');
    });

    testWidgets('T2-F08-02: 無事トースト表示中に SOS タップで #rescue へ遷移しても例外・タイマー残存しない', (
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
        findSafetyStatusButton('無事').first,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await scrollAndTap(tester, find.text('救助要請'), settle: false);
      await pumpPastToasts(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('現在の状況を確認'), findsOneWidget);
    });

    testWidgets('T2-F08-03: 極狭画面 (320x568) で 3 列安否ボタン・家族 4 行・避難所カード・下部タブが崩れない', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kNarrowViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await tester.ensureVisible(find.text('避難所情報'));
      expect(tester.takeException(), isNull);
      expect(find.text('避難所情報'), findsOneWidget);
      expect(find.text('設定'), findsOneWidget);
    });

    testWidgets('T2-F08-04: #home ☰ -> #login -> 再ログインで #home ホームタブになる', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await scrollAndTap(tester, find.text('☰'));
      await scrollAndTap(tester, find.text('ログイン'), settle: false);
      await pumpTransition(tester);
      await pumpPastToasts(tester);

      expect(find.text('家族グループ'), findsOneWidget);
      expect(find.text('避難所情報'), findsOneWidget);
    });

    testWidgets('T2-F08-05: テキスト拡大 (TextScaler.linear(1.3)) 下で家族バッジ・3 ボタンがはみ出さない', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await tester.ensureVisible(find.text('避難所情報'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F08-06: 新規登録完了直後の #home 表示項目整合性が保たれる', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
      await enterFieldByHint(tester, '山田 太郎', '新規 住民');
      await scrollAndTap(tester, find.text('次へ'));
      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);

      expect(find.textContaining('震度5強'), findsOneWidget);
      expect(find.text('家族グループ'), findsOneWidget);
      expect(find.text('避難所情報'), findsOneWidget);
      expect(find.text('マップ'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 9: 利用者 #rescue 救助要請画面 — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 9: 利用者 #rescue 救助要請画面 (Tier 2)', () {
    Future<FakeRescueDataSource> openRescueWithFakeDs(
      WidgetTester tester,
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
      await loginAsGuest(tester);
      await scrollAndTap(tester, find.text('救助要請'));
      return fakeDs;
    }

    testWidgets('T2-F09-01: 全欄空のまま送信で既定値 (あなた / 救助が必要です / なし) へフォールバックする', (
      tester,
    ) async {
      final fakeDs = await openRescueWithFakeDs(tester);

      await enterFieldByHint(tester, '登録した名前', '');
      await enterFieldByHint(tester, '建物内に閉じ込め', '');
      await enterFieldByHint(tester, '登録済みの配慮事項', '');
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
    });

    testWidgets('T2-F09-02: 全欄が空白文字のみ (   ) でもトリムされ既定値へフォールバックする', (
      tester,
    ) async {
      final fakeDs = await openRescueWithFakeDs(tester);

      await enterFieldByHint(tester, '登録した名前', '   ');
      await enterFieldByHint(tester, '建物内に閉じ込め', '   ');
      await enterFieldByHint(tester, '登録済みの配慮事項', '   ');
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
    });

    testWidgets('T2-F09-03: 送信後に #home 経由で再度 #rescue を開くと前回の救助内容がリセットされている', (
      tester,
    ) async {
      await openRescueWithFakeDs(tester);

      await enterFieldByHint(tester, '建物内に閉じ込め', '前回内容');
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);

      await scrollAndTap(tester, find.text('ホームへ戻る'));
      await scrollAndTap(tester, find.text('救助要請'));

      expect(find.text('前回内容'), findsNothing);
    });

    testWidgets('T2-F09-04: 途中入力後にキャンセルしても未送信テキストは RescueStore に登録されない', (
      tester,
    ) async {
      final fakeDs = await openRescueWithFakeDs(tester);

      await enterFieldByHint(tester, '建物内に閉じ込め', '下書きテキスト');
      await scrollAndTap(tester, find.text('キャンセル'));
      expect(fakeDs.insertedPayloads, isEmpty);

      await switchCitizenToMunicipality(tester);
      await navigateMunicipalityView(tester, '救助要請一覧');
      expect(find.text('下書きテキスト'), findsNothing);
    });

    testWidgets('T2-F09-05: 300 文字以上の長文入力時も送信ボタンまでスクロール到達できる', (tester) async {
      await openRescueWithFakeDs(tester);

      await enterFieldByHint(tester, '建物内に閉じ込め', '救' * 320);
      await enterFieldByHint(tester, '登録済みの配慮事項', '配' * 200);
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('救助要請を送信しました'), findsOneWidget);
    });

    testWidgets('T2-F09-06: #reg2 登録氏名 鈴木 美咲 が #rescue のお名前欄に自動プリフィルされる', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
      await enterFieldByHint(tester, '山田 太郎', '鈴木 美咲');
      await scrollAndTap(tester, find.text('次へ'));
      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);

      await scrollAndTap(tester, find.text('救助要請'));
      expect(find.text('鈴木 美咲'), findsAtLeastNWidgets(1));
    });
  });

  // =========================================================================
  // Area 10: 利用者 #rescueSent 送信完了画面 — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 10: 利用者 #rescueSent 送信完了画面 (Tier 2)', () {
    Future<void> submitCustomSos(
      WidgetTester tester, {
      required String name,
      required String detail,
      Size viewport = kMobileViewportSize,
      FakeRescueDataSource? dataSource,
    }) async {
      await pumpMamoApp(
        tester,
        dataSource: dataSource,
        autoConnect: dataSource != null,
        viewport: viewport,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);
      await scrollAndTap(tester, find.text('救助要請'));
      await enterFieldByHint(tester, '登録した名前', name);
      await enterFieldByHint(tester, '建物内に閉じ込め', detail);
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);
    }

    testWidgets('T2-F10-01: HTML/XSS 特殊文字がプレーンテキストとして安全表示される', (tester) async {
      const xss = '<script>alert(1)</script>&"\'';
      await submitCustomSos(tester, name: xss, detail: xss);

      expect(tester.takeException(), isNull);
      expect(find.textContaining(xss), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F10-02: 2 回連続で SOS 送信すると最新の受付内容に更新される', (tester) async {
      await submitCustomSos(tester, name: '送信者A', detail: '件目A');
      expect(find.textContaining('件目A'), findsAtLeastNWidgets(1));

      await scrollAndTap(tester, find.text('ホームへ戻る'));
      await tester.pump(const Duration(milliseconds: 20));
      await scrollAndTap(tester, find.text('救助要請'));
      await enterFieldByHint(tester, '登録した名前', '送信者B');
      await enterFieldByHint(tester, '建物内に閉じ込め', '件目B');
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);

      expect(find.textContaining('送信者B'), findsAtLeastNWidgets(1));
      expect(find.textContaining('件目B'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F10-03: 低高さ画面 (390x500) でも受付カードとホームへ戻るがスクロール到達できる', (
      tester,
    ) async {
      await submitCustomSos(
        tester,
        name: '低高さ ユーザー',
        detail: '支援要請',
        viewport: const Size(390, 500),
      );

      await scrollAndTap(tester, find.text('ホームへ戻る'));
      expect(tester.takeException(), isNull);
      expect(find.text('家族グループ'), findsOneWidget);
    });

    testWidgets('T2-F10-04: 送信時トーストの 1800ms タイマーが #home 復帰後に残存エラーを起こさない', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);
      await scrollAndTap(tester, find.text('救助要請'));
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await scrollAndTap(tester, find.text('ホームへ戻る'), settle: false);
      await pumpPastToasts(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('家族グループ'), findsOneWidget);
    });

    testWidgets('T2-F10-05: #rescueSent 表示中に自治体モードへ切替 -> 市民モード復帰しても正常描画される', (
      tester,
    ) async {
      await submitCustomSos(
        tester,
        name: '往復確認者',
        detail: '救助待機',
        viewport: kDesktopViewportSize,
      );

      await switchCitizenToMunicipality(tester);
      expect(find.textContaining('往復確認者'), findsAtLeastNWidgets(1));

      await switchMunicipalityToCitizen(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('救助要請を送信しました'), findsOneWidget);
    });

    testWidgets('T2-F10-06: 非常に長い名前・内容（各 150 文字）でもオーバーフローしない', (tester) async {
      await submitCustomSos(tester, name: '名' * 150, detail: '内' * 150);

      expect(tester.takeException(), isNull);
      expect(find.text('救助要請を送信しました'), findsOneWidget);
    });
  });

  // =========================================================================
  // Area 11: 下部 5 タブ — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 11: 下部 5 タブ切替・各タブ機能 (Tier 2)', () {
    Future<void> enterHome(
      WidgetTester tester, {
      Size viewport = kMobileViewportSize,
    }) async {
      await pumpMamoApp(
        tester,
        viewport: viewport,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);
    }

    testWidgets('T2-F11-01: タブ間状態連動: 安否タブで本人安否を変更するとホームへ反映される', (
      tester,
    ) async {
      await enterHome(tester);

      await tapCitizenBottomTab(tester, '安否');
      final injuredBtn = findSafetyStatusButton('被害あり');
      expect(injuredBtn, findsAtLeastNWidgets(1));
      await scrollAndTap(tester, injuredBtn.first, settle: false);
      await pumpPastToasts(tester);

      await tapCitizenBottomTab(tester, 'ホーム');
      expect(find.text('家族グループ'), findsOneWidget);
      expect(find.textContaining('被害あり'), findsAtLeastNWidgets(3));
      expectAtMostNWidgets(find.textContaining('無事'), 3);
    });

    testWidgets('T2-F11-02: メッセージタブで送信した文面がタブ往復後も保持される', (tester) async {
      await enterHome(tester);

      await tapCitizenBottomTab(tester, 'メッセージ');
      final input = find.byType(TextField);
      expect(input, findsAtLeastNWidgets(1));
      await scrollAndEnterText(tester, input.first, '水を持っています');

      final sendTrigger = findSendMessageTrigger();
      expect(sendTrigger, findsAtLeastNWidgets(1));
      await scrollAndTap(tester, sendTrigger.first, settle: false);
      await pumpPastToasts(tester);

      await tapCitizenBottomTab(tester, 'ホーム');
      expect(find.text('家族グループ'), findsOneWidget);
      await tapCitizenBottomTab(tester, 'メッセージ');
      expect(find.text('家族グループ'), findsNothing);
      expect(find.textContaining('水を持っています'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F11-03: メッセージタブで空文字または空白のみの送信は無視される', (tester) async {
      await enterHome(tester);

      await tapCitizenBottomTab(tester, 'メッセージ');
      final input = find.byType(TextField);
      expect(input, findsAtLeastNWidgets(1));
      final textCountBefore = find.byType(Text).evaluate().length;

      await scrollAndEnterText(tester, input.first, '   ');
      final sendTrigger = findSendMessageTrigger();
      expect(sendTrigger, findsAtLeastNWidgets(1));
      await scrollAndTap(tester, sendTrigger.first, settle: false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('送信しました'), findsNothing);
      await pumpPastToasts(tester);
      expect(find.text('   '), findsNothing);
      expectAtMostNWidgets(find.byType(Text), textCountBefore);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F11-04: 設定タブからログアウトすると #login へ戻り、再ログイン時にホームタブになる', (
      tester,
    ) async {
      await enterHome(tester);

      await tapCitizenBottomTab(tester, '設定');
      await scrollAndTap(tester, find.textContaining('ログアウト').first);
      expect(find.text('ゲストモードではじめる'), findsOneWidget);

      await loginAsGuest(tester);
      expect(find.text('家族グループ'), findsOneWidget);
    });

    testWidgets('T2-F11-05: 極狭幅 (320x568) で下部 5 タブすべてオーバーフローせず切替できる', (
      tester,
    ) async {
      await enterHome(tester, viewport: kNarrowViewportSize);

      for (final tab in const ['マップ', '安否', 'メッセージ', '設定', 'ホーム']) {
        await tapCitizenBottomTab(tester, tab);
        expect(tester.takeException(), isNull);
        if (tab == 'ホーム') {
          expect(find.text('家族グループ'), findsOneWidget);
        } else {
          expect(find.text('家族グループ'), findsNothing);
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

    testWidgets('T2-F11-06: 登録内容が設定タブに反映され、通知スイッチ切替状態がタブ往復後も保持される', (
      tester,
    ) async {
      await pumpMamoApp(
        tester,
        viewport: kMobileViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await scrollAndTap(tester, find.text('新規登録'));
      await scrollAndTap(tester, find.text('次へ'));
      await enterFieldByHint(tester, '山田 太郎', '小林 直樹');
      await scrollAndTap(tester, find.text('次へ'));
      await scrollAndTap(tester, find.textContaining('妊娠中').first);
      await scrollAndTap(tester, find.text('登録する'), settle: false);
      await pumpPastToasts(tester);

      await tapCitizenBottomTab(tester, '設定');
      expect(find.textContaining('小林 直樹'), findsAtLeastNWidgets(1));

      final switchFinder = find.byType(Switch).first;
      final before = tester.widget<Switch>(switchFinder).value;
      await scrollAndTap(tester, switchFinder, settle: false);
      await pumpPastToasts(tester);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, !before);

      await tapCitizenBottomTab(tester, 'ホーム');
      await tapCitizenBottomTab(tester, '設定');
      expect(tester.widget<Switch>(find.byType(Switch).first).value, !before);
    });
  });

  // =========================================================================
  // Area 12: 市民 SOS -> 自治体反映 & オフライン/Supabase 15列連携 — 6 Boundary/Corner tests
  // =========================================================================
  group('Area 12: 市民 SOS -> 自治体反映 & 15列連携 (Tier 2)', () {
    Future<void> triggerSosFromHome(
      WidgetTester tester, {
      required String name,
      required String detail,
    }) async {
      await scrollAndTap(tester, find.text('救助要請'));
      await enterFieldByHint(tester, '登録した名前', name);
      await enterFieldByHint(tester, '建物内に閉じ込め', detail);
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await pumpPastToasts(tester);
    }

    testWidgets('T2-F12-01: insertRequest が例外を投げる障害状態でもクラッシュせずローカル反映される', (
      tester,
    ) async {
      final fakeDs = FakeRescueDataSource(
        insertBehavior: FakeInsertBehavior.throwError,
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
      await triggerSosFromHome(tester, name: '障害耐性ユーザー', detail: '通信不調テスト');

      expect(tester.takeException(), isNull);
      expect(find.text('救助要請を送信しました'), findsOneWidget);

      await switchCitizenToMunicipality(tester);
      await navigateMunicipalityView(tester, '救助要請一覧');
      expect(find.textContaining('障害耐性ユーザー'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F12-02: insertRequest が null (未設定/オフライン返却) でも正常完了する', (
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
      await triggerSosFromHome(tester, name: '未設定ユーザー', detail: 'ローカル継続');

      expect(find.text('救助要請を送信しました'), findsOneWidget);
      await switchCitizenToMunicipality(tester);
      await navigateMunicipalityView(tester, '救助要請一覧');
      expect(find.textContaining('未設定ユーザー'), findsAtLeastNWidgets(1));
    });

    testWidgets('T2-F12-03: Realtime 重複排除: 同一 id / request_id の INSERT イベントが重複しない', (
      tester,
    ) async {
      final fakeDs = FakeRescueDataSource(startingDbId: 777);
      addTearDown(fakeDs.dispose);

      await pumpMamoApp(
        tester,
        dataSource: fakeDs,
        autoConnect: true,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);
      await triggerSosFromHome(tester, name: '重複排除ユーザー', detail: '1回だけ表示');

      fakeDs.emitInsert({...fakeDs.insertedPayloads.single, 'id': 777});
      await pumpPastToasts(tester);

      await switchCitizenToMunicipality(tester);
      expect(find.text('1'), findsAtLeastNWidgets(1));
      await navigateMunicipalityView(tester, '救助要請一覧');
      expect(find.textContaining('重複排除ユーザー'), findsAtLeastNWidgets(1));
      expect(find.text('すべて 1'), findsOneWidget);
    });

    testWidgets('T2-F12-04: insertRequest 完了前に同一 request_id の Realtime INSERT が先行しても重複しない', (
      tester,
    ) async {
      final completer = Completer<Map<String, dynamic>?>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
      final fakeDs = FakeRescueDataSource(
        onInsert: (_) => completer.future,
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
      await enterFieldByHint(tester, '登録した名前', 'レース条件ユーザー');
      await enterFieldByHint(tester, '建物内に閉じ込め', '先行イベント');
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 50));

      final attempted = fakeDs.attemptedPayloads.single;
      fakeDs.emitInsert({...attempted, 'id': 888});
      await tester.pump(const Duration(milliseconds: 50));
      completer.complete({...attempted, 'id': 888});
      await pumpPastToasts(tester);

      await switchCitizenToMunicipality(tester);
      await navigateMunicipalityView(tester, '救助要請一覧');
      expect(find.text('すべて 1'), findsOneWidget);

      await scrollAndTap(tester, find.text('対応開始'), settle: false);
      await pumpPastSnackBars(tester);
      expect(fakeDs.updatedStatuses.last.dbId, '888');
    });

    testWidgets('T2-F12-05: 複数回連続の市民 SOS 送信が最新先頭順で自治体へ反映される', (tester) async {
      await pumpMamoApp(
        tester,
        viewport: kDesktopViewportSize,
        navigateTo: MamoAppMode.citizen,
      );
      await loginAsGuest(tester);

      await triggerSosFromHome(tester, name: '1件目市民', detail: '最初の要請');
      await scrollAndTap(tester, find.text('ホームへ戻る'));
      await tester.pump(const Duration(milliseconds: 20));
      await triggerSosFromHome(tester, name: '2件目市民', detail: '最新の要請');

      await switchCitizenToMunicipality(tester);
      expect(find.textContaining('1件目市民'), findsAtLeastNWidgets(1));
      expect(find.textContaining('2件目市民'), findsAtLeastNWidgets(1));

      await navigateMunicipalityView(tester, '救助要請一覧');
      expect(find.text('すべて 2'), findsOneWidget);
      final firstTop = tester.getTopLeft(find.textContaining('2件目市民').first).dy;
      final secondTop = tester.getTopLeft(find.textContaining('1件目市民').first).dy;
      expect(firstTop, lessThan(secondTop));
    });

    testWidgets('T2-F12-06: insertRequest 遅延中に画面遷移・自治体切替しても非同期完了が安全処理される', (
      tester,
    ) async {
      final completer = Completer<Map<String, dynamic>?>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
      final fakeDs = FakeRescueDataSource(
        onInsert: (_) => completer.future,
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
      await enterFieldByHint(tester, '登録した名前', '非同期遅延ユーザー');
      await scrollAndTap(
        tester,
        find.textContaining('救助要請を送信'),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('救助要請を送信しました'), findsOneWidget);
      await scrollAndTap(tester, find.text('ホームへ戻る'), settle: false);
      await switchCitizenToMunicipality(tester);

      final attempted = fakeDs.attemptedPayloads.single;
      completer.complete({...attempted, 'id': 555});
      await pumpPastToasts(tester);

      expect(tester.takeException(), isNull);
      await navigateMunicipalityView(tester, '救助要請一覧');
      expect(find.text('すべて 1'), findsOneWidget);
      await scrollAndTap(tester, find.text('対応開始'), settle: false);
      await pumpPastSnackBars(tester);
      expect(fakeDs.updatedStatuses.last.dbId, '555');
    });
  });
}
