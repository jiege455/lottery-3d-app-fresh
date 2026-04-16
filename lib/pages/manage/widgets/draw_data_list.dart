import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/draw_record.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/db_service.dart';
import '../../../services/lottery_api_service.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/toast.dart';

class DrawDataList extends StatefulWidget {
  const DrawDataList({super.key});

  @override
  State<DrawDataList> createState() => _DrawDataListState();
}

class _DrawDataListState extends State<DrawDataList> {
  List<DrawRecord> _draws = [];
  bool _loading = false;
  bool _loaded = false;
  bool _showAll = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loaded) {
        _loaded = true;
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      // 加载所有彩种的开奖数据
      final draws = await DatabaseHelper.instance.getAllDraws(limit: 100);
      if (mounted) setState(() { _draws = draws; _loading = false; });
    } catch (e) {
      print('DrawDataList._loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncFromApi() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      int totalCount = 0;
      int failCount = 0;
      try {
        totalCount += await LotteryApiService.syncDraws(lotteryType: 1, count: 20);
      } catch (e) {
        print('同步福彩3D失败: $e');
        failCount++;
      }
      try {
        totalCount += await LotteryApiService.syncDraws(lotteryType: 2, count: 20);
      } catch (e) {
        print('同步排列三失败: $e');
        failCount++;
      }
      await _loadData();
      if (mounted) {
        if (failCount == 2) {
          ToastUtil.error(context, '同步失败，请检查网络连接');
        } else if (failCount > 0) {
          ToastUtil.warning(context, '部分同步失败，成功新增 $totalCount 条');
        } else if (totalCount > 0) {
          ToastUtil.success(context, '同步成功，新增 $totalCount 条开奖数据（福彩 3D+ 排列三）');
        } else {
          ToastUtil.success(context, '已同步，暂无新数据');
        }
      }
    } catch (e) {
      if (mounted) ToastUtil.error(context, '同步失败: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showAddDialog() {
    final issueCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('添加开奖数据'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: issueCtrl, decoration: const InputDecoration(hintText: '期号（如 2024001）', isDense: true)),
        const SizedBox(height: 12),
        TextField(controller: numberCtrl, maxLength: 3, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6), decoration: const InputDecoration(hintText: '3位号码', counterText: '', isDense: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          final numbers = numberCtrl.text.trim();
          if (numbers.length != 3 || !RegExp(r'^[0-9]{3}$').hasMatch(numbers)) {
            ToastUtil.warning(context, '请输入 3 位有效号码');
            return;
          }
          final draw = DrawRecord(
            issue: issueCtrl.text.trim().isEmpty ? '手动录入' : issueCtrl.text.trim(),
            numbers: numbers,
            sumValue: DrawRecord.getSumValue(numbers),
            span: DrawRecord.getSpan(numbers),
            formType: DrawRecord.getFormType(numbers),
            drawDate: DateTime.now(),
            lotteryType: Provider.of<SettingsProvider>(context, listen: false).defaultLotteryType,
          );
          await DatabaseHelper.instance.insertDraw(draw);
          if (mounted) {
            Navigator.pop(ctx);
            ToastUtil.success(context, '添加成功');
            _loadData();
          }
        }, child: const Text('添加')),
      ],
    ));
  }

  void _showBatchAddDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('批量添加开奖数据'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: ctrl, maxLines: 8, decoration: const InputDecoration(hintText: '每行一条，格式：期号 号码\n如：2024001 358\n2024002 672', isDense: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          final text = ctrl.text.trim();
          if (text.isEmpty) return;
          int count = 0;
          final lines = text.split('\n');
          final lotteryType = Provider.of<SettingsProvider>(context, listen: false).defaultLotteryType;
          for (final line in lines) {
            final parts = line.trim().split(RegExp(r'\s+'));
            String issue = '手动录入';
            String numbers = '';
            if (parts.length >= 2) {
              issue = parts[0];
              numbers = parts[1];
            } else if (parts.length == 1 && RegExp(r'^[0-9]{3}$').hasMatch(parts[0])) {
              numbers = parts[0];
            }
            if (numbers.length == 3 && RegExp(r'^[0-9]{3}$').hasMatch(numbers)) {
              final draw = DrawRecord(
                issue: issue,
                numbers: numbers,
                sumValue: DrawRecord.getSumValue(numbers),
                span: DrawRecord.getSpan(numbers),
                formType: DrawRecord.getFormType(numbers),
                drawDate: DateTime.now(),
                lotteryType: lotteryType,
              );
              await DatabaseHelper.instance.insertDraw(draw);
              count++;
            }
          }
          if (mounted) {
            Navigator.pop(ctx);
            ToastUtil.success(context, '成功添加 $count 条');
            _loadData();
          }
        }, child: const Text('添加')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));

    final displayDraws = _showAll ? _draws : _draws.take(10).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('开奖数据 (${_draws.length}条)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(children: [
                IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                IconButton(onPressed: _showBatchAddDialog, icon: const Icon(Icons.playlist_add, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                IconButton(onPressed: _syncing ? null : _syncFromApi, icon: _syncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_download, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          if (_draws.isEmpty)
            EmptyState(message: '暂无开奖数据，点击 + 添加', icon: Icons.data_usage)
          else ...[
            _buildHeader(),
            const SizedBox(height: 4),
            ...displayDraws.map((item) => _buildItem(item)),
            if (_draws.length > 10) Center(child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? '收起' : '查看更多 (${_draws.length - 10}) 条'),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(flex: 2, child: Text('期号', style: TextStyle(fontSize: 11, color: AppColors.textLight))),
        Expanded(flex: 2, child: Text('号码', style: TextStyle(fontSize: 11, color: AppColors.textLight))),
        Expanded(child: Text('和值', style: TextStyle(fontSize: 11, color: AppColors.textLight), textAlign: TextAlign.center)),
        Expanded(child: Text('跨度', style: TextStyle(fontSize: 11, color: AppColors.textLight), textAlign: TextAlign.center)),
        Expanded(child: Text('形态', style: TextStyle(fontSize: 11, color: AppColors.textLight), textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _buildItem(DrawRecord item) {
    Color formColor;
    switch (item.formType) {
      case '豹子': formColor = AppColors.danger; break;
      case '组三': formColor = AppColors.warning; break;
      default: formColor = AppColors.success;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.issue, style: TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(item.numbers, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 3))),
          Expanded(child: Text('${item.sumValue}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
          Expanded(child: Text('${item.span}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: formColor.withAlpha(26), borderRadius: BorderRadius.circular(4)),
            child: Text(item.formType, style: TextStyle(fontSize: 10, color: formColor), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          )),
        ],
      ),
    );
  }
}
