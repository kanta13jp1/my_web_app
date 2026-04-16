import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ElectionKpiEditDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const ElectionKpiEditDialog({
    super.key,
    required this.initialData,
  });

  @override
  State<ElectionKpiEditDialog> createState() => _ElectionKpiEditDialogState();
}

class _ElectionKpiEditDialogState extends State<ElectionKpiEditDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _retainTargetCtrl;
  late TextEditingController _priorityMunicipalitiesCtrl;
  late TextEditingController _newTargetCtrl;
  late TextEditingController _newActualCtrl;
  late TextEditingController _endorsementTimingCtrl;
  late TextEditingController _supportVisitsCtrl;

  @override
  void initState() {
    super.initState();
    _retainTargetCtrl = TextEditingController(
      text: widget.initialData['incumbent_retain_target']?.toString() ?? '0',
    );
    _priorityMunicipalitiesCtrl = TextEditingController(
      text: widget.initialData['priority_municipalities']?.toString() ?? '0',
    );
    _newTargetCtrl = TextEditingController(
      text: widget.initialData['new_candidates_target']?.toString() ?? '0',
    );
    _newActualCtrl = TextEditingController(
      text: widget.initialData['new_candidates_actual']?.toString() ?? '0',
    );
    _endorsementTimingCtrl = TextEditingController(
      text: widget.initialData['endorsement_timing']?.toString() ?? '',
    );
    _supportVisitsCtrl = TextEditingController(
      text: widget.initialData['support_visits']?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _retainTargetCtrl.dispose();
    _priorityMunicipalitiesCtrl.dispose();
    _newTargetCtrl.dispose();
    _newActualCtrl.dispose();
    _endorsementTimingCtrl.dispose();
    _supportVisitsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final id = widget.initialData['id'];

      await supabase.from('election_regional_kpis').update({
        'incumbent_retain_target': int.tryParse(_retainTargetCtrl.text) ?? 0,
        'priority_municipalities':
            int.tryParse(_priorityMunicipalitiesCtrl.text) ?? 0,
        'new_candidates_target': int.tryParse(_newTargetCtrl.text) ?? 0,
        'new_candidates_actual': int.tryParse(_newActualCtrl.text) ?? 0,
        'endorsement_timing': _endorsementTimingCtrl.text,
        'support_visits': int.tryParse(_supportVisitsCtrl.text) ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      if (mounted) {
        Navigator.pop(context, true); // true: 更新成功
      }
    } catch (e) {
      debugPrint('Error updating KPI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新に失敗しました。管理者権限を確認してください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regionName = widget.initialData['region'] ?? '不明な地域';

    return AlertDialog(
      title: Text('$regionName - KPI更新'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNumberField(_retainTargetCtrl, '現職維持目標'),
              const SizedBox(height: 12),
              _buildNumberField(_priorityMunicipalitiesCtrl, '重点自治体数'),
              const SizedBox(height: 12),
              _buildNumberField(_newTargetCtrl, '新人擁立数 (目標)'),
              const SizedBox(height: 12),
              _buildNumberField(_newActualCtrl, '新人擁立数 (実績)'),
              const SizedBox(height: 12),
              _buildNumberField(_supportVisitsCtrl, '接戦区支援回数'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _endorsementTimingCtrl,
                decoration: const InputDecoration(
                  labelText: '公認内定時期',
                  border: OutlineInputBorder(),
                  hintText: '例: 2026年3月',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '入力必須です';
        if (int.tryParse(value) == null) return '数値を入力してください';
        return null;
      },
    );
  }
}
