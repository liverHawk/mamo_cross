import 'package:material_ui/material_ui.dart';

import '../services/hq_auth_service.dart';
import '../services/rescue_data_source.dart';

/// 対策本部オペレーターのパスコード入力ダイアログ。認証成功時にデータソースを返す。
Future<RescueDataSource?> showHqPasscodeDialog(
  BuildContext context,
  HqAuthService auth,
) {
  return showDialog<RescueDataSource>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _HqPasscodeDialog(auth: auth),
  );
}

class _HqPasscodeDialog extends StatefulWidget {
  const _HqPasscodeDialog({required this.auth});

  final HqAuthService auth;

  @override
  State<_HqPasscodeDialog> createState() => _HqPasscodeDialogState();
}

class _HqPasscodeDialogState extends State<_HqPasscodeDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ds = await widget.auth.signIn(_controller.text);
      if (!mounted) return;
      Navigator.of(context).pop(ds);
    } on HqAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '認証に失敗しました。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('対策本部オペレーター認証'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('自治体管理画面には個人情報が含まれます。パスコードを入力してください。'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('hq_passcode_field'),
            controller: _controller,
            obscureText: true,
            autofocus: true,
            maxLength: 128,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'パスコード',
              errorText: _error,
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('hq_passcode_submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('認証'),
        ),
      ],
    );
  }
}
