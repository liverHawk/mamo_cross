import 'package:material_ui/material_ui.dart';

import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../theme/mamo_theme.dart';

/// 利用者安否タブ（本人の安否登録・家族安否フィルタ・安否確認通知送信）
class CitizenSafetyTab extends StatelessWidget {
  const CitizenSafetyTab({super.key, required this.store});

  final CitizenStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final members = store.filteredFamilyMembers;
        return ColoredBox(
          color: MamoColors.citizenHomeBg,
          child: Column(
            children: [
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFEDF1F6))),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        '安否',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: MamoColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '家族安否管理',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: MamoColors.citizenBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MySafetyControlCard(store: store),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          FilterChip(
                            label: const Text('すべて'),
                            selected: store.familyStatusFilter == null,
                            onSelected: (_) =>
                                store.setFamilyStatusFilter(null),
                          ),
                          for (final status in CitizenSafetyStatus.values)
                            FilterChip(
                              label: Text(status.label),
                              selected: store.familyStatusFilter == status,
                              onSelected: (_) => store.setFamilyStatusFilter(
                                store.familyStatusFilter == status
                                    ? null
                                    : status,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE3EAF3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '家族の安否一覧',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: MamoColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (members.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  '該当する家族メンバーはいません。',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: MamoColors.textSecondary,
                                  ),
                                ),
                              )
                            else
                              for (var i = 0; i < members.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFEDF1F6),
                                  ),
                                _SafetyMemberTile(
                                  member: members[i],
                                  displayName: members[i].isSelf
                                      ? store.registeredName
                                      : members[i].name,
                                ),
                              ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: store.sendFamilySafetyCheck,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MamoColors.citizenBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          '家族に安否確認通知を送る',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (store.familyCheckInSent) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '✓ 安否確認通知を送信済みです（デモ）',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MamoColors.citizenSafeGreen,
                          ),
                        ),
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

class _MySafetyControlCard extends StatelessWidget {
  const _MySafetyControlCard({required this.store});

  final CitizenStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'あなたの安否ステータス',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: MamoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatusSelectButton(
                  status: CitizenSafetyStatus.safe,
                  selected: store.mySafety == CitizenSafetyStatus.safe,
                  onPressed: () =>
                      store.updateMySafety(CitizenSafetyStatus.safe),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusSelectButton(
                  status: CitizenSafetyStatus.damaged,
                  selected: store.mySafety == CitizenSafetyStatus.damaged,
                  onPressed: () =>
                      store.updateMySafety(CitizenSafetyStatus.damaged),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusSelectButton(
                  status: CitizenSafetyStatus.rescueNeeded,
                  selected:
                      store.mySafety == CitizenSafetyStatus.rescueNeeded,
                  onPressed: store.openRescue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusSelectButton extends StatelessWidget {
  const _StatusSelectButton({
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
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              status.label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyMemberTile extends StatelessWidget {
  const _SafetyMemberTile({
    required this.member,
    required this.displayName,
  });

  final FamilyMember member;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(member.avatar, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: MamoColors.textPrimary,
                  ),
                ),
                if (member.locationNote.isNotEmpty ||
                    member.lastUpdated.isNotEmpty)
                  Text(
                    [
                      if (member.locationNote.isNotEmpty) member.locationNote,
                      if (member.lastUpdated.isNotEmpty)
                        '更新 ${member.lastUpdated}',
                    ].join(' ・ '),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: MamoColors.textSecondary,
                    ),
                  ),
              ],
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
