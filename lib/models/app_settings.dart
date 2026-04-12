class AppSettings {
  double defaultMultiplier;
  int defaultLotteryType;
  String lastBackupTime;

  AppSettings({
    this.defaultMultiplier = 1.0,
    this.defaultLotteryType = 1,
    this.lastBackupTime = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'default_multiplier': defaultMultiplier,
      'default_lottery_type': defaultLotteryType,
      'last_backup_time': lastBackupTime,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      defaultMultiplier: (map['default_multiplier'] is num ? (map['default_multiplier'] as num).toDouble() : (double.tryParse(map['default_multiplier']?.toString() ?? '1.0') ?? 1.0)),
      defaultLotteryType: (map['default_lottery_type'] is int ? map['default_lottery_type'] : (int.tryParse(map['default_lottery_type']?.toString() ?? '1') ?? 1)),
      lastBackupTime: (map['last_backup_time'] ?? '') as String,
    );
  }
}
