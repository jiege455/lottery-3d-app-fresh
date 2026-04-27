import '../../models/learned_pattern.dart';
import '../constants/play_types.dart';
import 'batch_parser.dart';

/// 从样本文本中提取特征模式
/// 例如 "358-2倍" → 生成模式 "{digits3}-{number}倍"
class PatternLearner {
  /// 分析单条样本，生成可复用的匹配模式
  static String extractPattern(String sample) {
    var pattern = sample;

    // 1. 替换3位数字号码 (最常见)
    pattern = pattern.replaceAllMapped(
      RegExp(r'\b\d{3}\b'),
      (match) => '{N3}',
    );

    // 2. 替换2位数字
    pattern = pattern.replaceAllMapped(
      RegExp(r'\b\d{2}\b'),
      (match) => '{N2}',
    );

    // 3. 替换1位数字 (单独的数字，不是其他数字的一部分)
    pattern = pattern.replaceAllMapped(
      RegExp(r'(?<![\d])\d(?![\d])'),
      (match) => '{N1}',
    );

    // 4. 替换多位数字序列 (如倍数、金额)
    pattern = pattern.replaceAllMapped(
      RegExp(r'\d+\.?\d*'),
      (match) {
        final num = match.group(0)!;
        if (num.length >= 2) return '{NUM}';
        return '{N1}';
      },
    );

    // 5. 转义正则特殊字符（注意：这里不能使用字符串插值，因为会产生歧义）
    pattern = pattern.replaceAllMapped(
      RegExp(r'[.+^$()|[\]\\]'),
      (match) {
        final ch = match.group(0)!;
        return '\\$ch';
      },
    );

    // 6. 将占位符还原为非捕获组或命名组
    pattern = pattern
        .replaceAll('{N3}', r'(?<n3>\d{3})')
        .replaceAll('{N2}', r'(?<n2>\d{2})')
        .replaceAll('{N1}', r'(?<n1>\d)')
        .replaceAll('{NUM}', r'(?<num>\d+\.?\d*)');

    return '^$pattern\$';
  }

  /// 从样本生成 LearnedPattern
  static LearnedPattern learn(String sample, String playType, String playTypeName) {
    final pattern = extractPattern(sample);
    return LearnedPattern(
      sampleText: sample,
      playType: playType,
      playTypeName: playTypeName,
      pattern: pattern,
      priority: 100, // 用户学习的规则优先级高
    );
  }

  /// 尝试用学习到的模式匹配文本
  /// 返回匹配结果，不匹配返回null
  static ParsedItem? tryMatch(String line, LearnedPattern learned, {double defaultMultiplier = 1.0}) {
    try {
      final reg = RegExp(learned.pattern);
      final match = reg.firstMatch(line.trim());
      if (match == null) return null;

      // 提取号码 (优先3位，其次2位，最后1位)
      String? number;
      if (match.namedGroup('n3') != null) {
        number = match.namedGroup('n3');
      } else if (match.namedGroup('n2') != null) {
        number = match.namedGroup('n2');
      } else if (match.namedGroup('n1') != null) {
        number = match.namedGroup('n1');
      }

      if (number == null || number.isEmpty) return null;

      // 提取倍数
      double multiplier = defaultMultiplier;
      final numStr = match.namedGroup('num');
      if (numStr != null) {
        final parsed = double.tryParse(numStr);
        if (parsed != null && parsed > 0) {
          multiplier = parsed;
        }
      }

      final config = PlayTypes.getByCode(learned.playType);
      if (config == null) return null;

      return ParsedItem(
        number: number,
        playType: config.code,
        playTypeName: config.name,
        multiplier: multiplier,
        color: config.color,
        baseAmount: config.baseAmount,
        isMultiplierCustomized: numStr != null,
      );
    } catch (e) {
      return null;
    }
  }

  /// 批量尝试匹配所有学习到的模式
  /// 返回第一个匹配的结果
  static ParsedItem? tryMatchAll(String line, List<LearnedPattern> patterns, {double defaultMultiplier = 1.0}) {
    // 按优先级排序
    final sorted = List<LearnedPattern>.from(patterns)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final pattern in sorted) {
      final result = tryMatch(line, pattern, defaultMultiplier: defaultMultiplier);
      if (result != null) return result;
    }
    return null;
  }

  /// 验证模式是否有效
  static bool isValidPattern(String pattern) {
    try {
      RegExp(pattern);
      return true;
    } catch (e) {
      return false;
    }
  }
}
