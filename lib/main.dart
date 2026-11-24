import 'package:material_ui/material_ui.dart';

import 'models/app_mode.dart';
import 'pages/mamo_root_page.dart';
import 'services/rescue_data_source.dart';
import 'state/rescue_store.dart';
import 'theme/mamo_theme.dart';

void main() {
  runApp(const MamoApp());
}

/// MAMO デモ版アプリ（ポータル／利用者／自治体管理システム）ルートウィジェット
class MamoApp extends StatelessWidget {
  const MamoApp({
    super.key,
    this.store,
    this.dataSource,
    this.startClock = true,
    this.autoConnect = true,
    this.initialMode = MamoAppMode.portal,
  });

  final RescueStore? store;
  final RescueDataSource? dataSource;
  final bool startClock;
  final bool autoConnect;
  final MamoAppMode initialMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAMO 自治体管理システム',
      debugShowCheckedModeBanner: false,
      theme: MamoTheme.light(),
      home: MamoRootPage(
        store: store,
        dataSource: dataSource,
        startClock: startClock,
        autoConnect: autoConnect,
        initialMode: initialMode,
      ),
    );
  }
}
