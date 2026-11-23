import '../models/rescue_request.dart';

/// Supabase Realtime で受信する `public.rescue_requests` 変更イベント
sealed class RescueRealtimeEvent {
  const RescueRealtimeEvent();
}

final class RescueInsertedEvent extends RescueRealtimeEvent {
  const RescueInsertedEvent(this.row);

  final Map<String, dynamic> row;
}

final class RescueUpdatedEvent extends RescueRealtimeEvent {
  const RescueUpdatedEvent(this.row);

  final Map<String, dynamic> row;
}

/// 救助要請データ取得・Realtime 購読・ステータス更新の抽象データソース
abstract interface class RescueDataSource {
  /// 初期表示用に最新 [limit] 件を取得する
  Future<List<Map<String, dynamic>>> fetchInitialRequests({int limit = 50});

  /// `public.rescue_requests` の INSERT / UPDATE を購読する
  Stream<RescueRealtimeEvent> subscribeRequests({
    void Function(bool connected)? onConnectionChanged,
  });

  /// DB レコードの対応ステータスを更新する
  Future<void> updateStatus({
    required String dbId,
    required RequestStatus status,
  });

  /// チャネルやクライアント等のリソースを解放する
  Future<void> dispose();
}
