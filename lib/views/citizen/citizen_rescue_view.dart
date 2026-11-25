import 'package:material_ui/material_ui.dart';

import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../state/rescue_store.dart';
import '../../theme/mamo_theme.dart';
import 'package:flutter/services.dart';

/// 利用者救助要請入力画面（#rescue）
class CitizenRescueView extends StatefulWidget {
  const CitizenRescueView({
    super.key,
    required this.citizenStore,
    required this.rescueStore,
  });

  final CitizenStore citizenStore;
  final RescueStore rescueStore;

  @override
  State<CitizenRescueView> createState() => _CitizenRescueViewState();
}

class _CitizenRescueViewState extends State<CitizenRescueView> {
  late final TextEditingController _nameController;
  late final TextEditingController _detailController;
  late final TextEditingController _careController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.citizenStore.rescueNameDraft);
    _detailController =
        TextEditingController(text: widget.citizenStore.rescueDetailDraft);
    _careController =
        TextEditingController(text: widget.citizenStore.rescueCareDraft);
    widget.citizenStore.addListener(_syncFromStore);
  }

  @override
  void didUpdateWidget(covariant CitizenRescueView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.citizenStore != widget.citizenStore) {
      oldWidget.citizenStore.removeListener(_syncFromStore);
      widget.citizenStore.addListener(_syncFromStore);
      _syncFromStore();
    }
  }

  @override
  void dispose() {
    widget.citizenStore.removeListener(_syncFromStore);
    _nameController.dispose();
    _detailController.dispose();
    _careController.dispose();
    super.dispose();
  }

  void _syncFromStore() {
    if (_nameController.text != widget.citizenStore.rescueNameDraft) {
      _nameController.text = widget.citizenStore.rescueNameDraft;
    }
    if (_detailController.text != widget.citizenStore.rescueDetailDraft) {
      _detailController.text = widget.citizenStore.rescueDetailDraft;
    }
    if (_careController.text != widget.citizenStore.rescueCareDraft) {
      _careController.text = widget.citizenStore.rescueCareDraft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MamoColors.citizenHomeBg,
      child: Column(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEDF1F6))),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: () =>
                      widget.citizenStore.goToScreen(CitizenScreen.home),
                  style: TextButton.styleFrom(
                    foregroundColor: MamoColors.citizenBlue,
                    minimumSize: const Size(40, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '‹',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: MamoColors.citizenBlue,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    '救助要請',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MamoColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'MAMO',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: MamoColors.citizenBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                      '🚨 救助要請を行います',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RescueCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '現在の状況を確認',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: MamoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const _FieldLabel('お名前'),
                        TextField(
                          inputFormatters: [LengthLimitingTextInputFormatter(100)],
                          controller: _nameController,
                          onChanged: (v) =>
                              widget.citizenStore.updateRescueDraft(name: v),
                          decoration: _inputDecoration('登録した名前'),
                        ),
                        const SizedBox(height: 14),
                        const _FieldLabel('救助内容'),
                        TextField(
                          inputFormatters: [LengthLimitingTextInputFormatter(500)],
                          controller: _detailController,
                          minLines: 3,
                          maxLines: 5,
                          onChanged: (v) =>
                              widget.citizenStore.updateRescueDraft(detail: v),
                          decoration: _inputDecoration(
                            '例）建物内に閉じ込められています／けが人がいます',
                          ),
                        ),
                        const SizedBox(height: 14),
                        const _FieldLabel('救助時の配慮事項'),
                        TextField(
                          inputFormatters: [LengthLimitingTextInputFormatter(500)],
                          controller: _careController,
                          minLines: 3,
                          maxLines: 5,
                          onChanged: (v) =>
                              widget.citizenStore.updateRescueDraft(care: v),
                          decoration: _inputDecoration('登録済みの配慮事項など'),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: MamoColors.citizenSoftBlueBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '📍 現在地：デモ位置情報（〇〇地区付近）\n距離：自治体側で受信時に表示',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _RescueCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '送信される情報',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: MamoColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '・救助要請時刻\n'
                          '・登録者名\n'
                          '・現在地／位置情報\n'
                          '・救助内容\n'
                          '・救助時の配慮事項',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.9,
                            color: MamoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE52F2F), Color(0xFFF04B42)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33E52F2F),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => widget.citizenStore
                          .submitRescue(widget.rescueStore),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        '🚨 救助要請を送信',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () =>
                        widget.citizenStore.goToScreen(CitizenScreen.home),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: MamoColors.citizenBlue,
                      side: const BorderSide(
                        color: MamoColors.citizenBlue,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                        horizontal: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'キャンセル',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCFD9E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2780E8), width: 1.5),
      ),
    );
  }
}

class _RescueCard extends StatelessWidget {
  const _RescueCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C17365D),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: MamoColors.textPrimary,
        ),
      ),
    );
  }
}
