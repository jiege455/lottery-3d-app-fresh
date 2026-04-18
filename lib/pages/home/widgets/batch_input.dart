import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class BatchInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const BatchInput({super.key, required this.controller, required this.onChanged});

  void _showExamples(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('输入格式示例', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
            ])),
            const Divider(height: 1),
            Expanded(child: ListView(controller: scrollController, padding: const EdgeInsets.all(16), children: _buildExampleGroups())),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildExampleGroups() {
    const groups = <Map<String, dynamic>>[
      {'title': '💡 基础三码（直选/组三/组六）', 'items': [
        '输入 358 → 自动识别为直选',
        '输入 112 → 自动识别为组三（有重复数字）',
        '输入 358,467 → 两注直选',
        '输入 358*2 → 直选2倍',
        '输入 358一单一组 → 直选1倍+组选1倍',
        '输入 358直组各一倍 → 直选1倍+组选1倍',
        '输入 358二单三组 → 直选2倍+组选3倍',
      ]},
      {'title': '📍 定位（百位/十位/个位）', 'items': [
        '输入 百位1,5,7 十位0,6,9 个位0,4,5',
        '  → 自动组合3×3×3=27注直选',
        '输入 百位：1、5、7（单行百位定位）',
        '输入 百位5 → 一码定位',
        '输入 前两位35 → 二码定位',
        '多行输入：',
        '  百位1,5,7',
        '  十位0,6,9',
        '  个位0,4,5',
      ]},
      {'title': '🦅 双飞（自动识别组三/组六）', 'items': [
        '输入 双飞12 10米 → 双飞组六，1倍',
        '  （1和2不同，自动识别为组六）',
        '输入 双飞11 10米 → 双飞对子，1倍',
        '  （两个1相同，自动识别为组三）',
        '输入 双飞12 10 → 双飞组六，1倍',
        '输入 双飞56 20米 → 双飞组六，2倍',
        '输入 358,558 → 传统双飞格式（两注三位数）',
      ]},
      {'title': '🎯 胆拖（胆码+拖码）', 'items': [
        '输入 1拖014578组六10米',
        '  → 组六1胆6拖，1倍',
        '输入 1拖014578组三10',
        '  → 组三1胆6拖，1倍',
        '输入 2拖34567组六20',
        '  → 组六1胆5拖，2倍',
        '输入 3拖456789组六10米',
        '  → 组六1胆6拖，1倍',
      ]},
      {'title': '🔢 复式（多码组六/组三）', 'items': [
        '输入 1234组六 → 四码组六',
        '输入 1234组六10 → 四码组六1倍（10元=1倍）',
        '输入 1234组六10米 → 四码组六1倍',
        '输入 45678组三20 → 五码组三2倍',
        '输入 15 → 组三2码',
        '输入 112 → 组三3码（有重复数字）',
        '输入 1234组三 4567组六各一倍 → 各1倍',
        '输入 1234组三 4567组三各10 → 各1倍',
      ]},
      {'title': '🐆 豹子', 'items': [
        '输入 豹子：555 → 豹子直选',
        '输入 555 → 自动识别豹子直选',
        '输入 111,222 → 多注豹子',
      ]},
      {'title': '🔄 转圈直选', 'items': [
        '输入 123转圈组六12 → 转圈组六3码，1倍',
        '  （12元÷12元base=1倍）',
        '输入 4567转圈组六48 → 转圈组六4码，1倍',
        '  （48元÷48元base=1倍）',
        '输入 112转圈组三12 → 转圈组三3码，1倍',
        '输入 12转圈组三12 → 转圈组三2码，1倍',
        '输入 12345转圈组六120 → 转圈组六5码，1倍',
        '输入 123转圈组六24 → 转圈组六3码，2倍',
        '  （24元÷12元base=2倍）',
        '也可用前缀：转圈组六3码：123',
      ]},
      {'title': '🔗 沾边', 'items': [
        '输入 1沾边组六72 → 沾边组六1胆，1倍',
        '  （72元÷72元base=1倍）',
        '输入 12沾边组六128 → 沾边组六2胆，1倍',
        '  （128元÷128元base=1倍）',
        '输入 1沾边组三36 → 沾边组三1胆，1倍',
        '  （36元÷36元base=1倍）',
        '输入 123沾边组六170 → 沾边组六3胆，1倍',
        '也可用前缀：沾边组六1胆：1',
      ]},
      {'title': '📐 跨度', 'items': [
        '输入 5跨 → 跨度5',
        '输入 0跨 → 跨度0（豹子）',
        '输入 9跨 → 跨度9',
      ]},
      {'title': '➕ 和数', 'items': [
        '输入 和数：12 → 和数12',
        '输入 和数：0 → 和数0',
        '输入 和数：27 → 和数27',
        '注意：单独输入0-9会被识别为独胆',
        '单独输入10-27会被识别为和数',
      ]},
      {'title': '📊 大小/单双', 'items': [
        '输入 大 → 大（和数≥14）',
        '输入 小 → 小（和数≤13）',
        '输入 单 → 单（和数为奇数）',
        '输入 双 → 双（和数为偶数）',
      ]},
      {'title': '🏷️ 前缀标记玩法', 'items': [
        '输入 直选：358 → 指定直选',
        '输入 组三：112 → 指定组三',
        '输入 组六：358 → 指定组六',
        '输入 组选：358 → 自动识别组三/组六',
        '输入 复式：158 → 复式3码',
      ]},
      {'title': '💰 倍数/金额说明', 'items': [
        '358*2 → 2倍（*号标记倍数）',
        '1234组六10 → 1倍（10元=1倍）',
        '1234组六20 → 2倍（20元=2倍）',
        '1234组六10米 → 1倍（米=元）',
        '1234组六10元 → 1倍',
        '1234组六*2 → 2倍（*号直接倍数）',
        '双飞12 10米 → 1倍',
        '双飞12 20 → 2倍',
      ]},
    ];

    return groups.map((g) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(g['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
        const SizedBox(height: 6),
        ...(g['items'] as List<String>).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(margin: const EdgeInsets.only(top: 7, right: 8), width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.textLight, shape: BoxShape.circle)),
            Expanded(child: Text(item, style: const TextStyle(fontSize: 13, height: 1.5))),
          ]),
        )),
      ]),
    )).toList();
  }

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
            Row(children: [
              const Text('批量输入', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 6),
              GestureDetector(onTap: () => _showExamples(context), child: const Icon(Icons.help_outline, size: 18, color: AppColors.textLight)),
            ]),
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
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppStyles.radiusXs), borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 6),
          const Text('提示：每行一条或用分隔符拆分，双飞、跨度等整行不拆分', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        ],
      ),
    );
  }
}
