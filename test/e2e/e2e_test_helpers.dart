import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mamo_cross/models/app_mode.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/main.dart';
import 'package:mamo_cross/services/rescue_data_source.dart';
import 'package:mamo_cross/state/rescue_store.dart';
import 'package:mamo_cross/widgets/app_sidebar.dart';

/// `insertRequest` の応答挙動モード
enum FakeInsertBehavior {
  /// 連番 `id` を付与した挿入行 Map を返却（オンライン成功）
  onlineSuccess,

  /// `null` を返却（オフライン / Supabase 未設定フォールバック相当）
  offlineNull,

  /// `Exception` をスロー（通信失敗 / PostgREST エラー相当）
  throwError,
}

/// `updateStatus` の呼び出し記録
class FakeStatusUpdate {
  const FakeStatusUpdate({required this.dbId, required this.status});

  final String dbId;
  final RequestStatus status;
}

/// 不透明箱 E2E テスト用のフェイク `RescueDataSource`
class FakeRescueDataSource implements RescueDataSource {
  FakeRescueDataSource({
    List<Map<String, dynamic>> initialRows = const [],
    this.insertBehavior = FakeInsertBehavior.onlineSuccess,
    this.initialConnected = true,
    this.emitRealtimeOnInsert = false,
    this.throwOnFetch = false,
    this.throwOnUpdate = false,
    this.onInsert,
    int startingDbId = 1001,
  }) : _rows = initialRows.map((e) => Map<String, dynamic>.from(e)).toList(),
       _nextDbId = startingDbId;

  final List<Map<String, dynamic>> _rows;
  final StreamController<RescueRealtimeEvent> _controller =
      StreamController<RescueRealtimeEvent>.broadcast();

  int _nextDbId;
  bool initialConnected;
  FakeInsertBehavior insertBehavior;
  bool emitRealtimeOnInsert;
  bool throwOnFetch;
  bool throwOnUpdate;
  Future<Map<String, dynamic>?> Function(Map<String, dynamic> payload)?
  onInsert;

  void Function(bool connected)? _onConnectionChanged;

  /// 検証用記録リスト
  final List<Map<String, dynamic>> insertedPayloads = [];
  final List<Map<String, dynamic>> attemptedPayloads = [];
  final List<FakeStatusUpdate> updatedStatuses = [];
  int fetchCallCount = 0;
  int disposeCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchInitialRequests({
    int limit = 50,
  }) async {
    fetchCallCount++;
    if (throwOnFetch) {
      throw Exception('Fake fetchInitialRequests error');
    }
    return _rows.take(limit).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Stream<RescueRealtimeEvent> subscribeRequests({
    void Function(bool connected)? onConnectionChanged,
  }) {
    _onConnectionChanged = onConnectionChanged;
    if (!initialConnected) {
      onConnectionChanged?.call(false);
      return const Stream.empty();
    }
    onConnectionChanged?.call(true);
    return _controller.stream;
  }

  @override
  Future<Map<String, dynamic>?> insertRequest(
    Map<String, dynamic> payload,
  ) async {
    final copy = Map<String, dynamic>.from(payload);
    attemptedPayloads.add(copy);

    final customHandler = onInsert;
    if (customHandler != null) {
      final result = await customHandler(copy);
      if (result != null) {
        final stored = Map<String, dynamic>.from(result);
        insertedPayloads.add(copy);
        _rows.insert(0, stored);
        if (emitRealtimeOnInsert && !_controller.isClosed) {
          _controller.add(
            RescueInsertedEvent(Map<String, dynamic>.from(stored)),
          );
        }
        return Map<String, dynamic>.from(stored);
      }
      return null;
    }

    switch (insertBehavior) {
      case FakeInsertBehavior.offlineNull:
        return null;
      case FakeInsertBehavior.throwError:
        throw Exception('Fake insertRequest network error');
      case FakeInsertBehavior.onlineSuccess:
        final assignedId = _nextDbId++;
        final row = <String, dynamic>{
          ...copy,
          'id': assignedId,
          'created_at':
              copy['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
        };
        insertedPayloads.add(copy);
        _rows.insert(0, row);
        if (emitRealtimeOnInsert && !_controller.isClosed) {
          _controller.add(RescueInsertedEvent(Map<String, dynamic>.from(row)));
        }
        return Map<String, dynamic>.from(row);
    }
  }

  @override
  Future<void> updateStatus({
    required String dbId,
    required RequestStatus status,
  }) async {
    if (throwOnUpdate) {
      throw Exception('Fake updateStatus error');
    }
    updatedStatuses.add(FakeStatusUpdate(dbId: dbId, status: status));
    for (var i = 0; i < _rows.length; i++) {
      if (_rows[i]['id']?.toString() == dbId) {
        _rows[i]['status'] = status.label;
      }
    }
  }

  /// テストから任意の Realtime INSERT イベントを発火する
  void emitInsert(Map<String, dynamic> row) {
    if (!_controller.isClosed) {
      _controller.add(RescueInsertedEvent(Map<String, dynamic>.from(row)));
    }
  }

  /// テストから任意の Realtime UPDATE イベントを発火する
  void emitUpdate(Map<String, dynamic> row) {
    if (!_controller.isClosed) {
      _controller.add(RescueUpdatedEvent(Map<String, dynamic>.from(row)));
    }
  }

  /// 接続状態通知をテストから変更する
  void setConnection(bool connected) {
    _onConnectionChanged?.call(connected);
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

/// 標準ビューポートプリセット
const Size kDesktopViewportSize = Size(1280, 800);
const Size kMobileViewportSize = Size(390, 844);
const Size kNarrowViewportSize = Size(320, 568);

/// テスト用の論理ビューポートサイズを設定し、`addTearDown` で復元を保証する
void setBoundaryViewport(WidgetTester tester, double width, double height) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void setDesktopViewport(
  WidgetTester tester, {
  Size size = kDesktopViewportSize,
}) {
  setBoundaryViewport(tester, size.width, size.height);
}

void setMobileViewport(
  WidgetTester tester, {
  Size size = kMobileViewportSize,
}) {
  setBoundaryViewport(tester, size.width, size.height);
}

/// テスト途中で画面サイズを動的変更してレイアウト再計算を待つ
Future<void> resizeViewportAndSettle(
  WidgetTester tester,
  double width,
  double height,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  await tester.pumpAndSettle();
}

/// 複数 `Scrollable`（例: `AppSidebar` + 本文リスト）存在時に、内側を優先して可視化までスクロールする
Future<void> _scrollUntilVisibleAny(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
  double delta = 200,
}) async {
  if (tester.any(finder)) return;
  if (scrollable != null) {
    await tester.scrollUntilVisible(finder, delta, scrollable: scrollable);
    return;
  }
  final candidates = find.byType(Scrollable);
  final count = candidates.evaluate().length;
  StateError? lastError;
  for (var i = count - 1; i >= 0; i--) {
    try {
      await tester.scrollUntilVisible(
        finder,
        delta,
        scrollable: candidates.at(i),
      );
      if (tester.any(finder)) return;
    } on StateError catch (e) {
      lastError = e;
    }
  }
  if (!tester.any(finder) && lastError != null) {
    throw lastError;
  }
}

/// スクロールが必要な要素を可視化してから安全にタップする
Future<void> scrollAndTap(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
  double delta = 200,
  bool settle = true,
}) async {
  await _scrollUntilVisibleAny(
    tester,
    finder,
    scrollable: scrollable,
    delta: delta,
  );
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// テキスト入力フィールドへの安全入力
Future<void> scrollAndEnterText(
  WidgetTester tester,
  Finder finder,
  String text, {
  Finder? scrollable,
}) async {
  await _scrollUntilVisibleAny(tester, finder, scrollable: scrollable);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

/// hintText 部分一致で `TextField` を探してテキスト入力する
Future<void> enterFieldByHint(
  WidgetTester tester,
  String hintSubstring,
  String text,
) async {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.hintText?.contains(hintSubstring) ?? false),
  );
  expect(finder, findsAtLeastNWidgets(1));
  await scrollAndEnterText(tester, finder.first, text);
}

/// `RadioGroup<String>` の `Radio<String>` を優先タップし、無ければ選択肢テキストをタップする
Future<void> selectRadioOption(WidgetTester tester, String value) async {
  final radioFinder = find.byWidgetPredicate(
    (widget) => widget is Radio<String> && widget.value == value,
  );
  if (tester.any(radioFinder)) {
    await scrollAndTap(tester, radioFinder.first);
    return;
  }
  await scrollAndTap(tester, find.text(value).first);
}

/// `#reg2` の生年月日入力欄へ日付文字列を入力する（hint またはラベル位置で特定）
Future<void> enterBirthDate(WidgetTester tester, String birthDate) async {
  final hintField = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        ((widget.decoration?.hintText?.contains('YYYY') ?? false) ||
            (widget.decoration?.hintText?.contains('yyyy') ?? false) ||
            (widget.decoration?.hintText?.contains('生年月日') ?? false) ||
            (widget.decoration?.hintText?.contains('199') ?? false) ||
            (widget.decoration?.hintText?.contains('200') ?? false)),
  );
  if (tester.any(hintField)) {
    await scrollAndEnterText(tester, hintField.first, birthDate);
    return;
  }

  final birthLabel = find.text('生年月日（必須）');
  final bloodLabel = find.text('血液型（必須）');
  expect(birthLabel, findsOneWidget);
  expect(bloodLabel, findsOneWidget);
  await tester.ensureVisible(birthLabel);
  await tester.pump();
  final birthTop = tester.getTopLeft(birthLabel).dy;
  final bloodTop = tester.getTopLeft(bloodLabel).dy;

  Finder? matched;
  for (final element in find.byType(TextField).evaluate()) {
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final dy = box.localToGlobal(Offset.zero).dy;
    if (dy >= birthTop && dy < bloodTop) {
      matched = find.byWidget(element.widget);
      break;
    }
  }
  expect(matched, isNotNull);
  await scrollAndEnterText(tester, matched!, birthDate);
}

/// ドロップダウン選択肢の安全選択
Future<void> selectDropdownOption(
  WidgetTester tester,
  Finder trigger,
  String optionText,
) async {
  await scrollAndTap(tester, trigger);
  final option = find.text(optionText).last;
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

/// `demoLogin()` (450ms) 等の遷移遅延を完了させる
Future<void> pumpTransition(
  WidgetTester tester, {
  Duration duration = const Duration(milliseconds: 550),
}) async {
  await tester.pump(duration);
  await tester.pumpAndSettle();
}

/// 市民側トースト (1800ms) タイマーを確実に排出し、テスト終了時の未完了タイマーを防ぐ
Future<void> pumpPastToasts(
  WidgetTester tester, {
  Duration duration = const Duration(seconds: 2),
}) async {
  await tester.pump(duration);
  await tester.pumpAndSettle();
}

/// 自治体側 `SnackBar` (既定 4000ms) タイマーを確実に排出し、テスト終了時の未完了タイマーを防ぐ
Future<void> pumpPastSnackBars(
  WidgetTester tester, {
  Duration duration = const Duration(seconds: 5),
}) async {
  await tester.pump(duration);
  await tester.pumpAndSettle();
}

/// トースト文言をアサートした後にタイマーを排出するヘルパー
Future<void> expectToastAndDrain(WidgetTester tester, String message) async {
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.textContaining(message), findsAtLeastNWidgets(1));
  await pumpPastToasts(tester);
}

/// `MamoApp` マウント（デフォルトは Desktop 1280x800、clock 停止）
///
/// `navigateTo` に `citizen` または `municipality` を指定すると、
/// ポータル上のモード選択ボタンをタップして対象モードへ遷移した状態で開始する。
Future<void> pumpMamoApp(
  WidgetTester tester, {
  RescueStore? store,
  RescueDataSource? dataSource,
  bool autoConnect = false,
  Size viewport = kDesktopViewportSize,
  MamoAppMode? navigateTo,
}) async {
  setBoundaryViewport(tester, viewport.width, viewport.height);
  await tester.pumpWidget(
    MamoApp(
      store: store,
      dataSource: dataSource,
      startClock: false,
      autoConnect: autoConnect,
    ),
  );
  await tester.pumpAndSettle();

  if (navigateTo == MamoAppMode.citizen) {
    await openCitizenFromPortal(tester);
  } else if (navigateTo == MamoAppMode.municipality) {
    await openMunicipalityFromPortal(tester);
  }
}

bool _descendantHasConciseLabel(
  Widget root,
  String labelSubstring, {
  String? excludeSubstring,
  int maxLength = 25,
}) {
  final texts = find.descendant(
    of: find.byWidget(root),
    matching: find.byType(Text),
  );
  for (final element in texts.evaluate()) {
    final widget = element.widget as Text;
    final data = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    if (!data.contains(labelSubstring)) continue;
    if (data.contains('お知らせ') || data.contains('MAMO管理画面')) continue;
    if (excludeSubstring != null && data.contains(excludeSubstring)) continue;
    if (data.length <= maxLength) return true;
  }
  return false;
}

bool _tooltipMatches(Widget widget, String labelSubstring) {
  String? message;
  if (widget is IconButton) {
    message = widget.tooltip;
  } else if (widget is PopupMenuButton) {
    message = widget.tooltip;
  } else if (widget is Tooltip) {
    message = widget.message;
  }
  if (message == null || !message.contains(labelSubstring)) return false;
  if (message.contains('お知らせ') || message.contains('MAMO管理画面')) {
    return false;
  }
  return message.length <= 25;
}

bool _isButtonWidget(Widget widget) =>
    widget is ElevatedButton ||
    widget is FilledButton ||
    widget is OutlinedButton ||
    widget is TextButton ||
    widget is ActionChip ||
    widget is IconButton ||
    widget is PopupMenuButton;

/// モード切替用の対話的ウィジェットのみを検索する（静的 Text や「お知らせ」は絶対に対象外）
Finder findModeActionTrigger(String labelSubstring) {
  final buttonFinder = find.byWidgetPredicate(
    (widget) =>
        _isButtonWidget(widget) &&
        (_descendantHasConciseLabel(widget, labelSubstring) ||
            _tooltipMatches(widget, labelSubstring)),
  );
  if (buttonFinder.evaluate().any((_) => true)) {
    return buttonFinder.first;
  }

  final interactiveFinder = find.byWidgetPredicate(
    (widget) =>
        (widget is ListTile ||
            widget is InkWell ||
            widget is GestureDetector ||
            widget is Tooltip) &&
        (_descendantHasConciseLabel(widget, labelSubstring) ||
            _tooltipMatches(widget, labelSubstring)),
  );
  if (interactiveFinder.evaluate().any((_) => true)) {
    return interactiveFinder.first;
  }

  return buttonFinder;
}

/// フル幅プライマリボタン等を測定するためにインタラクティブボタンを検索する
Finder findPrimaryButtonWithText(String labelSubstring) {
  return find.byWidgetPredicate(
    (widget) =>
        (widget is ElevatedButton ||
            widget is FilledButton ||
            widget is OutlinedButton) &&
        _descendantHasConciseLabel(widget, labelSubstring, maxLength: 40),
  );
}

/// ラベル部分一致でインタラクティブ要素（ボタン/チップ/ListTile/InkWell/GestureDetector）を検索する
Finder findInteractiveWithText(
  String labelSubstring, {
  String? excludeSubstring,
}) {
  return find.byWidgetPredicate(
    (widget) =>
        (_isButtonWidget(widget) ||
            widget is ChoiceChip ||
            widget is FilterChip ||
            widget is ListTile ||
            widget is InkWell ||
            widget is GestureDetector) &&
        _descendantHasConciseLabel(
          widget,
          labelSubstring,
          excludeSubstring: excludeSubstring,
          maxLength: 32,
        ),
  );
}

/// `#home` / 安否タブの本人安否ボタン（「無事」「被害あり」「救助要請」）を家族バッジと区別して検索する
Finder findSafetyStatusButton(String labelSubstring) {
  return find.byWidgetPredicate((widget) {
    if (widget is! ElevatedButton &&
        widget is! FilledButton &&
        widget is! OutlinedButton &&
        widget is! TextButton &&
        widget is! ChoiceChip &&
        widget is! ActionChip &&
        widget is! InkWell &&
        widget is! GestureDetector) {
      return false;
    }
    final hasFamilyNames = find
        .descendant(
          of: find.byWidget(widget),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text &&
                ((w.data?.contains('お母さん') ?? false) ||
                    (w.data?.contains('お父さん') ?? false) ||
                    (w.data?.contains('お姉ちゃん') ?? false)),
          ),
        )
        .evaluate()
        .any((_) => true);
    if (hasFamilyNames) return false;
    return _descendantHasConciseLabel(widget, labelSubstring, maxLength: 16);
  });
}

/// メッセージタブの送信トリガ（送信ボタンまたは `Icons.send`）を検索する
Finder findSendMessageTrigger() {
  return find.byWidgetPredicate((widget) {
    if (widget is IconButton) {
      final icon = widget.icon;
      if (icon is Icon && icon.icon == Icons.send) return true;
      if (widget.tooltip?.contains('送信') ?? false) return true;
    }
    if (_isButtonWidget(widget) ||
        widget is InkWell ||
        widget is GestureDetector) {
      final hasSendText = _descendantHasConciseLabel(widget, '送信', maxLength: 16);
      if (hasSendText) return true;
      final hasSendIcon = find
          .descendant(
            of: find.byWidget(widget),
            matching: find.byIcon(Icons.send),
          )
          .evaluate()
          .any((_) => true);
      if (hasSendIcon) return true;
    }
    return false;
  });
}

/// ウィジェット数が最大 [max] 件以下であることを検証する
void expectAtMostNWidgets(Finder finder, int max) {
  expect(finder.evaluate().length, lessThanOrEqualTo(max));
}

/// ポータル → 利用者モードへ遷移
Future<void> openCitizenFromPortal(WidgetTester tester) async {
  final trigger = findModeActionTrigger('利用者');
  expect(trigger, findsAtLeastNWidgets(1));
  await scrollAndTap(tester, trigger);
}

/// ポータル → 自治体モードへ遷移
Future<void> openMunicipalityFromPortal(WidgetTester tester) async {
  final trigger = findModeActionTrigger('自治体');
  expect(trigger, findsAtLeastNWidgets(1));
  await scrollAndTap(tester, trigger);
}

/// 利用者画面ヘッダー等から自治体モードへ切替
Future<void> switchCitizenToMunicipality(WidgetTester tester) async {
  final trigger = findModeActionTrigger('自治体');
  expect(trigger, findsAtLeastNWidgets(1));
  await scrollAndTap(tester, trigger);
}

/// 利用者画面ヘッダー等からポータルへ切替
Future<void> switchCitizenToPortal(WidgetTester tester) async {
  final trigger = findModeActionTrigger('ポータル');
  expect(trigger, findsAtLeastNWidgets(1));
  await scrollAndTap(tester, trigger);
}

/// 自治体画面ヘッダー（またはドロワー）から利用者モードへ切替
Future<void> switchMunicipalityToCitizen(WidgetTester tester) async {
  final direct = findModeActionTrigger('利用者');
  if (tester.any(direct)) {
    await scrollAndTap(tester, direct);
    return;
  }
  final menuBtn = find.byTooltip('メニューを開く');
  expect(menuBtn, findsOneWidget);
  await tester.tap(menuBtn);
  await tester.pumpAndSettle();
  final drawerTrigger = findModeActionTrigger('利用者');
  expect(drawerTrigger, findsAtLeastNWidgets(1));
  await scrollAndTap(tester, drawerTrigger);
}

/// 自治体画面ヘッダー（またはドロワー）からポータルへ切替
Future<void> switchMunicipalityToPortal(WidgetTester tester) async {
  final direct = findModeActionTrigger('ポータル');
  if (tester.any(direct)) {
    await scrollAndTap(tester, direct);
    return;
  }
  final menuBtn = find.byTooltip('メニューを開く');
  expect(menuBtn, findsOneWidget);
  await tester.tap(menuBtn);
  await tester.pumpAndSettle();
  final drawerTrigger = findModeActionTrigger('ポータル');
  expect(drawerTrigger, findsAtLeastNWidgets(1));
  await scrollAndTap(tester, drawerTrigger);
}

/// ゲストログイン（`#login` → 450ms 後 `#home`）
Future<void> loginAsGuest(WidgetTester tester) async {
  await scrollAndTap(tester, find.text('ゲストモードではじめる'), settle: false);
  await pumpTransition(tester);
  await pumpPastToasts(tester);
}

/// 利用者側下部 5 タブ切替（重複文言を避けるため最下部の `.last` をタップ）
Future<void> tapCitizenBottomTab(
  WidgetTester tester,
  String tabLabel,
) async {
  final finder = find.text(tabLabel).last;
  await scrollAndTap(tester, finder);
}

/// 自治体側 `AppSidebar` 経由の画面切替（`<650px` の Drawer 分岐にも対応）
Future<void> navigateMunicipalityView(
  WidgetTester tester,
  String viewLabel,
) async {
  if (!tester.any(find.byType(AppSidebar))) {
    final menuBtn = find.byTooltip('メニューを開く');
    expect(menuBtn, findsOneWidget);
    await tester.tap(menuBtn);
    await tester.pumpAndSettle();
  }
  final sidebarItem = find.descendant(
    of: find.byType(AppSidebar),
    matching: find.text(viewLabel),
  );
  await scrollAndTap(tester, sidebarItem.first);
}

/// 自治体 `RequestsView` で指定の通報者行を選択（狭幅時は詳細ボトムシートを開く）
Future<void> selectMunicipalityRequest(
  WidgetTester tester,
  String requesterName,
) async {
  final item = find.textContaining(requesterName).first;
  await scrollAndTap(tester, item);
}

/// `RequestsView` のモバイル詳細シートが開いている場合に閉じる
Future<void> closeRequestDetailSheetIfOpen(WidgetTester tester) async {
  final closeBtn = find.byTooltip('閉じる');
  if (tester.any(closeBtn)) {
    await tester.tap(closeBtn.last);
    await tester.pumpAndSettle();
  }
}

/// `GsiMapView` のマップピンを Tooltip 文言で検索する
Finder findMapPinTooltip(String requesterName, {String? statusLabel}) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Tooltip) return false;
    final msg = widget.message ?? '';
    if (!msg.contains(requesterName)) return false;
    if (statusLabel != null && !msg.contains(statusLabel)) return false;
    return true;
  });
}

/// 15 カラム Supabase INSERT ペイロード検証ヘルパー
void expectValid15ColPayload(
  Map<String, dynamic> payload, {
  required String expectedName,
  required String expectedDetail,
  String? expectedConsiderations,
  List<String>? expectedConsiderationSubstrings,
  String expectedLocation = '〇〇地区付近',
  String expectedDistance = '約150m先（デモ）',
}) {
  assert(
    expectedConsiderations != null || expectedConsiderationSubstrings != null,
  );
  const requiredKeys = <String>{
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
  };
  for (final key in requiredKeys) {
    expect(payload.containsKey(key), isTrue, reason: 'Missing key: $key');
  }
  for (final forbidden in const ['age', 'gender', 'latPercent', 'topPercent']) {
    expect(
      payload.containsKey(forbidden),
      isFalse,
      reason: 'Forbidden key: $forbidden',
    );
  }
  expect(payload.keys.toSet(), equals(requiredKeys));
  expect(payload['request_id'].toString(), startsWith('MAMO-'));
  expect(DateTime.tryParse(payload['created_at'].toString()), isNotNull);
  expect(payload['requester_name'], expectedName);
  expect(payload['user_name'], expectedName);
  expect(payload['request_type'], '救助要請');
  expect(payload['rescue_details'], expectedDetail);
  expect(payload['detail'], expectedDetail);
  final actualConsiderations = payload['considerations'].toString();
  expect(payload['consideration'], actualConsiderations);
  expect(payload['health_condition'], actualConsiderations);
  if (expectedConsiderations != null) {
    expect(actualConsiderations, expectedConsiderations);
  }
  if (expectedConsiderationSubstrings != null) {
    for (final sub in expectedConsiderationSubstrings) {
      expect(actualConsiderations, contains(sub));
    }
  }
  expect(payload['location_text'], expectedLocation);
  expect(payload['location'], expectedLocation);
  expect(payload['distance_text'], expectedDistance);
  expect(payload['distance'], expectedDistance);
  expect(payload['status'], '未対応');
}
