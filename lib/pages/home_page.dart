import 'package:material_ui/material_ui.dart';

import 'detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ホーム画面")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const DetailPage(message: "ホームボタンから渡したテキストです"),
              ),
            );
          },
          child: const Text("詳細画面へ行く"),
        ),
      ),
    );
  }
}
