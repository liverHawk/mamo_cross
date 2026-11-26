import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 緯度・経度ペア（WGS84）
typedef GeoCoordinates = ({double latitude, double longitude});

/// 国土地理院 住所検索 API を用いた住所ジオコーダ
class AddressGeocoder {
  AddressGeocoder({
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
    this.enabled = true,
  }) : _injectedClient = client;

  static const String _endpoint =
      'https://msearch.gsi.go.jp/address-search/AddressSearch';

  final http.Client? _injectedClient;
  final Duration timeout;
  final bool enabled;

  http.Client? _ownedClient;
  final Map<String, GeoCoordinates?> _cache = <String, GeoCoordinates?>{};
  bool _disposed = false;

  /// ジオコーディングに適した検索クエリへ正規化する。
  ///
  /// プレースホルダ（`〇〇`, `○○` 等）や空文字の場合は空文字を返す。
  static String normalizeQuery(String rawAddress) {
    var text = rawAddress.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';

    // 郵便番号プレフィックス（〒123-4567 等）を除去
    text = text.replaceFirst(RegExp(r'^〒\s*\d{3}-?\d{4}\s*'), '').trim();

    // 末尾の装飾語（（デモ）・付近・周辺）を除去
    while (true) {
      final stripped = text
          .replaceFirst(RegExp(r'\s*[（(]デモ[)）]\s*$'), '')
          .replaceFirst(RegExp(r'\s*(?:付近|周辺)\s*$'), '')
          .trim();
      if (stripped == text) break;
      text = stripped;
    }

    if (text.length < 2) return '';
    if (text.contains('〇〇') ||
        text.contains('○○') ||
        text == '位置情報' ||
        text == '不明') {
      return '';
    }
    return text;
  }

  /// 住所文字列から緯度・経度を解決する（失敗・対象外時は null）。
  Future<GeoCoordinates?> geocode(String address) async {
    if (!enabled || _disposed) return null;
    final query = normalizeQuery(address);
    if (query.isEmpty) return null;

    if (_cache.containsKey(query)) {
      return _cache[query];
    }

    final client = _injectedClient ?? (_ownedClient ??= http.Client());
    try {
      final uri = Uri.parse(_endpoint).replace(
        queryParameters: <String, String>{'q': query},
      );
      final response = await client.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        _cache[query] = null;
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        _cache[query] = null;
        return null;
      }

      for (final item in decoded) {
        if (item is! Map) continue;
        final geometry = item['geometry'];
        if (geometry is! Map) continue;
        final coords = geometry['coordinates'];
        if (coords is! List || coords.length < 2) continue;

        final rawLng = coords[0];
        final rawLat = coords[1];
        final lng = rawLng is num ? rawLng.toDouble() : double.tryParse('$rawLng');
        final lat = rawLat is num ? rawLat.toDouble() : double.tryParse('$rawLat');
        if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
          continue;
        }
        if (lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0) {
          continue;
        }

        final resolved = (latitude: lat, longitude: lng);
        _cache[query] = resolved;
        return resolved;
      }

      _cache[query] = null;
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ownedClient?.close();
    _ownedClient = null;
  }
}
