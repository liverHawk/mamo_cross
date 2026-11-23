import 'package:material_ui/material_ui.dart';

import '../theme/mamo_theme.dart';
import '../widgets/stat_card.dart';

/// 統計・履歴画面（静的KPIカード3枚＋履歴データパネル）
class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 650;
    final isDesktop = screenWidth >= 900;

    const cards = [
      StatCard(title: '本日の要請', value: '5'),
      StatCard(title: '平均対応時間', value: '12分'),
      StatCard(title: '救助完了', value: '8'),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 15 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '統計・履歴',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: MamoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'MAMOの救助要請履歴を確認します。',
            style: TextStyle(
              fontSize: 14,
              color: MamoColors.pageSubtitle,
            ),
          ),
          const SizedBox(height: 22),
          if (isDesktop)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[2]),
                  const SizedBox(width: 16),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            )
          else ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 16),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: MamoTheme.panelDecoration,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '履歴データ',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: MamoColors.textPrimary,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'ここに今後、期間別・機関別の統計グラフを追加できます。',
                  style: TextStyle(
                    fontSize: 14,
                    color: MamoColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
