import 'package:material_ui/material_ui.dart';

/// 救助要請の対応ステータス
enum RequestStatus {
  pending('未対応', Color(0xFFD84A43), Color(0xFFEFB4B0)),
  working('対応中', Color(0xFFB77900), Color(0xFFF0CE85)),
  done('対応済み', Color(0xFF23804A), Color(0xFF9FD0B4));

  const RequestStatus(this.label, this.textColor, this.borderColor);

  final String label;
  final Color textColor;
  final Color borderColor;
}

/// 連携関係機関
enum AgencyType {
  emergency('救急', Color(0xFFE13D35), '救急要請・傷病者情報', Icons.medical_services_rounded),
  fire('消防', Color(0xFFEF921E), '消防・救助活動情報', Icons.local_fire_department_rounded),
  police('警察', Color(0xFF1767C6), '警察への共有情報', Icons.local_police_rounded),
  sdf('自衛隊', Color(0xFF28A35A), '災害派遣・救助情報', Icons.shield_rounded);

  const AgencyType(this.label, this.color, this.description, this.icon);

  final String label;
  final Color color;
  final String description;
  final IconData icon;
}

/// サイドバーから切り替える主要ビュー
enum MamoView {
  dashboard('ダッシュボード', Icons.home_outlined),
  requests('救助要請一覧', Icons.assignment_outlined),
  map('位置情報マップ', Icons.my_location_outlined),
  partners('関係機関連携', Icons.grid_view_outlined),
  status('対応状況', Icons.fact_check_outlined),
  history('統計・履歴', Icons.bar_chart_outlined),
  settings('設定', Icons.settings_outlined);

  const MamoView(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 救助要請データモデル
class RescueRequest {
  /// デフォルト座標（山口県庁付近）
  static const double defaultLatitude = 34.1859;
  static const double defaultLongitude = 131.4706;

  static const Map<String, ({double latitude, double longitude})>
      _yamaguchiMunicipalityCoordinates = {
    // 13市
    '山口市': (latitude: 34.1785, longitude: 131.4737),
    '下関市': (latitude: 33.9578, longitude: 130.9415),
    '萩市': (latitude: 34.4081, longitude: 131.3991),
    '宇部市': (latitude: 33.9516, longitude: 131.2468),
    '岩国市': (latitude: 34.1666, longitude: 132.2200),
    '防府市': (latitude: 34.0558, longitude: 131.5646),
    '周南市': (latitude: 34.0556, longitude: 131.8061),
    '光市': (latitude: 33.9614, longitude: 131.9422),
    '長門市': (latitude: 34.3747, longitude: 131.1835),
    '柳井市': (latitude: 33.9639, longitude: 132.1016),
    '美祢市': (latitude: 34.1694, longitude: 131.2063),
    '山陽小野田市': (latitude: 33.9794, longitude: 131.1743),
    '下松市': (latitude: 34.0033, longitude: 131.8692),
    // 6町（各町役場付近の代表座標）
    '周防大島町': (latitude: 33.9276, longitude: 132.1952),
    '和木町': (latitude: 34.2024, longitude: 132.2202),
    '上関町': (latitude: 33.8309, longitude: 132.1104),
    '田布施町': (latitude: 33.9547, longitude: 132.0414),
    '平生町': (latitude: 33.9379, longitude: 132.0732),
    '阿武町': (latitude: 34.5033, longitude: 131.4714),
  };

  const RescueRequest({
    required this.id,
    required this.time,
    required this.name,
    required this.age,
    required this.gender,
    required this.agency,
    required this.location,
    required this.distance,
    required this.content,
    required this.consideration,
    required this.latPercent,
    required this.topPercent,
    this.latitude = defaultLatitude,
    this.longitude = defaultLongitude,
    required this.status,
    this.dbId,
  });

  final String id;
  final String time;
  final String name;
  final int age;
  final String gender;
  final AgencyType agency;
  final String location;
  final String distance;
  final String content;
  final String consideration;

  /// マップ横位置（0〜100%）
  final double latPercent;

  /// マップ縦位置（0〜100%）
  final double topPercent;

  /// 緯度（WGS84）
  final double latitude;

  /// 経度（WGS84）
  final double longitude;

  final RequestStatus status;
  final String? dbId;

  /// `public.rescue_requests` の行レコードから `RescueRequest` を生成（mamo-main/script.js 準拠）
  factory RescueRequest.fromSupabaseRow(Map<String, dynamic> row) {
    final rawDbId = row['id']?.toString().trim();
    final dbId = (rawDbId != null && rawDbId.isNotEmpty) ? rawDbId : null;
    final requestId = _firstNonEmpty([row['request_id']], '');
    final id = requestId.isNotEmpty ? requestId : 'DB-${dbId ?? ''}';
    final location = _firstNonEmpty(
      [row['location_text'], row['location']],
      '位置情報',
    );
    final coords =
        parseCoordinates(row) ?? resolveCoordinatesFromLocation(location);

    return RescueRequest(
      id: id,
      dbId: dbId,
      time: _formatRowTime(row['created_at']),
      name: _firstNonEmpty([row['requester_name'], row['user_name']], '不明'),
      age: int.tryParse('${row['age'] ?? ''}') ?? 0,
      gender: _firstNonEmpty([row['gender']], ''),
      agency: parseAgency(
        _firstNonEmpty([row['assigned_agency'], row['request_type']], ''),
      ),
      location: location,
      distance: _firstNonEmpty([row['distance_text'], row['distance']], ''),
      content: _firstNonEmpty([row['rescue_details'], row['detail']], '救助要請'),
      consideration: _firstNonEmpty(
        [row['considerations'], row['health_condition'], row['consideration']],
        'なし',
      ),
      latPercent: _parseDouble(row['lat_percent'], 50.0),
      topPercent: _parseDouble(row['top_percent'], 50.0),
      latitude: coords.latitude,
      longitude: coords.longitude,
      status: parseStatus(row['status']),
    );
  }

  /// DB レコードから緯度・経度（`latitude`/`lat`, `longitude`/`lng`/`lon`）をパース
  static ({double latitude, double longitude})? parseCoordinates(
    Map<String, dynamic> row,
  ) {
    final rawLat = row['latitude'] ?? row['lat'];
    final rawLng = row['longitude'] ?? row['lng'] ?? row['lon'];
    if (rawLat == null || rawLng == null) return null;

    final lat = rawLat is num
        ? rawLat.toDouble()
        : double.tryParse(rawLat.toString().trim());
    final lng = rawLng is num
        ? rawLng.toDouble()
        : double.tryParse(rawLng.toString().trim());
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
      return null;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return null;
    }
    return (latitude: lat, longitude: lng);
  }

  /// 住所文字列に含まれる山口県内市町名から代表座標を解決
  static ({double latitude, double longitude}) resolveCoordinatesFromLocation(
    String location,
  ) {
    for (final entry in _yamaguchiMunicipalityCoordinates.entries) {
      if (location.contains(entry.key)) {
        return entry.value;
      }
    }
    return (latitude: defaultLatitude, longitude: defaultLongitude);
  }

  static double _parseDouble(Object? value, double fallback) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value != null) {
      final parsed = double.tryParse(value.toString().trim());
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return fallback;
  }

  /// DB `request_type` 文字列から `AgencyType` へ変換
  static AgencyType parseAgency(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains('消防')) return AgencyType.fire;
    if (text.contains('警察')) return AgencyType.police;
    if (text.contains('自衛隊')) return AgencyType.sdf;
    return AgencyType.emergency;
  }

  /// DB `status` 文字列から `RequestStatus` へ変換
  static RequestStatus parseStatus(Object? value) {
    final text = value?.toString().trim() ?? '';
    return switch (text) {
      '対応中' => RequestStatus.working,
      '対応済み' => RequestStatus.done,
      _ => RequestStatus.pending,
    };
  }

  static String _firstNonEmpty(List<Object?> candidates, String fallback) {
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final text = candidate.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  static String _formatRowTime(Object? rawCreatedAt) {
    DateTime? parsed;
    if (rawCreatedAt is DateTime) {
      parsed = rawCreatedAt.toLocal();
    } else if (rawCreatedAt != null) {
      final str = rawCreatedAt.toString().trim();
      if (str.isNotEmpty) {
        parsed = DateTime.tryParse(str)?.toLocal();
      }
    }
    final dt = parsed ?? DateTime.now();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// `mamo` 準拠のマップピン色
  Color get pinColor {
    if (status == RequestStatus.done) {
      return const Color(0xFF27A35A);
    }
    if (agency == AgencyType.police) {
      return const Color(0xFF1767C6);
    }
    return const Color(0xFFE3433B);
  }

  RescueRequest copyWith({
    String? id,
    String? time,
    String? name,
    int? age,
    String? gender,
    AgencyType? agency,
    String? location,
    String? distance,
    String? content,
    String? consideration,
    double? latPercent,
    double? topPercent,
    double? latitude,
    double? longitude,
    RequestStatus? status,
    String? dbId,
  }) {
    return RescueRequest(
      id: id ?? this.id,
      time: time ?? this.time,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      agency: agency ?? this.agency,
      location: location ?? this.location,
      distance: distance ?? this.distance,
      content: content ?? this.content,
      consideration: consideration ?? this.consideration,
      latPercent: latPercent ?? this.latPercent,
      topPercent: topPercent ?? this.topPercent,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      dbId: dbId ?? this.dbId,
    );
  }
}
