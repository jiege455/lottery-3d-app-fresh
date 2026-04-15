import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/play_types.dart';
import '../../../models/bet_record.dart';
import '../../../providers/bet_provider.dart';
import '../../../services/db_service.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/toast.dart';

class BetHistoryList extends StatefulWidget {
  const BetHistoryList({super.key});

  @override
  State<BetHistoryList> createState() => _BetHistoryListState();
}

class _BetHistoryListState extends State<BetHistoryList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _pageSize = 20;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BetRecord> _getFilteredBets() {
    final bets = Provider.of<BetProvider>(context).bets;
    if (_searchQuery.isEmpty) return bets;
    final query = _searchQuery.toLowerCase();
    return bets.where((b) =>
      b.number.toLowerCase().contains(query) ||
      b.playTypeName.toLowerCase().contains(query) ||
      b.playType.toLowerCase().contains(query) ||
      b.batchId.toLowerCase().contains(query)
    ).toList();
  }

  Map<String, List<BetRecord>> _getGroupedBets() {
    final bets = _getFilteredBets();
    final grouped = <String, List<BetRecord>>{};
    for (final bet in bets) {
      grouped.putIfAbsent(bet.batchId, () => []).add(bet);
    }
    return grouped;
  }

  void _deleteBet(int id) async {
    await Provider.of<BetProvider>(context, listen: false).deleteBet(id);
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

  @override
  Widget build(BuildContext context) {
    final groupedBets = _getGroupedBets();
    final batchIds = groupedBets.keys.toList()..sort((a, b) {
      final aBets = groupedBets[a]!;
      final bBets = groupedBets[b]!;
      return bBets.first.createTime.compareTo(aBets.first.createTime);
    });
    final displayBatches = <String>[];
    var count = 0;
    for (final batchId in batchIds) {
      if (count >= _pageSize) break;
      displayBatches.add(batchId);
      count += groupedBets[batchId]!.length;
    }
    final totalBets = groupedBets.values.expand((e) => e).toList();
    final totalAmount = totalBets.fold<double>(0, (sum, b) => sum + b.multiplier * b.baseAmount);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('投注记录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Row(children: [
            Text('${totalBets.length}注', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.danger.withAlpha(26), borderRadius: BorderRadius.circular(10)), child: Text('${totalAmount.toStringAsFixed(1)}元', style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600))),
          ]),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _searchController, onChanged: (v) => setState(() => _searchQuery = v), decoration: InputDecoration(hintText: '搜索号码/玩法/批次...', prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textLight), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14))),
        const SizedBox(height: 12),
        if (totalBets.isEmpty)
          EmptyState(message: '暂无投注记录', icon: Icons.receipt_long_outlined)
        else
          ...displayBatches.map((batchId) {
            final bets = groupedBets[batchId]!;
            final batchAmount = bets.fold<double>(0, (sum, b) => sum + b.multiplier * b.baseAmount);
            return _buildBatchItem(batchId, bets, batchAmount);
          }),
        if (_pageSize < totalBets.length) Center(child: Padding(padding: const EdgeInsets.only(top: 8), child: TextButton.icon(onPressed: () => setState(() => _pageSize += 20), icon: const Icon(Icons.expand_more, size: 16), label: Text('加载更多 (${totalBets.length - _pageSize})')))),
      ]),
    );
  }

  Widget _buildBatchItem(String batchId, List<BetRecord> bets, double batchAmount) {
    final firstBet = bets.first;
    final batchTime = firstBet.createTime;
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
              Row(
                children: [
                  Icon(Icons.receipt_long, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('批次：${batchId.substring(0, batchId.length > 10 ? 10 : batchId.length)}...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
              Text(DateFormat('MM-dd HH:mm').format(batchTime), style: TextStyle(fontSize: 10, color: AppColors.textLight)),
            ],
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
                children: bets.map((bet) {
                  Color playColor = AppColors.primary;
                  try {
                    final pt = PlayTypes.all.firstWhere((p) => p.code == bet.playType, orElse: () => PlayTypes.all.first);
                    final colorKey = PlayTypes.categoryColorKey[pt.category] ?? 'basic';
                    playColor = AppColors.playTypeColors[colorKey] ?? AppColors.primary;
                  } catch (_) {}
                  return Container(
                    width: actualWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(color: playColor.withAlpha(26), borderRadius: BorderRadius.circular(4)),
                    child: Text('${bet.number} ×${bet.multiplier}', style: TextStyle(fontSize: 10, color: playColor, fontWeight: FontWeight.w500, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => _confirmDeleteBatch(batchId, bets),
                child: Text('删除批次', style: TextStyle(fontSize: 11, color: AppColors.danger)),
              ),
              Row(
                children: [
                  Text('${bets.length}注', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.danger.withAlpha(26), borderRadius: BorderRadius.circular(10)), child: Text('${batchAmount.toStringAsFixed(1)}元', style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600))),
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
