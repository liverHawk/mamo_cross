import 'package:material_ui/material_ui.dart';

import '../models/rescue_request.dart';
import '../state/rescue_store.dart';
import '../theme/mamo_theme.dart';
import '../widgets/status_badge.dart';

/// 救助要請一覧画面（フィルタ・650px以上で2ペイン・650px未満でボトムシート詳細）
class RequestsView extends StatelessWidget {
  const RequestsView({super.key, required this.store});

  final RescueStore store;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 650;
    final isTwoPane = screenWidth >= 650;
    final padding = EdgeInsets.all(isMobile ? 15 : 28);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, outerConstraints) {
            final headerWidgets = <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    '救助要請一覧',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: MamoColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: MamoColors.liveBadgeBorder),
                    ),
                    child: const Text(
                      'リアルタイム',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MamoColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Text(
                '受信した救助要請を確認・対応します。',
                style: TextStyle(
                  fontSize: 14,
                  color: MamoColors.pageSubtitle,
                ),
              ),
              const SizedBox(height: 22),
              _RequestsToolbar(store: store),
            ];

            if (outerConstraints.hasBoundedHeight &&
                outerConstraints.maxHeight >= 380) {
              return Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...headerWidgets,
                    const SizedBox(height: 14),
                    Expanded(
                      child: isTwoPane
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 44,
                                  child: _RequestListPanel(
                                    store: store,
                                    scrollable: true,
                                    onItemTap: (r) =>
                                        _handleItemTap(context, r, isTwoPane),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 56,
                                  child: _RequestDetailPanel(
                                    store: store,
                                    scrollable: true,
                                  ),
                                ),
                              ],
                            )
                          : _RequestListPanel(
                              store: store,
                              scrollable: true,
                              onItemTap: (r) =>
                                  _handleItemTap(context, r, isTwoPane),
                            ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...headerWidgets,
                  const SizedBox(height: 14),
                  if (isTwoPane)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 44,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 700),
                            child: _RequestListPanel(
                              store: store,
                              scrollable: true,
                              onItemTap: (r) =>
                                  _handleItemTap(context, r, isTwoPane),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 56,
                          child: _RequestDetailPanel(
                            store: store,
                            scrollable: false,
                          ),
                        ),
                      ],
                    )
                  else
                    _RequestListPanel(
                      store: store,
                      scrollable: false,
                      onItemTap: (r) => _handleItemTap(context, r, isTwoPane),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleItemTap(
    BuildContext context,
    RescueRequest request,
    bool isTwoPane,
  ) {
    store.selectRequest(request.id);
    if (isTwoPane) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MobileRequestDetailSheet(store: store),
    );
  }
}

class _MobileRequestDetailSheet extends StatefulWidget {
  const _MobileRequestDetailSheet({required this.store});

  final RescueStore store;

  @override
  State<_MobileRequestDetailSheet> createState() =>
      _MobileRequestDetailSheetState();
}

class _MobileRequestDetailSheetState extends State<_MobileRequestDetailSheet> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool _snackBarVisible = false;
  int _snackBarSeq = 0;

  void _showSnackBar(String message) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    final seq = ++_snackBarSeq;
    if (!_snackBarVisible) {
      setState(() {
        _snackBarVisible = true;
      });
    }
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
    controller.closed.then((_) {
      if (!mounted || seq != _snackBarSeq) return;
      setState(() {
        _snackBarVisible = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: ScaffoldMessenger(
          key: _messengerKey,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              top: false,
              child: ListenableBuilder(
                listenable: widget.store,
                builder: (innerContext, _) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                        child: Row(
                          children: [
                            const SizedBox(width: 40),
                            Expanded(
                              child: Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: MamoColors.controlBorder,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: '閉じる',
                              onPressed: () =>
                                  Navigator.of(innerContext).pop(),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
                          child: _RequestDetailContent(
                            store: widget.store,
                            onShowSnackBar: _showSnackBar,
                          ),
                        ),
                      ),
                      SizedBox(height: _snackBarVisible ? 80 : 0),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestsToolbar extends StatelessWidget {
  const _RequestsToolbar({required this.store});

  final RescueStore store;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'すべて',
                count: store.requests.length,
                active: store.statusFilter == null,
                onTap: () => store.setStatusFilter(null),
              ),
              _FilterButton(
                label: '未対応',
                count: store.newCount,
                active: store.statusFilter == RequestStatus.pending,
                onTap: () => store.setStatusFilter(RequestStatus.pending),
              ),
              _FilterButton(
                label: '対応中',
                count: store.workingCount,
                active: store.statusFilter == RequestStatus.working,
                onTap: () => store.setStatusFilter(RequestStatus.working),
              ),
              _FilterButton(
                label: '対応済み',
                count: store.doneCount,
                active: store.statusFilter == RequestStatus.done,
                onTap: () => store.setStatusFilter(RequestStatus.done),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: MamoColors.controlBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AgencyType?>(
                value: store.currentAgencyFilter,
                isDense: true,
                style: const TextStyle(
                  fontSize: 14,
                  color: MamoColors.textPrimary,
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
                items: [
                  const DropdownMenuItem<AgencyType?>(
                    value: null,
                    child: Text('すべての機関'),
                  ),
                  for (final agency in AgencyType.values)
                    DropdownMenuItem<AgencyType?>(
                      value: agency,
                      child: Text(agency.label),
                    ),
                ],
                onChanged: store.setAgencyFilter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? MamoColors.activeFilterBg : Colors.white,
        foregroundColor: active ? Colors.white : MamoColors.textPrimary,
        side: BorderSide(
          color: active ? MamoColors.activeFilterBg : MamoColors.controlBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 14),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: '$count',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestListPanel extends StatelessWidget {
  const _RequestListPanel({
    required this.store,
    required this.scrollable,
    required this.onItemTap,
  });

  final RescueStore store;
  final bool scrollable;
  final ValueChanged<RescueRequest> onItemTap;

  @override
  Widget build(BuildContext context) {
    final filtered = store.filteredRequests;

    Widget content;
    if (filtered.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '該当する救助要請はありません。',
          style: TextStyle(
            fontSize: 14,
            color: MamoColors.textSecondary,
          ),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in filtered)
            _RequestListItem(
              request: r,
              selected: store.selectedId == r.id,
              onTap: () => onItemTap(r),
            ),
        ],
      );
    }

    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: MamoTheme.panelDecoration,
      child: content,
    );
  }
}

class _RequestListItem extends StatelessWidget {
  const _RequestListItem({
    required this.request,
    required this.selected,
    required this.onTap,
  });

  final RescueRequest request;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: selected ? BorderRadius.circular(8) : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: selected
              ? BoxDecoration(
                  color: MamoColors.selectedItemBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MamoColors.primaryBlue),
                )
              : const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: MamoColors.itemBorder),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: MamoColors.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: request.time,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '　${request.agency.label}要請'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  StatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                request.location,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: MamoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: MamoColors.dangerRed,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${request.distance}　｜　${request.name}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: MamoColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestDetailPanel extends StatelessWidget {
  const _RequestDetailPanel({
    required this.store,
    required this.scrollable,
  });

  final RescueStore store;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final child = _RequestDetailContent(store: store);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: MamoTheme.panelDecoration,
      child: scrollable
          ? SingleChildScrollView(child: child)
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 560),
              child: child,
            ),
    );
  }
}

class _RequestDetailContent extends StatelessWidget {
  const _RequestDetailContent({
    required this.store,
    this.onShowSnackBar,
  });

  final RescueStore store;
  final ValueChanged<String>? onShowSnackBar;

  @override
  Widget build(BuildContext context) {
    final req = store.selectedRequest;
    if (req == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 15),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: MamoColors.detailHeaderBorder),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.start,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: req.agency.color,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${req.agency.label}要請',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: MamoColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    StatusBadge(status: req.status),
                  ],
                ),
                Text(
                  '受信時刻　${req.time}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: MamoColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        _DetailSection(
          title: 'いつ（受信時刻）',
          child: Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 16,
                color: MamoColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '2024/06/05 ${req.time}',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: MamoColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        _DetailSection(
          title: 'どこから来た情報か / 届いた情報は何m先・何km先か',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: MamoColors.dangerRed,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      req.location,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: MamoColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: MamoColors.textPrimary,
                  ),
                  children: [
                    TextSpan(
                      text: req.distance,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '（直線距離）'),
                  ],
                ),
              ),
            ],
          ),
        ),
        _DetailSection(
          title: 'だれから（通報者情報）',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: MamoColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: MamoColors.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: req.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: '（MAMOアプリユーザー）'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ID：${req.id}',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: MamoColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        _DetailSection(
          title: 'どういった内容か',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: MamoColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  req.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: MamoColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        _DetailSection(
          title: '関連情報',
          child: LayoutBuilder(
            builder: (context, constraints) {
              const box1 = _InfoBox(
                icon: Icons.smartphone,
                iconColor: MamoColors.textSecondary,
                title: 'MAMOアプリからの救助要請',
                subtitle: 'アプリバージョン：2.3.1',
              );
              final box2 = _InfoBox(
                icon: Icons.location_on_outlined,
                iconColor: MamoColors.dangerRed,
                title: 'GPS位置情報',
                subtitle: req.location,
              );

              if (constraints.maxWidth >= 320) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(child: box1),
                      const SizedBox(width: 12),
                      Expanded(child: box2),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  box1,
                  const SizedBox(height: 12),
                  box2,
                ],
              );
            },
          ),
        ),
        _DetailSection(
          title: '救助時の配慮事項',
          child: Text(
            req.consideration,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: MamoColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final startButton = ElevatedButton(
              onPressed: () {
                store.changeStatus(req.id, RequestStatus.working);
                _showSnackBar(context, '「対応中」に変更しました（デモ）');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MamoColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('対応開始', textAlign: TextAlign.center),
            );

            final shareButton = OutlinedButton(
              onPressed: () {
                _showSnackBar(context, '関係機関へ共有しました（デモ）');
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MamoColors.primaryBlue,
                side: const BorderSide(color: MamoColors.primaryBlue),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('関係機関に共有', textAlign: TextAlign.center),
            );

            final doneButton = OutlinedButton.icon(
              onPressed: () {
                store.changeStatus(req.id, RequestStatus.done);
                _showSnackBar(context, '「対応済み」に変更しました（デモ）');
              },
              icon: const Icon(Icons.notifications_none, size: 18),
              label: const Text('対応完了', textAlign: TextAlign.center),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MamoColors.dangerRed,
                side: const BorderSide(color: MamoColors.dangerRed),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );

            if (constraints.maxWidth >= 420) {
              return Row(
                children: [
                  Expanded(child: startButton),
                  const SizedBox(width: 10),
                  Expanded(child: shareButton),
                  const SizedBox(width: 10),
                  Expanded(child: doneButton),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                startButton,
                const SizedBox(height: 10),
                shareButton,
                const SizedBox(height: 10),
                doneButton,
              ],
            );
          },
        ),
      ],
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    if (onShowSnackBar != null) {
      onShowSnackBar!(message);
      return;
    }
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: MamoColors.dividerLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: MamoColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MamoColors.infoBoxBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: MamoColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: MamoColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: MamoColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
