import 'package:material_ui/material_ui.dart';

/// mamo/app/assets/css/main.css 準拠のカラー定数
abstract final class MamoColors {
  static const topBarBg = Color(0xFF063875);
  static const sidebarBg = Color(0xFF062B58);
  static const navActiveBg = Color(0xFF145A9D);
  static const scaffoldBg = Color(0xFFF4F6F9);
  static const textPrimary = Color(0xFF172033);
  static const textSecondary = Color(0xFF626C78);
  static const textMuted = Color(0xFF687383);
  static const textSubtle = Color(0xFF8A929D);
  static const panelBorder = Color(0xFFE0E4EA);
  static const dividerLight = Color(0xFFE7E9ED);
  static const controlBorder = Color(0xFFD7DDE5);
  static const primaryBlue = Color(0xFF1767C6);
  static const activeFilterBg = Color(0xFF07366E);
  static const selectedItemBg = Color(0xFFF7FAFF);
  static const infoBoxBg = Color(0xFFFAFBFC);
  static const tableHeaderBg = Color(0xFFF8FAFC);
  static const dangerRed = Color(0xFFE13D35);
  static const badgeRed = Color(0xFFE34545);
  static const pageSubtitle = Color(0xFF6C7480);
  static const liveBadgeBorder = Color(0xFFD8DDE5);
  static const miniDivider = Color(0xFFEDF0F3);
  static const itemBorder = Color(0xFFE8EBEF);
  static const detailHeaderBorder = Color(0xFFE6E9ED);
  static const toolbarText = Color(0xFF596574);
  static const partnerText = Color(0xFF6D7681);
}

/// MAMO アプリの共通テーマと装飾
abstract final class MamoTheme {
  static BoxDecoration get panelDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MamoColors.panelBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1A3152),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      );

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MamoColors.primaryBlue,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: MamoColors.scaffoldBg,
      textTheme: const TextTheme().apply(
        bodyColor: MamoColors.textPrimary,
        displayColor: MamoColors.textPrimary,
      ),
    );
  }
}
