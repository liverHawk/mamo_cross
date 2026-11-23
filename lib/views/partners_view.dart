import 'package:material_ui/material_ui.dart';

import '../models/rescue_request.dart';
import '../state/rescue_store.dart';
import '../theme/mamo_theme.dart';

/// 関係機関連携画面（救急・消防・警察・自衛隊カード）
class PartnersView extends StatelessWidget {
  const PartnersView({super.key, required this.store});

  final RescueStore store;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 650;
    final columns = screenWidth >= 900 ? 4 : (screenWidth >= 360 ? 2 : 1);

    const agencies = AgencyType.values;
    final rows = <List<AgencyType>>[];
    for (var i = 0; i < agencies.length; i += columns) {
      final end = (i + columns < agencies.length) ? i + columns : agencies.length;
      rows.add(agencies.sublist(i, end));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 15 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '関係機関連携',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: MamoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '救急・消防・警察・自衛隊への情報共有を管理します。',
            style: TextStyle(
              fontSize: 14,
              color: MamoColors.pageSubtitle,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 18.0;
              final cardWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              final compactPadding = cardWidth < 180;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var r = 0; r < rows.length; r++) ...[
                    if (r > 0) const SizedBox(height: gap),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var c = 0; c < columns; c++) ...[
                            if (c > 0) const SizedBox(width: gap),
                            if (c < rows[r].length)
                              Expanded(
                                child: _PartnerCard(
                                  agency: rows[r][c],
                                  compactPadding: compactPadding,
                                  onTap: () => store.filterAgency(rows[r][c]),
                                ),
                              )
                            else
                              const Spacer(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.agency,
    required this.compactPadding,
    required this.onTap,
  });

  final AgencyType agency;
  final bool compactPadding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compactPadding
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 20)
          : const EdgeInsets.all(25),
      decoration: MamoTheme.panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            agency.icon,
            size: 38,
            color: agency.color,
          ),
          const SizedBox(height: 10),
          Text(
            agency.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: MamoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            agency.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: MamoColors.partnerText,
            ),
          ),
          const SizedBox(height: 16),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: agency.color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(
                '${agency.label}要請を見る',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
