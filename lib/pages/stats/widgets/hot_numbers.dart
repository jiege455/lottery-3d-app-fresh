import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';

class HotNumbers extends StatelessWidget {
  final List<dynamic> filteredBets;

  const HotNumbers({super.key, required this.filteredBets});

  Map<String, int> _calcFrequency() {
    final freq = <String, int>{};
    for (var i = 0; i < 10; i++) freq[i.toString()] = 0;
    for (final bet in filteredBets) {
      for (final char in bet.number.split('')) {
        if (freq.containsKey(char)) {
          freq[char] = freq[char]! + 1;
        }
      }
    }
    return freq;
  }

  @override
  Widget build(BuildContext context) {
    final freq = _calcFrequency();
    final total = freq.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return EmptyState(message: '暂无投注数据', icon: Icons.bar_chart);

    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.isNotEmpty ? sorted.first.value : 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('热门号码排行', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...sorted.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildBar(e.key + 1, e.value.key, e.value.value, maxVal, total))),
      ]),
    );
  }

  Widget _buildBar(int rank, String digit, int count, int maxVal, int total) {
    final pct = total > 0 ? (count / total * 100) : 0;
    final ratio = maxVal > 0 ? count / maxVal : 0;
    return Row(children: [
      SizedBox(width: 24, child: Text('#$rank', style: TextStyle(fontSize: 12, color: rank <= 3 ? AppColors.danger : AppColors.textSecondary, fontWeight: FontWeight.w600))),
      Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: rank <= 3 ? AppColors.danger.withAlpha(26) : AppColors.primaryLight, borderRadius: BorderRadius.circular(8)), child: Text(digit, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: rank <= 3 ? AppColors.danger : AppColors.primary))),
      const SizedBox(width: 10),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ratio.toDouble(), minHeight: 8, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation(rank <= 3 ? AppColors.danger : AppColors.primary)))),
      const SizedBox(width: 8),
      Expanded(child: Text('$count 次(${pct.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.right)),
    ]);
  }
}
