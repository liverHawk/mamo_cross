import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/app_mode.dart';
import '../services/auth_service.dart';
import '../services/hq_auth_service.dart';
import '../services/rescue_data_source.dart';
import '../services/supabase_citizen_data_source.dart';
import '../services/supabase_rescue_data_source.dart';
import '../state/citizen_store.dart';
import '../state/rescue_store.dart';
import '../widgets/hq_passcode_dialog.dart';
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
    this.hqAuth,
  });

  final RescueStore? store;
  final RescueDataSource? dataSource;
  final bool startClock;
  final bool autoConnect;
  final MamoAppMode initialMode;

  /// 指定時は自治体（HQ）モードへの切替にオペレーター認証を要求し、
  /// 認証後のみ全件購読用の専用ストアを生成する。
  final HqAuthService? hqAuth;

  @override
  State<MamoRootPage> createState() => _MamoRootPageState();
}

class _MamoRootPageState extends State<MamoRootPage> {
  late RescueStore _rescueStore;
  late bool _ownsRescueStore;
  late CitizenStore _citizenStore;
  late MamoAppMode _mode;
  RescueStore? _hqStore;
  bool _hqBusy = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final connectCitizenRemote =
        widget.store == null && widget.dataSource == null && widget.autoConnect;
    final citizenDataSource =
        connectCitizenRemote ? SupabaseCitizenDataSource() : null;
    final authService = citizenDataSource != null
        ? SupabaseAuthService(
            clientResolver: () => citizenDataSource.sharedClient,
          )
        : null;
    _citizenStore = CitizenStore(
      dataSource: citizenDataSource,
      authService: authService,
    );
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
    _hqStore?.dispose();
    _hqStore = null;
    final hqAuth = widget.hqAuth;
    if (hqAuth != null) unawaited(hqAuth.signOut());
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
      // HQ ゲート有効時は市民/ポータル滞在中に全件購読しない
      autoInitialize: widget.hqAuth == null,
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
    if (mode == MamoAppMode.municipality &&
        widget.hqAuth != null &&
        _hqStore == null) {
      unawaited(_enterHq());
      return;
    }
    if (_mode == MamoAppMode.municipality) {
      _leaveHq();
    }
    setState(() {
      _mode = mode;
    });
  }

  Future<void> _enterHq() async {
    if (_hqBusy) return;
    _hqBusy = true;
    try {
      final ds = await showHqPasscodeDialog(context, widget.hqAuth!);
      if (!mounted || ds == null) return;
      setState(() {
        _hqStore = RescueStore(startClock: widget.startClock, dataSource: ds);
        _mode = MamoAppMode.municipality;
      });
    } finally {
      _hqBusy = false;
    }
  }

  void _leaveHq() {
    final store = _hqStore;
    _hqStore = null;
    if (store != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => store.dispose());
    }
    final hqAuth = widget.hqAuth;
    if (hqAuth != null) unawaited(hqAuth.signOut());
  }

  @override
  Widget build(BuildContext context) {
    return switch (_mode) {
      MamoAppMode.portal => PortalPage(
          onSelectMode: _setMode,
          rescueStore: widget.hqAuth == null ? _rescueStore : null,
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
          store: _hqStore ?? _rescueStore,
          onSelectMode: _setMode,
        ),
    };
  }
}
