import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/play_types.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/check_service.dart';
import '../../../widgets/toast.dart';

class PlayTypeAmountSettingsPage extends StatefulWidget {
  const PlayTypeAmountSettingsPage({super.key});

  @override
  State<PlayTypeAmountSettingsPage> createState() => _PlayTypeAmountSettingsPageState();
}

class _PlayTypeAmountSettingsPageState extends State<PlayTypeAmountSettingsPage> {
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, TextEditingController> _winAmountControllers = {};

  @override
  void initState() {
    super.initState();
    for (final pt in PlayTypes.all) {
      _amountControllers[pt.code] = TextEditingController();
      _winAmountControllers[pt.code] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAmounts());
  }

  void _loadAmounts() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    for (final pt in PlayTypes.all) {
      final amount = settings.getPlayTypeAmount(pt.code);
      var winAmount = settings.getPlayTypeWinAmount(pt.code);
      // 如果中奖金额未设置，使用默认赔率计算
      if (winAmount <= 0) {
        final defaultOdds = CheckService.oddsMap[pt.code] ?? 0.0;
        winAmount = amount * defaultOdds;
      }
      _amountControllers[pt.code]!.text = amount.toStringAsFixed(1);
      _winAmountControllers[pt.code]!.text = winAmount.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    for (final controller in _amountControllers.values) controller.dispose();
    for (final controller in _winAmountControllers.values) controller.dispose();
    super.dispose();
  }

  Future<void> _saveAmount(String playType) async {
    final amount = double.tryParse(_amountControllers[playType]!.text);
    final winAmount = double.tryParse(_winAmountControllers[playType]!.text) ?? 0.0;
    if (amount == null || amount <= 0) {
      ToastUtil.warning(context, '请输入有效金额');
      return;
    }
    await Provider.of<SettingsProvider>(context, listen: false).updatePlayTypeAmount(playType, amount, winAmount);
  }

  Future<void> _resetAll() async {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认重置？'),
      content: const Text('将把所有玩法金额恢复为默认值'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          await Provider.of<SettingsProvider>(context, listen: false).resetPlayTypeAmounts();
          _loadAmounts();
          ToastUtil.success(context, '已恢复默认值');
        }, child: const Text('确认重置')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('玩法金额设置'),
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton.icon(onPressed: _resetAll, icon: const Icon(Icons.restore, size: 18), label: const Text('恢复默认')),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...PlayTypes.categories.map((category) {
                final playTypesInCategory = PlayTypes.getByCategory(category);
                if (playTypesInCategory.isEmpty) return const SizedBox.shrink();
                return _buildCategorySection(category, playTypesInCategory, settings);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(String category, List<PlayTypeConfig> playTypes, SettingsProvider settings) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: playTypes.first.color.withAlpha(26), borderRadius: BorderRadius.circular(12)),
            child: Text(category, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: playTypes.first.color)),
          ),
        ]),
      ),
      Card(
        margin: EdgeInsets.zero,
        child: Column(children: playTypes.asMap().entries.map((entry) {
          final pt = entry.value;
          final isLast = entry.key == playTypes.length - 1;
          final defaultAmount = pt.baseAmount;
          return _buildPlayTypeItem(pt.code, pt.name, defaultAmount, settings, isLast);
        }).toList()),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildPlayTypeItem(String code, String name, double defaultAmount, SettingsProvider settings, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border.withAlpha(77)))),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('默认 ${defaultAmount.toStringAsFixed(1)} 元', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
          ]),
        ),
        Column(children: [
          SizedBox(
            width: 70,
            child: TextField(
              controller: _amountControllers[code],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), labelText: '投注', labelStyle: TextStyle(fontSize: 10), suffixText: '元', suffixStyle: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _saveAmount(code),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _winAmountControllers[code],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), labelText: '中奖', labelStyle: TextStyle(fontSize: 10), suffixText: '元', suffixStyle: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _saveAmount(code),
            ),
          ),
        ]),
        const SizedBox(width: 8),
        IconButton(icon: Icon(Icons.save, color: AppColors.primary, size: 20), onPressed: () => _saveAmount(code), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
      ]),
    );
  }
}
