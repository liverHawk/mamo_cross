import 'package:material_ui/material_ui.dart';

import '../models/app_mode.dart';
import '../state/citizen_store.dart';
import '../state/rescue_store.dart';
import '../theme/mamo_theme.dart';

/// 起動時のモード選択ポータル画面（利用者・自治体）
class PortalPage extends StatelessWidget {
  const PortalPage({
    super.key,
    required this.onSelectMode,
    this.rescueStore,
    this.citizenStore,
  });

  final ValueChanged<MamoAppMode> onSelectMode;
  final RescueStore? rescueStore;
  final CitizenStore? citizenStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MamoColors.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 680;
            final horizontalPadding = constraints.maxWidth < 400 ? 16.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 56
                      ? constraints.maxHeight - 56
                      : 0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PortalHeroHeader(rescueStore: rescueStore),
                        const SizedBox(height: 28),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _PortalModeCard(
                                  badgeText: '住民・スマホアプリ',
                                  title: '利用者（住民・スマホ）モード',
                                  description:
                                      '安否登録・避難所マップ確認・家族への連絡・緊急救助要請の送信を体験できます。',
                                  buttonLabel: '利用者モードを開く',
                                  icon: Icons.smartphone_rounded,
                                  accentColor: MamoColors.citizenBlue,
                                  onTap: () =>
                                      onSelectMode(MamoAppMode.citizen),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _PortalModeCard(
                                  badgeText: '自治体・対策本部',
                                  title: '自治体管理システムモード',
                                  description:
                                      '住民からの救助要請のリアルタイム受信・位置確認・関係機関連携・対応状況管理を行います。',
                                  buttonLabel: '自治体モードを開く',
                                  icon: Icons.account_balance_rounded,
                                  accentColor: MamoColors.topBarBg,
                                  onTap: () =>
                                      onSelectMode(MamoAppMode.municipality),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PortalModeCard(
                                badgeText: '住民・スマホアプリ',
                                title: '利用者（住民・スマホ）モード',
                                description:
                                    '安否登録・避難所マップ確認・家族への連絡・緊急救助要請の送信を体験できます。',
                                buttonLabel: '利用者モードを開く',
                                icon: Icons.smartphone_rounded,
                                accentColor: MamoColors.citizenBlue,
                                onTap: () => onSelectMode(MamoAppMode.citizen),
                              ),
                              const SizedBox(height: 16),
                              _PortalModeCard(
                                badgeText: '自治体・対策本部',
                                title: '自治体管理システムモード',
                                description:
                                    '住民からの救助要請のリアルタイム受信・位置確認・関係機関連携・対応状況管理を行います。',
                                buttonLabel: '自治体モードを開く',
                                icon: Icons.account_balance_rounded,
                                accentColor: MamoColors.topBarBg,
                                onTap: () =>
                                    onSelectMode(MamoAppMode.municipality),
                              ),
                            ],
                          ),
                        const SizedBox(height: 20),
                        const Text(
                          'デモ環境では両モード間で救助要請データが即時連携されます。画面上部のボタンからいつでもモードを切り替えられます。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: MamoColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PortalHeroHeader extends StatelessWidget {
  const _PortalHeroHeader({this.rescueStore});

  final RescueStore? rescueStore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F063875),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/icon/mamo_app_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: MamoColors.topBarBg,
                alignment: Alignment.center,
                child: const Text(
                  'M',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'MAMO',
          style: TextStyle(
            color: MamoColors.topBarBg,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '災害時 安否確認・救助要請連携システム',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MamoColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (rescueStore != null)
          ListenableBuilder(
            listenable: rescueStore!,
            builder: (context, _) {
              final pending = rescueStore!.newCount;
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MamoColors.panelBorder),
                  ),
                  child: Text(
                    '現在の受信要請：${rescueStore!.requests.length}件（未対応 $pending件）',
                    style: const TextStyle(
                      color: MamoColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _PortalModeCard extends StatelessWidget {
  const _PortalModeCard({
    required this.badgeText,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String badgeText;
  final String title;
  final String description;
  final String buttonLabel;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MamoColors.panelBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1A3152),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accentColor, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: const TextStyle(
                              color: MamoColors.textPrimary,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  description,
                  style: const TextStyle(
                    color: MamoColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
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
