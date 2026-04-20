import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/bet_record.dart';

class ExportPanel extends StatelessWidget {
  final List<dynamic> filteredBets;

  const ExportPanel({super.key, required this.filteredBets});

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  int _displayWidth(String text) {
    int width = 0;
    for (final rune in text.runes) {
      if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
          (rune >= 0x3000 && rune <= 0x303F) ||
          (rune >= 0xFF00 && rune <= 0xFFEF) ||
          (rune >= 0xF900 && rune <= 0xFAFF) ||
          (rune >= 0x2E80 && rune <= 0x2EFF) ||
          (rune >= 0x3400 && rune <= 0x4DBF) ||
          (rune >= 0xFE30 && rune <= 0xFE4F)) {
        width += 2;
      } else {
        width += 1;
      }
    }
    return width;
  }

  String _padRightDisplay(String text, int targetWidth) {
    final currentWidth = _displayWidth(text);
    if (currentWidth >= targetWidth) return text;
    return text + ' ' * (targetWidth - currentWidth);
  }

  String _padLeftDisplay(String text, int targetWidth) {
    final currentWidth = _displayWidth(text);
    if (currentWidth >= targetWidth) return text;
    return ' ' * (targetWidth - currentWidth) + text;
  }

  String _generateCSV(List<BetRecord> bets) {
    final buf = StringBuffer();
    buf.write('\uFEFF');
    buf.writeln('序号,彩种,玩法,号码,金额(元),录入时间');
    for (var i = 0; i < bets.length; i++) {
      final b = bets[i];
      final amount = (b.multiplier * b.baseAmount).toStringAsFixed(2);
      buf.writeln('${i + 1},${_escapeCsvField(b.lotteryType == 1 ? "福彩3D" : "排列三")},${_escapeCsvField(b.playTypeName)},${_escapeCsvField(b.number)},$amount,${DateFormat('yyyy-MM-dd HH:mm:ss').format(b.createTime)}');
    }
    final totalAmount = bets.fold<double>(0, (sum, b) => sum + b.multiplier * b.baseAmount);
    buf.writeln(',,,,合计,${totalAmount.toStringAsFixed(2)}元,');
    return buf.toString();
  }

  String _generateTXT(List<BetRecord> bets) {
    final totalAmount = bets.fold<double>(0, (sum, b) => sum + b.multiplier * b.baseAmount);
    const lineLen = 80;
    final doubleLine = '═' * lineLen;
    final singleLine = '─' * lineLen;
    final lines = <String>[
      doubleLine,
      '  福彩3D / 排列三  投注记录导出',
      doubleLine,
      '',
      '  开发者：杰哥网络科技 · QQ 2711793818',
      '',
      '  导出时间：${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
      '  总记录数：${bets.length}',
      '  总金额：${totalAmount.toStringAsFixed(2)} 元',
      '',
      singleLine,
      '  ${_padLeftDisplay("序号", 6)} ${_padRightDisplay("彩种", 10)} ${_padRightDisplay("玩法", 12)} ${_padRightDisplay("号码", 16)} ${_padLeftDisplay("金额", 8)} 时间',
      singleLine,
    ];

    for (var i = 0; i < bets.length; i++) {
      final b = bets[i];
      final lotteryName = b.lotteryType == 1 ? '福彩3D' : '排列三';
      final amount = (b.multiplier * b.baseAmount).toStringAsFixed(2);
      final numStr = b.number.length > 14 ? '${b.number.substring(0, 12)}..' : b.number;
      final idx = (i + 1).toString();
      final amtStr = '$amount元';
      lines.add(
        '  ${_padLeftDisplay(idx, 6)} ${_padRightDisplay(lotteryName, 10)} ${_padRightDisplay(b.playTypeName, 12)} ${_padRightDisplay(numStr, 16)} ${_padLeftDisplay(amtStr, 8)} ${DateFormat('MM-dd HH:mm').format(b.createTime)}',
      );
    }

    lines.addAll([
      singleLine,
      '  合计：${bets.length} 条记录  总金额：${totalAmount.toStringAsFixed(2)} 元',
      doubleLine,
    ]);
    return lines.join('\n');
  }

  String _generateJSON(List<BetRecord> bets) {
    final totalAmount = bets.fold<double>(0, (sum, b) => sum + b.multiplier * b.baseAmount);
    final data = {
      'exportInfo': {
        'appName': '福彩3D助手',
        'developer': '杰哥网络科技',
        'exportTime': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'totalRecords': bets.length,
        'totalAmount': totalAmount.toStringAsFixed(2),
      },
      'records': bets.map((b) => {
        'number': b.number,
        'playType': b.playType,
        'playTypeName': b.playTypeName,
        'lotteryType': b.lotteryType,
        'lotteryName': b.lotteryType == 1 ? '福彩3D' : '排列三',
        'multiplier': b.multiplier,
        'baseAmount': b.baseAmount,
        'amount': (b.multiplier * b.baseAmount).toStringAsFixed(2),
        'batchId': b.batchId,
        'createTime': DateFormat('yyyy-MM-dd HH:mm:ss').format(b.createTime),
      }).toList(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  String _generateMarkdown(List<BetRecord> bets) {
    final totalAmount = bets.fold<double>(0, (sum, b) => sum + b.multiplier * b.baseAmount);
    final buf = StringBuffer();
    buf.writeln('# 福彩3D / 排列三 投注记录导出');
    buf.writeln();
    buf.writeln('> 开发者：杰哥网络科技 · 导出时间：${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buf.writeln('>');
    buf.writeln('> 总记录数：${bets.length} · 总金额：${totalAmount.toStringAsFixed(2)} 元');
    buf.writeln();
    buf.writeln('| 序号 | 彩种 | 玩法 | 号码 | 金额(元) | 时间 |');
    buf.writeln('|------|------|------|------|----------|------|');
    for (var i = 0; i < bets.length; i++) {
      final b = bets[i];
      final amount = (b.multiplier * b.baseAmount).toStringAsFixed(2);
      final lotteryName = b.lotteryType == 1 ? '福彩3D' : '排列三';
      buf.writeln('| ${i + 1} | $lotteryName | ${b.playTypeName} | ${b.number} | $amount | ${DateFormat('MM-dd HH:mm').format(b.createTime)} |');
    }
    buf.writeln();
    buf.writeln('**合计：${bets.length} 条记录 · 总金额：${totalAmount.toStringAsFixed(2)} 元**');
    return buf.toString();
  }

  Future<void> _shareFile(String content, String fileName, String mimeType, BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);
      await Share.shareXFiles([XFile(file.path, mimeType: mimeType)], text: '福彩3D助手数据导出');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  void _showExportDialog(BuildContext context, List<BetRecord> bets) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('数据导出', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.table_chart, color: AppColors.primary),
            title: const Text('导出 CSV 文件'),
            subtitle: const Text('Excel 兼容格式，含单价和金额'),
            onTap: () {
              Navigator.pop(ctx);
              final csv = _generateCSV(bets);
              final fileName = '投注记录_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
              _shareFile(csv, fileName, 'text/csv', context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.description, color: AppColors.cyan),
            title: const Text('导出 TXT 文本'),
            subtitle: const Text('纯文本格式，清晰对齐'),
            onTap: () {
              Navigator.pop(ctx);
              final txt = _generateTXT(bets);
              final fileName = '投注记录_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.txt';
              _shareFile(txt, fileName, 'text/plain', context);
            },
          ),
          ListTile(
            leading: Icon(Icons.code, color: AppColors.purple),
            title: const Text('导出 JSON 文件'),
            subtitle: const Text('结构化数据格式，便于二次处理'),
            onTap: () {
              Navigator.pop(ctx);
              final json = _generateJSON(bets);
              final fileName = '投注记录_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
              _shareFile(json, fileName, 'application/json', context);
            },
          ),
          ListTile(
            leading: Icon(Icons.article, color: AppColors.success),
            title: const Text('导出 Markdown'),
            subtitle: const Text('表格格式，适合文档和笔记'),
            onTap: () {
              Navigator.pop(ctx);
              final md = _generateMarkdown(bets);
              final fileName = '投注记录_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.md';
              _shareFile(md, fileName, 'text/markdown', context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.copy, color: AppColors.textSecondary),
            title: const Text('复制到剪贴板'),
            subtitle: const Text('复制格式化文本到剪贴板'),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                final txt = _generateTXT(bets);
                await Clipboard.setData(ClipboardData(text: txt));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 2)),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('复制失败: $e')));
                }
              }
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (filteredBets.isEmpty) return const SizedBox.shrink();
    final bets = filteredBets.cast<BetRecord>();
    final totalAmount = bets.fold<double>(0, (sum, b) => sum + b.multiplier * b.baseAmount);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.upload_file_outlined, color: AppColors.primary, size: 28),
        title: const Text('数据导出', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('共 ${bets.length} 条记录 / ${totalAmount.toStringAsFixed(2)} 元 · 支持 CSV/TXT/JSON/MD', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showExportDialog(context, bets),
      ),
    );
  }
}
