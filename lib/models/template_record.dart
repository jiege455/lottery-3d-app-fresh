class TemplateRecord {
  final int? id;
  final String name;
  final String content;
  final String playType;
  final String playTypeName;
  String defaultMultiplier;
  final DateTime createdAt;
  final DateTime updatedAt;

  TemplateRecord({
    this.id,
    required this.name,
    required this.content,
    this.playType = 'auto',
    this.playTypeName = '自动识别',
    this.defaultMultiplier = '2',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'content': content,
      'play_type': playType,
      'play_type_name': playTypeName,
      'default_multiplier': defaultMultiplier,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TemplateRecord.fromMap(Map<String, dynamic> map) {
    return TemplateRecord(
      id: map['id'] as int?,
      name: (map['name'] ?? '') as String,
      content: (map['content'] ?? '') as String,
      playType: (map['play_type'] ?? 'auto') as String,
      playTypeName: (map['play_type_name'] ?? '自动识别') as String,
      defaultMultiplier: (map['default_multiplier'] ?? '2') as String,
      createdAt: map['created_at'] != null ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()) : DateTime.now(),
    );
  }
}
