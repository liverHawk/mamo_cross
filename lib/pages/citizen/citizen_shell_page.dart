import 'package:material_ui/material_ui.dart';

import '../../models/app_mode.dart';
import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../state/rescue_store.dart';
import '../../theme/mamo_theme.dart';
import '../../views/citizen/citizen_home_tab.dart';
import '../../views/citizen/citizen_login_view.dart';
import '../../views/citizen/citizen_map_tab.dart';
import '../../views/citizen/citizen_messages_tab.dart';
import '../../views/citizen/citizen_reg1_view.dart';
import '../../views/citizen/citizen_reg2_view.dart';
import '../../views/citizen/citizen_reg3_view.dart';
import '../../views/citizen/citizen_rescue_sent_view.dart';
import '../../views/citizen/citizen_rescue_view.dart';
import '../../views/citizen/citizen_safety_tab.dart';
import '../../views/citizen/citizen_settings_tab.dart';

/// 利用者（住民・スマホ）側の画面切替・下部5タブ・トースト・モード切替を担うシェル
class CitizenShellPage extends StatelessWidget {
  const CitizenShellPage({
    super.key,
    required this.citizenStore,
    required this.rescueStore,
    this.onSelectMode,
  });

  final CitizenStore citizenStore;
  final RescueStore rescueStore;
  final ValueChanged<MamoAppMode>? onSelectMode;

  Widget _buildActiveScreen() {
    return switch (citizenStore.currentScreen) {
      CitizenScreen.login => CitizenLoginView(store: citizenStore),
      CitizenScreen.reg1 => CitizenReg1View(store: citizenStore),
      CitizenScreen.reg2 => CitizenReg2View(store: citizenStore),
      CitizenScreen.reg3 => CitizenReg3View(store: citizenStore),
      CitizenScreen.home => _buildHomeTab(),
      CitizenScreen.rescue => CitizenRescueView(
          citizenStore: citizenStore,
          rescueStore: rescueStore,
        ),
      CitizenScreen.rescueSent => CitizenRescueSentView(store: citizenStore),
    };
  }

  Widget _buildHomeTab() {
    return switch (citizenStore.currentTab) {
      CitizenTab.home => CitizenHomeTab(store: citizenStore),
      CitizenTab.map => CitizenMapTab(store: citizenStore),
      CitizenTab.safety => CitizenSafetyTab(store: citizenStore),
      CitizenTab.messages => CitizenMessagesTab(store: citizenStore),
      CitizenTab.settings => CitizenSettingsTab(
          store: citizenStore,
          onSelectMode: onSelectMode,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final modeCallback = onSelectMode;
    return ListenableBuilder(
      listenable: citizenStore,
      builder: (context, _) {
        final isHome = citizenStore.currentScreen == CitizenScreen.home;
        final toast = citizenStore.toastMessage;

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  if (modeCallback != null)
                    _CitizenModeSwitchBar(onSelectMode: modeCallback),
                  Expanded(child: _buildActiveScreen()),
                  if (isHome)
                    _CitizenBottomNavBar(
                      activeTab: citizenStore.currentTab,
                      onSelectTab: citizenStore.selectTab,
                    ),
                ],
              ),
              if (toast != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: isHome ? 82 : 24,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: MamoColors.citizenNavy,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x33071A3D),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          toast,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CitizenModeSwitchBar extends StatelessWidget {
  const _CitizenModeSwitchBar({required this.onSelectMode});

  final ValueChanged<MamoAppMode> onSelectMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: MamoColors.citizenSoftBlueBg,
        border: Border(
          bottom: BorderSide(color: MamoColors.citizenLine),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              '利用者デモ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MamoColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () => onSelectMode(MamoAppMode.portal),
            style: OutlinedButton.styleFrom(
              foregroundColor: MamoColors.citizenBlue,
              backgroundColor: Colors.white,
              side: const BorderSide(color: MamoColors.citizenLine),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('ポータル'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () => onSelectMode(MamoAppMode.municipality),
            style: FilledButton.styleFrom(
              backgroundColor: MamoColors.citizenBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('自治体'),
          ),
        ],
      ),
    );
  }
}

class _CitizenBottomNavBar extends StatelessWidget {
  const _CitizenBottomNavBar({
    required this.activeTab,
    required this.onSelectTab,
  });

  final CitizenTab activeTab;
  final ValueChanged<CitizenTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: MamoColors.citizenLine),
        ),
      ),
      child: Row(
        children: CitizenTab.values.map((tab) {
          final isActive = tab == activeTab;
          final color =
              isActive ? MamoColors.citizenBlue : const Color(0xFF6D7787);
          return Expanded(
            child: InkWell(
              onTap: () => onSelectTab(tab),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      tab.symbol,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.1,
                        color: color,
                        fontWeight:
                            isActive ? FontWeight.w900 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight:
                              isActive ? FontWeight.w900 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
