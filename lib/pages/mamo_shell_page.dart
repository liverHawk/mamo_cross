import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/rescue_request.dart';
import '../services/rescue_data_source.dart';
import '../services/supabase_rescue_data_source.dart';
import '../state/rescue_store.dart';
import '../views/dashboard_view.dart';
import '../views/history_view.dart';
import '../views/map_view.dart';
import '../views/partners_view.dart';
import '../views/requests_view.dart';
import '../views/settings_view.dart';
import '../views/status_view.dart';
import '../widgets/app_header.dart';
import '../widgets/app_sidebar.dart';

/// MAMO アプリのレスポンシブシェル（ヘッダー＋サイドバー/ドロワー＋7ビュー切替）
class MamoShellPage extends StatefulWidget {
  const MamoShellPage({
    super.key,
    this.store,
    this.dataSource,
    this.startClock = true,
    this.autoConnect = true,
  });

  final RescueStore? store;
  final RescueDataSource? dataSource;
  final bool startClock;
  final bool autoConnect;

  @override
  State<MamoShellPage> createState() => _MamoShellPageState();
}

class _MamoShellPageState extends State<MamoShellPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late RescueStore _store;
  late bool _ownsStore;
  StreamSubscription<RescueRequest>? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _initStore();
  }

  @override
  void didUpdateWidget(covariant MamoShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final storeChanged = widget.store != oldWidget.store;
    final configChanged = widget.store == null &&
        (widget.dataSource != oldWidget.dataSource ||
            widget.startClock != oldWidget.startClock ||
            widget.autoConnect != oldWidget.autoConnect);
    if (storeChanged || configChanged) {
      _disposeManagedStore();
      _initStore();
    }
  }

  @override
  void dispose() {
    _disposeManagedStore();
    super.dispose();
  }

  void _initStore() {
    final externalStore = widget.store;
    if (externalStore != null) {
      _store = externalStore;
      _ownsStore = false;
    } else {
      final resolvedDataSource = widget.dataSource ??
          (widget.autoConnect ? SupabaseRescueDataSource() : null);
      _store = RescueStore(
        startClock: widget.startClock,
        dataSource: resolvedDataSource,
      );
      _ownsStore = true;
    }

    _alertSubscription = _store.incomingAlerts.listen(_onIncomingAlert);
  }

  void _disposeManagedStore() {
    unawaited(_alertSubscription?.cancel());
    _alertSubscription = null;
    if (_ownsStore) {
      _store.dispose();
    }
  }

  void _onIncomingAlert(RescueRequest request) {
    if (!mounted || !_store.realtimeNotification) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final distanceSuffix =
        request.distance.isNotEmpty ? '　${request.distance}' : '';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '🚨 新しい救助要請が届きました：${request.name}$distanceSuffix',
          ),
        ),
      );
  }

  Widget _buildActiveView(RescueStore store) {
    return switch (store.currentView) {
      MamoView.dashboard => DashboardView(store: store),
      MamoView.requests => RequestsView(store: store),
      MamoView.map => MapView(store: store),
      MamoView.partners => PartnersView(store: store),
      MamoView.status => StatusView(store: store),
      MamoView.history => const HistoryView(),
      MamoView.settings => SettingsView(store: store),
    };
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 650;
    final sidebarWidth = width >= 900 ? 218.0 : 180.0;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile
          ? Drawer(
              width: 218,
              child: SafeArea(
                child: ListenableBuilder(
                  listenable: _store,
                  builder: (context, _) {
                    return AppSidebar(
                      store: _store,
                      width: 218,
                      onNavigate: () => Navigator.of(context).pop(),
                    );
                  },
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            return Column(
              children: [
                AppHeader(
                  store: _store,
                  isMobile: isMobile,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isMobile)
                        AppSidebar(
                          store: _store,
                          width: sidebarWidth,
                        ),
                      Expanded(
                        child: _buildActiveView(_store),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
