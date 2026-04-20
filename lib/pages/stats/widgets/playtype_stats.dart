import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/play_types.dart';

class PlayTypeStats extends StatelessWidget {
  final List<dynamic> filteredBets;

  const PlayTypeStats({super.key, required this.filteredBets});

  @override
  Widget build(BuildContext context) {
    final stats = <String, Map<String, dynamic>>{};
    for (final bet in filteredBets) {
      final key = bet.playType as String;
      stats.putIfAbsent(key, () => {'count': 0, 'totalAmount': 0.0});
      stats[key]!['count'] = (stats[key]!['count'] as int) + 1;
      stats[key]!['totalAmount'] = (stats[key]!['totalAmount'] as double) + bet.multiplier * bet.baseAmount;
    }

    final totalCount = stats.values.fold<int>(0, (a, b) => a + (b['count'] as int));
    if (totalCount == 0) return const SizedBox.shrink();

    final sorted = stats.entries.toList()
      ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));
    final maxVal = sorted.isNotEmpty ? sorted.first.value['count'] as int : 1;
    final totalAmount = stats.values.fold<double>(0, (sum, e) => sum + (e['totalAmount'] as double));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('玩法分布', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('${totalAmount.toStringAsFixed(2)} 元', style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        ...sorted.take(10).map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildBar(e.key, e.value['count'] as int, e.value['totalAmount'] as double, maxVal, totalCount))),
      ]),
    );
  }

  Widget _buildBar(String playType, int count, double amount, int maxVal, int total) {
    final pct = total > 0 ? count / total * 100 : 0;
    final ratio = maxVal > 0 ? count / maxVal : 0;
    final config = PlayTypes.getByCode(playType);
    final name = config?.name ?? playType;
    final color = config?.color ?? AppColors.primary;

    return Row(children: [
      Container(
        width: 56,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(4)),
        child: Text(name, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(width: 8),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ratio.toDouble(), minHeight: 8, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation(color)))),
      const SizedBox(width: 8),
      Expanded(child: Text('$count 注 ${amount.toStringAsFixed(2)} 元 (${pct.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, maxLines: 1)),
    ]);
  }
}
