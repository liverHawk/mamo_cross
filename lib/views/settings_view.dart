import 'package:material_ui/material_ui.dart';

import '../state/rescue_store.dart';
import '../theme/mamo_theme.dart';

/// 設定画面（自治体名・リアルタイム通知設定）
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.store});

  final RescueStore store;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _municipalityController;
  late bool _realtimeNotification;
  late String _lastSyncedMunicipality;
  late bool _lastSyncedRealtime;

  @override
  void initState() {
    super.initState();
    _lastSyncedMunicipality = widget.store.municipalityName;
    _lastSyncedRealtime = widget.store.realtimeNotification;
    _municipalityController = TextEditingController(
      text: _lastSyncedMunicipality,
    );
    _realtimeNotification = _lastSyncedRealtime;
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStoreChanged);
      widget.store.addListener(_onStoreChanged);
      _resetFromStore();
    } else {
      _syncFromStoreIfNeeded();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _municipalityController.dispose();
    super.dispose();
  }

  void _resetFromStore() {
    _lastSyncedMunicipality = widget.store.municipalityName;
    _lastSyncedRealtime = widget.store.realtimeNotification;
    _setControllerText(_lastSyncedMunicipality);
    setState(() {
      _realtimeNotification = _lastSyncedRealtime;
    });
  }

  void _onStoreChanged() {
    _syncFromStoreIfNeeded();
  }

  void _syncFromStoreIfNeeded() {
    final storeMunicipality = widget.store.municipalityName;
    if (storeMunicipality != _lastSyncedMunicipality) {
      final isEditing = _municipalityController.text != _lastSyncedMunicipality;
      _lastSyncedMunicipality = storeMunicipality;
      if (!isEditing) {
        _setControllerText(storeMunicipality);
      }
    }

    final storeRealtime = widget.store.realtimeNotification;
    if (storeRealtime != _lastSyncedRealtime) {
      final isEditingRealtime = _realtimeNotification != _lastSyncedRealtime;
      _lastSyncedRealtime = storeRealtime;
      if (!isEditingRealtime && mounted) {
        setState(() {
          _realtimeNotification = storeRealtime;
        });
      }
    }
  }

  void _setControllerText(String value) {
    _municipalityController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _saveSettings() {
    widget.store.updateSettings(
      municipalityName: _municipalityController.text,
      realtimeNotification: _realtimeNotification,
    );
    _lastSyncedMunicipality = widget.store.municipalityName;
    _lastSyncedRealtime = widget.store.realtimeNotification;
    if (_municipalityController.text != _lastSyncedMunicipality) {
      _setControllerText(_lastSyncedMunicipality);
    }
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('設定を保存しました（デモ）')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 650;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 15 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '設定',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: MamoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '自治体管理システムの設定です。',
            style: TextStyle(
              fontSize: 14,
              color: MamoColors.pageSubtitle,
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: MamoTheme.panelDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '自治体名',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: MamoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _municipalityController,
                      style: const TextStyle(
                        fontSize: 14,
                        color: MamoColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.all(11),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: MamoColors.controlBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: MamoColors.controlBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: MamoColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    InkWell(
                      onTap: () => setState(() {
                        _realtimeNotification = !_realtimeNotification;
                      }),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _realtimeNotification,
                              activeColor: MamoColors.primaryBlue,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (value) => setState(() {
                                _realtimeNotification = value ?? false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'リアルタイム通知 有効',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: MamoColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MamoColors.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('保存する'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
