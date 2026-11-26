import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/main.dart';
import 'package:mamo_cross/pages/mamo_shell_page.dart';
import 'package:mamo_cross/services/hq_auth_service.dart';
import 'package:mamo_cross/services/rescue_data_source.dart';
import 'package:material_ui/material_ui.dart';

import 'e2e/e2e_test_helpers.dart';

class _FakeHqAuth implements HqAuthService {
  _FakeHqAuth(this.dataSource);

  final RescueDataSource dataSource;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  Future<RescueDataSource> signIn(String passcode) async {
    signInCalls++;
    if (passcode != 'correct') {
      throw const HqAuthException('パスコードが正しくありません。');
    }
    return dataSource;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

void main() {
  testWidgets('HQ モードはパスコード認証後にのみ開き、誤りでは遷移しない', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final citizenDs = FakeRescueDataSource();
    final hqDs = FakeRescueDataSource();
    final auth = _FakeHqAuth(hqDs);

    await tester.pumpWidget(
      MamoApp(dataSource: citizenDs, startClock: false, hqAuth: auth),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('自治体モードを開く').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hq_passcode_field')), findsOneWidget);
    expect(find.byType(MamoShellPage), findsNothing);

    // 誤ったパスコード
    await tester.enterText(find.byKey(const Key('hq_passcode_field')), 'wrong');
    await tester.tap(find.byKey(const Key('hq_passcode_submit')));
    await tester.pumpAndSettle();
    expect(find.text('パスコードが正しくありません。'), findsOneWidget);
    expect(find.byType(MamoShellPage), findsNothing);

    // 正しいパスコード
    await tester.enterText(
      find.byKey(const Key('hq_passcode_field')),
      'correct',
    );
    await tester.tap(find.byKey(const Key('hq_passcode_submit')));
    await tester.pumpAndSettle();
    expect(find.byType(MamoShellPage), findsOneWidget);
    expect(auth.signInCalls, 2);
  });
}
