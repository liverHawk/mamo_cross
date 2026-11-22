import 'package:material_ui/material_ui.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('詳細画面')),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Text(message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
