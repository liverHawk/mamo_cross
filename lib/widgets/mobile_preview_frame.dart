import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/mamo_theme.dart';

/// 画面幅に応じてモバイル端末枠（>520px）またはフルスクリーン（<=520px）で表示するラッパー
class MobilePreviewFrame extends StatefulWidget {
  const MobilePreviewFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<MobilePreviewFrame> createState() => _MobilePreviewFrameState();
}

class _MobilePreviewFrameState extends State<MobilePreviewFrame> {
  static const double _frameBreakpointWidth = 520.0;
  static const double _deviceOuterWidth = 390.0;
  static const double _deviceBorderWidth = 6.0;
  static const double _statusBarHeight = 28.0;

  final GlobalKey _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewportSize = mediaQuery.size;
    final isFramed = viewportSize.width > _frameBreakpointWidth;
    final keyedChild = KeyedSubtree(key: _childKey, child: widget.child);

    if (!isFramed) {
      return keyedChild;
    }

    return ColoredBox(
      color: MamoColors.citizenFrameOuterBg,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : viewportSize.height;
            final verticalPadding = maxHeight >= 760 ? 20.0 : 8.0;
            final availableHeight = math.max(240.0, maxHeight - verticalPadding * 2);
            final frameHeight = math.min(820.0, availableHeight);
            final innerWidth = _deviceOuterWidth - _deviceBorderWidth * 2;
            final innerContentHeight = math.max(
              180.0,
              frameHeight - _deviceBorderWidth * 2 - _statusBarHeight,
            );

            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: verticalPadding,
                ),
                child: Container(
                  width: _deviceOuterWidth,
                  height: frameHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(42),
                    border: Border.all(
                      color: const Color(0xFF111111),
                      width: _deviceBorderWidth,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33071A3D),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Material(
                      color: MamoColors.citizenBg,
                      child: Column(
                        children: [
                          const _MockStatusBar(),
                          Expanded(
                            child: MediaQuery(
                              data: mediaQuery.copyWith(
                                size: Size(innerWidth, innerContentHeight),
                                padding: EdgeInsets.zero,
                                viewPadding: EdgeInsets.zero,
                              ),
                              child: keyedChild,
                            ),
                          ),
                        ],
                      ),
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

class _MockStatusBar extends StatelessWidget {
  const _MockStatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _MobilePreviewFrameState._statusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: TextStyle(
              color: MamoColors.citizenNavy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '● ● ▮',
            style: TextStyle(
              color: MamoColors.citizenNavy,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
