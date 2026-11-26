import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mamo_cross/models/citizen_models.dart';
import 'package:mamo_cross/models/rescue_request.dart';
import 'package:mamo_cross/services/address_geocoder.dart';
import 'package:mamo_cross/services/rescue_data_source.dart';
import 'package:mamo_cross/state/citizen_store.dart';
import 'package:mamo_cross/state/rescue_store.dart';

class _StubRescueDataSource implements RescueDataSource {
  final List<Map<String, dynamic>> insertedPayloads = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> fetchInitialRequests({
    int limit = 50,
  }) async =>
      const [];

  @override
  Stream<RescueRealtimeEvent> subscribeRequests({
    void Function(bool connected)? onConnectionChanged,
  }) =>
      const Stream.empty();

  @override
  Future<void> updateStatus({
    required String dbId,
    required RequestStatus status,
  }) async {}

  @override
  Future<Map<String, dynamic>?> insertRequest(
    Map<String, dynamic> payload,
  ) async {
    insertedPayloads.add(Map<String, dynamic>.from(payload));
    return <String, dynamic>{
      'id': 501,
      ...payload,
    };
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('AddressGeocoder', () {
    test('normalizeQuery strips postal code, demo/suffix words, and skips placeholders', () {
      expect(
        AddressGeocoder.normalizeQuery('〒753-0001 山口県山口市亀山町2-1付近'),
        '山口県山口市亀山町2-1',
      );
      expect(
        AddressGeocoder.normalizeQuery('山口県萩市大字江向510周辺（デモ）'),
        '山口県萩市大字江向510',
      );
      expect(AddressGeocoder.normalizeQuery('〇〇地区付近'), '');
      expect(AddressGeocoder.normalizeQuery('○○市○○町1-2-3付近'), '');
      expect(AddressGeocoder.normalizeQuery('位置情報'), '');
      expect(AddressGeocoder.normalizeQuery('   '), '');
    });

    test('geocode parses [lng, lat] from GSI GeoJSON and caches results', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        expect(request.url.queryParameters['q'], '山口県山口市湯田温泉1-1-1');
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'Feature',
              'geometry': <String, dynamic>{
                'type': 'Point',
                'coordinates': <double>[131.460281, 34.166466],
              },
            },
          ]),
          200,
        );
      });
      final geocoder = AddressGeocoder(client: client);
      addTearDown(geocoder.dispose);

      final first = await geocoder.geocode('山口県山口市湯田温泉1-1-1付近');
      expect(first, isNotNull);
      expect(first!.latitude, closeTo(34.166466, 0.000001));
      expect(first.longitude, closeTo(131.460281, 0.000001));

      final second = await geocoder.geocode('山口県山口市湯田温泉1-1-1');
      expect(second, equals(first));
      expect(callCount, 1);
    });

    test('geocode returns null on HTTP error, empty result, or invalid coordinates', () async {
      final client = MockClient((request) async {
        final q = request.url.queryParameters['q'];
        if (q == 'エラー住所') {
          return http.Response('error', 500);
        }
        if (q == '範囲外住所') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'geometry': <String, dynamic>{
                  'coordinates': <double>[200.0, 95.0],
                },
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });
      final geocoder = AddressGeocoder(client: client);
      addTearDown(geocoder.dispose);

      expect(await geocoder.geocode('エラー住所'), isNull);
      expect(await geocoder.geocode('範囲外住所'), isNull);
      expect(await geocoder.geocode('存在しない住所'), isNull);
    });
  });

  group('RescueStore & CitizenStore address coordinate integration', () {
    test('addDbRequest refines fallback coordinates via AddressGeocoder when DB coords are null', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'geometry': <String, dynamic>{
                'coordinates': <double>[131.394684, 34.098232],
              },
            },
          ]),
          200,
        );
      });
      final geocoder = AddressGeocoder(client: client);
      final store = RescueStore(startClock: false, geocoder: geocoder);
      addTearDown(store.dispose);
      addTearDown(geocoder.dispose);

      store.addDbRequest(<String, dynamic>{
        'id': 12,
        'request_id': 'MAMO-OGORI',
        'requester_name': 'テスト 太郎',
        'location_text': '山口県山口市小郡下郷',
        'status': '未対応',
      });

      // 初期状態は山口市代表座標
      expect(store.requests.single.latitude, closeTo(34.1785, 0.0001));
      expect(store.requests.single.longitude, closeTo(131.4737, 0.0001));

      await pumpEventQueue();

      // 非同期ジオコーディング完了後は小郡下郷の座標へ更新される
      expect(store.requests.single.latitude, closeTo(34.098232, 0.000001));
      expect(store.requests.single.longitude, closeTo(131.394684, 0.000001));
    });

    test('CitizenStore.submitRescue uses registered address and saves geocoded coordinates', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'geometry': <String, dynamic>{
                'coordinates': <double>[131.460281, 34.166466],
              },
            },
          ]),
          200,
        );
      });
      final geocoder = AddressGeocoder(client: client);
      final ds = _StubRescueDataSource();
      final rescueStore = RescueStore(
        startClock: false,
        dataSource: ds,
        autoInitialize: false,
        geocoder: geocoder,
      );
      final citizenStore = CitizenStore();
      addTearDown(rescueStore.dispose);
      addTearDown(citizenStore.dispose);
      addTearDown(geocoder.dispose);

      citizenStore.updateBasicInfo(
        name: '湯田 花子',
        postalCode: '753-0056',
        prefecture: '山口県',
        addressDetail: '山口市湯田温泉1-1-1',
      );
      citizenStore.openRescue();
      expect(citizenStore.rescueLocationDraft, '山口県山口市湯田温泉1-1-1');

      final submitted = await citizenStore.submitRescue(
        rescueStore,
        detail: '浸水で動けません',
      );

      expect(submitted.location, '山口県山口市湯田温泉1-1-1');
      expect(submitted.latitude, closeTo(34.166466, 0.000001));
      expect(submitted.longitude, closeTo(131.460281, 0.000001));
      expect(ds.insertedPayloads, hasLength(1));
      expect(ds.insertedPayloads.single['location_text'], '山口県山口市湯田温泉1-1-1');
      expect(ds.insertedPayloads.single['latitude'], closeTo(34.166466, 0.000001));
      expect(ds.insertedPayloads.single['longitude'], closeTo(131.460281, 0.000001));
      expect(citizenStore.latestRescueSummary?.locationText, '山口県山口市湯田温泉1-1-1');
    });

    test('buildCitizenRescuePayload omits latitude/longitude unless explicitly given', () {
      final base = buildCitizenRescuePayload(
        requestId: 'MAMO-1',
        createdAt: DateTime.utc(2026, 11, 26),
        requesterName: '山田',
        rescueDetails: '詳細',
        considerations: 'なし',
      );
      expect(base.length, 15);
      expect(base.containsKey('latitude'), isFalse);
      expect(base.containsKey('longitude'), isFalse);

      final withCoords = buildCitizenRescuePayload(
        requestId: 'MAMO-2',
        createdAt: DateTime.utc(2026, 11, 26),
        requesterName: '山田',
        rescueDetails: '詳細',
        considerations: 'なし',
        latitude: 34.166466,
        longitude: 131.460281,
      );
      expect(withCoords.length, 17);
      expect(withCoords['latitude'], 34.166466);
      expect(withCoords['longitude'], 131.460281);
    });
  });
}
