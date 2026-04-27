class LearnedPattern {
  final int? id;
  final String sampleText;
  final String playType;
  final String playTypeName;
  final String pattern;
  final int priority;
  final DateTime createdAt;

  LearnedPattern({
    this.id,
    required this.sampleText,
    required this.playType,
    required this.playTypeName,
    required this.pattern,
    this.priority = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'sample_text': sampleText,
      'play_type': playType,
      'play_type_name': playTypeName,
      'pattern': pattern,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory LearnedPattern.fromMap(Map<String, dynamic> map) {
    return LearnedPattern(
      id: map['id'] as int?,
      sampleText: (map['sample_text'] ?? '') as String,
      playType: (map['play_type'] ?? '') as String,
      playTypeName: (map['play_type_name'] ?? '') as String,
      pattern: (map['pattern'] ?? '') as String,
      priority: (map['priority'] ?? 0) as int,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
