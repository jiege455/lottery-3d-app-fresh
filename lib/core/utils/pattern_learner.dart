import '../../models/learned_pattern.dart';
import '../constants/play_types.dart';
import 'batch_parser.dart';

/// 关键词匹配引擎
/// 从样本文本中提取关键词特征，通过相似度匹配新文本
class PatternLearner {
  /// 从样本文本中提取关键词特征
  /// 返回关键词列表（去重、排序）
  static List<String> extractKeywords(String sample) {
    final keywords = <String>[];
    var text = sample;

    // 1. 提取3位数字号码 → 标记为 {N3}
    text = text.replaceAllMapped(
      RegExp(r'\b\d{3}\b'),
      (match) {
        keywords.add('{N3}');
        return '__NUM3__';
      },
    );

    // 2. 提取2位数字 → 标记为 {N2}
    text = text.replaceAllMapped(
      RegExp(r'\b\d{2}\b'),
      (match) {
        keywords.add('{N2}');
        return '__NUM2__';
      },
    );

    // 3. 提取1位数字 → 标记为 {N1}
    text = text.replaceAllMapped(
      RegExp(r'(?<![\d])\d(?![\d])'),
      (match) {
        keywords.add('{N1}');
        return '__NUM1__';
      },
    );

    // 4. 提取剩余数字（倍数、金额）→ 标记为 {NUM}
    // 注意：步骤1-3已经替换了大部分数字，这里只处理剩余的
    text = text.replaceAllMapped(
      RegExp(r'\d+\.?\d*'),
      (match) {
        keywords.add('{NUM}');
        return '__NUM__';
      },
    );

    // 5. 提取剩余的非空字符作为分隔符/关键词
    final remaining = text.replaceAll(RegExp(r'__NUM\d*__'), '').trim();
    if (remaining.isNotEmpty) {
      // 将连续的符号拆分为单独的关键词
      final symbols = remaining.split('').where((s) => s.trim().isNotEmpty).toList();
      keywords.addAll(symbols);
    }

    // 去重并保持顺序
    final unique = <String>[];
    for (final kw in keywords) {
      if (!unique.contains(kw)) {
        unique.add(kw);
      }
    }

    return unique;
  }

  /// 计算两个关键词列表的相似度
  /// 返回 0.0 ~ 1.0
  static double calculateSimilarity(List<String> keywords1, List<String> keywords2) {
    if (keywords1.isEmpty || keywords2.isEmpty) return 0.0;

    // 计算交集
    final intersection = keywords1.where((kw) => keywords2.contains(kw)).toList();

    // 计算并集
    final union = <String>[...keywords1, ...keywords2];
    final uniqueUnion = union.toSet().toList();

    // Jaccard 相似度 = 交集 / 并集
    if (uniqueUnion.isEmpty) return 0.0;
    final jaccard = intersection.length / uniqueUnion.length;

    // 额外加分：如果结构相同（都有号码和倍数标记）
    double structureBonus = 0.0;
    final hasNum1 = keywords1.any((k) => k.startsWith('{N'));
    final hasNum2 = keywords2.any((k) => k.startsWith('{N'));
    final hasMultiplier1 = keywords1.contains('{NUM}');
    final hasMultiplier2 = keywords2.contains('{NUM}');

    if (hasNum1 && hasNum2) structureBonus += 0.1;
    if (hasMultiplier1 && hasMultiplier2) structureBonus += 0.1;

    // 额外加分：分隔符匹配
    final separators1 = keywords1.where((k) => !k.startsWith('{') && !RegExp(r'\d').hasMatch(k)).toList();
    final separators2 = keywords2.where((k) => !k.startsWith('{') && !RegExp(r'\d').hasMatch(k)).toList();
    if (separators1.isNotEmpty && separators2.isNotEmpty) {
      final commonSep = separators1.where((s) => separators2.contains(s)).toList();
      if (commonSep.isNotEmpty) structureBonus += 0.1;
    }

    return (jaccard + structureBonus).clamp(0.0, 1.0);
  }

  /// 从样本生成 LearnedPattern
  /// pattern 字段现在存储关键词列表的逗号分隔字符串
  static LearnedPattern learn(String sample, String playType, String playTypeName) {
    final keywords = extractKeywords(sample);
    return LearnedPattern(
      sampleText: sample,
      playType: playType,
      playTypeName: playTypeName,
      pattern: keywords.join(','),
      priority: 100,
    );
  }

  /// 尝试用学习到的模式匹配文本
  /// 返回匹配结果和相似度，不匹配返回null
  static ({ParsedItem item, double similarity})? tryMatchWithSimilarity(String line, LearnedPattern learned, {double defaultMultiplier = 1.0}) {
    try {
      final inputKeywords = extractKeywords(line.trim());
      final patternKeywords = learned.pattern.split(',').where((s) => s.isNotEmpty).toList();

      if (patternKeywords.isEmpty) return null;

      final similarity = calculateSimilarity(inputKeywords, patternKeywords);

      // 相似度阈值：0.5（50%）认为匹配，更宽松
      if (similarity < 0.5) return null;

      // 提取号码（找3位数字）
      String? number;
      final num3Match = RegExp(r'\b\d{3}\b').firstMatch(line.trim());
      if (num3Match != null) {
        number = num3Match.group(0);
      } else {
        final num2Match = RegExp(r'\b\d{2}\b').firstMatch(line.trim());
        if (num2Match != null) number = num2Match.group(0);
      }

      if (number == null || number.isEmpty) return null;

      // 提取倍数（找数字+倍/元等后缀，或单独的数字）
      double multiplier = defaultMultiplier;
      String? numStr;

      // 尝试匹配 "X倍"、"X元" 等格式
      final multiplierMatch = RegExp(r'(\d+\.?\d*)\s*[倍元]').firstMatch(line.trim());
      if (multiplierMatch != null) {
        numStr = multiplierMatch.group(1);
        final parsed = double.tryParse(numStr!);
        if (parsed != null && parsed > 0) {
          multiplier = parsed;
        }
      } else {
        // 如果没有倍数标记，找最后一个数字（排除号码）
        final allNumbers = RegExp(r'\d+\.?\d*').allMatches(line.trim()).toList();
        if (allNumbers.length > 1) {
          // 有多个数字，最后一个可能是倍数
          final lastNum = allNumbers.last.group(0);
          if (lastNum != null && lastNum != number) {
            final parsed = double.tryParse(lastNum);
            if (parsed != null && parsed > 0) {
              numStr = lastNum;
              multiplier = parsed;
            }
          }
        }
      }

      final config = PlayTypes.getByCode(learned.playType);
      if (config == null) return null;

      final item = ParsedItem(
        number: number,
        playType: config.code,
        playTypeName: config.name,
        multiplier: multiplier,
        color: config.color,
        baseAmount: config.baseAmount,
        isMultiplierCustomized: numStr != null,
      );

      return (item: item, similarity: similarity);
    } catch (e) {
      print('PatternLearner.tryMatchWithSimilarity error: $e');
      return null;
    }
  }

  /// 尝试用学习到的模式匹配文本（兼容旧接口）
  static ParsedItem? tryMatch(String line, LearnedPattern learned, {double defaultMultiplier = 1.0}) {
    final result = tryMatchWithSimilarity(line, learned, defaultMultiplier: defaultMultiplier);
    return result?.item;
  }

  /// 批量尝试匹配所有学习到的模式
  /// 返回相似度最高的匹配结果
  static ParsedItem? tryMatchAll(String line, List<LearnedPattern> patterns, {double defaultMultiplier = 1.0}) {
    if (patterns.isEmpty) return null;

    ({ParsedItem item, double similarity})? bestMatch;

    for (final pattern in patterns) {
      final result = tryMatchWithSimilarity(line, pattern, defaultMultiplier: defaultMultiplier);
      if (result != null) {
        if (bestMatch == null || result.similarity > bestMatch.similarity) {
          bestMatch = result;
        }
      }
    }

    return bestMatch?.item;
  }

  /// 验证模式是否有效
  static bool isValidPattern(String pattern) {
    return pattern.isNotEmpty;
  }
}
