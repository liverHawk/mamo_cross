import 'package:material_ui/material_ui.dart';

import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../theme/mamo_theme.dart';
import 'citizen_onboarding_widgets.dart';

/// `#reg1` 新規登録 1/3：本人確認画面
class CitizenReg1View extends StatelessWidget {
  const CitizenReg1View({
    super.key,
    required this.store,
  });

  final CitizenStore store;

  @override
  Widget build(BuildContext context) {
    final photoSelected = store.profile.photoSelected;
    final idDocSelected = store.profile.idDocSelected;

    return DecoratedBox(
      decoration: kCitizenScreenBackground,
      child: Column(
        children: <Widget>[
          CitizenTopBar(
            title: '① 本人確認',
            onBack: () => store.goToScreen(CitizenScreen.login),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      '本人確認',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(
                      'デモでは実際の本人確認・身分証送信は行いません。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5E6878),
                      ),
                    ),
                  ),
                  CitizenCard(
                    child: InkWell(
                      onTap: store.selectPhotoDemo,
                      borderRadius: BorderRadius.circular(14),
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: photoSelected
                              ? MamoColors.citizenBlue
                              : const Color(0xFFB9C8DA),
                          radius: 14,
                        ),
                        child: Container(
                          height: 190,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBFDFF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Container(
                                width: 82,
                                height: 82,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFE7EBF0),
                                ),
                                child: const Text(
                                  '👤',
                                  style: TextStyle(fontSize: 42),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '顔写真を登録',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                photoSelected ? 'タップして選択（選択済み）' : 'タップして選択',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7584),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  CitizenCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '公的身分証の登録',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '運転免許証・マイナンバーカード等を想定',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CitizenInfoBox(
                          text: idDocSelected
                              ? '🔒 デモでは画像を保存・送信しません。実サービスでは安全な本人確認方式を設計します。（選択済み）'
                              : '🔒 デモでは画像を保存・送信しません。実サービスでは安全な本人確認方式を設計します。',
                        ),
                        const SizedBox(height: 12),
                        CitizenPrimaryButton(
                          label: '身分証を選択',
                          onPressed: store.selectIdDocDemo,
                        ),
                      ],
                    ),
                  ),
                  const CitizenOnboardingStepper(activeStep: 1),
                  CitizenPrimaryButton(
                    label: '次へ',
                    onPressed: () => store.goToScreen(CitizenScreen.reg2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
