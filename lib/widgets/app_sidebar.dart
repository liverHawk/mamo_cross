import 'package:material_ui/material_ui.dart';

import '../models/rescue_request.dart';
import '../state/rescue_store.dart';
import '../theme/mamo_theme.dart';

/// 画面左側のナビゲーションサイドバー（AppSidebar.vue 相当）
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.store,
    this.width = 218,
    this.onNavigate,
  });

  final RescueStore store;
  final double width;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: MamoColors.sidebarBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final view in MamoView.values)
                    _SidebarNavItem(
                      view: view,
                      isActive: store.currentView == view,
                      badgeCount:
                          view == MamoView.requests ? store.newCount : null,
                      onTap: () {
                        store.setView(view);
                        onNavigate?.call();
                      },
                    ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.only(top: 18),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final agency in AgencyType.values)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: _AgencyShortcutButton(
                              agency: agency,
                              onTap: () {
                                store.filterAgency(agency);
                                onNavigate?.call();
                              },
                            ),
                          ),
                      ],
                    ),
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

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.view,
    required this.isActive,
    required this.onTap,
    this.badgeCount,
  });

  final MamoView view;
  final bool isActive;
  final int? badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? MamoColors.navActiveBg : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          hoverColor: MamoColors.navActiveBg.withValues(alpha: 0.7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(view.icon, color: Colors.white, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    view.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeCount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MamoColors.badgeRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgencyShortcutButton extends StatelessWidget {
  const _AgencyShortcutButton({
    required this.agency,
    required this.onTap,
  });

  final AgencyType agency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: agency.color,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(agency.icon, color: Colors.white, size: 17),
              const SizedBox(width: 8),
              Text(
                agency.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
