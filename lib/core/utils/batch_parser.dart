import '../constants/play_types.dart';
import 'package:flutter/material.dart';

class ParsedItem {
  final String number;
  String playType;
  String playTypeName;
  double multiplier;
  Color color;
  double baseAmount;
  bool isMultiplierCustomized;

  ParsedItem({
    required this.number,
    required this.playType,
    required this.playTypeName,
    this.multiplier = 1.0,
    required this.color,
    this.baseAmount = 2.0,
    this.isMultiplierCustomized = false,
  });
}

class BatchParser {
  static const int previewMax = 50;
  static const Set<String> separators = {',', ';', '\t', '，', '；', '、', '|'};
  static final RegExp _multiplierRegex = RegExp(r'[*×xX](\d+\.?\d*)$');

  static final Map<String, String> _prefixLookup = () {
    final map = <String, String>{};
    for (final pt in PlayTypes.all) {
      map['${pt.name}:'] = pt.code;
      map['${pt.name}：'] = pt.code;
    }
    for (var i = 0; i <= 9; i++) {
      map['${i}跨'] = 'span$i';
      map['${i}跨：'] = 'span$i';
    }
    map['组选'] = 'group_auto';
    map['组选：'] = 'group_auto';
    map['豹子'] = 'baozi_single';
    map['豹子：'] = 'baozi_single';
    map['豹子:'] = 'baozi_single';
    return map;
  }();

  static final RegExp _posCompositeRegex = RegExp(r'百位?[\s：:，,、]*([\d，,、]+).*?十位?[\s：:，,、]*([\d，,、]+).*?个位?[\s：:，,、]*([\d，,、]+)', dotAll: true);

  static final RegExp _numGroupSuffixRegex = RegExp(r'^(\d{2,9})\s*组([六三63])?\s*([*×xX]?\d*\.?\d*)?$');

  static final RegExp _singleGroupSuffixRegex = RegExp(r'([一二两三四五六七八九十\d]*)[单直]([一二两三四五六七八九十\d]*)组\s*$');

  static int? _parseChineseNum(String s) {
    if (s.isEmpty) return 1;
    const cnMap = {'一': 1, '二': 2, '两': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10};
    if (cnMap.containsKey(s)) return cnMap[s];
    return int.tryParse(s);
  }

  static const List<String> _validChineseKeywords = [
    '转圈组六全包', '转圈组三全包',
    '沾边组六', '沾边组三',
    '转圈组六', '转圈组三',
    '双飞对子', '双飞组六',
    '豹子直选', '豹子全包',
    '一码定位', '二码定位',
    '复式全包', '组三全包', '组六全包',
    '前两位', '后两位',
    '直选', '组三', '组六', '独胆',
    '复式', '和数', '组选',
    '豹子',
    '大小', '单双',
    '百位', '十位', '个位',
    '首尾',
    '大', '小', '单', '双',
    '跨',
    '百', '十', '个',
  ];

  static final Set<String> _wholeLineNoNumberCodes = {
    'bigsmall', 'oddeven',
    'span0', 'span1', 'span2', 'span3', 'span4',
    'span5', 'span6', 'span7', 'span8', 'span9',
  };

  static final List<String> _prefixKeywordsSorted = () {
    final set = <String>{};
    for (final pt in PlayTypes.all) {
      if (_wholeLineNoNumberCodes.contains(pt.code)) continue;
      set.add(pt.name);
    }
    set.add('组选');
    set.add('豹子');
    return set.toList()..sort((a, b) => b.length.compareTo(a.length));
  }();

  static bool _isChineseChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x4e00 && code <= 0x9fff) ||
        (code >= 0x3400 && code <= 0x4dbf) ||
        (code >= 0x20000 && code <= 0x2a6df);
  }

  static String _filterUnrecognizedChinese(String line) {
    final result = StringBuffer();
    var i = 0;
    while (i < line.length) {
      if (!_isChineseChar(line[i])) {
        result.write(line[i]);
        i++;
      } else {
        var matched = false;
        for (final keyword in _validChineseKeywords) {
          if (i + keyword.length <= line.length &&
              line.substring(i, i + keyword.length) == keyword) {
            result.write(keyword);
            i += keyword.length;
            matched = true;
            break;
          }
        }
        if (!matched) {
          final prevChar = result.isNotEmpty ? result.toString()[result.length - 1] : '';
          if (RegExp(r'^\d$').hasMatch(prevChar)) {
            result.write(' ');
          }
          i++;
        }
      }
    }
    return result.toString();
  }

  static String _ensurePrefixColon(String line) {
    for (final prefix in _prefixKeywordsSorted) {
      if (line.startsWith(prefix)) {
        final afterPrefix = line.substring(prefix.length);
        if (afterPrefix.isNotEmpty &&
            !afterPrefix.startsWith(':') &&
            !afterPrefix.startsWith('：')) {
          return '$prefix：$afterPrefix';
        }
        break;
      }
    }
    return line;
  }

  static String _preprocessInput(String input) {
    final lines = input.split('\n');
    final processedLines = <String>[];
    for (final line in lines) {
      var processed = _filterUnrecognizedChinese(line);
      processed = _ensurePrefixColon(processed);
      processedLines.add(processed);
    }
    return processedLines.join('\n');
  }

  static bool _isPosCompositeFormat(String line) {
    final clean = line.replaceAll(_multiplierRegex, '').trim();
    return _posCompositeRegex.hasMatch(clean);
  }

  static List<ParsedItem>? _tryParseMultiLinePosition(String input, {String? forcePlayType, double defaultMultiplier = 1.0}) {
    final lines = input.split(RegExp(r'[\n\r]')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return null;

    String? baiLine, shiLine, geLine;
    final otherLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (baiLine == null && RegExp(r'^百位?[\s：:，,、]*\d').hasMatch(trimmed)) {
        baiLine = trimmed;
      } else if (shiLine == null && RegExp(r'^十位?[\s：:，,、]*\d').hasMatch(trimmed)) {
        shiLine = trimmed;
      } else if (geLine == null && RegExp(r'^个位?[\s：:，,、]*\d').hasMatch(trimmed)) {
        geLine = trimmed;
      } else {
        otherLines.add(trimmed);
      }
    }

    if (baiLine == null || shiLine == null || geLine == null) return null;

    final baiDigits = _extractDigitsFromPosLine(baiLine);
    final shiDigits = _extractDigitsFromPosLine(shiLine);
    final geDigits = _extractDigitsFromPosLine(geLine);

    if (baiDigits.isEmpty || shiDigits.isEmpty || geDigits.isEmpty) return null;

    double? mult;
    final posLines = [baiLine, shiLine, geLine].whereType<String>();
    for (final posLine in posLines) {
      final m = _extractMultiplier(posLine);
      if (m != null) mult = m;
    }
    final effectiveDefault = mult ?? defaultMultiplier;

    final compositeStr = '百位${baiDigits.join(',')} 十位${shiDigits.join(',')} 个位${geDigits.join(',')}';
    final items = _parsePosComposite(compositeStr, forcePlayType: forcePlayType, defaultMultiplier: effectiveDefault);

    if (otherLines.isNotEmpty) {
      final otherResult = _tryParseSingleGroupLines(otherLines.join('\n'), forcePlayType: forcePlayType, defaultMultiplier: defaultMultiplier);
      if (otherResult != null) {
        items.addAll(otherResult);
      } else {
        final preprocessed = _preprocessInput(otherLines.join('\n'));
        final otherLinesList = preprocessed.split('\n').where((l) => l.trim().isNotEmpty).toList();
        for (final line in otherLinesList) {
          final lineItems = _parseLine(line.trim(), forcePlayType: forcePlayType, defaultMultiplier: defaultMultiplier);
          items.addAll(lineItems);
        }
      }
    }

    return items;
  }

  static List<String> _extractDigitsFromPosLine(String line) {
    final withoutMult = line.replaceAll(_multiplierRegex, '').trim();
    final digitsOnly = withoutMult.replaceAll(RegExp(r'[^\d]'), '');
    return digitsOnly.split('').toSet().toList()..sort();
  }

  static List<String> _extractThreeDigitNumbers(String text) {
    final parts = <String>[];
    var cleaned = text;
    for (final sep in separators) {
      cleaned = cleaned.replaceAll(sep, ',');
    }
    cleaned = cleaned.replaceAll(RegExp(r'[\s\u3000]+'), ',');
    for (final part in cleaned.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (RegExp(r'^\d{3}$').hasMatch(trimmed)) {
        parts.add(trimmed);
      } else if (RegExp(r'^\d+$').hasMatch(trimmed) && trimmed.length % 3 == 0 && trimmed.length <= 18) {
        for (var i = 0; i < trimmed.length; i += 3) {
          parts.add(trimmed.substring(i, i + 3));
        }
      }
    }
    return parts;
  }

  static List<ParsedItem>? _tryParseSingleGroupLines(String input, {String? forcePlayType, double defaultMultiplier = 1.0}) {
    final lines = input.split(RegExp(r'[\n\r]')).where((l) => l.trim().isNotEmpty).toList();
    final results = <ParsedItem>[];
    final normalLines = <String>[];
    var hasSingleGroup = false;

    for (final line in lines) {
      final trimmed = line.trim();
      final match = _singleGroupSuffixRegex.firstMatch(trimmed);
      if (match == null) {
        normalLines.add(trimmed);
        continue;
      }

      final beforeSuffix = trimmed.substring(0, match.start).trim();
      final singleMult = (_parseChineseNum(match.group(1) ?? '') ?? 1).toDouble();
      final groupMult = (_parseChineseNum(match.group(2) ?? '') ?? 1).toDouble();

      final numbers = _extractThreeDigitNumbers(beforeSuffix);
      if (numbers.isEmpty) {
        normalLines.add(trimmed);
        continue;
      }

      hasSingleGroup = true;
      for (final num in numbers) {
        final singleConfig = PlayTypes.getByCode('single')!;
        results.add(ParsedItem(
          number: num,
          playType: 'single',
          playTypeName: '直选',
          multiplier: singleMult,
          color: singleConfig.color,
          baseAmount: singleConfig.baseAmount,
        ));

        final hasDup = _hasDuplicateDigit(num);
        final groupCode = hasDup ? 'group3' : 'group6';
        final groupConfig = PlayTypes.getByCode(groupCode)!;
        results.add(ParsedItem(
          number: num,
          playType: groupCode,
          playTypeName: hasDup ? '组三' : '组六',
          multiplier: groupMult,
          color: groupConfig.color,
          baseAmount: groupConfig.baseAmount,
        ));
      }
    }

    if (!hasSingleGroup) return null;

    if (normalLines.isNotEmpty) {
      final preprocessed = _preprocessInput(normalLines.join('\n'));
      final normalLinesList = preprocessed.split('\n').where((l) => l.trim().isNotEmpty).toList();
      for (final line in normalLinesList) {
        final lineItems = _parseLine(line.trim(), forcePlayType: forcePlayType, defaultMultiplier: defaultMultiplier);
        results.addAll(lineItems);
      }
    }

    return results;
  }

  static bool _isMultiLinePosComposite(String input) {
    final joined = input.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
    if (!_isPosCompositeFormat(joined)) return false;
    final match = _posCompositeRegex.firstMatch(joined.replaceAll(_multiplierRegex, '').trim());
    if (match == null) return false;
    final afterMatch = joined.substring(match.end).replaceAll(_multiplierRegex, '').trim();
    return afterMatch.isEmpty;
  }

  static List<ParsedItem> _parsePosComposite(String line, {String? forcePlayType, double defaultMultiplier = 1.0}) {
    final mult = _extractMultiplier(line);
    final cleanLine = line.replaceAll(_multiplierRegex, '').trim();

    final match = _posCompositeRegex.firstMatch(cleanLine);
    if (match == null) return [];

    final baiDigits = match.group(1)!.replaceAll(RegExp(r'[，,、]'), '').split('').toSet().toList()..sort();
    final shiDigits = match.group(2)!.replaceAll(RegExp(r'[，,、]'), '').split('').toSet().toList()..sort();
    final geDigits = match.group(3)!.replaceAll(RegExp(r'[，,、]'), '').split('').toSet().toList()..sort();

    final items = <ParsedItem>[];
    final effectiveMultiplier = mult ?? defaultMultiplier;

    final isGroup = forcePlayType == 'group3' || forcePlayType == 'group6' || forcePlayType == 'group_auto';

    if (!isGroup) {
      final config = PlayTypes.getByCode('single')!;
      for (final b in baiDigits) {
        for (final s in shiDigits) {
          for (final g in geDigits) {
            items.add(ParsedItem(
              number: '$b$s$g',
              playType: 'single',
              playTypeName: '直选',
              multiplier: effectiveMultiplier,
              color: config.color,
              baseAmount: config.baseAmount,
            ));
          }
        }
      }
    } else {
      final seen = <String>{};
      for (final b in baiDigits) {
        for (final s in shiDigits) {
          for (final g in geDigits) {
            final sorted = [b, s, g]..sort();
            final key = sorted.join();
            if (seen.contains(key)) continue;
            seen.add(key);

            final hasDup = sorted[0] == sorted[1] || sorted[1] == sorted[2];
            final actualType = hasDup ? 'group3' : 'group6';
            final config = PlayTypes.getByCode(actualType)!;

            items.add(ParsedItem(
              number: key,
              playType: actualType,
              playTypeName: hasDup ? '组三' : '组六',
              multiplier: effectiveMultiplier,
              color: config.color,
              baseAmount: config.baseAmount,
            ));
          }
        }
      }
    }

    return items;
  }

  static List<ParsedItem> _parseNumGroupSuffix(String line, double defaultMultiplier) {
    final match = _numGroupSuffixRegex.firstMatch(line.trim());
    if (match == null) return [];

    final digits = match.group(1)!;
    final typeHint = match.group(2);
    final multStr = match.group(3);

    double? mult;
    if (multStr != null && multStr.isNotEmpty) {
      final cleaned = multStr.replaceFirst(RegExp(r'^[*×xX]'), '');
      if (cleaned.isNotEmpty) mult = double.tryParse(cleaned);
    }
    final effectiveMultiplier = mult ?? defaultMultiplier;

    final uniqueDigits = digits.split('').toSet().toList()..sort();
    final count = uniqueDigits.length;
    if (count < 2 || count > 9) return [];

    String playTypeCode;
    if (typeHint == '六' || typeHint == '6') {
      if (count < 4) return [];
      playTypeCode = 'g6_$count';
    } else if (typeHint == '三' || typeHint == '3') {
      playTypeCode = 'g3_$count';
    } else {
      if (count <= 3) {
        playTypeCode = 'g3_$count';
      } else {
        playTypeCode = 'g6_$count';
      }
    }

    final config = PlayTypes.getByCode(playTypeCode);
    if (config == null) return [];

    return [ParsedItem(
      number: uniqueDigits.join(),
      playType: config.code,
      playTypeName: config.name,
      multiplier: effectiveMultiplier,
      color: config.color,
      baseAmount: config.baseAmount,
    )];
  }

  static List<ParsedItem> _parseZqComposite(String line, String playTypeCode, double defaultMultiplier) {
    final mult = _extractMultiplier(line);
    final cleanLine = line.replaceAll(_multiplierRegex, '').trim();
    final digitsOnly = cleanLine.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 2) return [];

    final config = PlayTypes.getByCode(playTypeCode);
    if (config == null) return [];

    return [ParsedItem(
      number: digitsOnly,
      playType: config.code,
      playTypeName: config.name,
      multiplier: mult ?? defaultMultiplier,
      color: config.color,
      baseAmount: config.baseAmount,
    )];
  }

  static bool _isZqPlayType(String? code) {
    if (code == null) return false;
    return code.startsWith('zq6_') || code.startsWith('zq3_');
  }

  static List<ParsedItem> parse(String input, {String? forcePlayType, double defaultMultiplier = 1.0}) {
    if (input.trim().isEmpty) return [];

    final multiLinePosResult = _tryParseMultiLinePosition(input, forcePlayType: forcePlayType, defaultMultiplier: defaultMultiplier);
    if (multiLinePosResult != null) return multiLinePosResult;

    final singleGroupResult = _tryParseSingleGroupLines(input, forcePlayType: forcePlayType, defaultMultiplier: defaultMultiplier);
    if (singleGroupResult != null) return singleGroupResult;

    final preprocessed = _preprocessInput(input);
    if (preprocessed.trim().isEmpty) return [];

    if (_isMultiLinePosComposite(preprocessed)) {
      final joined = preprocessed.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
      return _parsePosComposite(joined, forcePlayType: forcePlayType, defaultMultiplier: defaultMultiplier);
    }

    final results = <ParsedItem>[];
    final lines = preprocessed.split('\n').where((l) => l.trim().isNotEmpty).toList();
    for (final line in lines) {
      final items = _parseLine(line.trim(), forcePlayType: forcePlayType, defaultMultiplier: defaultMultiplier);
      results.addAll(items);
    }
    return results;
  }

  static List<ParsedItem> _parseLine(String line, {String? forcePlayType, double defaultMultiplier = 1.0}) {
    if (_isPosCompositeFormat(line)) {
      return _parsePosComposite(line, forcePlayType: forcePlayType, defaultMultiplier: defaultMultiplier);
    }

    final config = forcePlayType != null ? PlayTypes.getByCode(forcePlayType) : null;
    if (config != null && config.isWholeLine) return [_createItem(line, config, defaultMultiplier)];

    final prefixMatch = _detectPrefix(line);
    if (prefixMatch != null) return _parseWithPrefix(line, prefixMatch, defaultMultiplier);

    if (_isZqPlayType(forcePlayType)) {
      return _parseZqComposite(line, forcePlayType!, defaultMultiplier);
    }
    if (forcePlayType != null) return _splitAndCreate(line, PlayTypes.getByCode(forcePlayType)!, defaultMultiplier);
    final numGroupResult = _parseNumGroupSuffix(line, defaultMultiplier);
    if (numGroupResult.isNotEmpty) return numGroupResult;
    final detected = _autoDetectPlayType(line);
    if (detected != null) {
      final pc = PlayTypes.getByCode(detected);
      if (pc == null) return _splitAndCreate(line, PlayTypes.getByCode('single')!, defaultMultiplier);
      if (pc.isWholeLine) return [_createItem(line, pc, defaultMultiplier)];
      if (detected == 'pos1') {
        final posName = _extractPosNameFromLine(line);
        final numStr = line.replaceAll(RegExp(r'[^\d]'), '').trim();
        if (numStr.length == 1) {
          return [ParsedItem(number: '$posName,$numStr', playType: pc.code, playTypeName: pc.name, multiplier: defaultMultiplier, color: pc.color, baseAmount: pc.baseAmount)];
        }
      }
      if (detected == 'pos2') {
        final posName = _extractPos2NameFromLine(line);
        final numStr = line.replaceAll(RegExp(r'[^\d]'), '').trim();
        if (numStr.length == 2) {
          return [ParsedItem(number: '$posName,$numStr', playType: pc.code, playTypeName: pc.name, multiplier: defaultMultiplier, color: pc.color, baseAmount: pc.baseAmount)];
        }
      }
      return _splitAndCreate(line, pc, defaultMultiplier);
    }
    return _splitAndCreate(line, PlayTypes.getByCode('single')!, defaultMultiplier);
  }

  static String? _detectPrefix(String line) {
    for (final entry in _prefixLookup.entries) {
      if (line.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  static List<ParsedItem> _parseWithPrefix(String line, String playTypeCode, double defaultMultiplier) {
    final colonIndex = line.indexOf(RegExp(r'[:：]'));
    final prefix = line.substring(0, colonIndex).trim();
    final content = line.substring(colonIndex + 1).trim();

    if (playTypeCode == 'group_auto') {
      if (_isPosCompositeFormat(content)) {
        return _parsePosComposite(content, forcePlayType: 'group_auto', defaultMultiplier: defaultMultiplier);
      }
      final parts = _splitContent(content);
      final items = <ParsedItem>[];
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final mult = _extractMultiplier(trimmed);
        final numStr = trimmed.replaceAll(_multiplierRegex, '').trim();
        if (numStr.isEmpty) continue;
        final effectiveMult = mult ?? defaultMultiplier;
        if (RegExp(r'^\d{3}$').hasMatch(numStr)) {
          final hasDup = _hasDuplicateDigit(numStr);
          final actualCode = hasDup ? 'group3' : 'group6';
          final config = PlayTypes.getByCode(actualCode)!;
          items.add(ParsedItem(number: numStr, playType: actualCode, playTypeName: hasDup ? '组三' : '组六', multiplier: effectiveMult, color: config.color, baseAmount: config.baseAmount));
        } else {
          final config = PlayTypes.getByCode('group6')!;
          items.add(ParsedItem(number: numStr, playType: 'group6', playTypeName: '组六', multiplier: effectiveMult, color: config.color, baseAmount: config.baseAmount));
        }
      }
      return items;
    }

    final config = PlayTypes.getByCode(playTypeCode);
    if (config == null) return _splitAndCreate(content, PlayTypes.getByCode('single')!, defaultMultiplier);

    if (_isPosCompositeFormat(content)) {
      return _parsePosComposite(content, forcePlayType: playTypeCode, defaultMultiplier: defaultMultiplier);
    }

    if (_isZqPlayType(playTypeCode)) {
      return _parseZqComposite(content, playTypeCode, defaultMultiplier);
    }

    if (config.isWholeLine) {
      if (content.trim().isEmpty) return [];
      return [_createItem(content, config, defaultMultiplier)];
    }

    if (playTypeCode == 'pos1') {
      final posName = _extractPosName(prefix);
      final parts = _splitContent(content);
      final items = <ParsedItem>[];
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final mult = _extractMultiplier(trimmed);
        final numStr = trimmed.replaceAll(_multiplierRegex, '').trim();
        if (numStr.isEmpty) continue;
        items.add(ParsedItem(number: '$posName,$numStr', playType: config.code, playTypeName: config.name, multiplier: mult ?? defaultMultiplier, color: config.color, baseAmount: config.baseAmount));
      }
      return items;
    }

    if (playTypeCode == 'pos2') {
      final posName = _extractPos2Name(prefix);
      final parts = _splitContent(content);
      final items = <ParsedItem>[];
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final mult = _extractMultiplier(trimmed);
        final numStr = trimmed.replaceAll(_multiplierRegex, '').trim();
        if (numStr.isEmpty) continue;
        items.add(ParsedItem(number: '$posName,$numStr', playType: config.code, playTypeName: config.name, multiplier: mult ?? defaultMultiplier, color: config.color, baseAmount: config.baseAmount));
      }
      return items;
    }

    return _splitAndCreate(content, config, defaultMultiplier);
  }

  static String _extractPosName(String prefix) {
    if (prefix.contains('百')) return '百位';
    if (prefix.contains('十')) return '十位';
    if (prefix.contains('个')) return '个位';
    return '百位';
  }

  static String _extractPos2Name(String prefix) {
    if (prefix.contains('前两') || prefix.contains('首尾')) return '前两位';
    if (prefix.contains('后两')) return '后两位';
    return '前两位';
  }

  static String _extractPosNameFromLine(String line) {
    if (line.contains('百')) return '百位';
    if (line.contains('十')) return '十位';
    if (line.contains('个')) return '个位';
    return '百位';
  }

  static String _extractPos2NameFromLine(String line) {
    if (line.contains('前两') || line.contains('首尾')) return '前两位';
    if (line.contains('后两')) return '后两位';
    return '前两位';
  }

  static String? _autoDetectPlayType(String line) {
    final clean = line.replaceAll(RegExp(r'[ *×xX]\d+\.?\d*$'), '').trim();
    if (clean == '大' || clean == '小' || clean == '大小') return 'bigsmall';
    if (clean == '单' || clean == '双' || clean == '单双') return 'oddeven';
    if (RegExp(r'^[0-9]$').hasMatch(clean)) return 'dan';
    if (RegExp(r'^(百|十|个)位?\d$').hasMatch(clean)) return 'pos1';
    if (RegExp(r'^(前两位|后两位|首尾),\d{2}$').hasMatch(clean)) return 'pos2';
    final spanMatch = RegExp(r'^(\d)跨').firstMatch(clean);
    if (spanMatch != null) return 'span${spanMatch.group(1)}';
    if (RegExp(r'^\d{3},\d{3}$').hasMatch(clean)) {
      final parts = clean.split(',');
      final hasPair = _hasDuplicateDigit(parts[0]) || _hasDuplicateDigit(parts[1]);
      return hasPair ? 'shuangfei_g3' : 'shuangfei_g6';
    }
    if (RegExp(r'^\d{3}$').hasMatch(clean)) return _hasDuplicateDigit(clean) ? 'group3' : 'group6';
    final numVal = int.tryParse(clean);
    if (numVal != null && numVal >= 0 && numVal <= 27) return 'sum_$numVal';
    final digitsOnly = clean.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 2 && digitsOnly.length <= 9) {
      final uniqueDigits = digitsOnly.split('').toSet().length;
      if (uniqueDigits >= 2 && uniqueDigits <= 9 && uniqueDigits == digitsOnly.length) {
        if (uniqueDigits <= 3) {
          if (uniqueDigits == 2) return 'g3_2';
          return 'g3_$uniqueDigits';
        }
        if (uniqueDigits == 4) return 'g6_4';
        return 'g6_$uniqueDigits';
      }
    }
    return null;
  }

  static bool _hasDuplicateDigit(String s) => s.split('').toSet().length < s.length;

  static List<ParsedItem> _splitAndCreate(String content, PlayTypeConfig config, double defaultMultiplier) {
    final parts = _splitContent(content);
    final items = <ParsedItem>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final mult = _extractMultiplier(trimmed);
      final numStr = trimmed.replaceAll(_multiplierRegex, '').trim();
      if (numStr.isEmpty) continue;
      items.add(ParsedItem(number: numStr, playType: config.code, playTypeName: config.name, multiplier: mult ?? defaultMultiplier, color: config.color, baseAmount: config.baseAmount));
    }
    return items;
  }

  static List<String> _splitContent(String content) {
    var result = content;
    for (final sep in separators) result = result.replaceAll(sep, ',');
    result = result.replaceAll(RegExp(r'[\s\u3000]+'), ',');
    result = result.replaceAll(RegExp(r'(?<=\d)[-—–](?=\d)'), ',');
    result = result.replaceAll(RegExp(r'(?<=\d)/'), ',');
    result = result.replaceAll(RegExp(r'(?<=\d{3})\.(?=\d{3})'), ',');
    return result.split(',').where((s) => s.trim().isNotEmpty).toList();
  }

  static double? _extractMultiplier(String text) {
    final match = _multiplierRegex.firstMatch(text);
    return match != null ? double.parse(match.group(1)!) : null;
  }

  static ParsedItem _createItem(String number, PlayTypeConfig config, double multiplier) {
    final mult = _extractMultiplier(number) ?? multiplier;
    var cleanNum = number.replaceAll(_multiplierRegex, '').trim();
    if (config.isWholeLine) {
      cleanNum = cleanNum.replaceAll(RegExp(r'[ *×xX]\d+\.?\d*$'), '').trim();
    }
    return ParsedItem(number: cleanNum.isEmpty ? number : cleanNum, playType: config.code, playTypeName: config.name, multiplier: mult, color: config.color, baseAmount: config.baseAmount);
  }
}
