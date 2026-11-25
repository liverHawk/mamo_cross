import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'models/app_mode.dart';
import 'pages/mamo_root_page.dart';
import 'services/hq_auth_service.dart';
import 'services/rescue_data_source.dart';
import 'state/rescue_store.dart';
import 'theme/mamo_theme.dart';
import 'utils/app_logger.dart';

/// Supabase 初期化を安全に実行する（未設定・オフライン・タイムアウト時はデモ継続）
Future<void> initializeSupabaseSafely({
  SupabaseConfig config = SupabaseConfig.fromEnvironment,
  Duration timeout = const Duration(seconds: 5),
  Future<void> Function(SupabaseConfig config)? initializer,
}) async {
  if (!config.isConfigured) return;
  try {
    final run = initializer ??
        (c) => Supabase.initialize(
              url: c.url,
              publishableKey: c.publishableKey,
            );
    await run(config).timeout(timeout);
  } catch (e) {
    appLog('Supabase 初期化をスキップしてオフライン/デモ起動します: $e');
  }
}

const bool _allowHq = bool.fromEnvironment('ALLOW_HQ_MODE', defaultValue: true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSupabaseSafely();
  // HQ モードは認証必須（--dart-define=ALLOW_HQ_MODE=false で無効化）
  runApp(MamoApp(hqAuth: _allowHq
        ? SupabaseHqAuthService()
        : const DisabledHqAuthService()));
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
    this.hqAuth,
  });

  final RescueStore? store;
  final RescueDataSource? dataSource;
  final bool startClock;
  final bool autoConnect;
  final MamoAppMode initialMode;
  final HqAuthService? hqAuth;

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
        hqAuth: hqAuth,
      ),
    );
  }
}
