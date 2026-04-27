import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/bet_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/db_service.dart';
import '../../models/bet_record.dart';
import '../../models/draw_record.dart';
import '../../models/app_settings.dart';
import '../../widgets/toast.dart';
import 'widgets/draw_data_list.dart';
import 'widgets/play_type_amount_settings.dart';
import '../pattern/pattern_manage_page.dart' as pattern;

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('数据管理', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text('开发者：杰哥网络科技', style: TextStyle(fontSize: 10, color: AppColors.textLight))])),
          const DrawDataList(),
          const SizedBox(height: 16),
          _buildActionCards(context),
          const SizedBox(height: 20),
        ],
      ),
    ));
  }

  Widget _buildActionCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        _buildCard(Icons.psychology, '智能识别设置', '添加案例让系统学习您的输入习惯', AppColors.primary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const pattern.PatternManagePage()))),
        _buildCard(Icons.attach_money, '玩法金额设置', '自定义各玩法的投注金额', AppColors.success, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayTypeAmountSettingsPage()))),
        _buildCard(Icons.backup_outlined, '数据备份', '备份所有数据到文件', AppColors.primary, () => _showBackupDialog(context)),
        _buildCard(Icons.restore_outlined, '数据恢复', '从备份文件恢复数据', AppColors.warning, () => _showRestoreDialog(context)),
        _buildCard(Icons.cleaning_services_outlined, '清空数据', '删除所有投注和开奖记录', AppColors.danger, () => _showClearConfirm(context)),
      ]),
    );
  }

  Widget _buildCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      leading: CircleAvatar(backgroundColor: color.withAlpha(26), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ));
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('数据备份'), content: const Text('将备份所有投注记录、开奖数据和设置信息，导出为 JSON 文件'), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
      ElevatedButton(onPressed: () async {
        Navigator.pop(ctx);
        try {
          final db = DatabaseHelper.instance;
          final bets = await db.getAllBets();
          final draws = await db.getAllDraws();
          final settings = await db.getSettings();
          final amounts = await db.getPlayTypeAmounts();
          final winAmounts = await db.getPlayTypeWinAmounts();

          final backupData = {
            'version': 1,
            'backupTime': DateTime.now().toIso8601String(),
            'developer': '杰哥网络科技',
            'bets': bets.map((b) => b.toMap()).toList(),
            'draws': draws.map((d) => d.toMap()).toList(),
            'settings': settings.toMap(),
            'playTypeAmounts': amounts,
            'playTypeWinAmounts': winAmounts,
          };

          final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/lottery3d_backup_${DateTime.now().millisecondsSinceEpoch}.json');
          await file.writeAsString(jsonStr);

          await Share.shareXFiles([XFile(file.path)], text: '福彩3D助手数据备份 - ${DateTime.now().toString().substring(0, 10)}');

          if (!mounted) return;
          final backupTime = DateTime.now().toIso8601String();
          await Provider.of<SettingsProvider>(context, listen: false).updateBackupTime(backupTime);
          if (mounted) ToastUtil.success(context, '备份成功');
        } catch (e) {
          if (mounted) ToastUtil.error(context, '备份失败: $e');
        }
      }, child: const Text('确认备份')),
    ]));
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('⚠️ 数据恢复'),
      content: const Text('从备份文件恢复数据将覆盖当前所有数据，建议先备份当前数据。\n\n请将备份的 JSON 文件内容粘贴到下方输入框中'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () {
          Navigator.pop(ctx);
          _showRestoreInputDialog(context);
        }, child: const Text('下一步')),
      ],
    ));
  }

  void _showRestoreInputDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('粘贴备份数据'),
      content: SizedBox(width: double.maxFinite, height: 200, child: TextField(controller: ctrl, maxLines: null, expands: true, decoration: const InputDecoration(hintText: '粘贴 JSON 备份内容...', border: OutlineInputBorder()))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          try {
            final data = json.decode(ctrl.text.trim());
            if (data['version'] == null) {
              if (mounted) ToastUtil.warning(context, '无效的备份文件');
              return;
            }
            final db = DatabaseHelper.instance;
            await db.deleteAllBets();
            await db.deleteAllDraws();

            if (data['bets'] != null) {
              for (final betMap in data['bets']) {
                await db.insertBet(BetRecord.fromMap(Map<String, dynamic>.from(betMap)));
              }
            }
            if (data['draws'] != null) {
              for (final drawMap in data['draws']) {
                await db.insertDraw(DrawRecord.fromMap(Map<String, dynamic>.from(drawMap)));
              }
            }
            if (data['settings'] != null) {
              await db.updateSettings(AppSettings.fromMap(Map<String, dynamic>.from(data['settings'])));
            }
            if (data['playTypeAmounts'] != null) {
              final amounts = Map<String, dynamic>.from(data['playTypeAmounts']);
              final winAmounts = data['playTypeWinAmounts'] != null ? Map<String, dynamic>.from(data['playTypeWinAmounts']) : <String, dynamic>{};
              for (final entry in amounts.entries) {
                await db.setPlayTypeAmount(entry.key, (entry.value as num).toDouble(), (winAmounts[entry.key] as num?)?.toDouble() ?? 0.0);
              }
            }

            await Provider.of<BetProvider>(context, listen: false).loadBets();
            await Provider.of<SettingsProvider>(context, listen: false).loadSettings();
            if (mounted) ToastUtil.success(context, '数据恢复成功');
          } catch (e) {
            if (mounted) ToastUtil.error(context, '恢复失败: $e');
          }
        }, child: const Text('确认恢复')),
      ],
    ));
  }

  void _showClearConfirm(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('⚠️ 确认清空'),
      content: const Text('此操作将删除所有投注记录和开奖数据，且不可恢复！建议先备份数据'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () async {
            Navigator.pop(ctx);
            await Provider.of<BetProvider>(context, listen: false).deleteAllBets();
            await DatabaseHelper.instance.deleteAllDraws();
            if (mounted) ToastUtil.success(context, '已清空所有数据');
          },
          child: const Text('确认清空'),
        ),
      ],
    ));
  }
}
