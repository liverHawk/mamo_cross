import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../models/rescue_request.dart';
import '../theme/mamo_theme.dart';

/// 1x1 透過 PNG（オフライン・テスト環境でのタイル読込失敗時フォールバック用）
const List<int> _transparentImageBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

/// 国土地理院 淡色地図タイル（ラスタ版）を用いた位置情報マップ
class GsiMapView extends StatefulWidget {
  const GsiMapView({
    super.key,
    required this.requests,
    required this.onPinTap,
    this.height,
    this.initialZoom = 8.5,
    this.tileProvider,
  });

  /// 国土地理院 淡色地図タイル URL テンプレート
  static const String gsiPaleTileUrl =
      'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png';

  /// 初期中心座標（山口県中心付近）
  static const LatLng defaultCenter = LatLng(34.18, 131.58);
  static const double minZoom = 5.0;
  static const double maxZoom = 18.0;

  final List<RescueRequest> requests;
  final ValueChanged<String> onPinTap;
  final double? height;
  final double initialZoom;
  final TileProvider? tileProvider;

  @override
  State<GsiMapView> createState() => _GsiMapViewState();
}

class _GsiMapViewState extends State<GsiMapView> {
  static final ImageProvider _transparentErrorImage = MemoryImage(
    Uint8List.fromList(_transparentImageBytes),
  );

  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final nextZoom =
        (camera.zoom + delta).clamp(GsiMapView.minZoom, GsiMapView.maxZoom);
    _mapController.move(camera.center, nextZoom);
  }

  void _fitAllRequests() {
    if (widget.requests.isEmpty) {
      _mapController.move(GsiMapView.defaultCenter, widget.initialZoom);
      return;
    }
    if (widget.requests.length == 1) {
      final r = widget.requests.first;
      _mapController.move(LatLng(r.latitude, r.longitude), 14.0);
      return;
    }
    final points = [
      for (final r in widget.requests) LatLng(r.latitude, r.longitude),
    ];
    final bounds = LatLngBounds.fromPoints(points);
    if (bounds.southWest == bounds.northEast) {
      _mapController.move(bounds.center, 14.0);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(36),
        maxZoom: 14.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: GsiMapView.defaultCenter,
                  initialZoom: widget.initialZoom,
                  minZoom: GsiMapView.minZoom,
                  maxZoom: GsiMapView.maxZoom,
                  backgroundColor: const Color(0xFFE9EDF0),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: GsiMapView.gsiPaleTileUrl,
                    userAgentPackageName: 'jp.mamo.mamo_cross',
                    minNativeZoom: 5,
                    maxNativeZoom: 18,
                    tileDisplay: const TileDisplay.instantaneous(),
                    tileProvider: widget.tileProvider,
                    errorImage: _transparentErrorImage,
                    errorTileCallback: (_, _, _) {},
                  ),
                  MarkerLayer(
                    markers: [
                      for (final r in widget.requests)
                        Marker(
                          point: LatLng(r.latitude, r.longitude),
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: _MapPin(
                            request: r,
                            onTap: () => widget.onPinTap(r.id),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _MapControls(
                onZoomIn: () => _zoomBy(1),
                onZoomOut: () => _zoomBy(-1),
                onFitAll: _fitAllRequests,
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xDCFFFFFF),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: MamoColors.controlBorder),
                  ),
                  child: const Text(
                    '出典：国土地理院（地理院タイル・淡色地図）',
                    style: TextStyle(
                      fontSize: 10,
                      color: MamoColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitAll,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitAll;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF2FFFFFF),
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MamoColors.controlBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ControlButton(
              icon: Icons.add,
              tooltip: '拡大',
              onTap: onZoomIn,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            Container(
              height: 1,
              width: 24,
              color: MamoColors.dividerLight,
            ),
            _ControlButton(
              icon: Icons.remove,
              tooltip: '縮小',
              onTap: onZoomOut,
              borderRadius: BorderRadius.zero,
            ),
            Container(
              height: 1,
              width: 24,
              color: MamoColors.dividerLight,
            ),
            _ControlButton(
              icon: Icons.fit_screen_outlined,
              tooltip: '全体を表示',
              onTap: onFitAll,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.borderRadius,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 18,
            color: MamoColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.request,
    required this.onTap,
  });

  final RescueRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${request.name}：${request.status.label}\n${request.location}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Center(
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: request.pinColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x45000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
