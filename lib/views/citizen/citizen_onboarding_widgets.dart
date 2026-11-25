import 'package:material_ui/material_ui.dart';

import '../../theme/mamo_theme.dart';

/// 利用者側のオンボーディング・共通画面背景グラデーション
const BoxDecoration kCitizenScreenBackground = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Colors.white,
      Colors.white,
      MamoColors.citizenSkyEnd,
    ],
    stops: <double>[0.0, 0.82, 1.0],
  ),
);

/// 利用者画面共通のトップバー（戻る `‹`・中央タイトル・右 `MAMO`）
class CitizenTopBar extends StatelessWidget {
  const CitizenTopBar({
    super.key,
    required this.title,
    required this.onBack,
    this.backSymbol = '‹',
    this.trailingLabel = 'MAMO',
  });

  final String title;
  final VoidCallback onBack;
  final String backSymbol;
  final String trailingLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEDF1F6)),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(22),
              child: Center(
                child: Text(
                  backSymbol,
                  style: const TextStyle(
                    fontSize: 25,
                    color: MamoColors.citizenBlue,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF111111),
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              trailingLabel,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: MamoColors.citizenBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 白背景・角丸16・枠線付きの共通カード
class CitizenCard extends StatelessWidget {
  const CitizenCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: const <BoxShadow>[
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

/// 淡青背景の情報・免責ボックス
class CitizenInfoBox extends StatelessWidget {
  const CitizenInfoBox({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MamoColors.citizenSoftBlueBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF475569),
          height: 1.7,
        ),
      ),
    );
  }
}

/// フル幅青グラデーションのプライマリボタン
class CitizenPrimaryButton extends StatelessWidget {
  const CitizenPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            MamoColors.citizenBlue,
            Color(0xFF0876E8),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33075BC7),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// 3段階オンボーディングステッパー（#reg1〜#reg3）
class CitizenOnboardingStepper extends StatelessWidget {
  const CitizenOnboardingStepper({
    super.key,
    required this.activeStep,
  });

  /// 1, 2, 3 のいずれか（activeStep 以下のステップをアクティブ表示）
  final int activeStep;

  static const List<String> _labels = <String>[
    '本人確認',
    '基本情報',
    '救助情報',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 14),
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Positioned(
            top: 14,
            left: 36,
            right: 36,
            child: Container(
              height: 2,
              color: const Color(0xFFD8E1ED),
            ),
          ),
          Row(
            children: List<Widget>.generate(_labels.length, (index) {
              final stepNumber = index + 1;
              final isOn = stepNumber <= activeStep;
              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 29,
                      height: 29,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOn ? MamoColors.citizenBlue : Colors.white,
                        border: Border.all(
                          color: isOn
                              ? MamoColors.citizenBlue
                              : const Color(0xFFBCC8D8),
                        ),
                      ),
                      child: Text(
                        '$stepNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isOn ? Colors.white : const Color(0xFF657184),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[index],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isOn ? FontWeight.w800 : FontWeight.w500,
                        color: isOn
                            ? MamoColors.citizenBlue
                            : const Color(0xFF657184),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// 登録フォーム用の標準 InputDecoration
InputDecoration citizenInputDecoration({
  required String hintText,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFCFD9E6)),
    ),
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
