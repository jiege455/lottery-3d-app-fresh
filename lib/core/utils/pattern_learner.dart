import '../../models/learned_pattern.dart';
import '../constants/play_types.dart';
import 'batch_parser.dart';

/// 从样本文本中提取特征模式
/// 例如 "358-2倍" → 生成模式 "(?<n3>\\d{3})-(?<num>\\d+\\.?\\d*)倍"
class PatternLearner {
  /// 分析单条样本，生成可复用的匹配模式
  static String extractPattern(String sample) {
    var pattern = sample;

    // 步骤1: 替换3位数字号码 (最常见)
    pattern = pattern.replaceAllMapped(
      RegExp(r'\b\d{3}\b'),
      (match) => '__N3__',
    );

    // 步骤2: 替换2位数字
    pattern = pattern.replaceAllMapped(
      RegExp(r'\b\d{2}\b'),
      (match) => '__N2__',
    );

    // 步骤3: 替换1位数字 (单独的数字，不是其他数字的一部分)
    pattern = pattern.replaceAllMapped(
      RegExp(r'(?<![\d])\d(?![\d])'),
      (match) => '__N1__',
    );

    // 步骤4: 替换剩余的多位数字序列 (如倍数、金额)
    pattern = pattern.replaceAllMapped(
      RegExp(r'\d+\.?\d*'),
      (match) {
        final num = match.group(0)!;
        if (num.length >= 2) return '__NUM__';
        return '__N1__';
      },
    );

    // 步骤5: 转义正则特殊字符（必须在占位符替换之后）
    // 注意：不包含 { } 因为它们已经被替换为 __xxx__ 了
    pattern = pattern.replaceAllMapped(
      RegExp(r'[.+^$()*?|\\[\]]'),
      (match) {
        final ch = match.group(0)!;
        return '\\$ch';
      },
    );

    // 步骤6: 将占位符还原为捕获组（使用编号组而非命名组，Dart兼容性好）
    // 组1: 3位数字, 组2: 2位数字, 组3: 1位数字, 组4: 倍数
    pattern = pattern
        .replaceAll('__N3__', r'(\d{3})')
        .replaceAll('__N2__', r'(\d{2})')
        .replaceAll('__N1__', r'(\d)')
        .replaceAll('__NUM__', r'(\d+\.?\d*)');

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

      // 提取号码 - 按顺序检查各捕获组
      // 组1: 3位数字, 组2: 2位数字, 组3: 1位数字
      String? number;
      if (match.groupCount >= 1 && match.group(1) != null) {
        number = match.group(1);
      } else if (match.groupCount >= 2 && match.group(2) != null) {
        number = match.group(2);
      } else if (match.groupCount >= 3 && match.group(3) != null) {
        number = match.group(3);
      }

      if (number == null || number.isEmpty) return null;

      // 提取倍数 - 通常是最后一个捕获组
      double multiplier = defaultMultiplier;
      String? numStr;
      // 从后往前找数字组（倍数通常是最后匹配的）
      for (var i = match.groupCount; i >= 1; i--) {
        final group = match.group(i);
        if (group != null && group.isNotEmpty) {
          final parsed = double.tryParse(group);
          if (parsed != null && parsed > 0) {
            // 如果这个组不是号码（号码通常是3位），则认为是倍数
            if (group.length != 3 || int.tryParse(group) == null) {
              numStr = group;
              multiplier = parsed;
              break;
            }
          }
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
      print('PatternLearner.tryMatch error: $e');
      return null;
    }
  }

  /// 批量尝试匹配所有学习到的模式
  /// 返回第一个匹配的结果
  static ParsedItem? tryMatchAll(String line, List<LearnedPattern> patterns, {double defaultMultiplier = 1.0}) {
    if (patterns.isEmpty) return null;

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
