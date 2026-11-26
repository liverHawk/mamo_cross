import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../models/app_mode.dart';
import '../../models/citizen_models.dart';
import '../../state/citizen_store.dart';
import '../../theme/mamo_theme.dart';
import 'package:flutter/services.dart';

/// 利用者設定タブ（登録プロフィール確認/編集・配慮事項・通知スイッチ・モード切替・ログアウト）
class CitizenSettingsTab extends StatefulWidget {
  const CitizenSettingsTab({
    super.key,
    required this.store,
    this.onSelectMode,
  });

  final CitizenStore store;
  final ValueChanged<MamoAppMode>? onSelectMode;

  @override
  State<CitizenSettingsTab> createState() => _CitizenSettingsTabState();
}

class _CitizenSettingsTabState extends State<CitizenSettingsTab> {
  bool _isEditing = false;
  String _initialName = '';
  String _initialAddress = '';
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.profile.name);
    _addressController =
        TextEditingController(text: widget.store.profile.addressDetail);
    widget.store.addListener(_syncFromStore);
  }

  @override
  void didUpdateWidget(covariant CitizenSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_syncFromStore);
      widget.store.addListener(_syncFromStore);
      _syncFromStore();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_syncFromStore);
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _syncFromStore() {
    if (!mounted || !_isEditing) return;
    final profile = widget.store.profile;
    if (_nameController.text == _initialName &&
        _nameController.text != profile.name) {
      _nameController.value = TextEditingValue(
        text: profile.name,
        selection: TextSelection.collapsed(offset: profile.name.length),
      );
    }
    _initialName = profile.name;
    if (_addressController.text == _initialAddress &&
        _addressController.text != profile.addressDetail) {
      _addressController.value = TextEditingValue(
        text: profile.addressDetail,
        selection: TextSelection.collapsed(
          offset: profile.addressDetail.length,
        ),
      );
    }
    _initialAddress = profile.addressDetail;
  }

  void _startEdit() {
    _initialName = widget.store.profile.name;
    _initialAddress = widget.store.profile.addressDetail;
    _nameController.text = _initialName;
    _addressController.text = _initialAddress;
    setState(() => _isEditing = true);
  }

  void _saveEdit() {
    final nextName =
        _nameController.text == _initialName ? null : _nameController.text.trim();
    final nextAddress = _addressController.text == _initialAddress
        ? null
        : _addressController.text.trim();
    setState(() => _isEditing = false);
    unawaited(
      widget.store.saveProfileEdits(
        name: nextName,
        addressDetail: nextAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final profile = store.profile;
        final considerationsText = profile.formattedConsiderations;

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
                        '設定',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: MamoColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'アカウント',
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
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '登録プロフィール',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: MamoColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (!_isEditing)
                                  TextButton(
                                    onPressed: _startEdit,
                                    style: TextButton.styleFrom(
                                      foregroundColor: MamoColors.citizenBlue,
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      '編集',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_isEditing) ...[
                              TextField(
                                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'お名前',
                                  hintText: '例）山田 太郎',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                inputFormatters: [LengthLimitingTextInputFormatter(300)],
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: '市区町村・番地・建物名',
                                  hintText: '市区町村・番地・建物名',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _saveEdit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: MamoColors.citizenBlue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text(
                                        '保存',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          setState(() => _isEditing = false),
                                      child: const Text('キャンセル'),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              _ProfileRow(
                                label: 'お名前',
                                value: store.registeredName,
                              ),
                              _ProfileRow(
                                label: '生年月日',
                                value: profile.birthDate.trim().isEmpty
                                    ? '未設定'
                                    : profile.birthDate.trim(),
                              ),
                              _ProfileRow(
                                label: '血液型',
                                value: (profile.bloodType.trim().isEmpty ||
                                        profile.bloodType == '選択してください')
                                    ? '未設定'
                                    : profile.bloodType,
                              ),
                              _ProfileRow(
                                label: '性別',
                                value: profile.gender.trim().isEmpty
                                    ? '未設定'
                                    : profile.gender,
                              ),
                              _ProfileRow(
                                label: '住所',
                                value: profile.fullAddress.isEmpty
                                    ? '未設定'
                                    : profile.fullAddress,
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      store.goToScreen(CitizenScreen.reg2),
                                  style: TextButton.styleFrom(
                                    foregroundColor: MamoColors.citizenBlue,
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    '基本情報登録画面を開く ›',
                                    style: TextStyle(fontSize: 12.5),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '救助時の配慮事項',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: MamoColors.textPrimary,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      store.goToScreen(CitizenScreen.reg3),
                                  style: TextButton.styleFrom(
                                    foregroundColor: MamoColors.citizenBlue,
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    '変更',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              considerationsText.isEmpty
                                  ? '特記事項なし'
                                  : considerationsText,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.5,
                                color: MamoColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '災害警報・避難通知',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: MamoColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '震度情報や避難所開設の通知を受け取る',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: MamoColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: store.notificationsEnabled,
                              onChanged: store.setNotificationsEnabled,
                            ),
                          ],
                        ),
                      ),
                      if (widget.onSelectMode != null) ...[
                        const SizedBox(height: 12),
                        _SettingsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'デモモード切替',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: MamoColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: () =>
                                    widget.onSelectMode!(MamoAppMode.portal),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: MamoColors.citizenBlue,
                                  side: const BorderSide(
                                    color: MamoColors.citizenBlue,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: const Text(
                                  'ポータルへ戻る',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: () => widget.onSelectMode!(
                                  MamoAppMode.municipality,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: MamoColors.citizenNavy,
                                  side: const BorderSide(
                                    color: MamoColors.citizenLine,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: const Text(
                                  '自治体管理画面へ',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton(
                        // 別世帯・ゲスト再ログインデモのため利用者プロフィール等も初期化する
                        onPressed: store.resetDemo,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MamoColors.citizenHelpRed,
                          side: const BorderSide(
                            color: MamoColors.citizenHelpRed,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          'ログアウト',
                          style: TextStyle(
                            fontSize: 15,
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
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: child,
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: MamoColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: MamoColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
