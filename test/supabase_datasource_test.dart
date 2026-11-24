import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/config/supabase_config.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/services/rescue_data_source.dart';
import 'package:mamo_cross/services/supabase_rescue_data_source.dart';

void main() {
  group('SupabaseRescueDataSource loopback protocol tests', () {
    test(
      'sends PostgREST select/patch with sb_publishable key and subscribes to Realtime INSERT/UPDATE',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        final requestsReceived = <({
          String method,
          Uri uri,
          Map<String, String> headers,
          String body,
        })>[];
        WebSocket? activeSocket;
        final joinedCompleter = Completer<void>();

        server.listen((HttpRequest req) async {
          if (req.uri.path.startsWith('/realtime/v1/websocket') &&
              WebSocketTransformer.isUpgradeRequest(req)) {
            final socket = await WebSocketTransformer.upgrade(req);
            activeSocket = socket;
            socket.listen((dynamic raw) {
              final decoded = jsonDecode(raw as String);
              final String? joinRef;
              final String? ref;
              final String topic;
              final String event;
              final Map<String, dynamic> payload;
              if (decoded is List) {
                joinRef = decoded[0]?.toString();
                ref = decoded[1]?.toString();
                topic = decoded[2] as String;
                event = decoded[3] as String;
                payload = Map<String, dynamic>.from(decoded[4] as Map);
              } else {
                final map = decoded as Map<String, dynamic>;
                joinRef = map['join_ref']?.toString();
                ref = map['ref']?.toString();
                topic = map['topic'] as String;
                event = map['event'] as String;
                payload = Map<String, dynamic>.from(map['payload'] as Map);
              }

              void sendReply(Map<String, dynamic> replyPayload) {
                if (decoded is List) {
                  socket.add(
                    jsonEncode([joinRef, ref, topic, 'phx_reply', replyPayload]),
                  );
                } else {
                  socket.add(
                    jsonEncode({
                      'topic': topic,
                      'event': 'phx_reply',
                      'ref': ref,
                      'payload': replyPayload,
                    }),
                  );
                }
              }

              if (event == 'phx_join') {
                final config = payload['config'] as Map<String, dynamic>;
                final pgBindings = (config['postgres_changes'] as List)
                    .cast<Map<String, dynamic>>();
                final serverFilters = [
                  for (var i = 0; i < pgBindings.length; i++)
                    {
                      'id': i + 1,
                      'event': pgBindings[i]['event'],
                      'schema': pgBindings[i]['schema'],
                      'table': pgBindings[i]['table'],
                    },
                ];
                sendReply({
                  'status': 'ok',
                  'response': {'postgres_changes': serverFilters},
                });
                if (!joinedCompleter.isCompleted) {
                  joinedCompleter.complete();
                }
              } else if (event == 'heartbeat') {
                sendReply({'status': 'ok', 'response': {}});
              }
            });
            return;
          }

          final body = await utf8.decoder.bind(req).join();
          final headerMap = <String, String>{};
          req.headers.forEach((name, values) {
            headerMap[name.toLowerCase()] = values.join(',');
          });
          requestsReceived.add((
            method: req.method,
            uri: req.uri,
            headers: headerMap,
            body: body,
          ));

          if (req.method == 'GET' &&
              req.uri.path == '/rest/v1/rescue_requests') {
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode([
                  {
                    'id': 42,
                    'request_id': 'MAMO-42',
                    'requester_name': 'テスト太郎',
                    'status': '未対応',
                  },
                ]),
              );
            await req.response.close();
            return;
          }

          if (req.method == 'PATCH' &&
              req.uri.path == '/rest/v1/rescue_requests') {
            req.response.statusCode = HttpStatus.noContent;
            await req.response.close();
            return;
          }

          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final ds = SupabaseRescueDataSource(
          config: SupabaseConfig(
            url: 'http://127.0.0.1:${server.port}',
            publishableKey: SupabaseConfig.exhibition.publishableKey,
          ),
        );
        addTearDown(ds.dispose);

        // 1. 初期取得検証
        final rows = await ds.fetchInitialRequests(limit: 50);
        expect(rows.length, 1);
        expect(rows.first['id'], 42);
        expect(requestsReceived.first.method, 'GET');
        expect(
          requestsReceived.first.headers['apikey'],
          SupabaseConfig.exhibition.publishableKey,
        );
        expect(requestsReceived.first.uri.queryParameters['limit'], '50');

        // 2. ステータス更新 PATCH 検証
        await ds.updateStatus(dbId: '42', status: RequestStatus.working);
        final patchReq = requestsReceived.last;
        expect(patchReq.method, 'PATCH');
        expect(patchReq.uri.queryParameters['id'], 'eq.42');
        expect(jsonDecode(patchReq.body), {'status': '対応中'});

        // 3. Realtime 購読と INSERT / UPDATE イベント受信検証
        final events = <RescueRealtimeEvent>[];
        final connectedCompleter = Completer<bool>();
        final sub = ds
            .subscribeRequests(
              onConnectionChanged: (connected) {
                if (connected && !connectedCompleter.isCompleted) {
                  connectedCompleter.complete(true);
                }
              },
            )
            .listen(events.add);
        addTearDown(sub.cancel);

        await joinedCompleter.future.timeout(const Duration(seconds: 5));
        expect(
          await connectedCompleter.future.timeout(const Duration(seconds: 5)),
          isTrue,
        );

        activeSocket!.add(
          jsonEncode([
            null,
            null,
            'realtime:mamo-rescue-live',
            'postgres_changes',
            {
              'ids': [1],
              'data': {
                'schema': 'public',
                'table': 'rescue_requests',
                'commit_timestamp': '2026-11-23T15:00:00Z',
                'type': 'INSERT',
                'columns': [],
                'record': {'id': 43, 'request_id': 'MAMO-43', 'status': '未対応'},
              },
            },
          ]),
        );
        activeSocket!.add(
          jsonEncode([
            null,
            null,
            'realtime:mamo-rescue-live',
            'postgres_changes',
            {
              'ids': [2],
              'data': {
                'schema': 'public',
                'table': 'rescue_requests',
                'commit_timestamp': '2026-11-23T15:00:01Z',
                'type': 'UPDATE',
                'columns': [],
                'record': {'id': 42, 'status': '対応中'},
                'old_record': {'id': 42},
              },
            },
          ]),
        );

        await pumpEventQueue(times: 30);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(events.length, 2);
        expect(events[0], isA<RescueInsertedEvent>());
        expect((events[0] as RescueInsertedEvent).row['id'], 43);
        expect(events[1], isA<RescueUpdatedEvent>());
        expect((events[1] as RescueUpdatedEvent).row['status'], '対応中');
      },
    );

    test(
      're-subscribing while previous subscription is active succeeds with zero leaked timers',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        WebSocket? activeSocket;
        var joinCount = 0;
        final firstJoin = Completer<void>();
        final secondJoin = Completer<void>();

        server.listen((HttpRequest req) async {
          if (req.uri.path.startsWith('/realtime/v1/websocket') &&
              WebSocketTransformer.isUpgradeRequest(req)) {
            final socket = await WebSocketTransformer.upgrade(req);
            activeSocket = socket;
            socket.listen((dynamic raw) {
              final decoded = jsonDecode(raw as String);
              final String? joinRef;
              final String? ref;
              final String topic;
              final String event;
              final Map<String, dynamic> payload;
              if (decoded is List) {
                joinRef = decoded[0]?.toString();
                ref = decoded[1]?.toString();
                topic = decoded[2] as String;
                event = decoded[3] as String;
                payload = Map<String, dynamic>.from(decoded[4] as Map);
              } else {
                final map = decoded as Map<String, dynamic>;
                joinRef = map['join_ref']?.toString();
                ref = map['ref']?.toString();
                topic = map['topic'] as String;
                event = map['event'] as String;
                payload = Map<String, dynamic>.from(map['payload'] as Map);
              }

              void sendReply(Map<String, dynamic> replyPayload) {
                if (decoded is List) {
                  socket.add(
                    jsonEncode([joinRef, ref, topic, 'phx_reply', replyPayload]),
                  );
                } else {
                  socket.add(
                    jsonEncode({
                      'topic': topic,
                      'event': 'phx_reply',
                      'ref': ref,
                      'payload': replyPayload,
                    }),
                  );
                }
              }

              if (event == 'phx_join') {
                joinCount++;
                final config = payload['config'] as Map<String, dynamic>;
                final pgBindings = (config['postgres_changes'] as List)
                    .cast<Map<String, dynamic>>();
                final serverFilters = [
                  for (var i = 0; i < pgBindings.length; i++)
                    {
                      'id': i + 1,
                      'event': pgBindings[i]['event'],
                      'schema': pgBindings[i]['schema'],
                      'table': pgBindings[i]['table'],
                    },
                ];
                sendReply({
                  'status': 'ok',
                  'response': {'postgres_changes': serverFilters},
                });
                if (joinCount == 1 && !firstJoin.isCompleted) {
                  firstJoin.complete();
                } else if (joinCount == 2 && !secondJoin.isCompleted) {
                  secondJoin.complete();
                }
              } else if (event == 'phx_leave') {
                sendReply({'status': 'ok', 'response': {}});
              } else if (event == 'heartbeat') {
                sendReply({'status': 'ok', 'response': {}});
              }
            });
            return;
          }

          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final createdTimers = <Timer>[];
        await runZoned(
          () async {
            final ds = SupabaseRescueDataSource(
              config: SupabaseConfig(
                url: 'http://127.0.0.1:${server.port}',
                publishableKey: SupabaseConfig.exhibition.publishableKey,
              ),
            );
            try {
              final events1 = <RescueRealtimeEvent>[];
              final sub1Done = Completer<void>();
              final connected1 = Completer<bool>();
              final sub1 = ds
                  .subscribeRequests(
                    onConnectionChanged: (connected) {
                      if (connected && !connected1.isCompleted) {
                        connected1.complete(true);
                      }
                    },
                  )
                  .listen(events1.add, onDone: () {
                    if (!sub1Done.isCompleted) {
                      sub1Done.complete();
                    }
                  });

              await firstJoin.future.timeout(const Duration(seconds: 5));
              expect(
                await connected1.future.timeout(const Duration(seconds: 5)),
                isTrue,
              );

              // sub1 をアクティブのまま再購読する
              final events2 = <RescueRealtimeEvent>[];
              final connected2 = Completer<bool>();
              final sub2 = ds
                  .subscribeRequests(
                    onConnectionChanged: (connected) {
                      if (connected && !connected2.isCompleted) {
                        connected2.complete(true);
                      }
                    },
                  )
                  .listen(events2.add);

              await secondJoin.future.timeout(const Duration(seconds: 5));
              expect(
                await connected2.future.timeout(const Duration(seconds: 5)),
                isTrue,
              );
              await sub1Done.future.timeout(const Duration(seconds: 5));

              activeSocket!.add(
                jsonEncode([
                  null,
                  null,
                  'realtime:mamo-rescue-live',
                  'postgres_changes',
                  {
                    'ids': [1],
                    'data': {
                      'schema': 'public',
                      'table': 'rescue_requests',
                      'commit_timestamp': '2026-11-24T00:00:00Z',
                      'type': 'INSERT',
                      'columns': [],
                      'record': {
                        'id': 101,
                        'request_id': 'MAMO-101',
                        'status': '未対応',
                      },
                    },
                  },
                ]),
              );
              activeSocket!.add(
                jsonEncode([
                  null,
                  null,
                  'realtime:mamo-rescue-live',
                  'postgres_changes',
                  {
                    'ids': [2],
                    'data': {
                      'schema': 'public',
                      'table': 'rescue_requests',
                      'commit_timestamp': '2026-11-24T00:00:01Z',
                      'type': 'UPDATE',
                      'columns': [],
                      'record': {'id': 101, 'status': '対応中'},
                      'old_record': {'id': 101},
                    },
                  },
                ]),
              );

              await pumpEventQueue(times: 30);
              await Future<void>.delayed(const Duration(milliseconds: 50));

              expect(events1, isEmpty);
              expect(events2.length, 2);
              expect(events2[0], isA<RescueInsertedEvent>());
              expect((events2[0] as RescueInsertedEvent).row['id'], 101);
              expect(events2[1], isA<RescueUpdatedEvent>());
              expect((events2[1] as RescueUpdatedEvent).row['status'], '対応中');

              await sub1.cancel();
              await sub2.cancel();
            } finally {
              await ds.dispose();
            }
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, f) {
              final timer = parent.createTimer(zone, duration, f);
              createdTimers.add(timer);
              return timer;
            },
            createPeriodicTimer: (self, parent, zone, period, f) {
              final timer = parent.createPeriodicTimer(zone, period, f);
              createdTimers.add(timer);
              return timer;
            },
          ),
        );

        await pumpEventQueue(times: 20);
        expect(createdTimers, isNotEmpty);
        expect(createdTimers.where((t) => t.isActive), isEmpty);
      },
    );

    test(
      're-subscribing right after unawaited(sub1.cancel()) succeeds with zero leaked timers',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        WebSocket? activeSocket;
        var joinCount = 0;
        final firstJoin = Completer<void>();
        final secondJoin = Completer<void>();

        server.listen((HttpRequest req) async {
          if (req.uri.path.startsWith('/realtime/v1/websocket') &&
              WebSocketTransformer.isUpgradeRequest(req)) {
            final socket = await WebSocketTransformer.upgrade(req);
            activeSocket = socket;
            socket.listen((dynamic raw) {
              final decoded = jsonDecode(raw as String);
              final String? joinRef;
              final String? ref;
              final String topic;
              final String event;
              final Map<String, dynamic> payload;
              if (decoded is List) {
                joinRef = decoded[0]?.toString();
                ref = decoded[1]?.toString();
                topic = decoded[2] as String;
                event = decoded[3] as String;
                payload = Map<String, dynamic>.from(decoded[4] as Map);
              } else {
                final map = decoded as Map<String, dynamic>;
                joinRef = map['join_ref']?.toString();
                ref = map['ref']?.toString();
                topic = map['topic'] as String;
                event = map['event'] as String;
                payload = Map<String, dynamic>.from(map['payload'] as Map);
              }

              void sendReply(Map<String, dynamic> replyPayload) {
                if (decoded is List) {
                  socket.add(
                    jsonEncode([joinRef, ref, topic, 'phx_reply', replyPayload]),
                  );
                } else {
                  socket.add(
                    jsonEncode({
                      'topic': topic,
                      'event': 'phx_reply',
                      'ref': ref,
                      'payload': replyPayload,
                    }),
                  );
                }
              }

              if (event == 'phx_join') {
                joinCount++;
                final config = payload['config'] as Map<String, dynamic>;
                final pgBindings = (config['postgres_changes'] as List)
                    .cast<Map<String, dynamic>>();
                final serverFilters = [
                  for (var i = 0; i < pgBindings.length; i++)
                    {
                      'id': i + 1,
                      'event': pgBindings[i]['event'],
                      'schema': pgBindings[i]['schema'],
                      'table': pgBindings[i]['table'],
                    },
                ];
                sendReply({
                  'status': 'ok',
                  'response': {'postgres_changes': serverFilters},
                });
                if (joinCount == 1 && !firstJoin.isCompleted) {
                  firstJoin.complete();
                } else if (joinCount == 2 && !secondJoin.isCompleted) {
                  secondJoin.complete();
                }
              } else if (event == 'phx_leave') {
                sendReply({'status': 'ok', 'response': {}});
              } else if (event == 'heartbeat') {
                sendReply({'status': 'ok', 'response': {}});
              }
            });
            return;
          }

          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final createdTimers = <Timer>[];
        await runZoned(
          () async {
            final ds = SupabaseRescueDataSource(
              config: SupabaseConfig(
                url: 'http://127.0.0.1:${server.port}',
                publishableKey: SupabaseConfig.exhibition.publishableKey,
              ),
            );
            try {
              final connected1 = Completer<bool>();
              final sub1 = ds
                  .subscribeRequests(
                    onConnectionChanged: (connected) {
                      if (connected && !connected1.isCompleted) {
                        connected1.complete(true);
                      }
                    },
                  )
                  .listen((_) {});

              await firstJoin.future.timeout(const Duration(seconds: 5));
              expect(
                await connected1.future.timeout(const Duration(seconds: 5)),
                isTrue,
              );

              // unawaited(sub1.cancel()) の直後に再購読する
              unawaited(sub1.cancel());
              final events2 = <RescueRealtimeEvent>[];
              final connected2 = Completer<bool>();
              final sub2 = ds
                  .subscribeRequests(
                    onConnectionChanged: (connected) {
                      if (connected && !connected2.isCompleted) {
                        connected2.complete(true);
                      }
                    },
                  )
                  .listen(events2.add);

              await secondJoin.future.timeout(const Duration(seconds: 5));
              expect(
                await connected2.future.timeout(const Duration(seconds: 5)),
                isTrue,
              );

              activeSocket!.add(
                jsonEncode([
                  null,
                  null,
                  'realtime:mamo-rescue-live',
                  'postgres_changes',
                  {
                    'ids': [1],
                    'data': {
                      'schema': 'public',
                      'table': 'rescue_requests',
                      'commit_timestamp': '2026-11-24T00:00:02Z',
                      'type': 'INSERT',
                      'columns': [],
                      'record': {
                        'id': 202,
                        'request_id': 'MAMO-202',
                        'status': '未対応',
                      },
                    },
                  },
                ]),
              );
              activeSocket!.add(
                jsonEncode([
                  null,
                  null,
                  'realtime:mamo-rescue-live',
                  'postgres_changes',
                  {
                    'ids': [2],
                    'data': {
                      'schema': 'public',
                      'table': 'rescue_requests',
                      'commit_timestamp': '2026-11-24T00:00:03Z',
                      'type': 'UPDATE',
                      'columns': [],
                      'record': {'id': 202, 'status': '対応済み'},
                      'old_record': {'id': 202},
                    },
                  },
                ]),
              );

              await pumpEventQueue(times: 30);
              await Future<void>.delayed(const Duration(milliseconds: 50));

              expect(events2.length, 2);
              expect(events2[0], isA<RescueInsertedEvent>());
              expect((events2[0] as RescueInsertedEvent).row['id'], 202);
              expect(events2[1], isA<RescueUpdatedEvent>());
              expect((events2[1] as RescueUpdatedEvent).row['status'], '対応済み');

              // unawaited(sub2.cancel()) 後に即座に dispose() しても保留タイマーが残らないこと
              unawaited(sub2.cancel());
            } finally {
              await ds.dispose();
            }
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, f) {
              final timer = parent.createTimer(zone, duration, f);
              createdTimers.add(timer);
              return timer;
            },
            createPeriodicTimer: (self, parent, zone, period, f) {
              final timer = parent.createPeriodicTimer(zone, period, f);
              createdTimers.add(timer);
              return timer;
            },
          ),
        );

        await pumpEventQueue(times: 20);
        expect(createdTimers, isNotEmpty);
        expect(createdTimers.where((t) => t.isActive), isEmpty);
      },
    );
  });
}
