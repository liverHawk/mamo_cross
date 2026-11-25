import 'package:material_ui/material_ui.dart';

import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../theme/mamo_theme.dart';

/// 利用者救助要請送信完了画面（#rescueSent）
class CitizenRescueSentView extends StatelessWidget {
  const CitizenRescueSentView({super.key, required this.store});

  final CitizenStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final summary = store.latestRescueSummary;
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.82, 1.0],
              colors: [Colors.white, Colors.white, MamoColors.citizenSkyEnd],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 64,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F7EF),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '✓',
                            style: TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              color: MamoColors.citizenSafeGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '救助要請を送信しました',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: MamoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '自治体のMAMO管理画面へ\n救助要請が届く想定です。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.8,
                          fontWeight: FontWeight.w600,
                          color: MamoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE3EAF3)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C17365D),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '受付内容',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: MamoColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _SummaryLine(
                              label: '受付番号',
                              value: summary?.requestId ?? '-',
                              bold: true,
                            ),
                            _SummaryLine(
                              label: '時刻',
                              value: summary?.time ?? '-',
                            ),
                            _SummaryLine(
                              label: '名前',
                              value: summary?.requesterName ?? '-',
                            ),
                            _SummaryLine(
                              label: '場所',
                              value: summary?.locationText ?? '-',
                            ),
                            _SummaryLine(
                              label: '内容',
                              value: summary?.detail ?? '-',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              MamoColors.citizenBlue,
                              Color(0xFF0876E8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33075BC7),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () =>
                              store.goToScreen(CitizenScreen.home),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'ホームへ戻る',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label：$value',
        softWrap: true,
        style: TextStyle(
          fontSize: 13,
          height: 1.6,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: MamoColors.textPrimary,
        ),
      ),
    );
  }
}
