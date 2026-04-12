class BetRecord {
  final int? id;
  final String number;
  final String playType;
  final String playTypeName;
  int lotteryType;
  double multiplier;
  double baseAmount;
  String batchId;
  final DateTime createTime;

  BetRecord({
    this.id,
    required this.number,
    required this.playType,
    required this.playTypeName,
    this.lotteryType = 1,
    this.multiplier = 1.0,
    this.baseAmount = 2.0,
    String? batchId,
    DateTime? createTime,
  }) : batchId = batchId ?? _generateBatchId(),
       createTime = createTime ?? DateTime.now();

  static String _generateBatchId() {
    return 'B${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'number': number,
      'play_type': playType,
      'play_type_name': playTypeName,
      'lottery_type': lotteryType,
      'multiplier': multiplier,
      'base_amount': baseAmount,
      'batch_id': batchId,
      'create_time': createTime.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory BetRecord.fromMap(Map<String, dynamic> map) {
    return BetRecord(
      id: map['id'] as int?,
      number: (map['number'] ?? '') as String,
      playType: (map['play_type'] ?? 'single') as String,
      playTypeName: (map['play_type_name'] ?? '直选') as String,
      lotteryType: (map['lottery_type'] is int ? map['lottery_type'] : (int.tryParse(map['lottery_type']?.toString() ?? '1') ?? 1)),
      multiplier: (map['multiplier'] is num ? (map['multiplier'] as num).toDouble() : (double.tryParse(map['multiplier']?.toString() ?? '1.0') ?? 1.0)),
      baseAmount: (map['base_amount'] is num ? (map['base_amount'] as num).toDouble() : (double.tryParse(map['base_amount']?.toString() ?? '2.0') ?? 2.0)),
      batchId: (map['batch_id'] ?? _generateBatchId()) as String,
      createTime: map['create_time'] != null ? (DateTime.tryParse(map['create_time'].toString()) ?? DateTime.now()) : DateTime.now(),
    );
  }

  BetRecord copyWith({
    int? id,
    String? number,
    String? playType,
    String? playTypeName,
    int? lotteryType,
    double? multiplier,
    double? baseAmount,
    String? batchId,
    DateTime? createTime,
  }) {
    return BetRecord(
      id: id ?? this.id,
      number: number ?? this.number,
      playType: playType ?? this.playType,
      playTypeName: playTypeName ?? this.playTypeName,
      lotteryType: lotteryType ?? this.lotteryType,
      multiplier: multiplier ?? this.multiplier,
      baseAmount: baseAmount ?? this.baseAmount,
      batchId: batchId ?? this.batchId,
      createTime: createTime ?? this.createTime,
    );
  }
}
