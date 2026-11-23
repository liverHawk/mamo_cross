import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../state/rescue_store.dart';
import '../theme/mamo_theme.dart';
import '../widgets/status_badge.dart';

/// 対応状況画面（全救助要請の5列テーブル）
class StatusView extends StatelessWidget {
  const StatusView({super.key, required this.store});

  final RescueStore store;

  static const _cellTextStyle = TextStyle(
    fontSize: 14,
    color: MamoColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 650;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 15 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '対応状況',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: MamoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                '救助要請の対応状況を確認します。',
                style: TextStyle(
                  fontSize: 14,
                  color: MamoColors.pageSubtitle,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: MamoTheme.panelDecoration,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth = math.max(constraints.maxWidth, 560.0);
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Table(
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FlexColumnWidth(1.1),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(0.9),
                            3: FlexColumnWidth(2.2),
                            4: FlexColumnWidth(1.0),
                          },
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(
                                color: MamoColors.tableHeaderBg,
                                border: Border(
                                  bottom: BorderSide(
                                    color: MamoColors.itemBorder,
                                  ),
                                ),
                              ),
                              children: [
                                _HeaderCell('時刻'),
                                _HeaderCell('氏名'),
                                _HeaderCell('機関'),
                                _HeaderCell('位置'),
                                _HeaderCell('状況'),
                              ],
                            ),
                            for (final request in store.requests)
                              TableRow(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: MamoColors.itemBorder,
                                    ),
                                  ),
                                ),
                                children: [
                                  _DataCell(
                                    Text(request.time, style: _cellTextStyle),
                                  ),
                                  _DataCell(
                                    Text(request.name, style: _cellTextStyle),
                                  ),
                                  _DataCell(
                                    Text(
                                      request.agency.label,
                                      style: _cellTextStyle,
                                    ),
                                  ),
                                  _DataCell(
                                    Text(
                                      request.location,
                                      style: _cellTextStyle,
                                    ),
                                  ),
                                  _DataCell(
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: StatusBadge(status: request.status),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: MamoColors.toolbarText,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: child,
    );
  }
}
