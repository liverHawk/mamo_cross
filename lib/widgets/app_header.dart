import 'package:material_ui/material_ui.dart';

import '../models/rescue_request.dart';
import '../state/rescue_store.dart';
import '../theme/mamo_theme.dart';

/// アプリ上部の固定ヘッダー（AppHeader.vue 相当）
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.store,
    required this.isMobile,
    this.onMenuTap,
  });

  final RescueStore store;
  final bool isMobile;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showSubtitle = width >= 650;
    final showMunicipality = width >= 900;

    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 28),
      decoration: const BoxDecoration(
        color: MamoColors.topBarBg,
        boxShadow: [
          BoxShadow(
            color: Color(0x21000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isMobile) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu, color: Colors.white),
              tooltip: 'メニューを開く',
            ),
            const SizedBox(width: 4),
          ],
          const Text(
            'MAMO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          if (showSubtitle) ...[
            const SizedBox(width: 8),
            const Text(
              '自治体管理システム',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Spacer(),
          _BellButton(
            count: store.newCount,
            onTap: () {
              store.setStatusFilter(RequestStatus.pending);
              store.setAgencyFilter(null);
              store.setView(MamoView.requests);
            },
          ),
          if (showMunicipality) ...[
            const SizedBox(width: 24),
            Text(
              '${store.municipalityName} ▾',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
          const SizedBox(width: 20),
          InkWell(
            onTap: () => _showHelpDialog(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white),
              ),
              child: const Text(
                '?',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MAMO 自治体管理システム'),
        content: const Text(
          '災害時の救助要請受信・位置確認・関係機関（救急・消防・警察・自衛隊）への共有および対応ステータス管理を行うシステムです。\n\n'
          'ベルアイコンを押すと未対応の救助要請一覧へ移動します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications,
              color: Colors.amberAccent,
              size: 22,
            ),
            Positioned(
              top: -7,
              right: -9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE13C3C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
