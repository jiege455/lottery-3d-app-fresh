import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/play_types.dart';
import '../../../models/bet_record.dart';
import '../../../providers/bet_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/db_service.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/toast.dart';
import '../../../widgets/advanced_search_dialog.dart';

class BetHistoryList extends StatefulWidget {
  const BetHistoryList({super.key});

  @override
  State<BetHistoryList> createState() => _BetHistoryListState();
}

class _BetHistoryListState extends State<BetHistoryList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _displayBatchCount = 10;
  bool _isSearchMode = false;
  List<BetRecord> _searchResults = [];
  int _searchTotalCount = 0;
  bool _isSearching = false;
  final Set<int> _selectedIds = {};
  bool _isSelectMode = false;
  final Set<String> _expandedBatches = {};
  static const int _collapsedItemCount = 6;
  int? _lastLotteryType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _lastLotteryType = Provider.of<SettingsProvider>(context, listen: false).defaultLotteryType;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _checkLotteryTypeReset() {
    final currentType = Provider.of<SettingsProvider>(context, listen: false).defaultLotteryType;
    if (_lastLotteryType != null && _lastLotteryType != currentType) {
      _displayBatchCount = 10;
      _expandedBatches.clear();
    }
    _lastLotteryType = currentType;
  }

  List<BetRecord> _getDisplayBets() {
    if (_isSearchMode) return _searchResults;
    final lotteryType = Provider.of<SettingsProvider>(context).defaultLotteryType;
    final bets = Provider.of<BetProvider>(context).bets.where((b) => b.lotteryType == lotteryType).toList();
    if (_searchQuery.isEmpty) return bets;
    final query = _searchQuery.toLowerCase();
    return bets.where((b) =>
      b.number.toLowerCase().contains(query) ||
      b.playTypeName.toLowerCase().contains(query) ||
      b.playType.toLowerCase().contains(query) ||
      b.batchId.toLowerCase().contains(query)
    ).toList();
  }

  Map<String, List<BetRecord>> _getGroupedBets(List<BetRecord> bets) {
    final grouped = <String, List<BetRecord>>{};
    for (final bet in bets) {
      grouped.putIfAbsent(bet.batchId, () => []).add(bet);
    }
    return grouped;
  }

  void _deleteBet(int id) async {
    await Provider.of<BetProvider>(context, listen: false).deleteBet(id);
    _selectedIds.remove(id);
    if (!mounted) return;
    ToastUtil.success(context, '已删除');
  }

  void _confirmDelete(BetRecord bet) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定要删除 ${bet.number}(${bet.playTypeName})这条记录吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () { Navigator.pop(ctx); if (bet.id != null) _deleteBet(bet.id!); },
          child: const Text('删除', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _showEditDialog(BetRecord bet) {
    final multiplierCtl = TextEditingController(text: (bet.multiplier * bet.baseAmount).toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑投注'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('号码: ${bet.number}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('玩法: ${bet.playTypeName}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: multiplierCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '每注金额(元)',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final newAmount = double.tryParse(multiplierCtl.text);
              if (newAmount == null || newAmount <= 0) {
                ToastUtil.warning(context, '请输入有效金额');
                return;
              }
              Navigator.pop(ctx);
              final newMultiplier = bet.baseAmount > 0 ? newAmount / bet.baseAmount : 1.0;
              final updated = bet.copyWith(multiplier: newMultiplier);
              await Provider.of<BetProvider>(context, listen: false).updateBet(updated);
              if (mounted) ToastUtil.success(context, '已更新');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showBatchEditDialog(String batchId, List<BetRecord> bets) {
    final batchMultiplierCtl = TextEditingController();
    final editControllers = <int, TextEditingController>{};
    for (final bet in bets) {
      if (bet.id != null) {
        editControllers[bet.id!] = TextEditingController(text: (bet.multiplier * bet.baseAmount).toString());
      }
    }
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('编辑批次 (${bets.length}注)'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('批量修改金额', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      SizedBox(
                        width: 80,
                        height: 32,
                        child: TextField(
                          controller: batchMultiplierCtl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            border: OutlineInputBorder(),
                            hintText: '金额',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {
                          final newMult = double.tryParse(batchMultiplierCtl.text);
                          if (newMult == null || newMult <= 0) return;
                          setDialogState(() {
                            for (final ctl in editControllers.values) {
                              ctl.text = newMult.toString();
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                        child: const Text('应用', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: bets.map((bet) {
                        if (bet.id == null) return const SizedBox.shrink();
                        final ctl = editControllers[bet.id]!;
                        Color playColor = AppColors.primary;
                        final pt = PlayTypes.all.firstWhere((p) => p.code == bet.playType, orElse: () => PlayTypes.all.first);
                        final colorKey = PlayTypes.categoryColorKey[pt.category] ?? 'basic';
                        playColor = AppColors.playTypeColors[colorKey] ?? AppColors.primary;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: playColor.withAlpha(26), borderRadius: BorderRadius.circular(4)),
                                child: Text(bet.number, style: TextStyle(fontSize: 12, color: playColor, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: playColor.withAlpha(15), borderRadius: BorderRadius.circular(3)),
                                child: Text(bet.playTypeName, style: TextStyle(fontSize: 9, color: playColor)),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 60,
                                height: 28,
                                child: TextField(
                                  controller: ctl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                    border: OutlineInputBorder(),
                                    suffixText: '倍',
                                    suffixStyle: TextStyle(fontSize: 9),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final updatedBets = <BetRecord>[];
                for (final bet in bets) {
                  if (bet.id == null) continue;
                  final ctl = editControllers[bet.id];
                  if (ctl == null) continue;
                  final newAmount = double.tryParse(ctl.text);
                  if (newAmount == null || newAmount <= 0) continue;
                  final newMultiplier = bet.baseAmount > 0 ? newAmount / bet.baseAmount : 1.0;
                  updatedBets.add(bet.copyWith(multiplier: newMultiplier));
                }
                if (updatedBets.isEmpty) {
                  ToastUtil.warning(context, '请输入有效金额');
                  return;
                }
                Navigator.pop(ctx);
                await Provider.of<BetProvider>(context, listen: false).updateBetsBatch(updatedBets);
                if (mounted) ToastUtil.success(context, '已更新${updatedBets.length}条记录');
              },
              child: const Text('保存全部'),
            ),
          ],
        ),
      ),
    ).then((_) {
      for (final ctl in editControllers.values) {
        ctl.dispose();
      }
      batchMultiplierCtl.dispose();
    });
  }

  Future<void> _doAdvancedSearch(Map<String, dynamic> params) async {
    setState(() => _isSearching = true);
    try {
      final lotteryType = Provider.of<SettingsProvider>(context, listen: false).defaultLotteryType;
      final results = await Provider.of<BetProvider>(context, listen: false).searchBets(
        lotteryType: lotteryType,
        keyword: params['keyword'] as String?,
        playType: params['playType'] as String?,
        minAmount: params['minAmount'] as double?,
        maxAmount: params['maxAmount'] as double?,
        startDate: params['startDate'] as DateTime?,
        endDate: params['endDate'] as DateTime?,
        page: 1,
        pageSize: 200,
      );
      final count = await Provider.of<BetProvider>(context, listen: false).getSearchBetsCount(
        lotteryType: lotteryType,
        keyword: params['keyword'] as String?,
        playType: params['playType'] as String?,
        minAmount: params['minAmount'] as double?,
        maxAmount: params['maxAmount'] as double?,
        startDate: params['startDate'] as DateTime?,
        endDate: params['endDate'] as DateTime?,
      );
      if (mounted) {
        setState(() {
          _isSearchMode = true;
          _searchResults = results;
          _searchTotalCount = count;
          _isSearching = false;
          _displayBatchCount = 10;
          _expandedBatches.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ToastUtil.error(context, '搜索失败: $e');
      }
    }
  }

  void _exitSearchMode() {
    setState(() {
      _isSearchMode = false;
      _searchResults = [];
      _searchTotalCount = 0;
      _selectedIds.clear();
      _isSelectMode = false;
      _displayBatchCount = 10;
      _expandedBatches.clear();
    });
  }

  void _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('批量删除'),
      content: Text('确定要删除选中的 ${_selectedIds.length} 条记录吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () async {
            Navigator.pop(ctx);
            await Provider.of<BetProvider>(context, listen: false).deleteBetsByIds(_selectedIds.toList());
            _selectedIds.clear();
            setState(() => _isSelectMode = false);
            if (!mounted) return;
            ToastUtil.success(context, '已批量删除');
          },
          child: const Text('删除', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final displayBets = _getDisplayBets();
    _checkLotteryTypeReset();
    final groupedBets = _getGroupedBets(displayBets);
    final batchIds = groupedBets.keys.toList()..sort((a, b) {
      final aBets = groupedBets[a]!;
      final bBets = groupedBets[b]!;
      return bBets.first.createTime.compareTo(aBets.first.createTime);
    });
    final displayBatches = batchIds.take(_displayBatchCount).toList();
    final totalBets = displayBets;
    final totalAmount = totalBets.fold<double>(0, (sum, b) => sum + b.multiplier * b.baseAmount);
    final hasMoreBatches = displayBatches.length < batchIds.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            if (_isSelectMode)
              Checkbox(
                value: _selectedIds.length == totalBets.length && totalBets.isNotEmpty,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedIds.clear();
                      for (final b in totalBets) {
                        if (b.id != null) _selectedIds.add(b.id!);
                      }
                    } else {
                      _selectedIds.clear();
                    }
                  });
                },
              ),
            Text(_isSearchMode ? '搜索结果' : '投注记录', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          Row(children: [
            if (_isSearchMode)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('$_searchTotalCount条', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            if (!_isSearchMode) ...[
              Text('${totalBets.length}注', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.danger.withAlpha(26), borderRadius: BorderRadius.circular(10)), child: Text('${totalAmount.toStringAsFixed(2)}元', style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600))),
            ],
            const SizedBox(width: 4),
            if (_isSelectMode && _selectedIds.isNotEmpty)
              IconButton(
                onPressed: _deleteSelected,
                icon: Icon(Icons.delete, size: 20, color: AppColors.danger),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            IconButton(
              onPressed: () => setState(() => _isSelectMode = !_isSelectMode),
              icon: Icon(_isSelectMode ? Icons.check_circle : Icons.checklist, size: 20, color: _isSelectMode ? AppColors.primary : AppColors.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() { _searchQuery = v; _displayBatchCount = 10; _expandedBatches.clear(); }),
                decoration: InputDecoration(
                  hintText: '搜索号码/玩法/批次...',
                  prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textLight),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () { _searchController.clear(); setState(() { _searchQuery = ''; _displayBatchCount = 10; _expandedBatches.clear(); }); },
                          icon: Icon(Icons.clear, size: 16, color: AppColors.textLight),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AdvancedSearchDialog(
                    lotteryType: Provider.of<SettingsProvider>(context, listen: false).defaultLotteryType,
                    onSearch: _doAdvancedSearch,
                  ),
                );
              },
              icon: Icon(Icons.tune, color: AppColors.primary),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                padding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        if (_isSearchMode)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.filter_alt, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '高级搜索结果: $_searchTotalCount 条',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: _exitSearchMode,
                  child: const Text('退出搜索', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (_isSearching)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (totalBets.isEmpty)
          EmptyState(message: _isSearchMode ? '没有搜索到结果' : '暂无投注记录', icon: Icons.receipt_long_outlined)
        else
          ...displayBatches.map((batchId) {
            final bets = groupedBets[batchId]!;
            final batchAmount = bets.fold<double>(0, (sum, b) => sum + b.multiplier * b.baseAmount);
            return _buildBatchItem(batchId, bets, batchAmount);
          }),
        if (!_isSearching && hasMoreBatches) Center(child: Padding(padding: const EdgeInsets.only(top: 8), child: TextButton.icon(onPressed: () => setState(() => _displayBatchCount += 10), icon: const Icon(Icons.expand_more, size: 16), label: Text('加载更多 (${batchIds.length - displayBatches.length}个批次)')))),
      ]),
    );
  }

  Widget _buildBatchItem(String batchId, List<BetRecord> bets, double batchAmount) {
    final firstBet = bets.first;
    final batchTime = firstBet.createTime;
    final isExpanded = _expandedBatches.contains(batchId);
    final playTypeSet = <String>{};
    final playTypeNameMap = <String, String>{};
    for (final bet in bets) {
      if (playTypeSet.add(bet.playType)) {
        playTypeNameMap[bet.playType] = bet.playTypeName;
      }
    }
    final displayBets = (isExpanded || bets.length <= _collapsedItemCount)
        ? bets
        : bets.sublist(0, _collapsedItemCount);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusSm),
        border: Border.all(color: AppColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '批次：${batchId.substring(0, batchId.length > 10 ? 10 : batchId.length)}...',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(DateFormat('MM-dd HH:mm').format(batchTime), style: TextStyle(fontSize: 10, color: AppColors.textLight)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: playTypeSet.map((code) {
              Color tagColor = AppColors.primary;
              final pt = PlayTypes.all.firstWhere((p) => p.code == code, orElse: () => PlayTypes.all.first);
              final colorKey = PlayTypes.categoryColorKey[pt.category] ?? 'basic';
              tagColor = AppColors.playTypeColors[colorKey] ?? AppColors.primary;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  playTypeNameMap[code] ?? code,
                  style: TextStyle(fontSize: 10, color: tagColor, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final chipWidth = 90.0;
              final crossCount = (constraints.maxWidth / chipWidth).floor().clamp(3, 6);
              final actualWidth = (constraints.maxWidth - (crossCount - 1) * 4) / crossCount;
              return Wrap(
                spacing: 4,
                runSpacing: 4,
                children: displayBets.map((bet) {
                  Color playColor = AppColors.primary;
                  final pt = PlayTypes.all.firstWhere((p) => p.code == bet.playType, orElse: () => PlayTypes.all.first);
                  final colorKey = PlayTypes.categoryColorKey[pt.category] ?? 'basic';
                  playColor = AppColors.playTypeColors[colorKey] ?? AppColors.primary;
                  final isSelected = _isSelectMode && bet.id != null && _selectedIds.contains(bet.id);
                  return GestureDetector(
                    onLongPress: () => _showEditDialog(bet),
                    onTap: _isSelectMode && bet.id != null
                        ? () => setState(() {
                              if (_selectedIds.contains(bet.id)) {
                                _selectedIds.remove(bet.id);
                              } else {
                                _selectedIds.add(bet.id!);
                              }
                            })
                        : null,
                    child: Container(
                      width: actualWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? playColor.withAlpha(77) : playColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected ? Border.all(color: playColor, width: 1.5) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSelectMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Icon(
                                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 12,
                                color: playColor,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              '${bet.number} ${(bet.multiplier * bet.baseAmount).toStringAsFixed(2)}元',
                              style: TextStyle(fontSize: 10, color: playColor, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (bets.length > _collapsedItemCount) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() {
                if (isExpanded) {
                  _expandedBatches.remove(batchId);
                } else {
                  _expandedBatches.add(batchId);
                }
              }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(51),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isExpanded ? '收起' : '展开全部 (${bets.length}条)',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => _confirmDeleteBatch(batchId, bets),
                    child: Text('删除批次', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                  ),
                  TextButton(
                    onPressed: () => _showBatchEditDialog(batchId, bets),
                    child: Text('编辑', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('${bets.length}注', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.danger.withAlpha(26), borderRadius: BorderRadius.circular(10)), child: Text('${batchAmount.toStringAsFixed(2)}元', style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBatch(String batchId, List<BetRecord> bets) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认删除批次'),
      content: Text('确定要删除这个批次的 ${bets.length} 条记录吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () async {
            Navigator.pop(ctx);
            await DatabaseHelper.instance.deleteBetsByBatchId(batchId);
            _expandedBatches.remove(batchId);
            await Provider.of<BetProvider>(context, listen: false).loadBets();
            if (!mounted) return;
            ToastUtil.success(context, '已删除批次');
          },
          child: const Text('删除', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }
}
