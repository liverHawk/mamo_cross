import 'package:material_ui/material_ui.dart';

import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../theme/mamo_theme.dart';
import 'citizen_onboarding_widgets.dart';

/// `#reg3` 新規登録 3/3：救助要請時の情報（配慮事項）入力画面
class CitizenReg3View extends StatefulWidget {
  const CitizenReg3View({
    super.key,
    required this.store,
  });

  final CitizenStore store;

  @override
  State<CitizenReg3View> createState() => _CitizenReg3ViewState();
}

class _CitizenReg3ViewState extends State<CitizenReg3View> {
  late TextEditingController _otherController;

  @override
  void initState() {
    super.initState();
    _otherController =
        TextEditingController(text: widget.store.profile.otherConsideration);
  }

  @override
  void didUpdateWidget(covariant CitizenReg3View oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      final target = widget.store.profile.otherConsideration;
      if (_otherController.text != target) {
        _otherController.value = TextEditingValue(
          text: target,
          selection: TextSelection.collapsed(offset: target.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.store.profile.considerations;

    return DecoratedBox(
      decoration: kCitizenScreenBackground,
      child: Column(
        children: <Widget>[
          CitizenTopBar(
            title: '③ 救助要請時の情報',
            onBack: () => widget.store.goToScreen(CitizenScreen.reg2),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: Text.rich(
                      TextSpan(
                        text: '救助時の配慮事項 ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111111),
                        ),
                        children: <InlineSpan>[
                          TextSpan(
                            text: '（任意）',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(
                      '救助・医療対応時に知っておいてほしいこと',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5E6878),
                      ),
                    ),
                  ),
                  CitizenCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ...kCitizenConsiderationOptions.map((option) {
                          final isChecked = selected.contains(option);
                          return InkWell(
                            onTap: () =>
                                widget.store.toggleConsideration(option),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: <Widget>[
                                  Checkbox(
                                    value: isChecked,
                                    activeColor: MamoColors.citizenBlue,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (_) => widget.store
                                        .toggleConsideration(option),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xFF111111),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 14),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 7),
                          child: Text(
                            'その他（自由入力）',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ),
                        TextField(
                          controller: _otherController,
                          minLines: 4,
                          maxLines: 6,
                          decoration: citizenInputDecoration(
                            hintText: '例）アレルギー、持病、服薬中など',
                          ),
                          onChanged: widget.store.updateOtherConsideration,
                        ),
                      ],
                    ),
                  ),
                  const CitizenInfoBox(
                    text: '🔒 デモ版では入力内容を外部へ送信しません。',
                  ),
                  const CitizenOnboardingStepper(activeStep: 3),
                  CitizenPrimaryButton(
                    label: '登録する',
                    onPressed: widget.store.completeRegistration,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
