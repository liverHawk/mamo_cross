import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../theme/mamo_theme.dart';

/// 利用者マップタブ（防災・避難所・危険箇所デモマップ）
class CitizenMapTab extends StatelessWidget {
  const CitizenMapTab({super.key, required this.store});

  final CitizenStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final activeShelter = store.selectedShelter ?? store.nearestShelter;
        return ColoredBox(
          color: MamoColors.citizenHomeBg,
          child: Column(
            children: [
              _SimpleTabTopBar(title: 'マップ', trailingText: '避難マップ'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CitizenInteractiveMap(
                        shelters: store.shelters,
                        selectedShelter: activeShelter,
                        hazardSpots: store.hazardSpots,
                        showHazards: store.showHazardsOnMap,
                        onSelectShelter: store.selectShelter,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const _LegendBadge(
                            color: MamoColors.citizenBlue,
                            label: '現在地',
                          ),
                          const _LegendBadge(
                            color: MamoColors.citizenSafeGreen,
                            label: '避難所',
                          ),
                          FilterChip(
                            label: const Text(
                              '危険箇所を表示',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selected: store.showHazardsOnMap,
                            selectedColor: const Color(0xFFFEE2E2),
                            checkmarkColor: MamoColors.citizenHelpRed,
                            onSelected: (_) => store.toggleHazardsOnMap(),
                          ),
                        ],
                      ),
                      if (store.showHazardsOnMap) ...[
                        const SizedBox(height: 10),
                        _HazardSummaryCard(hazards: store.hazardSpots),
                      ],
                      const SizedBox(height: 12),
                      _ShelterDetailCard(shelter: activeShelter),
                      const SizedBox(height: 14),
                      const Text(
                        '周辺の避難所一覧',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: MamoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final shelter in store.shelters) ...[
                        _ShelterListCard(
                          shelter: shelter,
                          isSelected: activeShelter.id == shelter.id,
                          onTap: () => store.selectShelter(shelter),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SimpleTabTopBar extends StatelessWidget {
  const _SimpleTabTopBar({
    required this.title,
    this.trailingText = 'MAMO',
  });

  final String title;
  final String trailingText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDF1F6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: MamoColors.textPrimary,
              ),
            ),
          ),
          Text(
            trailingText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: MamoColors.citizenBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _CitizenInteractiveMap extends StatelessWidget {
  const _CitizenInteractiveMap({
    required this.shelters,
    required this.selectedShelter,
    required this.hazardSpots,
    required this.showHazards,
    required this.onSelectShelter,
  });

  final List<CitizenShelter> shelters;
  final CitizenShelter selectedShelter;
  final List<CitizenHazardSpot> hazardSpots;
  final bool showHazards;
  final ValueChanged<CitizenShelter> onSelectShelter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE7EEF5),
            border: Border.all(color: MamoColors.citizenLine),
            borderRadius: BorderRadius.circular(14),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _CitizenMapPainter()),
                  ),
                  // 現在地マーカー
                  Positioned(
                    left: (width * 0.48 - 32).clamp(8.0, math.max(8.0, width - 78)),
                    top: (height * 0.46 - 16).clamp(8.0, math.max(8.0, height - 38)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MamoColors.citizenBlue,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33071A3D),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        '📍 現在地',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  // 危険箇所マーカー
                  if (showHazards)
                    for (final hazard in hazardSpots)
                      Positioned(
                        left: (width * hazard.xPercent - 16).clamp(
                          6.0,
                          math.max(6.0, width - 38),
                        ),
                        top: (height * hazard.yPercent - 16).clamp(
                          6.0,
                          math.max(6.0, height - 38),
                        ),
                        child: Tooltip(
                          message: '${hazard.title}：${hazard.description}',
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: MamoColors.citizenHelpRed,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '⚠',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  // 避難所マーカー
                  for (final shelter in shelters)
                    Positioned(
                      left: (width * shelter.xPercent - 20).clamp(
                        6.0,
                        math.max(6.0, width - 48),
                      ),
                      top: (height * shelter.yPercent - 18).clamp(
                        6.0,
                        math.max(6.0, height - 42),
                      ),
                      child: GestureDetector(
                        onTap: () => onSelectShelter(shelter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: selectedShelter.id == shelter.id
                                ? MamoColors.citizenNavy
                                : MamoColors.citizenSafeGreen,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33071A3D),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            '🏫',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CitizenMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    final subRoadPaint = Paint()
      ..color = const Color(0xFFD2DFEC)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final parkPaint = Paint()
      ..color = const Color(0xFFD6ECD9)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.65,
          size.height * 0.60,
          size.width * 0.25,
          size.height * 0.28,
        ),
        const Radius.circular(14),
      ),
      parkPaint,
    );

    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width, size.height * 0.45),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, 0),
      Offset(size.width * 0.56, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.70),
      Offset(size.width, size.height * 0.64),
      subRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.20, 0),
      Offset(size.width * 0.16, size.height),
      subRoadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendBadge extends StatelessWidget {
  const _LegendBadge({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MamoColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HazardSummaryCard extends StatelessWidget {
  const _HazardSummaryCard({required this.hazards});

  final List<CitizenHazardSpot> hazards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '⚠ 危険箇所情報',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 6),
          for (final h in hazards)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '・${h.title}（${h.description}）',
                style: const TextStyle(
                  fontSize: 12,
                  color: MamoColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShelterDetailCard extends StatelessWidget {
  const _ShelterDetailCard({required this.shelter});

  final CitizenShelter shelter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MamoColors.citizenBlue, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '選択中の避難所',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: MamoColors.citizenBlue,
                ),
              ),
              const Spacer(),
              Text(
                shelter.distanceText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: MamoColors.citizenSafeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            shelter.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: MamoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '住所：${shelter.address}',
            style: const TextStyle(
              fontSize: 12.5,
              color: MamoColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '収容人数：${shelter.occupied} / ${shelter.capacity}人（${shelter.statusText}）',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: MamoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final facility in shelter.facilities)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MamoColors.citizenSoftBlueBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MamoColors.citizenLine),
                  ),
                  child: Text(
                    facility,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: MamoColors.citizenBlue,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShelterListCard extends StatelessWidget {
  const _ShelterListCard({
    required this.shelter,
    required this.isSelected,
    required this.onTap,
  });

  final CitizenShelter shelter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? MamoColors.selectedItemBg : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? MamoColors.citizenBlue
                  : const Color(0xFFE3EAF3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shelter.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: MamoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${shelter.address} ・ ${shelter.occupied}/${shelter.capacity}人',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MamoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                shelter.distanceText,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: MamoColors.citizenBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
