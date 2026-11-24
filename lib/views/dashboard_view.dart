import 'package:material_ui/material_ui.dart';

import '../models/rescue_request.dart';
import '../state/rescue_store.dart';
import '../theme/mamo_theme.dart';
import '../widgets/fake_map_view.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';

/// ダッシュボード画面（KPIカード4枚、最新救助要請5件、位置情報マップ）
class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.store});

  final RescueStore store;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 650;
    final isDesktop = screenWidth >= 900;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cards = [
          StatCard(
            title: '新規救助要請',
            value: '${store.newCount}',
            subtitle: '未対応',
          ),
          StatCard(
            title: '対応中',
            value: '${store.workingCount}',
            subtitle: '現在対応中',
          ),
          StatCard(
            title: '対応済み',
            value: '${store.doneCount}',
            subtitle: '本日',
          ),
          const StatCard(
            title: '登録者',
            value: '1,284',
            subtitle: 'MAMO登録者',
          ),
        ];

        final recentRequests = store.requests.take(5).toList();

        final recentPanel = Container(
          padding: const EdgeInsets.all(18),
          decoration: MamoTheme.panelDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      '最新の救助要請',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: MamoColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => store.setView(MamoView.requests),
                    style: TextButton.styleFrom(
                      foregroundColor: MamoColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('一覧を見る →'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (recentRequests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '受信した救助要請はありません。',
                    style: TextStyle(
                      fontSize: 14,
                      color: MamoColors.textSecondary,
                    ),
                  ),
                )
              else
                for (var i = 0; i < recentRequests.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      color: MamoColors.miniDivider,
                    ),
                  _MiniRequestTile(
                    request: recentRequests[i],
                    onTap: () => store.selectFromMap(recentRequests[i].id),
                  ),
                ],
            ],
          ),
        );

        final mapPanel = Container(
          padding: const EdgeInsets.all(18),
          decoration: MamoTheme.panelDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      '位置情報マップ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: MamoColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => store.setView(MamoView.map),
                    style: TextButton.styleFrom(
                      foregroundColor: MamoColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('詳細 →'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FakeMapView(
                requests: store.requests,
                height: 280,
                onPinTap: store.selectFromMap,
              ),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 15 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ダッシュボード',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: MamoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                '災害時のMAMO救助要請・安否情報を管理します。',
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
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(child: cards[i]),
                      ],
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
                      Expanded(child: cards[3]),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 12, child: recentPanel),
                    const SizedBox(width: 20),
                    Expanded(flex: 10, child: mapPanel),
                  ],
                )
              else ...[
                recentPanel,
                const SizedBox(height: 20),
                mapPanel,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MiniRequestTile extends StatelessWidget {
  const _MiniRequestTile({
    required this.request,
    required this.onTap,
  });

  final RescueRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  request.time,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: MamoColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.agency.label}要請',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: MamoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.location,
                      style: const TextStyle(
                        fontSize: 14,
                        color: MamoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${request.name}　${request.distance}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MamoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: request.status),
            ],
          ),
        ),
      ),
    );
  }
}
