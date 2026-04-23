class DrawRecord {
  final int? id;
  final String issue;
  final String numbers;
  final int sumValue;
  final int span;
  final String formType;
  final DateTime drawDate;
  final int lotteryType;

  DrawRecord({
    this.id,
    required this.issue,
    required this.numbers,
    required this.sumValue,
    required this.span,
    required this.formType,
    required this.drawDate,
    this.lotteryType = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'issue': issue,
      'numbers': numbers,
      'sum_value': sumValue,
      'span': span,
      'form_type': formType,
      'draw_date': drawDate.toIso8601String(),
      'lottery_type': lotteryType,
    };
  }

  factory DrawRecord.fromMap(Map<String, dynamic> map) {
    return DrawRecord(
      id: map['id'] as int?,
      issue: (map['issue'] ?? '') as String,
      numbers: (map['numbers'] ?? '') as String,
      sumValue: (map['sum_value'] is int ? map['sum_value'] : (int.tryParse(map['sum_value']?.toString() ?? '0') ?? 0)),
      span: (map['span'] is int ? map['span'] : (int.tryParse(map['span']?.toString() ?? '0') ?? 0)),
      formType: (map['form_type'] ?? '') as String,
      drawDate: map['draw_date'] != null ? (DateTime.tryParse(map['draw_date'].toString()) ?? DateTime.now()) : DateTime.now(),
      lotteryType: (map['lottery_type'] is int ? map['lottery_type'] : (int.tryParse(map['lottery_type']?.toString() ?? '1') ?? 1)),
    );
  }

  static String getFormType(String numbers) {
    if (numbers.length != 3) return '';
    final a = numbers[0], b = numbers[1], c = numbers[2];
    if (a == b && b == c) return '豹子';
    if (a == b || b == c || a == c) return '组三';
    return '组六';
  }

  static int getSumValue(String numbers) {
    if (numbers.length != 3) return 0;
    return numbers.split('').map((c) => int.tryParse(c) ?? 0).reduce((a, b) => a + b);
  }

  static int getSpan(String numbers) {
    if (numbers.length != 3) return 0;
    final digits = numbers.split('').map((c) => int.tryParse(c) ?? 0).toList();
    if (digits.length < 3) return 0;
    final maxDigit = digits.reduce((a, b) => a > b ? a : b);
    final minDigit = digits.reduce((a, b) => a < b ? a : b);
    return maxDigit - minDigit;
  }
}
