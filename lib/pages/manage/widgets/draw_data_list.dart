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
  int _selectedLotteryType = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loaded) {
        _loaded = true;
        _selectedLotteryType = Provider.of<SettingsProvider>(context, listen: false).defaultLotteryType;
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final draws = await DatabaseHelper.instance.getAllDraws(lotteryType: _selectedLotteryType, limit: 100);
      if (mounted) setState(() { _draws = draws; _loading = false; });
    } catch (e) {
      print('DrawDataList._loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onLotteryTypeChanged(int type) {
    if (_selectedLotteryType == type) return;
    setState(() {
      _selectedLotteryType = type;
      _showAll = false;
    });
    _loadData();
  }

  Future<void> _syncFromApi() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      int fc3dCount = 0;
      int plsCount = 0;
      int failCount = 0;
      try {
        fc3dCount = await LotteryApiService.syncDraws(lotteryType: 1, count: 20);
      } catch (e) {
        print('同步福彩3D失败: $e');
        failCount++;
      }
      try {
        plsCount = await LotteryApiService.syncDraws(lotteryType: 2, count: 20);
      } catch (e) {
        print('同步排列三失败: $e');
        failCount++;
      }
      await _loadData();
      if (mounted) {
        if (failCount == 2) {
          ToastUtil.error(context, '同步失败，请检查网络连接');
        } else if (failCount > 0) {
          final successCount = fc3dCount + plsCount;
          ToastUtil.warning(context, '部分同步失败，成功新增 $successCount 条');
        } else {
          final totalCount = fc3dCount + plsCount;
          if (totalCount > 0) {
            ToastUtil.success(context, '同步成功！福彩3D新增 $fc3dCount 条，排列三新增 $plsCount 条');
          } else {
            ToastUtil.success(context, '已同步，暂无新数据');
          }
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
    int dialogLotteryType = _selectedLotteryType;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: const Text('添加开奖数据'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setDialogState(() => dialogLotteryType = 1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: dialogLotteryType == 1 ? AppColors.primary : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppStyles.radiusXs),
              ),
              child: Text('福彩 3D', textAlign: TextAlign.center, style: TextStyle(
                color: dialogLotteryType == 1 ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 13,
              )),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(
            onTap: () => setDialogState(() => dialogLotteryType = 2),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: dialogLotteryType == 2 ? AppColors.purple : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppStyles.radiusXs),
              ),
              child: Text('排列三', textAlign: TextAlign.center, style: TextStyle(
                color: dialogLotteryType == 2 ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 13,
              )),
            ),
          )),
        ]),
        const SizedBox(height: 12),
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
            lotteryType: dialogLotteryType,
          );
          await DatabaseHelper.instance.insertDraw(draw);
          if (mounted) {
            Navigator.pop(ctx);
            final typeName = dialogLotteryType == 1 ? '福彩3D' : '排列三';
            ToastUtil.success(context, '$typeName 开奖数据添加成功');
            if (dialogLotteryType == _selectedLotteryType) {
              _loadData();
            }
          }
        }, child: const Text('添加')),
      ],
    )));
  }

  void _showBatchAddDialog() {
    final ctrl = TextEditingController();
    int dialogLotteryType = _selectedLotteryType;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: const Text('批量添加开奖数据'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setDialogState(() => dialogLotteryType = 1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: dialogLotteryType == 1 ? AppColors.primary : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppStyles.radiusXs),
              ),
              child: Text('福彩 3D', textAlign: TextAlign.center, style: TextStyle(
                color: dialogLotteryType == 1 ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 13,
              )),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(
            onTap: () => setDialogState(() => dialogLotteryType = 2),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: dialogLotteryType == 2 ? AppColors.purple : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppStyles.radiusXs),
              ),
              child: Text('排列三', textAlign: TextAlign.center, style: TextStyle(
                color: dialogLotteryType == 2 ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 13,
              )),
            ),
          )),
        ]),
        const SizedBox(height: 12),
        TextField(controller: ctrl, maxLines: 8, decoration: const InputDecoration(hintText: '每行一条，格式：期号 号码\n如：2024001 358\n2024002 672', isDense: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          final text = ctrl.text.trim();
          if (text.isEmpty) return;
          int count = 0;
          final lines = text.split('\n');
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
                lotteryType: dialogLotteryType,
              );
              await DatabaseHelper.instance.insertDraw(draw);
              count++;
            }
          }
          if (mounted) {
            Navigator.pop(ctx);
            final typeName = dialogLotteryType == 1 ? '福彩3D' : '排列三';
            ToastUtil.success(context, '$typeName 成功添加 $count 条');
            if (dialogLotteryType == _selectedLotteryType) {
              _loadData();
            }
          }
        }, child: const Text('添加')),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));

    final displayDraws = _showAll ? _draws : _draws.take(10).toList();
    final typeName = _selectedLotteryType == 1 ? '福彩 3D' : '排列三';

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
              Text('$typeName 开奖数据 (${_draws.length}条)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(children: [
                IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                IconButton(onPressed: _showBatchAddDialog, icon: const Icon(Icons.playlist_add, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                IconButton(onPressed: _syncing ? null : _syncFromApi, icon: _syncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_download, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          _buildLotterySwitcher(),
          const SizedBox(height: 8),
          if (_draws.isEmpty)
            EmptyState(message: '暂无$typeName开奖数据，点击 + 添加', icon: Icons.data_usage)
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

  Widget _buildLotterySwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppStyles.radiusXs),
      ),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => _onLotteryTypeChanged(1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _selectedLotteryType == 1 ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('福彩 3D', textAlign: TextAlign.center, style: TextStyle(
                  color: _selectedLotteryType == 1 ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 13,
                )),
              ],
            ),
          ),
        )),
        Expanded(child: GestureDetector(
          onTap: () => _onLotteryTypeChanged(2),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _selectedLotteryType == 2 ? AppColors.purple : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('排列三', textAlign: TextAlign.center, style: TextStyle(
                  color: _selectedLotteryType == 2 ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 13,
                )),
              ],
            ),
          ),
        )),
      ]),
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

    final isFc3d = item.lotteryType == 1;
    final tagColor = isFc3d ? AppColors.primary : AppColors.purple;
    final tagText = isFc3d ? '福彩' : '排列';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 2, child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: tagColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(tagText, style: TextStyle(fontSize: 8, color: tagColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 3),
              Expanded(child: Text(item.issue, style: TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
            ],
          )),
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
