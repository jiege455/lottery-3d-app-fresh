import 'package:flutter/material.dart';
import '../../../core/constants/play_types.dart';
import '../../../core/theme/app_theme.dart';

class RuleHintBox extends StatelessWidget {
  final String playTypeCode;
  const RuleHintBox({super.key, required this.playTypeCode});

  @override
  Widget build(BuildContext context) {
    if (playTypeCode == 'auto') {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(AppStyles.radiusXs),
          border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('自动识别模式：根据输入内容智能匹配玩法', style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('示例：5→独胆  大→大小  5跨→跨度  123→组三  1358→组六4码  13→和数', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
          ],
        ),
      );
    }

    final config = PlayTypes.getByCode(playTypeCode);
    if (config == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppStyles.radiusXs),
        border: Border(left: BorderSide(color: config.color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: config.color),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(config.ruleText, style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text('示例：${config.example}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
        ],
      ),
    );
  }
}
