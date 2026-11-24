import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/config/supabase_config.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/services/rescue_data_source.dart';
import 'package:mamo_cross/services/supabase_rescue_data_source.dart';

const bool _runLiveSupabase = bool.fromEnvironment('RUN_LIVE_SUPABASE');

void main() {
  test(
    'live Supabase verification: fetchInitialRequests, subscribeRequests, and safe updateStatus roundtrip',
    () async {
      final ds = SupabaseRescueDataSource(config: SupabaseConfig.exhibition);
      StreamSubscription<RescueRealtimeEvent>? sub;
      String? testRowDbId;
      RequestStatus? originalStatus;
      var statusChanged = false;

      try {
        // 1. 初期取得（最新50件）
        final rows = await ds.fetchInitialRequests(limit: 50);
        expect(rows, isA<List<Map<String, dynamic>>>());
        for (final row in rows) {
          final parsed = RescueRequest.fromSupabaseRow(row);
          expect(parsed.id, isNotEmpty);
        }

        // 2. Realtime 購読（SUBSCRIBED 確認）
        final subscribedCompleter = Completer<void>();
        final updatedCompleter = Completer<Map<String, dynamic>>();

        sub = ds
            .subscribeRequests(
              onConnectionChanged: (connected) {
                if (connected && !subscribedCompleter.isCompleted) {
                  subscribedCompleter.complete();
                }
              },
            )
            .listen((event) {
          if (event is RescueUpdatedEvent &&
              testRowDbId != null &&
              event.row['id']?.toString() == testRowDbId &&
              !updatedCompleter.isCompleted) {
            updatedCompleter.complete(event.row);
          }
        });

        await subscribedCompleter.future.timeout(const Duration(seconds: 15));

        // 3. ステータス更新の疎通確認（既存行がある場合はトグルして即時復元）
        if (rows.isNotEmpty && rows.first['id'] != null) {
          final target = rows.first;
          testRowDbId = target['id'].toString();
          originalStatus = RescueRequest.parseStatus(target['status']);
          final nextStatus = originalStatus == RequestStatus.pending
              ? RequestStatus.working
              : RequestStatus.pending;

          await ds.updateStatus(dbId: testRowDbId, status: nextStatus);
          statusChanged = true;

          // REST 再取得で反映を確認
          final refreshed = await ds.fetchInitialRequests(limit: 50);
          final matched = refreshed.firstWhere(
            (r) => r['id']?.toString() == testRowDbId,
          );
          expect(
            RescueRequest.parseStatus(matched['status']),
            nextStatus,
          );

          // Realtime UPDATE イベント受信も確認（タイムアウトしないこと）
          final realtimeRow = await updatedCompleter.future.timeout(
            const Duration(seconds: 10),
          );
          expect(
            RescueRequest.parseStatus(realtimeRow['status']),
            nextStatus,
          );
        }
      } finally {
        if (statusChanged && testRowDbId != null && originalStatus != null) {
          await ds.updateStatus(dbId: testRowDbId, status: originalStatus);
          final restoredRows = await ds.fetchInitialRequests(limit: 50);
          final restored = restoredRows.firstWhere(
            (r) => r['id']?.toString() == testRowDbId,
          );
          expect(
            RescueRequest.parseStatus(restored['status']),
            originalStatus,
          );
        }
        await sub?.cancel();
        await ds.dispose();
      }
    },
    skip: !_runLiveSupabase,
    timeout: const Timeout(Duration(seconds: 35)),
  );
}
