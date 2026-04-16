import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class BatchInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const BatchInput({super.key, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('批量输入', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            TextButton(onPressed: () { controller.text = ''; onChanged(''); }, child: const Text('清空', style: TextStyle(fontSize: 12, color: AppColors.danger))),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 5,
            minLines: 3,
            onChanged: onChanged,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 0.5),
            decoration: InputDecoration(
              hintText: '输入号码，支持逗号/顿号/横线/斜杠/空格分隔\n支持前缀标记玩法，如：直选：358\n支持倍数标记，如：358*2',
              hintStyle: TextStyle(fontSize: 13, color: AppColors.textLight),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppStyles.radiusXs), borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 6),
          Text('提示：每行一条或用分隔符拆分，双飞、跨度等整行不拆分', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        ],
      ),
    );
  }
}
