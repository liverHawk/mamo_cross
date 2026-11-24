import 'package:material_ui/material_ui.dart';

import '../models/app_mode.dart';
import '../services/rescue_data_source.dart';
import '../services/supabase_rescue_data_source.dart';
import '../state/citizen_store.dart';
import '../state/rescue_store.dart';
import '../widgets/mobile_preview_frame.dart';
import 'citizen/citizen_shell_page.dart';
import 'mamo_shell_page.dart';
import 'portal_page.dart';

/// ポータル・利用者アプリ・自治体管理画面を単一の共有ストアで切り替えるルートウィジェット
class MamoRootPage extends StatefulWidget {
  const MamoRootPage({
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
  State<MamoRootPage> createState() => _MamoRootPageState();
}

class _MamoRootPageState extends State<MamoRootPage> {
  late RescueStore _rescueStore;
  late bool _ownsRescueStore;
  late CitizenStore _citizenStore;
  late MamoAppMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _citizenStore = CitizenStore();
    _initRescueStore();
  }

  @override
  void didUpdateWidget(covariant MamoRootPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final storeChanged = widget.store != oldWidget.store;
    final configChanged = widget.store == null &&
        (widget.dataSource != oldWidget.dataSource ||
            widget.startClock != oldWidget.startClock ||
            widget.autoConnect != oldWidget.autoConnect);
    if (storeChanged || configChanged) {
      _disposeManagedRescueStore();
      _initRescueStore();
      _citizenStore.resetDemo();
      _mode = widget.initialMode;
    } else if (widget.initialMode != oldWidget.initialMode) {
      _mode = widget.initialMode;
    }
  }

  @override
  void dispose() {
    _disposeManagedRescueStore();
    _citizenStore.dispose();
    super.dispose();
  }

  void _initRescueStore() {
    final externalStore = widget.store;
    if (externalStore != null) {
      _rescueStore = externalStore;
      _ownsRescueStore = false;
      return;
    }

    final resolvedDataSource = widget.dataSource ??
        (widget.autoConnect ? SupabaseRescueDataSource() : null);
    _rescueStore = RescueStore(
      startClock: widget.startClock,
      dataSource: resolvedDataSource,
    );
    _ownsRescueStore = true;
  }

  void _disposeManagedRescueStore() {
    if (_ownsRescueStore) {
      _rescueStore.dispose();
    }
  }

  void _setMode(MamoAppMode mode) {
    if (!mounted || _mode == mode) return;
    setState(() {
      _mode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_mode) {
      MamoAppMode.portal => PortalPage(
          onSelectMode: _setMode,
          rescueStore: _rescueStore,
          citizenStore: _citizenStore,
        ),
      MamoAppMode.citizen => MobilePreviewFrame(
          child: CitizenShellPage(
            citizenStore: _citizenStore,
            rescueStore: _rescueStore,
            onSelectMode: _setMode,
          ),
        ),
      MamoAppMode.municipality => MamoShellPage(
          store: _rescueStore,
          onSelectMode: _setMode,
        ),
    };
  }
}
