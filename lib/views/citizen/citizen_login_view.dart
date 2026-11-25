import 'package:material_ui/material_ui.dart';

import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../theme/mamo_theme.dart';
import 'citizen_onboarding_widgets.dart';

/// `#login` 利用者起動・ログイン画面（mamo-main/index.html 準拠）
class CitizenLoginView extends StatelessWidget {
  const CitizenLoginView({
    super.key,
    required this.store,
  });

  final CitizenStore store;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: kCitizenScreenBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 34,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/icon/mamo_app_icon.png',
                        width: 118,
                        height: 118,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MAMO',
                      style: TextStyle(
                        fontSize: 42,
                        letterSpacing: 3,
                        color: MamoColors.citizenBlue,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'マモ',
                      style: TextStyle(
                        fontSize: 15,
                        color: MamoColors.citizenBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 20, bottom: 28),
                      child: Text(
                        'いつでも、どこでも、\nつながる安心を。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.7,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                    CitizenPrimaryButton(
                      label: '新規登録',
                      onPressed: () => store.goToScreen(CitizenScreen.reg1),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => store.demoLogin(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: MamoColors.citizenBlue,
                          side: const BorderSide(
                            color: MamoColors.citizenBlue,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        child: const Text('ログイン'),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () => store.demoLogin(),
                      style: TextButton.styleFrom(
                        foregroundColor: MamoColors.citizenBlue,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('ゲストモードではじめる'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
