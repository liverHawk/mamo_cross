import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamo_cross/config/supabase_config.dart';
import 'package:mamo_cross/models/citizen_models.dart';
import 'package:mamo_cross/services/auth_service.dart';
import 'package:mamo_cross/services/supabase_citizen_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _encodeDummyJwt() {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode('{"sub":"anon-user-1","exp":1999999999}'),
  );
  return '$header.$payload.sig';
}

Map<String, dynamic> _fakeAuthSessionPayload(String userId) {
  return <String, dynamic>{
    'access_token': _encodeDummyJwt(),
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'refresh-token-1',
    'user': <String, dynamic>{
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'created_at': '2026-11-25T00:00:00Z',
      'is_anonymous': true,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
    },
  };
}

void main() {
  group('SupabaseCitizenDataSource loopback tests', () {
    test(
      'fetchMessages filters by groupId (or notices only), orders desc limit 100, and reverses to chronological order',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        final requests = <Uri>[];
        server.listen((HttpRequest req) async {
          await utf8.decoder.bind(req).drain<void>();
          requests.add(req.uri);
          if (req.method == 'GET' && req.uri.path == '/rest/v1/messages') {
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode([
                  {
                    'id': 'msg-new',
                    'kind': 'family_thread',
                    'group_id': 'grp_1',
                    'sender_id': 'u1',
                    'sender_name': 'あなた',
                    'avatar': '🙂',
                    'body': '新しいメッセージ',
                    'is_important': false,
                    'created_at': '2026-11-25T10:05:00Z',
                  },
                  {
                    'id': 'msg-old',
                    'kind': 'municipality_notice',
                    'sender_name': '〇〇市',
                    'avatar': '🏛️',
                    'body': '古いお知らせ',
                    'is_important': true,
                    'created_at': '2026-11-25T10:00:00Z',
                  },
                ]),
              );
            await req.response.close();
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final ds = SupabaseCitizenDataSource(
          config: SupabaseConfig(
            url: 'http://127.0.0.1:${server.port}',
            publishableKey: SupabaseConfig.exhibition.publishableKey,
          ),
        );
        addTearDown(ds.dispose);

        // 1) groupId あり
        final withGroup = await ds.fetchMessages(
          groupId: 'grp_1',
          currentUserId: 'u1',
        );
        expect(requests.last.queryParameters['or'],
            '(kind.eq.municipality_notice,and(kind.eq.family_thread,group_id.eq.grp_1))');
        expect(
          requests.last.queryParameters['order'],
          'created_at.desc.nullslast,id.desc.nullslast',
        );
        expect(requests.last.queryParameters['limit'], '100');
        expect(withGroup.map((m) => m.id).toList(), ['msg-old', 'msg-new']);
        expect(withGroup[1].isMine, isTrue);

        // 2) groupId なし、および不正文字を含む groupId は municipality_notice のみ
        await ds.fetchMessages(groupId: null);
        expect(requests.last.queryParameters['kind'], 'eq.municipality_notice');
        expect(requests.last.queryParameters.containsKey('or'), isFalse);

        await ds.fetchMessages(groupId: 'bad,id)');
        expect(requests.last.queryParameters['kind'], 'eq.municipality_notice');
        expect(requests.last.queryParameters.containsKey('or'), isFalse);
      },
    );

    test(
      'subscribeMessages registers dual bindings and drops other-group family_thread events',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        WebSocket? activeSocket;
        List<Map<String, dynamic>>? joinedBindings;
        final joined = Completer<void>();

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
                joinedBindings = (config['postgres_changes'] as List)
                    .cast<Map<String, dynamic>>();
                final serverFilters = [
                  for (var i = 0; i < joinedBindings!.length; i++)
                    {
                      'id': i + 1,
                      'event': joinedBindings![i]['event'],
                      'schema': joinedBindings![i]['schema'],
                      'table': joinedBindings![i]['table'],
                      if (joinedBindings![i].containsKey('filter'))
                        'filter': joinedBindings![i]['filter'],
                    },
                ];
                sendReply({
                  'status': 'ok',
                  'response': {'postgres_changes': serverFilters},
                });
                if (!joined.isCompleted) joined.complete();
              } else if (event == 'heartbeat' || event == 'phx_leave') {
                sendReply({'status': 'ok', 'response': {}});
              }
            });
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final ds = SupabaseCitizenDataSource(
          config: SupabaseConfig(
            url: 'http://127.0.0.1:${server.port}',
            publishableKey: SupabaseConfig.exhibition.publishableKey,
          ),
        );
        addTearDown(ds.dispose);

        final received = <CitizenMessage>[];
        final sub = ds
            .subscribeMessages(groupId: 'grp-1', currentUserId: 'u1')
            .listen(received.add);
        addTearDown(sub.cancel);

        await joined.future.timeout(const Duration(seconds: 5));
        expect(joinedBindings, hasLength(2));
        expect(joinedBindings![0]['filter'], 'kind=eq.municipality_notice');
        expect(joinedBindings![1]['filter'], 'group_id=eq.grp-1');

        // 他グループの family_thread イベントはコールバック内の防御検証で破棄される
        activeSocket!.add(
          jsonEncode([
            null,
            null,
            'realtime:mamo-messages-grp-1',
            'postgres_changes',
            {
              'ids': [2],
              'data': {
                'schema': 'public',
                'table': 'messages',
                'commit_timestamp': '2026-11-25T00:00:00Z',
                'type': 'INSERT',
                'columns': [],
                'record': {
                  'id': 'm-other',
                  'kind': 'family_thread',
                  'group_id': 'grp-other',
                  'sender_name': '他人',
                  'body': '漏洩してはいけないメッセージ',
                },
              },
            },
          ]),
        );

        // 自治体お知らせと自グループメッセージは受信する
        activeSocket!.add(
          jsonEncode([
            null,
            null,
            'realtime:mamo-messages-grp-1',
            'postgres_changes',
            {
              'ids': [1],
              'data': {
                'schema': 'public',
                'table': 'messages',
                'commit_timestamp': '2026-11-25T00:00:01Z',
                'type': 'INSERT',
                'columns': [],
                'record': {
                  'id': 'm-notice',
                  'kind': 'municipality_notice',
                  'sender_name': '〇〇市',
                  'body': '避難情報',
                },
              },
            },
          ]),
        );
        activeSocket!.add(
          jsonEncode([
            null,
            null,
            'realtime:mamo-messages-grp-1',
            'postgres_changes',
            {
              'ids': [2],
              'data': {
                'schema': 'public',
                'table': 'messages',
                'commit_timestamp': '2026-11-25T00:00:02Z',
                'type': 'INSERT',
                'columns': [],
                'record': {
                  'id': 'm-family',
                  'kind': 'family_thread',
                  'group_id': 'grp-1',
                  'sender_id': 'u1',
                  'sender_name': 'あなた',
                  'body': '無事です',
                },
              },
            },
          ]),
        );

        await pumpEventQueue(times: 30);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(received.map((m) => m.id).toList(), ['m-notice', 'm-family']);
      },
    );

    test(
      'fetchOrCreateDefaultFamilyGroup orders memberships and calls create_default_family_group RPC; joinFamilyGroupByCode distinguishes not-found from HTTP 500',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        final calls = <({String method, Uri uri, String body})>[];
        var returnMembership = false;
        var joinStatusCode = HttpStatus.badRequest;
        var joinErrorMessage = 'Family group not found for invite code';

        server.listen((HttpRequest req) async {
          final body = await utf8.decoder.bind(req).join();
          calls.add((method: req.method, uri: req.uri, body: body));

          if (req.method == 'GET' && req.uri.path == '/rest/v1/family_members') {
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode(
                  returnMembership
                      ? [
                          {'group_id': 'grp-existing'},
                        ]
                      : [],
                ),
              );
            await req.response.close();
            return;
          }

          if (req.method == 'GET' && req.uri.path == '/rest/v1/family_groups') {
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'id': 'grp-existing',
                  'name': '既存グループ',
                  'invite_code': 'EX1234',
                }),
              );
            await req.response.close();
            return;
          }

          if (req.method == 'POST' &&
              req.uri.path == '/rest/v1/rpc/create_default_family_group') {
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'id': 'grp-created',
                  'name': 'マイ家族グループ',
                  'invite_code': 'NEW999',
                }),
              );
            await req.response.close();
            return;
          }

          if (req.method == 'POST' &&
              req.uri.path == '/rest/v1/rpc/join_family_group_by_code') {
            req.response
              ..statusCode = joinStatusCode
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'code': 'P0001',
                  'message': joinErrorMessage,
                }),
              );
            await req.response.close();
            return;
          }

          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final ds = SupabaseCitizenDataSource(
          config: SupabaseConfig(
            url: 'http://127.0.0.1:${server.port}',
            publishableKey: SupabaseConfig.exhibition.publishableKey,
          ),
        );
        addTearDown(ds.dispose);

        // 1) 未所属時は RPC 呼び出し
        final created = await ds.fetchOrCreateDefaultFamilyGroup(
          userId: 'user-1',
          displayName: '山田太郎',
        );
        expect(created?.id, 'grp-created');
        expect(created?.inviteCode, 'NEW999');

        final memberQuery = calls.firstWhere(
          (c) => c.uri.path == '/rest/v1/family_members',
        );
        expect(
          memberQuery.uri.queryParameters['order'],
          'joined_at.desc.nullslast,safety_updated_at.desc.nullslast',
        );
        expect(memberQuery.uri.queryParameters['limit'], '1');

        final rpcCall = calls.firstWhere(
          (c) => c.uri.path == '/rest/v1/rpc/create_default_family_group',
        );
        expect(jsonDecode(rpcCall.body), {
          'p_group_name': 'マイ家族グループ',
          'p_display_name': '山田太郎',
          'p_avatar': '🙂',
        });

        // 2) 所属済み時は既存グループを返却
        returnMembership = true;
        final existing = await ds.fetchOrCreateDefaultFamilyGroup(
          userId: 'user-1',
          displayName: '山田太郎',
        );
        expect(existing?.id, 'grp-existing');
        expect(existing?.inviteCode, 'EX1234');

        // 3) joinFamilyGroupByCode: not found は null、HTTP 500 は例外再スロー
        final notFound = await ds.joinFamilyGroupByCode(
          inviteCode: 'XXXXXX',
          displayName: '山田太郎',
        );
        expect(notFound, isNull);

        joinStatusCode = HttpStatus.internalServerError;
        joinErrorMessage = 'Database connection failed';
        await expectLater(
          () => ds.joinFamilyGroupByCode(
            inviteCode: 'XXXXXX',
            displayName: '山田太郎',
          ),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    test(
      'dispose closes all StreamControllers, removes channels, and leaves zero leaked timers',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        var joinCount = 0;
        final allJoined = Completer<void>();

        server.listen((HttpRequest req) async {
          if (req.uri.path.startsWith('/realtime/v1/websocket') &&
              WebSocketTransformer.isUpgradeRequest(req)) {
            final socket = await WebSocketTransformer.upgrade(req);
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
                sendReply({
                  'status': 'ok',
                  'response': {
                    'postgres_changes': [
                      for (var i = 0; i < pgBindings.length; i++)
                        {
                          'id': i + 1,
                          'event': pgBindings[i]['event'],
                          'schema': pgBindings[i]['schema'],
                          'table': pgBindings[i]['table'],
                        },
                    ],
                  },
                });
                if (joinCount >= 3 && !allJoined.isCompleted) {
                  allJoined.complete();
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

        // 1) _ownedClient パスでの全 StreamController クローズ & タイマーリーク 0 検証
        final createdTimers = <Timer>[];
        await runZoned(
          () async {
            final ds = SupabaseCitizenDataSource(
              config: SupabaseConfig(
                url: 'http://127.0.0.1:${server.port}',
                publishableKey: SupabaseConfig.exhibition.publishableKey,
              ),
            );
            var doneCount = 0;
            ds.subscribeFamilyMembers('grp-1').listen((_) {}, onDone: () {
              doneCount++;
            });
            ds.subscribeMessages(groupId: 'grp-1').listen((_) {}, onDone: () {
              doneCount++;
            });
            ds.subscribeShelters().listen((_) {}, onDone: () {
              doneCount++;
            });

            await allJoined.future.timeout(const Duration(seconds: 5));
            await ds.dispose();
            await pumpEventQueue(times: 20);
            expect(doneCount, 3);
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, f) {
              final t = parent.createTimer(zone, duration, f);
              createdTimers.add(t);
              return t;
            },
            createPeriodicTimer: (self, parent, zone, period, f) {
              final t = parent.createPeriodicTimer(zone, period, f);
              createdTimers.add(t);
              return t;
            },
          ),
        );

        await pumpEventQueue(times: 20);
        expect(createdTimers, isNotEmpty);
        expect(createdTimers.where((t) => t.isActive), isEmpty);
      },
    );

    test(
      'dispose removes channels from injected/shared client without disposing the client itself',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        var joinCount = 0;
        var leaveCount = 0;
        final allJoined = Completer<void>();
        final allLeft = Completer<void>();

        server.listen((HttpRequest req) async {
          if (req.uri.path.startsWith('/realtime/v1/websocket') &&
              WebSocketTransformer.isUpgradeRequest(req)) {
            final socket = await WebSocketTransformer.upgrade(req);
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
                sendReply({
                  'status': 'ok',
                  'response': {
                    'postgres_changes': [
                      for (var i = 0; i < pgBindings.length; i++)
                        {
                          'id': i + 1,
                          'event': pgBindings[i]['event'],
                          'schema': pgBindings[i]['schema'],
                          'table': pgBindings[i]['table'],
                        },
                    ],
                  },
                });
                if (joinCount >= 3 && !allJoined.isCompleted) {
                  allJoined.complete();
                }
              } else if (event == 'phx_leave') {
                leaveCount++;
                sendReply({'status': 'ok', 'response': {}});
                if (leaveCount >= 3 && !allLeft.isCompleted) {
                  allLeft.complete();
                }
              } else if (event == 'heartbeat') {
                sendReply({'status': 'ok', 'response': {}});
              }
            });
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final sharedClient = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          SupabaseConfig.exhibition.publishableKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
          realtimeClientOptions: const RealtimeClientOptions(
            connectionCloseTimeout: Duration.zero,
          ),
        );
        addTearDown(sharedClient.dispose);

        final injectedDs = SupabaseCitizenDataSource(client: sharedClient);
        var injectedDone = 0;
        injectedDs.subscribeFamilyMembers('grp-2').listen((_) {}, onDone: () {
          injectedDone++;
        });
        injectedDs.subscribeMessages(groupId: 'grp-2').listen((_) {}, onDone: () {
          injectedDone++;
        });
        injectedDs.subscribeShelters().listen((_) {}, onDone: () {
          injectedDone++;
        });

        await allJoined.future.timeout(const Duration(seconds: 5));
        expect(joinCount, 3);

        await injectedDs.dispose();
        await allLeft.future.timeout(const Duration(seconds: 5));
        await pumpEventQueue(times: 20);
        expect(injectedDone, 3);
        expect(leaveCount, 3);
        expect(sharedClient.realtime.getChannels(), isEmpty);
      },
    );
  });

  group('SupabaseAuthService loopback tests', () {
    test(
      'serializes concurrent ensureAnonymousSession calls and signOut after in-flight signIn',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        var signupCount = 0;
        var logoutCount = 0;
        final signupStarted = Completer<void>();
        final releaseSignup = Completer<void>();

        server.listen((HttpRequest req) async {
          await utf8.decoder.bind(req).drain<void>();
          if (req.method == 'POST' && req.uri.path == '/auth/v1/signup') {
            signupCount++;
            if (signupCount == 1 && !signupStarted.isCompleted) {
              signupStarted.complete();
              await releaseSignup.future;
            }
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_fakeAuthSessionPayload('anon-user-$signupCount')));
            await req.response.close();
            return;
          }
          if (req.method == 'POST' && req.uri.path == '/auth/v1/logout') {
            logoutCount++;
            req.response.statusCode = HttpStatus.noContent;
            await req.response.close();
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          SupabaseConfig.exhibition.publishableKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);

        final authService = SupabaseAuthService(clientResolver: () => client);
        addTearDown(authService.dispose);

        final emittedUserIds = <String?>[];
        final sub = authService.userIdChanges.listen(emittedUserIds.add);
        addTearDown(sub.cancel);

        // 1) 並行 ensureAnonymousSession() は 1 回だけ /auth/v1/signup を叩き、同じ userId を返す
        final f1 = authService.ensureAnonymousSession();
        final f2 = authService.ensureAnonymousSession();
        await signupStarted.future.timeout(const Duration(seconds: 5));
        releaseSignup.complete();

        final results = await Future.wait([f1, f2]);
        expect(results, ['anon-user-1', 'anon-user-1']);
        expect(signupCount, 1);
        expect(authService.currentUserId, 'anon-user-1');

        await authService.signOut();
        await pumpEventQueue(times: 20);
        expect(logoutCount, 1);
        expect(authService.currentUserId, isNull);
        expect(emittedUserIds, containsAllInOrder(['anon-user-1', null]));
      },
    );

    test(
      'ensureAnonymousSession waits for in-flight signOut before creating a new session',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        var signupCount = 0;
        var logoutCount = 0;
        final logoutStarted = Completer<void>();
        final releaseLogout = Completer<void>();

        server.listen((HttpRequest req) async {
          await utf8.decoder.bind(req).drain<void>();
          if (req.method == 'POST' && req.uri.path == '/auth/v1/signup') {
            signupCount++;
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_fakeAuthSessionPayload('anon-user-$signupCount')));
            await req.response.close();
            return;
          }
          if (req.method == 'POST' && req.uri.path == '/auth/v1/logout') {
            logoutCount++;
            if (!logoutStarted.isCompleted) {
              logoutStarted.complete();
              await releaseLogout.future;
            }
            req.response.statusCode = HttpStatus.noContent;
            await req.response.close();
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          SupabaseConfig.exhibition.publishableKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);

        final authService = SupabaseAuthService(clientResolver: () => client);
        addTearDown(authService.dispose);

        final firstUid = await authService.ensureAnonymousSession();
        expect(firstUid, 'anon-user-1');
        expect(signupCount, 1);

        // signOut() 開始（/auth/v1/logout 応答待ちで停止）
        final signOutFuture = authService.signOut();
        await logoutStarted.future.timeout(const Duration(seconds: 5));

        // signOut 完了前に ensureAnonymousSession() を直接呼んでも、signup はまだ走らない
        final secondFuture = authService.ensureAnonymousSession();
        await pumpEventQueue(times: 20);
        expect(signupCount, 1);

        releaseLogout.complete();
        await signOutFuture;
        final secondUid = await secondFuture;

        expect(logoutCount, 1);
        expect(signupCount, 2);
        expect(secondUid, 'anon-user-2');
        expect(authService.currentUserId, 'anon-user-2');
      },
    );

    test(
      'signOut handles null client without LateInitializationError and does not block subsequent ensureAnonymousSession',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        server.listen((HttpRequest req) async {
          await utf8.decoder.bind(req).drain<void>();
          if (req.method == 'POST' && req.uri.path == '/auth/v1/signup') {
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_fakeAuthSessionPayload('anon-user-after-null')));
            await req.response.close();
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final loopbackClient = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          SupabaseConfig.exhibition.publishableKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(loopbackClient.dispose);

        SupabaseClient? activeClient;
        final authService = SupabaseAuthService(
          clientResolver: () => activeClient,
        );
        addTearDown(authService.dispose);

        // client == null 時の単発・連続 signOut が LateInitializationError なく完了すること
        await expectLater(
          authService.signOut().timeout(const Duration(seconds: 2)),
          completes,
        );
        await expectLater(
          Future.wait([
            authService.signOut(),
            authService.signOut(),
          ]).timeout(const Duration(seconds: 2)),
          completes,
        );

        // client == null のまま ensureAnonymousSession() は null を返すこと
        final uidWhileNull = await authService
            .ensureAnonymousSession()
            .timeout(const Duration(seconds: 2));
        expect(uidWhileNull, isNull);

        // 後から有効な client を設定しても _inFlightSignOut 残留でハングせず成功すること
        activeClient = loopbackClient;
        final uidAfter = await authService
            .ensureAnonymousSession()
            .timeout(const Duration(seconds: 2));
        expect(uidAfter, 'anon-user-after-null');
      },
    );

    test(
      'signOut after dispose completes cleanly without network calls and subsequent ensureAnonymousSession returns null',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        var signupCount = 0;
        var logoutCount = 0;
        server.listen((HttpRequest req) async {
          await utf8.decoder.bind(req).drain<void>();
          if (req.method == 'POST' && req.uri.path == '/auth/v1/signup') {
            signupCount++;
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_fakeAuthSessionPayload('anon-user-$signupCount')));
            await req.response.close();
            return;
          }
          if (req.method == 'POST' && req.uri.path == '/auth/v1/logout') {
            logoutCount++;
            req.response.statusCode = HttpStatus.noContent;
            await req.response.close();
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          SupabaseConfig.exhibition.publishableKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);

        final authService = SupabaseAuthService(clientResolver: () => client);
        addTearDown(authService.dispose);

        final uid = await authService.ensureAnonymousSession();
        expect(uid, 'anon-user-1');
        expect(signupCount, 1);

        authService.dispose();

        await expectLater(
          authService.signOut().timeout(const Duration(seconds: 2)),
          completes,
        );
        await expectLater(
          authService.signOut().timeout(const Duration(seconds: 2)),
          completes,
        );
        final uidAfterDispose = await authService
            .ensureAnonymousSession()
            .timeout(const Duration(seconds: 2));
        expect(uidAfterDispose, isNull);
        expect(logoutCount, 0);
        expect(signupCount, 1);
      },
    );

    test(
      'concurrent signOut calls serialize cleanly and allow subsequent ensureAnonymousSession',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        var signupCount = 0;
        final logoutStarted = Completer<void>();
        final releaseLogout = Completer<void>();
        server.listen((HttpRequest req) async {
          await utf8.decoder.bind(req).drain<void>();
          if (req.method == 'POST' && req.uri.path == '/auth/v1/signup') {
            signupCount++;
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_fakeAuthSessionPayload('anon-user-$signupCount')));
            await req.response.close();
            return;
          }
          if (req.method == 'POST' && req.uri.path == '/auth/v1/logout') {
            if (!logoutStarted.isCompleted) {
              logoutStarted.complete();
              await releaseLogout.future;
            }
            req.response.statusCode = HttpStatus.noContent;
            await req.response.close();
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          SupabaseConfig.exhibition.publishableKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);

        final authService = SupabaseAuthService(clientResolver: () => client);
        addTearDown(authService.dispose);

        expect(await authService.ensureAnonymousSession(), 'anon-user-1');

        final s1 = authService.signOut();
        await logoutStarted.future.timeout(const Duration(seconds: 5));
        final s2 = authService.signOut();

        releaseLogout.complete();
        await Future.wait([s1, s2]).timeout(const Duration(seconds: 5));

        final nextUid = await authService
            .ensureAnonymousSession()
            .timeout(const Duration(seconds: 2));
        expect(nextUid, 'anon-user-2');
      },
    );

    test(
      'clientResolver synchronous exception does not cause LateInitializationError and recovers cleanly',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        var signupCount = 0;
        server.listen((HttpRequest req) async {
          await utf8.decoder.bind(req).drain<void>();
          if (req.method == 'POST' && req.uri.path == '/auth/v1/signup') {
            signupCount++;
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_fakeAuthSessionPayload('anon-user-$signupCount')));
            await req.response.close();
            return;
          }
          if (req.method == 'POST' && req.uri.path == '/auth/v1/logout') {
            req.response.statusCode = HttpStatus.noContent;
            await req.response.close();
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          SupabaseConfig.exhibition.publishableKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);

        var shouldThrow = true;
        final authService = SupabaseAuthService(
          clientResolver: () {
            if (shouldThrow) {
              throw StateError('boom');
            }
            return client;
          },
        );
        addTearDown(authService.dispose);

        await expectLater(
          authService.signOut().timeout(const Duration(seconds: 2)),
          completes,
        );
        await expectLater(
          Future.wait([
            authService.signOut(),
            authService.signOut(),
          ]).timeout(const Duration(seconds: 2)),
          completes,
        );
        expect(
          await authService
              .ensureAnonymousSession()
              .timeout(const Duration(seconds: 2)),
          isNull,
        );

        shouldThrow = false;
        expect(
          await authService
              .ensureAnonymousSession()
              .timeout(const Duration(seconds: 2)),
          'anon-user-1',
        );
        await expectLater(
          authService.signOut().timeout(const Duration(seconds: 2)),
          completes,
        );
        expect(authService.currentUserId, isNull);
      },
    );

    test(
      'signOut and dispose during in-flight ensureAnonymousSession complete without hanging',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        final signupStarted = Completer<void>();
        final releaseSignup = Completer<void>();
        server.listen((HttpRequest req) async {
          await utf8.decoder.bind(req).drain<void>();
          if (req.method == 'POST' && req.uri.path == '/auth/v1/signup') {
            if (!signupStarted.isCompleted) {
              signupStarted.complete();
              await releaseSignup.future;
            }
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_fakeAuthSessionPayload('anon-user-1')));
            await req.response.close();
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });

        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          SupabaseConfig.exhibition.publishableKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);

        final authService = SupabaseAuthService(clientResolver: () => client);
        addTearDown(authService.dispose);

        final signInFuture = authService.ensureAnonymousSession();
        await signupStarted.future.timeout(const Duration(seconds: 5));

        final signOutFuture = authService.signOut();
        authService.dispose();

        releaseSignup.complete();
        expect(
          await signInFuture.timeout(const Duration(seconds: 5)),
          isNull,
        );
        await expectLater(
          signOutFuture.timeout(const Duration(seconds: 5)),
          completes,
        );
      },
    );
  });
}
