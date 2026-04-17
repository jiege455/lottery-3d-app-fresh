import '../models/bet_record.dart';
import '../models/draw_record.dart';

class CheckResult {
  final BetRecord bet;
  final bool isWin;
  final String winType;
  final double winAmount;
  final double betAmount;

  const CheckResult({
    required this.bet,
    required this.isWin,
    required this.winType,
    required this.winAmount,
    required this.betAmount,
  });
}

class CheckService {

  // ========== ⚠️ 重要：以下赔率配置为最终确认的默认值，禁止随意修改！ ==========
  // 开发者：杰哥网络科技 | 确认日期：2026-04-12
  // 修改规则：
  //   1. 所有玩法统一：中奖金额 = 投注金额(baseAmount) × 赔率(oddsMap)
  //   2. 基础三码(直选/组三/组六)投注=2元，其他玩法投注=10元
  //   3. 转圈/沾边类赔率已换算好，乘出来就是正确的中奖金额
  //   4. 如需调整金额，请在APP"玩法金额设置"页面修改，不要改此文件
  // =========================================================================
  static const Map<String, double> oddsMap = {
    'single': 925.0,
    'group3': 305.0,
    'group6': 152.5,
    'dan': 3.4,
    'pos1': 9.0,
    'pos2': 90.0,
    'shuangfei_g3': 30.0, 'shuangfei_g6': 16.5,
    'g3_2': 150.0, 'g3_3': 50.0, 'g3_4': 25.0, 'g3_5': 15.0,
    'g3_6': 10.0, 'g3_7': 7.2, 'g3_8': 5.4, 'g3_9': 4.2, 'g3_all': 3.3,
    'g6_4': 37.0, 'g6_5': 15.0, 'g6_6': 7.8, 'g6_7': 4.4,
    'g6_8': 2.7, 'g6_9': 1.9, 'g6_all': 1.25,
    'g6_dt2': 150.0, 'g6_dt3': 50.0, 'g6_dt4': 25.0, 'g6_dt5': 15.0,
    'g6_dt6': 10.0, 'g6_dt7': 7.0, 'g6_dt8': 5.0, 'g6_dt9': 4.0,
    'g3_dt2': 75.0, 'g3_dt3': 50.0, 'g3_dt4': 37.0, 'g3_dt5': 30.0,
    'g3_dt6': 25.0, 'g3_dt7': 20.0, 'g3_dt8': 18.5, 'g3_dt9': 16.0,
    'baozi_single': 170.0, 'baozi_all': 85.0,
    'zq6_3': 150.0, 'zq6_4': 37.5, 'zq6_5': 15.0, 'zq6_6': 7.5,
    'zq6_7': 4.29, 'zq6_8': 2.68, 'zq6_9': 1.79, 'zq6_all': 1.25,
    'zq3_2': 150.0, 'zq3_3': 50.0, 'zq3_4': 25.0, 'zq3_5': 15.0,
    'zq3_6': 10.0, 'zq3_7': 7.14, 'zq3_8': 5.36, 'zq3_9': 4.17, 'zq3_all': 3.33,
    'zbl_g6_1': 4.17, 'zbl_g6_2': 2.34, 'zbl_g6_3': 1.76, 'zbl_g6_4': 1.5,
    'zbl_g6_5': 1.36, 'zbl_g6_6': 1.29, 'zbl_g6_7': 1.26,
    'zbl_g3_1': 16.67, 'zbl_g3_2': 8.82, 'zbl_g3_3': 6.25, 'zbl_g3_4': 5.0,
    'zbl_g3_5': 4.29, 'zbl_g3_6': 3.85, 'zbl_g3_7': 3.57,
    'fs_3': 33.4, 'fs_4': 14.1, 'fs_5': 7.2, 'fs_6': 4.2,
    'fs_7': 2.6, 'fs_8': 1.7, 'fs_9': 1.23, 'fs_all': 1.0,
    'span0': 80.0, 'span1': 16.5, 'span2': 9.2, 'span3': 7.0,
    'span4': 6.2, 'span5': 6.0, 'span6': 6.2, 'span7': 7.0,
    'span8': 9.2, 'span9': 16.5,
    'sum_0': 900.0, 'sum_27': 900.0,
    'sum_1': 300.0, 'sum_26': 300.0,
    'sum_2': 150.0, 'sum_25': 150.0,
    'sum_3': 90.0, 'sum_24': 90.0,
    'sum_4': 60.0, 'sum_23': 60.0,
    'sum_5': 42.6, 'sum_22': 42.6,
    'sum_6': 32.0, 'sum_21': 32.0,
    'sum_7': 25.0, 'sum_20': 25.0,
    'sum_8': 20.0, 'sum_19': 20.0,
    'sum_9': 16.2, 'sum_18': 16.2,
    'sum_10': 14.2, 'sum_17': 14.2,
    'sum_11': 13.0, 'sum_16': 13.0,
    'sum_12': 12.2, 'sum_15': 12.2,
    'sum_13': 12.0, 'sum_14': 12.0,
    'bigsmall': 1.8,
    'oddeven': 1.8,
  };

  static List<CheckResult> checkAll(List<BetRecord> bets, DrawRecord draw, [Map<String, double>? customWinAmounts]) {
    return bets.map((bet) => checkSingle(bet, draw, customWinAmounts?[bet.playType] ?? 0.0)).toList();
  }

  static CheckResult checkSingle(BetRecord bet, DrawRecord draw, [double customWinAmount = 0.0]) {
    final nums = draw.numbers;
    if (nums.length != 3 || bet.number.isEmpty) {
      return CheckResult(bet: bet, isWin: false, winType: '', winAmount: 0, betAmount: bet.multiplier * bet.baseAmount);
    }

    bool isWin = false;
    String winType = '';
    double baseOdds = 0;

    switch (bet.playType) {
      case 'single':
        isWin = bet.number == nums;
        winType = '直选';
        break;
      case 'group3':
        isWin = _isGroup3(bet.number) && _isSameGroup(bet.number, nums);
        winType = '组三';
        break;
      case 'group6':
        isWin = _isGroup6(bet.number) && _isSameGroup(bet.number, nums);
        winType = '组六';
        break;
      case 'dan':
        isWin = nums.contains(bet.number);
        winType = '胆码';
        break;
      case 'pos1':
        final parts = bet.number.split(',');
        if (parts.length == 2) {
          final pos = parts[0];
          final digit = parts[1];
          int idx = pos == '百位' ? 0 : (pos == '十位' ? 1 : 2);
          isWin = nums[idx] == digit;
          winType = '定位';
        }
        break;
      case 'pos2':
        final parts = bet.number.split(',');
        if (parts.length == 2) {
          final pos = parts[0];
          final digits = parts[1];
          if (pos == '前两位') {
            isWin = '${nums[0]}${nums[1]}' == digits;
            winType = '前两位';
          } else if (pos == '后两位') {
            isWin = '${nums[1]}${nums[2]}' == digits;
            winType = '后两位';
          } else if (pos == '首尾') {
            isWin = '${nums[0]}${nums[2]}' == digits;
            winType = '首尾';
          }
        }
        break;
      case 'shuangfei_g3':
        if (DrawRecord.getFormType(nums) == '组三') {
          final betDigits = bet.number.replaceAll(RegExp(r'[^0-9]'), '').split('').toSet();
          final drawDigits = nums.split('').toSet();
          isWin = drawDigits.every((d) => betDigits.contains(d));
          if (isWin) winType = '双飞组三';
        }
        break;
      case 'shuangfei_g6':
        if (DrawRecord.getFormType(nums) == '组六') {
          final betDigits = bet.number.replaceAll(RegExp(r'[^0-9]'), '').split('').toSet();
          final drawDigits = nums.split('').toSet();
          isWin = drawDigits.every((d) => betDigits.contains(d));
          if (isWin) winType = '双飞组六';
        }
        break;
      case var pt when pt.startsWith('g6_dt'):
        if (DrawRecord.getFormType(nums) == '组六') {
          final parts = bet.number.split(':');
          if (parts.length == 2) {
            final dan = parts[0];
            final tuo = parts[1].split('').toSet();
            final drawDigits = nums.split('');
            if (drawDigits.contains(dan)) {
              final otherDigits = drawDigits.where((d) => d != dan).toSet();
              isWin = otherDigits.every((d) => tuo.contains(d));
            }
            if (isWin) winType = '组六胆拖';
          }
        }
        break;
      case var pt when pt.startsWith('g3_dt'):
        if (DrawRecord.getFormType(nums) == '组三') {
          final parts = bet.number.split(':');
          if (parts.length == 2) {
            final dan = parts[0];
            final tuo = parts[1].split('').toSet();
            final drawDigits = nums.split('');
            if (drawDigits.contains(dan)) {
              final otherDigits = drawDigits.where((d) => d != dan).toSet();
              isWin = otherDigits.every((d) => tuo.contains(d));
            }
            if (isWin) winType = '组三胆拖';
          }
        }
        break;
      case 'baozi_single':
        isWin = bet.number == nums && nums[0] == nums[1] && nums[1] == nums[2];
        if (isWin) winType = '豹子直选';
        break;
      case 'baozi_all':
        isWin = nums[0] == nums[1] && nums[1] == nums[2];
        if (isWin) winType = '豹子组选';
        break;
      case var pt when pt.startsWith('zq6_'):
        if (DrawRecord.getFormType(nums) == '组六') {
          final betDigits = bet.number.split('').toSet();
          final drawDigits = nums.split('').toSet();
          isWin = drawDigits.every((d) => betDigits.contains(d));
          if (isWin) winType = '转圈组六';
        }
        break;
      case var pt when pt.startsWith('zq3_'):
        if (DrawRecord.getFormType(nums) == '组三') {
          final betDigits = bet.number.split('').toSet();
          final drawDigits = nums.split('').toSet();
          isWin = drawDigits.every((d) => betDigits.contains(d));
          if (isWin) winType = '转圈组三';
        }
        break;
      case var pt when pt.startsWith('zbl_g6_'):
        if (DrawRecord.getFormType(nums) == '组六') {
          final betDigits = bet.number.split('').toSet();
          final drawDigits = nums.split('').toSet();
          isWin = betDigits.every((d) => drawDigits.contains(d));
          if (isWin) winType = '沾边组六';
        }
        break;
      case var pt when pt.startsWith('zbl_g3_'):
        if (DrawRecord.getFormType(nums) == '组三') {
          final betDigits = bet.number.split('').toSet();
          final drawDigits = nums.split('').toSet();
          isWin = betDigits.every((d) => drawDigits.contains(d));
          if (isWin) winType = '沾边组三';
        }
        break;
      case var pt when pt.startsWith('span'):
        final spanVal = int.tryParse(pt.replaceAll('span', '')) ?? 0;
        isWin = DrawRecord.getSpan(nums) == spanVal;
        if (isWin) winType = '跨度$spanVal';
        break;
      case var pt when pt.startsWith('sum_'):
        final sumVal = int.tryParse(pt.replaceAll('sum_', '')) ?? 0;
        isWin = DrawRecord.getSumValue(nums) == sumVal;
        if (isWin) winType = '和数$sumVal';
        break;
      case 'bigsmall':
        final sum = DrawRecord.getSumValue(nums);
        isWin = (bet.number == '大' && sum >= 14) || (bet.number == '小' && sum <= 13);
        if (isWin) winType = bet.number == '大' ? '大' : '小';
        break;
      case 'oddeven':
        final sum = DrawRecord.getSumValue(nums);
        isWin = (bet.number == '单' && sum % 2 == 1) || (bet.number == '双' && sum % 2 == 0);
        if (isWin) winType = bet.number == '单' ? '单' : '双';
        break;
      default:
        isWin = _checkComplexPlay(bet, nums);
        if (isWin) winType = bet.playTypeName;
        break;
    }

    if (isWin) {
      baseOdds = oddsMap[bet.playType] ?? 0;
    }

    double winAmount = 0;
    if (isWin) {
      // ⚠️ 以下中奖金额计算规则已确认，禁止修改！杰哥网络科技 2026-04-12
      // 所有玩法统一：中奖金额 = 倍数 × 投注金额 × 赔率
      if (customWinAmount > 0) {
        winAmount = bet.multiplier * customWinAmount;
      } else {
        winAmount = bet.multiplier * bet.baseAmount * baseOdds;
      }
    }

    return CheckResult(
      bet: bet,
      isWin: isWin,
      winType: winType,
      winAmount: winAmount,
      betAmount: bet.multiplier * bet.baseAmount,
    );
  }

  static bool _isSameGroup(String a, String b) {
    return Set.from(a.split('')) == Set.from(b.split(''));
  }

  static bool _isGroup3(String s) {
    final chars = s.split('');
    final uniqueCount = chars.toSet().length;
    return uniqueCount == 2;
  }

  static bool _isGroup6(String s) {
    return s.split('').toSet().length == s.length;
  }

  static bool _checkComplexPlay(BetRecord bet, String nums) {
    if ((bet.playType.startsWith('g3_') || bet.playType.startsWith('g6_')) && !bet.playType.contains('dt')) {
      final digitSet = bet.number.split('').toSet();
      final numSet = nums.split('').toSet();
      if (bet.playType.startsWith('g3_')) {
        if (_isGroup3(nums) && numSet.every((d) => digitSet.contains(d))) {
          return true;
        }
      } else {
        if (_isGroup6(nums) && numSet.every((d) => digitSet.contains(d))) {
          return true;
        }
      }
    }
    if (bet.playType.startsWith('fs_')) {
      final betDigits = bet.number.split('').toSet();
      final numSet = nums.split('').toSet();
      if (numSet.isNotEmpty && betDigits.containsAll(numSet)) return true;
      return false;
    }
    return false;
  }

  static double calculateTotalProfit(List<CheckResult> results) {
    return results.fold<double>(0, (sum, r) => sum + r.winAmount - r.betAmount);
  }

  static int getWinCount(List<CheckResult> results) {
    return results.where((r) => r.isWin).length;
  }

  static int getLoseCount(List<CheckResult> results) {
    return results.where((r) => !r.isWin).length;
  }
}
