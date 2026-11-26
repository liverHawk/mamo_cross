import 'package:flutter/foundation.dart';

/// リリースビルドでは出力しないログ（例外詳細・テーブル構造の端末ログ露出防止）
void appLog(String message) {
  if (kDebugMode) debugPrint(message);
}
