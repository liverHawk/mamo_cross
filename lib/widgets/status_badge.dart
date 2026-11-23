import 'package:material_ui/material_ui.dart';

import '../models/rescue_request.dart';

/// 対応ステータス（未対応 / 対応中 / 対応済み）バッジ
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: status.borderColor),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: status.textColor,
          height: 1.2,
        ),
      ),
    );
  }
}
