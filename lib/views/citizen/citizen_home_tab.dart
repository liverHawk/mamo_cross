import 'package:material_ui/material_ui.dart';

import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../theme/mamo_theme.dart';

/// 利用者ホーム画面（#home：災害警報・安否登録・家族グループ・避難所情報）
class CitizenHomeTab extends StatelessWidget {
  const CitizenHomeTab({super.key, required this.store});

  final CitizenStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final shelter = store.nearestShelter;
        return ColoredBox(
          color: MamoColors.citizenHomeBg,
          child: Column(
            children: [
              _HomeTopBar(
                onMenuTap: () => store.goToScreen(CitizenScreen.login),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF3D32),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          kCitizenAlertBannerText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(2, 14, 2, 10),
                        child: Text(
                          'あなたの安否を登録してください',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: MamoColors.textPrimary,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _SafetyActionButton(
                              status: CitizenSafetyStatus.safe,
                              selected:
                                  store.mySafety == CitizenSafetyStatus.safe,
                              onPressed: () => store.updateMySafety(
                                CitizenSafetyStatus.safe,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SafetyActionButton(
                              status: CitizenSafetyStatus.damaged,
                              selected:
                                  store.mySafety == CitizenSafetyStatus.damaged,
                              onPressed: () => store.updateMySafety(
                                CitizenSafetyStatus.damaged,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SafetyActionButton(
                              status: CitizenSafetyStatus.rescueNeeded,
                              selected: store.mySafety ==
                                  CitizenSafetyStatus.rescueNeeded,
                              onPressed: store.openRescue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FamilyGroupCard(
                        members: store.familyMembers,
                        registeredName: store.registeredName,
                      ),
                      const SizedBox(height: 14),
                      _ShelterInfoCard(shelter: shelter),
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

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.onMenuTap});

  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDF1F6))),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onMenuTap,
            style: TextButton.styleFrom(
              foregroundColor: MamoColors.citizenBlue,
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '☰',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: MamoColors.citizenBlue,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'ホーム',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MamoColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(
            width: 40,
            child: Center(
              child: Text(
                '♧',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: MamoColors.citizenBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyActionButton extends StatelessWidget {
  const _SafetyActionButton({
    required this.status,
    required this.selected,
    required this.onPressed,
  });

  final CitizenSafetyStatus status;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: status.buttonColor,
        foregroundColor: Colors.white,
        elevation: selected ? 3 : 0,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? const BorderSide(color: MamoColors.citizenNavy, width: 2)
              : BorderSide.none,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.symbol,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              status.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyGroupCard extends StatelessWidget {
  const _FamilyGroupCard({
    required this.members,
    required this.registeredName,
  });

  final List<FamilyMember> members;
  final String registeredName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C17365D),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '家族グループ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: MamoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < members.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: Color(0xFFEDF1F6)),
            _FamilyRow(
              member: members[i],
              displayName:
                  members[i].isSelf ? registeredName : members[i].name,
            ),
          ],
        ],
      ),
    );
  }
}

class _FamilyRow extends StatelessWidget {
  const _FamilyRow({
    required this.member,
    required this.displayName,
  });

  final FamilyMember member;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(member.avatar, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MamoColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            member.status.badgeText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: member.status.badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelterInfoCard extends StatelessWidget {
  const _ShelterInfoCard({required this.shelter});

  final CitizenShelter shelter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C17365D),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '避難所情報',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: MamoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '📍 ${shelter.distanceText}　${shelter.name}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: MamoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '📢 ${shelter.statusText}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEE3333),
            ),
          ),
        ],
      ),
    );
  }
}
