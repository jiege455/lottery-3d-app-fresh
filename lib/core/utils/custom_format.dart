import 'dart:convert';
import '../constants/play_types.dart';
import 'batch_parser.dart';

/// 自定义格式模板模型
/// 用户通过示例文本定义自己的输入格式
/// 例如：模板 "{号码}-{倍数}倍" + 玩法 "直选"
/// 可以匹配 "358-2倍" 这样的输入
class CustomFormatRule {
  final int? id;
  final String name; // 模板名称（用户自定义）
  final String template; // 格式模板，如 "{号码}-{倍数}倍"
  final String playTypeCode; // 玩法编码
  final double defaultMultiplier; // 默认倍数
  final DateTime createTime;
  bool enabled; // 是否启用

  CustomFormatRule({
    this.id,
    required this.name,
    required this.template,
    required this.playTypeCode,
    this.defaultMultiplier = 2.0,
    DateTime? createTime,
    this.enabled = true,
  }) : createTime = createTime ?? DateTime.now();

  /// 获取玩法配置
  PlayTypeConfig? get playTypeConfig => PlayTypes.getByCode(playTypeCode);

  /// 获取玩法名称
  String get playTypeName => playTypeConfig?.name ?? playTypeCode;

  /// 将模板转换为正则表达式
  /// {号码} → 匹配数字 (\d{3,})
  /// {倍数} → 匹配倍数 (\d+\.?\d*)
  RegExp? get regex {
    try {
      var pattern = template;
      // 转义正则特殊字符（除了 {} 占位符）
      pattern = pattern.replaceAllMapped(RegExp(r'[.+^${}()|[\]\\]'), (match) {
        final ch = match.group(0)!;
        if (ch == '{' || ch == '}') return ch;
        return '\\$ch';
      });
      // 替换占位符
      pattern = pattern.replaceAll('{号码}', r'(?<number>\d{3,9})');
      pattern = pattern.replaceAll('{倍数}', r'(?<multiplier>\d+\.?\d*)');
      // 如果没有任何占位符，把整个模板当普通文本匹配
      if (!pattern.contains('(?<')) {
        return null;
      }
      return RegExp('^$pattern\$');
    } catch (e) {
      return null;
    }
  }

  /// 尝试匹配一行文本
  /// 如果匹配成功，返回解析结果
  ParsedItem? tryMatch(String line, {double defaultMult = 1.0}) {
    final reg = regex;
    if (reg == null) return null;

    final match = reg.firstMatch(line.trim());
    if (match == null) return null;

    final number = match.namedGroup('number');
    if (number == null) return null;

    final config = playTypeConfig;
    if (config == null) return null;

    // 提取倍数
    double multiplier = defaultMult;
    final multStr = match.namedGroup('multiplier');
    if (multStr != null) {
      final parsed = double.tryParse(multStr);
      if (parsed != null && parsed > 0) {
        // 判断是倍数还是金额
        // 如果数字较大（>= config.baseAmount），当作金额处理
        if (parsed >= config.baseAmount) {
          multiplier = parsed / config.baseAmount;
        } else {
          multiplier = parsed;
        }
      }
    }

    return ParsedItem(
      number: number,
      playType: config.code,
      playTypeName: config.name,
      multiplier: multiplier,
      color: config.color,
      baseAmount: config.baseAmount,
      isMultiplierCustomized: multStr != null,
    );
  }

  /// 序列化
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'template': template,
      'play_type_code': playTypeCode,
      'default_multiplier': defaultMultiplier,
      'create_time': createTime.toIso8601String(),
      'enabled': enabled ? 1 : 0,
    };
  }

  /// 反序列化
  factory CustomFormatRule.fromMap(Map<String, dynamic> map) {
    return CustomFormatRule(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      template: map['template'] as String? ?? '',
      playTypeCode: map['play_type_code'] as String? ?? 'single',
      defaultMultiplier: (map['default_multiplier'] is num
          ? (map['default_multiplier'] as num).toDouble()
          : double.tryParse(map['default_multiplier']?.toString() ?? '2.0') ?? 2.0),
      createTime: DateTime.tryParse(map['create_time'] as String? ?? '') ?? DateTime.now(),
      enabled: map['enabled'] == 1,
    );
  }

  /// 验证模板是否有效
  static String? validate(String template, String playTypeCode) {
    if (template.trim().isEmpty) return '模板不能为空';
    if (!template.contains('{号码}')) return '模板必须包含 {号码} 占位符';
    if (PlayTypes.getByCode(playTypeCode) == null) return '请选择有效的玩法';
    // 检查占位符格式
    final placeholders = RegExp(r'\{(\w+)\}').allMatches(template);
    for (final m in placeholders) {
      final name = m.group(1);
      if (name != '号码' && name != '倍数') {
        return '不支持的占位符: {$name}，仅支持 {号码} 和 {倍数}';
      }
    }
    return null;
  }
}

/// 自定义格式管理器
class CustomFormatManager {
  final List<CustomFormatRule> _rules = [];
  bool _isLoaded = false;

  List<CustomFormatRule> get rules => List.unmodifiable(_rules);
  List<CustomFormatRule> get enabledRules => _rules.where((r) => r.enabled).toList();
  bool get isLoaded => _isLoaded;

  void setRules(List<CustomFormatRule> rules) {
    _rules.clear();
    _rules.addAll(rules);
    _isLoaded = true;
  }

  void addRule(CustomFormatRule rule) {
    _rules.add(rule);
  }

  void removeRule(int index) {
    if (index >= 0 && index < _rules.length) {
      _rules.removeAt(index);
    }
  }

  void updateRule(int index, CustomFormatRule rule) {
    if (index >= 0 && index < _rules.length) {
      _rules[index] = rule;
    }
  }

  /// 尝试用所有已启用的自定义模板匹配一行文本
  /// 返回第一个匹配的结果
  ParsedItem? tryMatchAll(String line, {double defaultMultiplier = 1.0}) {
    for (final rule in enabledRules) {
      final result = rule.tryMatch(line, defaultMult: defaultMultiplier);
      if (result != null) return result;
    }
    return null;
  }

  /// 批量尝试匹配
  /// 返回匹配结果列表，以及未匹配的行
  ({List<ParsedItem> matched, List<String> unmatched}) tryMatchBatch(
    List<String> lines, {
    double defaultMultiplier = 1.0,
  }) {
    final matched = <ParsedItem>[];
    final unmatched = <String>[];

    for (final line in lines) {
      final result = tryMatchAll(line, defaultMultiplier: defaultMultiplier);
      if (result != null) {
        matched.add(result);
      } else {
        unmatched.add(line);
      }
    }

    return (matched: matched, unmatched: unmatched);
  }

  /// 将规则列表序列化为 JSON 字符串
  static String rulesToJson(List<CustomFormatRule> rules) {
    final list = rules.map((r) => r.toMap()).toList();
    return jsonEncode(list);
  }

  /// 从 JSON 字符串反序列化规则列表
  static List<CustomFormatRule> rulesFromJson(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => CustomFormatRule.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
}
