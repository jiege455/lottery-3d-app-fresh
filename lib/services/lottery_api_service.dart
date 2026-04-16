import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/draw_record.dart';
import 'db_service.dart';

class LotteryApiService {
  static const Map<int, String> _lotteryCodes = {
    1: 'fcsd',
    2: 'pls',
  };

  static Future<List<DrawRecord>> fetchLatestDraws({required int lotteryType, int count = 10}) async {
    final code = _lotteryCodes[lotteryType] ?? 'fcsd';
    final url = 'https://api.huiniao.top/interface/home/lotteryHistory?type=$code&page=1&limit=$count';

    print('[LotteryApi] 请求: $url');

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['code'] != 1) {
        throw Exception('API 返回错误: ${data['info']}');
      }

      final results = <DrawRecord>[];
      final list = data['data']?['list'] as List? ?? [];

      for (var item in list) {
        if (item is Map) {
          final issue = (item['code'] ?? '').toString();
          final one = item['one'] ?? 0;
          final two = item['two'] ?? 0;
          final three = item['three'] ?? 0;
          final openTime = (item['open_time'] ?? '').toString();

          final numbers = '$one$two$three';

          if (RegExp(r'^[0-9]{3}$').hasMatch(numbers) && issue.isNotEmpty) {
            DateTime drawDate = DateTime.now();
            try {
              if (openTime.isNotEmpty) {
                drawDate = DateTime.parse(openTime);
              }
            } catch (_) {}

            results.add(DrawRecord(
              issue: issue,
              numbers: numbers,
              sumValue: DrawRecord.getSumValue(numbers),
              span: DrawRecord.getSpan(numbers),
              formType: DrawRecord.getFormType(numbers),
              drawDate: drawDate,
              lotteryType: lotteryType,
            ));
          }
        }
      }

      print('[LotteryApi] 成功获取 ${results.length} 条数据');
      return results;
    } on TimeoutException {
      print('[LotteryApi] 请求超时');
      throw Exception('请求超时，请检查网络连接');
    } catch (e) {
      print('[LotteryApi] 错误: $e');
      throw Exception('获取开奖数据失败: $e');
    }
  }

  static Future<int> syncDraws({required int lotteryType, int count = 10}) async {
    final draws = await fetchLatestDraws(lotteryType: lotteryType, count: count);
    if (draws.isEmpty) return 0;

    final existingDraws = await DatabaseHelper.instance.getAllDraws(lotteryType: lotteryType);
    final existingIssues = existingDraws.map((d) => d.issue).toSet();

    int addedCount = 0;
    for (final draw in draws) {
      if (!existingIssues.contains(draw.issue)) {
        await DatabaseHelper.instance.insertDraw(draw);
        addedCount++;
      }
    }

    print('[LotteryApi] 同步完成: 新增 $addedCount 条');
    return addedCount;
  }

  static Future<DrawRecord?> getLatestDraw({required int lotteryType}) async {
    try {
      final draws = await fetchLatestDraws(lotteryType: lotteryType, count: 1);
      return draws.isNotEmpty ? draws.first : null;
    } catch (e) {
      print('[LotteryApi] getLatestDraw error: $e');
      return null;
    }
  }
}
