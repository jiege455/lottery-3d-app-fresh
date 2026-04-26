import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/play_types.dart';
import '../../../core/utils/custom_format.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/toast.dart';

/// 自定义格式模板管理对话框
class CustomFormatDialog extends StatefulWidget {
  const CustomFormatDialog({super.key});

  @override
  State<CustomFormatDialog> createState() => _CustomFormatDialogState();
}

class _CustomFormatDialogState extends State<CustomFormatDialog> {
  List<CustomFormatRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      final provider = Provider.of<SettingsProvider>(context, listen: false);
      final rules = await provider.loadCustomFormatRules();
      if (mounted) {
        setState(() {
          _rules = rules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtil.error(context, '加载失败: $e');
      }
    }
  }

  Future<void> _saveRules() async {
    try {
      final provider = Provider.of<SettingsProvider>(context, listen: false);
      await provider.saveCustomFormatRules(_rules);
      if (mounted) {
        ToastUtil.success(context, '保存成功');
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.error(context, '保存失败: $e');
      }
    }
  }

  void _addRule() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CustomFormatEditDialog(
          onSave: (rule) {
            setState(() => _rules.add(rule));
            _saveRules();
          },
        ),
      ),
    );
  }

  void _editRule(int index) {
    final rule = _rules[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CustomFormatEditDialog(
          existingRule: rule,
          onSave: (updatedRule) {
            setState(() => _rules[index] = updatedRule);
            _saveRules();
          },
        ),
      ),
    );
  }

  void _deleteRule(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除模板"${_rules[index].name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _rules.removeAt(index));
              _saveRules();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _toggleRule(int index) {
    setState(() {
      _rules[index].enabled = !_rules[index].enabled;
    });
    _saveRules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义格式模板'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: _addRule,
            tooltip: '新增模板',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? _buildEmptyState()
              : _buildRulesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_fix_high, size: 64, color: AppColors.textLight.withAlpha(80)),
          const SizedBox(height: 16),
          const Text('暂无自定义格式模板', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('添加模板后，粘贴文本可自动识别', style: TextStyle(fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addRule,
            icon: const Icon(Icons.add),
            label: const Text('新增模板'),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rules.length,
      itemBuilder: (context, index) {
        final rule = _rules[index];
        final config = rule.playTypeConfig;
        final color = config?.color ?? AppColors.primary;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _editRule(index),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: rule.enabled ? AppColors.success : AppColors.textLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rule.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          rule.enabled ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                          color: AppColors.textLight,
                        ),
                        onPressed: () => _toggleRule(index),
                        tooltip: rule.enabled ? '禁用' : '启用',
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                        onPressed: () => _deleteRule(index),
                        tooltip: '删除',
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.text_fields, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          rule.template,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rule.playTypeName,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '默认 ${rule.defaultMultiplier} 倍',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        rule.enabled ? '已启用' : '已禁用',
                        style: TextStyle(
                          fontSize: 12,
                          color: rule.enabled ? AppColors.success : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 编辑/新增自定义格式模板对话框
class _CustomFormatEditDialog extends StatefulWidget {
  final CustomFormatRule? existingRule;
  final ValueChanged<CustomFormatRule> onSave;

  const _CustomFormatEditDialog({
    this.existingRule,
    required this.onSave,
  });

  @override
  State<_CustomFormatEditDialog> createState() => _CustomFormatEditDialogState();
}

class _CustomFormatEditDialogState extends State<_CustomFormatEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _templateController;
  late final TextEditingController _multiplierController;
  String _selectedPlayType = 'single';
  String? _errorText;

  // 按类别分组的玩法列表
  late final Map<String, List<PlayTypeConfig>> _groupedPlayTypes;

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    _nameController = TextEditingController(text: rule?.name ?? '');
    _templateController = TextEditingController(text: rule?.template ?? '');
    _multiplierController = TextEditingController(
      text: rule?.defaultMultiplier.toString() ?? '2.0',
    );
    _selectedPlayType = rule?.playTypeCode ?? 'single';

    // 分组玩法
    _groupedPlayTypes = {};
    for (final pt in PlayTypes.all) {
      _groupedPlayTypes.putIfAbsent(pt.category, () => []).add(pt);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _templateController.dispose();
    _multiplierController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final template = _templateController.text.trim();
    final multiplier = double.tryParse(_multiplierController.text) ?? 2.0;

    // 验证
    if (name.isEmpty) {
      setState(() => _errorText = '请输入模板名称');
      return;
    }
    final error = CustomFormatRule.validate(template, _selectedPlayType);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    final rule = CustomFormatRule(
      id: widget.existingRule?.id,
      name: name,
      template: template,
      playTypeCode: _selectedPlayType,
      defaultMultiplier: multiplier,
      createTime: widget.existingRule?.createTime ?? DateTime.now(),
      enabled: widget.existingRule?.enabled ?? true,
    );

    widget.onSave(rule);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingRule != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑模板' : '新增模板'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模板名称
            const Text('模板名称', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '例如：我的格式1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // 格式模板
            Row(
              children: [
                const Text('格式模板', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 18, color: AppColors.textLight),
                  onPressed: _showHelp,
                  tooltip: '使用说明',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _templateController,
              decoration: const InputDecoration(
                hintText: '例如：{号码}-{倍数}倍',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('占位符说明：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  _buildPlaceholder('{号码}', '必填', '匹配3~9位数字，如 358、12345'),
                  const SizedBox(height: 3),
                  _buildPlaceholder('{倍数}', '可选', '匹配倍数数字，如 2、1.5'),
                  const SizedBox(height: 6),
                  const Text('示例：模板 "{号码}-{倍数}倍" 可匹配 "358-2倍"', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 玩法选择
            const Text('玩法类型', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            _buildPlayTypeSelector(),
            const SizedBox(height: 20),

            // 默认倍数
            const Text('默认倍数', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _multiplierController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '2.0',
                border: OutlineInputBorder(),
                suffixText: '倍',
              ),
            ),
            const SizedBox(height: 8),
            const Text('如果模板中没有 {倍数} 占位符，则使用此默认倍数',
                style: TextStyle(fontSize: 12, color: AppColors.textLight)),

            // 错误提示
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // 测试区
            _buildTestSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String name, String required, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(name, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: required == '必填' ? AppColors.danger.withAlpha(20) : AppColors.warning.withAlpha(20),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(required, style: TextStyle(fontSize: 10, color: required == '必填' ? AppColors.danger : AppColors.warning)),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      ],
    );
  }

  Widget _buildPlayTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        children: _groupedPlayTypes.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ...entry.value.map((pt) => RadioListTile<String>(
                title: Text(pt.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(pt.ruleText, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                value: pt.code,
                groupValue: _selectedPlayType,
                onChanged: (v) => setState(() => _selectedPlayType = v!),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                activeColor: pt.color,
              )),
              const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('如何使用格式模板？'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _helpStep('1. 观察你的文本格式', '比如你经常复制这样的文本：\n  358-2倍\n  467-3倍\n  589-1倍'),
              const SizedBox(height: 12),
              _helpStep('2. 提取规律', '共同点是：三位数 + 横线 + 数字 + "倍"字'),
              const SizedBox(height: 12),
              _helpStep('3. 用占位符写模板', '数字部分用 {号码}\n倍数部分用 {倍数}\n\n模板：{号码}-{倍数}倍'),
              const SizedBox(height: 12),
              _helpStep('4. 选择玩法', '这个格式是直选，所以选"直选"'),
              const SizedBox(height: 12),
              _helpStep('5. 保存使用', '保存后，粘贴 "358-2倍" 就能自动识别为直选2倍！'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 小技巧：如果文本中有多种格式，可以创建多个模板！\n例如："直选:358" 和 "组三:112" 可以用同一个模板 {玩法}:{号码}，但需要分别指定玩法和模板。',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
        ],
      ),
    );
  }

  Widget _helpStep(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(fontSize: 13, height: 1.5)),
      ],
    );
  }

  /// 测试区：实时测试模板匹配效果
  Widget _buildTestSection() {
    final template = _templateController.text.trim();
    if (template.isEmpty || !template.contains('{号码}')) {
      return const SizedBox.shrink();
    }

    // 构造一个临时规则用于测试
    final testRule = CustomFormatRule(
      name: 'test',
      template: template,
      playTypeCode: _selectedPlayType,
      defaultMultiplier: double.tryParse(_multiplierController.text) ?? 2.0,
    );

    // 预置测试文本
    const testLines = ['358-2倍', '123-1倍', '789-3倍', '358-2', '358x2'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text('📋 测试匹配效果', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        ...testLines.map((line) {
          final result = testRule.tryMatch(line);
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: result != null ? AppColors.success.withAlpha(15) : AppColors.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: result != null ? AppColors.success.withAlpha(60) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  result != null ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: result != null ? AppColors.success : AppColors.textLight,
                ),
                const SizedBox(width: 8),
                Text(line, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                if (result != null) ...[
                  const Spacer(),
                  Text(
                    '→ ${result.playTypeName} ${result.multiplier.toStringAsFixed(1)}倍',
                    style: TextStyle(
                      fontSize: 12,
                      color: PlayTypes.getByCode(result.playType)?.color ?? AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        const Text('输入框中的文本也会尝试匹配此模板', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }
}
