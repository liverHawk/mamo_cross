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

  final RequestStatus status;
  final String? dbId;

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
      status: status ?? this.status,
      dbId: dbId ?? this.dbId,
    );
  }
}
