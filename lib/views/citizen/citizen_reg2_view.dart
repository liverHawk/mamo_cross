import 'package:material_ui/material_ui.dart';

import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../theme/mamo_theme.dart';
import 'citizen_onboarding_widgets.dart';

/// `#reg2` 新規登録 2/3：基本情報の入力画面
class CitizenReg2View extends StatefulWidget {
  const CitizenReg2View({
    super.key,
    required this.store,
  });

  final CitizenStore store;

  @override
  State<CitizenReg2View> createState() => _CitizenReg2ViewState();
}

class _CitizenReg2ViewState extends State<CitizenReg2View> {
  late TextEditingController _nameController;
  late TextEditingController _birthDateController;
  late TextEditingController _postalCodeController;
  late TextEditingController _addressDetailController;

  @override
  void initState() {
    super.initState();
    final p = widget.store.profile;
    _nameController = TextEditingController(text: p.name);
    _birthDateController = TextEditingController(text: p.birthDate);
    _postalCodeController = TextEditingController(text: p.postalCode);
    _addressDetailController = TextEditingController(text: p.addressDetail);
  }

  @override
  void didUpdateWidget(covariant CitizenReg2View oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      final p = widget.store.profile;
      _syncController(_nameController, p.name);
      _syncController(_birthDateController, p.birthDate);
      _syncController(_postalCodeController, p.postalCode);
      _syncController(_addressDetailController, p.addressDetail);
    }
  }

  void _syncController(TextEditingController controller, String target) {
    if (controller.text != target) {
      controller.value = TextEditingValue(
        text: target,
        selection: TextSelection.collapsed(offset: target.length),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _postalCodeController.dispose();
    _addressDetailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.store.profile;
    final bloodType = kCitizenBloodTypes.contains(profile.bloodType)
        ? profile.bloodType
        : kCitizenBloodTypes.first;
    final prefecture = kCitizenPrefectures.contains(profile.prefecture)
        ? profile.prefecture
        : kCitizenPrefectures.first;
    final gender =
        kCitizenGenders.contains(profile.gender) ? profile.gender : null;

    return DecoratedBox(
      decoration: kCitizenScreenBackground,
      child: Column(
        children: <Widget>[
          CitizenTopBar(
            title: '② 基本情報の入力',
            onBack: () => widget.store.goToScreen(CitizenScreen.reg1),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 16),
                    child: Text(
                      '基本情報の入力',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ),
                  CitizenCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _FieldLabel('名前（必須）'),
                        TextField(
                          controller: _nameController,
                          decoration:
                              citizenInputDecoration(hintText: '例）山田 太郎'),
                          onChanged: (v) =>
                              widget.store.updateBasicInfo(name: v),
                        ),
                        const SizedBox(height: 14),
                        const _FieldLabel('生年月日（必須）'),
                        TextField(
                          controller: _birthDateController,
                          decoration:
                              citizenInputDecoration(hintText: '例）1990-01-01'),
                          onChanged: (v) =>
                              widget.store.updateBasicInfo(birthDate: v),
                        ),
                        const SizedBox(height: 14),
                        const _FieldLabel('血液型（必須）'),
                        _CitizenDropdownField(
                          value: bloodType,
                          items: kCitizenBloodTypes,
                          onChanged: (v) =>
                              widget.store.updateBasicInfo(bloodType: v),
                        ),
                        const SizedBox(height: 14),
                        const _FieldLabel('性別（医療・救助活動に使用）'),
                        RadioGroup<String>(
                          groupValue: gender,
                          onChanged: (value) {
                            if (value != null) {
                              widget.store.updateBasicInfo(gender: value);
                            }
                          },
                          child: Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: kCitizenGenders.map((g) {
                              return InkWell(
                                onTap: () =>
                                    widget.store.updateBasicInfo(gender: g),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Radio<String>(
                                        value: g,
                                        activeColor: MamoColors.citizenBlue,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Text(
                                        g,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CitizenCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _FieldLabel('住所（必須）'),
                        TextField(
                          controller: _postalCodeController,
                          decoration: citizenInputDecoration(hintText: '郵便番号'),
                          onChanged: (v) =>
                              widget.store.updateBasicInfo(postalCode: v),
                        ),
                        const SizedBox(height: 10),
                        _CitizenDropdownField(
                          value: prefecture,
                          items: kCitizenPrefectures,
                          onChanged: (v) =>
                              widget.store.updateBasicInfo(prefecture: v),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _addressDetailController,
                          decoration: citizenInputDecoration(
                            hintText: '市区町村・番地・建物名',
                          ),
                          onChanged: (v) =>
                              widget.store.updateBasicInfo(addressDetail: v),
                        ),
                      ],
                    ),
                  ),
                  const CitizenOnboardingStepper(activeStep: 2),
                  CitizenPrimaryButton(
                    label: '次へ',
                    onPressed: () =>
                        widget.store.goToScreen(CitizenScreen.reg3),
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
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: Color(0xFF111111),
        ),
      ),
    );
  }
}

class _CitizenDropdownField extends StatelessWidget {
  const _CitizenDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCFD9E6)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF111111),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
      ),
    );
  }
}
