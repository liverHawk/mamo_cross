import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../state/rescue_store.dart';
import '../theme/mamo_theme.dart';
import '../widgets/gsi_map_view.dart';

/// 位置情報マップ画面（救助要請件数・現在時刻・全ピンマップ）
class MapView extends StatelessWidget {
  const MapView({super.key, required this.store});

  final RescueStore store;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 650;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final mapHeight = math.max(430.0, viewportHeight - 220.0);

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 15 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '位置情報マップ',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: MamoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    '救助要請の位置を確認できます。',
                    style: TextStyle(
                      fontSize: 14,
                      color: MamoColors.pageSubtitle,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: MamoTheme.panelDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: MamoColors.toolbarText,
                                    ),
                                    children: [
                                      const TextSpan(text: '救助要請 '),
                                      TextSpan(
                                        text: '${store.requests.length}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const TextSpan(text: '件'),
                                    ],
                                  ),
                                ),
                                Text(
                                  '更新：${store.currentTime}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: MamoColors.toolbarText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GsiMapView(
                          requests: store.requests,
                          height: mapHeight,
                          initialZoom: 9.0,
                          onPinTap: store.selectFromMap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
