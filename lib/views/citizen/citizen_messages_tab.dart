import 'package:material_ui/material_ui.dart';

import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../theme/mamo_theme.dart';
import 'package:flutter/services.dart';

/// 利用者メッセージタブ（自治体お知らせ・家族連絡・クイック返信・自由送信）
class CitizenMessagesTab extends StatefulWidget {
  const CitizenMessagesTab({super.key, required this.store});

  final CitizenStore store;

  @override
  State<CitizenMessagesTab> createState() => _CitizenMessagesTabState();
}

class _CitizenMessagesTabState extends State<CitizenMessagesTab> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text;
    _controller.clear();
    if (text.trim().isEmpty) return;
    widget.store.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final isNotice =
            store.activeMessageKind == CitizenMessageKind.municipalityNotice;
        final items =
            isNotice ? store.municipalityNotices : store.familyMessages;

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
                        'メッセージ',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: MamoColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '連絡・お知らせ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: MamoColors.citizenBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegmentButton(
                        label: CitizenMessageKind.municipalityNotice.label,
                        active: isNotice,
                        onTap: () => store.setActiveMessageKind(
                          CitizenMessageKind.municipalityNotice,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SegmentButton(
                        label: CitizenMessageKind.familyThread.label,
                        active: !isNotice,
                        onTap: () => store.setActiveMessageKind(
                          CitizenMessageKind.familyThread,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _MessageBubbleCard(message: items[index]),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: MamoColors.citizenLine)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final reply in store.quickReplyOptions) ...[
                            ActionChip(
                              label: Text(
                                reply,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              backgroundColor: MamoColors.citizenSoftBlueBg,
                              side: const BorderSide(
                                color: MamoColors.citizenLine,
                              ),
                              onPressed: () => store.sendQuickReply(reply),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            inputFormatters: [LengthLimitingTextInputFormatter(500)],
                            controller: _controller,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _handleSend(),
                            decoration: InputDecoration(
                              hintText: '家族へメッセージを入力...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: MamoColors.citizenLine,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _handleSend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MamoColors.citizenBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send, size: 16),
                              SizedBox(width: 4),
                              Text(
                                '送信',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? MamoColors.citizenBlue : Colors.white,
        foregroundColor: active ? Colors.white : MamoColors.textSecondary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: active ? MamoColors.citizenBlue : MamoColors.citizenLine,
          ),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _MessageBubbleCard extends StatelessWidget {
  const _MessageBubbleCard({required this.message});

  final CitizenMessage message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final bgColor = isMine
        ? MamoColors.citizenBlue
        : message.isImportant
            ? const Color(0xFFFEF2F2)
            : Colors.white;
    final borderColor = isMine
        ? MamoColors.citizenBlue
        : message.isImportant
            ? const Color(0xFFFECACA)
            : const Color(0xFFE3EAF3);
    final textColor = isMine ? Colors.white : MamoColors.textPrimary;
    final metaColor = isMine
        ? const Color(0xFFE0EDFF)
        : MamoColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(message.avatar, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message.sender,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: message.isImportant && !isMine
                        ? const Color(0xFFB91C1C)
                        : textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                message.time,
                style: TextStyle(fontSize: 11, color: metaColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
