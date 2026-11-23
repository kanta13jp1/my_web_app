import 'package:flutter/material.dart';

import '../models/self_skill_asset.dart';
import '../services/self_skill_asset_service.dart';
import 'atomic_forms/atoms/focus_blur_text_field.dart';
import 'atomic_forms/molecules/validated_input_group.dart';
import 'atomic_forms/organisms/validated_submit_form_card.dart';
import 'self_skill_radar_chart.dart';

/// 個人のスキル資産ポートフォリオ（保有スキルCRUD・レーダーチャート・獲得目標計画）パネル (#1392 / #2770 / #2730)。
class SelfSkillAssetPortfolioPanel extends StatefulWidget {
  const SelfSkillAssetPortfolioPanel({
    super.key,
    this.service,
  });

  final SelfSkillAssetService? service;

  @override
  State<SelfSkillAssetPortfolioPanel> createState() =>
      _SelfSkillAssetPortfolioPanelState();
}

class _SelfSkillAssetPortfolioPanelState
    extends State<SelfSkillAssetPortfolioPanel> {
  late final SelfSkillAssetService _service;

  final GlobalKey<FocusBlurTextFieldState> _skillNameKey =
      GlobalKey<FocusBlurTextFieldState>();
  final GlobalKey<FocusBlurTextFieldState> _skillLevelKey =
      GlobalKey<FocusBlurTextFieldState>();
  final GlobalKey<FocusBlurTextFieldState> _skillExpKey =
      GlobalKey<FocusBlurTextFieldState>();
  final TextEditingController _skillNameCtrl = TextEditingController();
  final TextEditingController _skillLevelCtrl =
      TextEditingController(text: '3');
  final TextEditingController _skillExpCtrl =
      TextEditingController(text: '1.0');
  final TextEditingController _skillNoteCtrl = TextEditingController();
  String _selectedSkillCategory = SelfSkillAssetService.defaultCategories.first;
  SkillAssessmentOrigin _selectedOrigin = SkillAssessmentOrigin.selfDeclared;
  SelfSkillAsset? _editingSkill;

  final GlobalKey<FocusBlurTextFieldState> _targetNameKey =
      GlobalKey<FocusBlurTextFieldState>();
  final GlobalKey<FocusBlurTextFieldState> _targetLevelKey =
      GlobalKey<FocusBlurTextFieldState>();
  final GlobalKey<FocusBlurTextFieldState> _targetPeriodKey =
      GlobalKey<FocusBlurTextFieldState>();
  final GlobalKey<FocusBlurTextFieldState> _targetProgressKey =
      GlobalKey<FocusBlurTextFieldState>();
  final TextEditingController _targetNameCtrl = TextEditingController();
  final TextEditingController _targetLevelCtrl =
      TextEditingController(text: '4');
  final TextEditingController _targetPeriodCtrl = TextEditingController(
    text: '2026-12',
  );
  final TextEditingController _targetProgressCtrl = TextEditingController(
    text: '20',
  );
  final TextEditingController _targetNoteCtrl = TextEditingController();
  String _selectedTargetCategory =
      SelfSkillAssetService.defaultCategories.first;
  SelfSkillTarget? _editingTarget;

  SelfSkillPortfolioData _data = const SelfSkillPortfolioData();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SelfSkillAssetService();
    _loadData();
  }

  @override
  void dispose() {
    _skillNameCtrl.dispose();
    _skillLevelCtrl.dispose();
    _skillExpCtrl.dispose();
    _skillNoteCtrl.dispose();
    _targetNameCtrl.dispose();
    _targetLevelCtrl.dispose();
    _targetPeriodCtrl.dispose();
    _targetProgressCtrl.dispose();
    _targetNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final loaded = await _service.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _data = loaded;
      _loading = false;
    });
  }

  Future<void> _saveSkill() async {
    final level = int.parse(_skillLevelCtrl.text.trim());
    final expText = _skillExpCtrl.text.trim();
    final exp = expText.isEmpty ? 0.0 : double.parse(expText);
    final editing = _editingSkill;
    final asset = SelfSkillAsset(
      id: editing?.id ?? 'skill_${DateTime.now().microsecondsSinceEpoch}',
      name: _skillNameCtrl.text.trim(),
      category: _selectedSkillCategory,
      proficiencyLevel: level,
      experienceYears: exp,
      origin: _selectedOrigin,
      note: _skillNoteCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );
    setState(() => _saving = true);
    try {
      final next = await _service.upsertSkill(asset, currentData: _data);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = next;
        _resetSkillForm();
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteSkill(String id) async {
    setState(() => _saving = true);
    try {
      final next = await _service.deleteSkill(id, currentData: _data);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = next;
        if (_editingSkill?.id == id) {
          _resetSkillForm();
        }
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveTarget() async {
    final targetLevel = int.parse(_targetLevelCtrl.text.trim());
    final progress = int.parse(_targetProgressCtrl.text.trim());
    final editing = _editingTarget;
    final target = SelfSkillTarget(
      id: editing?.id ?? 'target_${DateTime.now().microsecondsSinceEpoch}',
      skillName: _targetNameCtrl.text.trim(),
      category: _selectedTargetCategory,
      targetLevel: targetLevel,
      currentProgressPercent: progress,
      targetPeriod: _targetPeriodCtrl.text.trim(),
      investmentNote: _targetNoteCtrl.text.trim(),
      createdAt: editing?.createdAt ?? DateTime.now(),
    );
    setState(() => _saving = true);
    try {
      final next = await _service.upsertTarget(target, currentData: _data);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = next;
        _resetTargetForm();
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteTarget(String id) async {
    setState(() => _saving = true);
    try {
      final next = await _service.deleteTarget(id, currentData: _data);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = next;
        if (_editingTarget?.id == id) {
          _resetTargetForm();
        }
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _startEditSkill(SelfSkillAsset skill) {
    setState(() {
      _editingSkill = skill;
      _skillNameCtrl.text = skill.name;
      _skillLevelCtrl.text = skill.proficiencyLevel.toString();
      _skillExpCtrl.text = skill.experienceYears.toStringAsFixed(1);
      _skillNoteCtrl.text = skill.note;
      _selectedSkillCategory = skill.category;
      _selectedOrigin = skill.origin;
    });
  }

  void _resetSkillForm() {
    _editingSkill = null;
    _skillNameCtrl.clear();
    _skillLevelCtrl.text = '3';
    _skillExpCtrl.text = '1.0';
    _skillNoteCtrl.clear();
    _selectedSkillCategory = SelfSkillAssetService.defaultCategories.first;
    _selectedOrigin = SkillAssessmentOrigin.selfDeclared;
    _skillNameKey.currentState?.clearValidation();
    _skillLevelKey.currentState?.clearValidation();
    _skillExpKey.currentState?.clearValidation();
  }

  void _startEditTarget(SelfSkillTarget target) {
    setState(() {
      _editingTarget = target;
      _targetNameCtrl.text = target.skillName;
      _targetLevelCtrl.text = target.targetLevel.toString();
      _targetPeriodCtrl.text = target.targetPeriod;
      _targetProgressCtrl.text = target.currentProgressPercent.toString();
      _targetNoteCtrl.text = target.investmentNote;
      _selectedTargetCategory = target.category;
    });
  }

  void _resetTargetForm() {
    _editingTarget = null;
    _targetNameCtrl.clear();
    _targetLevelCtrl.text = '4';
    _targetPeriodCtrl.text = '2026-12';
    _targetProgressCtrl.text = '20';
    _targetNoteCtrl.clear();
    _selectedTargetCategory = SelfSkillAssetService.defaultCategories.first;
    _targetNameKey.currentState?.clearValidation();
    _targetLevelKey.currentState?.clearValidation();
    _targetPeriodKey.currentState?.clearValidation();
    _targetProgressKey.currentState?.clearValidation();
  }

  @override
  Widget build(BuildContext context) {
    final summary = SelfSkillAssetService.summarize(_data);
    return Card(
      key: const Key('self_skill_asset_portfolio_card'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.radar_outlined, color: Color(0xFF0F766E)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '人的スキル資産ポートフォリオ（自己資本・投資計画）',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'AIプロンプト管理（My Skills）とは独立した、個人の能力・経験・資格と習得投資計画の管理ボードです。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...<Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    key: const Key('self_skill_count_chip'),
                    label: Text(
                      '保有スキル ${summary.totalSkills}件 '
                      '(実績 ${summary.verifiedSkillsCount} / 自己申告 ${summary.selfDeclaredSkillsCount})',
                    ),
                  ),
                  Chip(
                    label: Text(
                      '平均習熟度 Lv ${summary.averageProficiency.toStringAsFixed(1)} / 5',
                    ),
                  ),
                  Chip(
                    key: const Key('self_skill_targets_chip'),
                    label: Text(
                      '投資目標 ${summary.totalTargets}件 '
                      '(平均進捗 ${summary.averageTargetProgress.round()}%)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SelfSkillRadarChart(axes: summary.radarAxes),
              const SizedBox(height: 16),
              _buildOwnedSkillForm(),
              if (_data.skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '登録済みスキル資産一覧',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final skill in _data.skills) _buildSkillTile(skill),
              ],
              const Divider(height: 28),
              _buildTargetForm(),
              if (_data.targets.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '今後獲得したいスキル・投資目標一覧',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final target in _data.targets) _buildTargetTile(target),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOwnedSkillForm() {
    return ValidatedSubmitFormCard(
      key: const Key('self_skill_asset_form_card'),
      title: _editingSkill == null ? '保有スキルを登録' : '保有スキルを編集',
      subtitle: '入力欄からフォーカスを外すと、送信前に即時バリデーションを行います。',
      fieldKeys: <GlobalKey<FocusBlurTextFieldState>>[
        _skillNameKey,
        _skillLevelKey,
        _skillExpKey,
      ],
      submitLabel: _editingSkill == null ? 'スキルを登録' : 'スキルを更新',
      submitButtonKey: const Key('self_skill_submit_button'),
      isSubmitting: _saving,
      onValidSubmit: _saveSkill,
      secondaryAction: _editingSkill == null
          ? null
          : TextButton(
              onPressed: _saving ? null : () => setState(_resetSkillForm),
              child: const Text('キャンセル'),
            ),
      children: <Widget>[
        ValidatedInputGroup(
          label: 'スキル名',
          requiredField: true,
          fieldKey: _skillNameKey,
          controller: _skillNameCtrl,
          hintText: '例: Flutter / TypeScript / 財務分析',
          validator: SelfSkillAssetService.validateSkillName,
        ),
        const SizedBox(height: 10),
        const Text(
          '分野・評価区分',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final cat in SelfSkillAssetService.defaultCategories)
              ChoiceChip(
                key: Key('self_skill_cat_$cat'),
                label: Text(cat, style: const TextStyle(fontSize: 11)),
                selected: _selectedSkillCategory == cat,
                onSelected: (_) => setState(() => _selectedSkillCategory = cat),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            for (final origin in SkillAssessmentOrigin.values)
              ChoiceChip(
                key: Key('self_skill_origin_${origin.name}'),
                label: Text(origin.label, style: const TextStyle(fontSize: 11)),
                selected: _selectedOrigin == origin,
                onSelected: (_) => setState(() => _selectedOrigin = origin),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ValidatedInputGroup(
                label: '習熟度 (1〜5)',
                requiredField: true,
                fieldKey: _skillLevelKey,
                controller: _skillLevelCtrl,
                keyboardType: TextInputType.number,
                validator: SelfSkillAssetService.validateProficiencyLevel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ValidatedInputGroup(
                label: '経験年数',
                fieldKey: _skillExpKey,
                controller: _skillExpCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: SelfSkillAssetService.validateExperienceYears,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _skillNoteCtrl,
          decoration: const InputDecoration(
            labelText: '根拠メモ・実績（任意）',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetForm() {
    return ValidatedSubmitFormCard(
      key: const Key('self_skill_target_form_card'),
      title: _editingTarget == null ? '今後獲得したいスキル（投資計画）を追加' : '投資目標を編集',
      fieldKeys: <GlobalKey<FocusBlurTextFieldState>>[
        _targetNameKey,
        _targetLevelKey,
        _targetPeriodKey,
        _targetProgressKey,
      ],
      submitLabel: _editingTarget == null ? '投資目標を追加' : '投資目標を更新',
      submitButtonKey: const Key('self_skill_target_submit_button'),
      isSubmitting: _saving,
      onValidSubmit: _saveTarget,
      secondaryAction: _editingTarget == null
          ? null
          : TextButton(
              onPressed: _saving ? null : () => setState(_resetTargetForm),
              child: const Text('キャンセル'),
            ),
      children: <Widget>[
        ValidatedInputGroup(
          label: '獲得したいスキル名',
          requiredField: true,
          fieldKey: _targetNameKey,
          controller: _targetNameCtrl,
          hintText: '例: セキュリティ監査 / 英語プレゼン',
          validator: SelfSkillAssetService.validateSkillName,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final cat in SelfSkillAssetService.defaultCategories)
              ChoiceChip(
                label: Text(cat, style: const TextStyle(fontSize: 11)),
                selected: _selectedTargetCategory == cat,
                onSelected: (_) =>
                    setState(() => _selectedTargetCategory = cat),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ValidatedInputGroup(
                label: '目標レベル (1〜5)',
                requiredField: true,
                fieldKey: _targetLevelKey,
                controller: _targetLevelCtrl,
                keyboardType: TextInputType.number,
                validator: SelfSkillAssetService.validateProficiencyLevel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ValidatedInputGroup(
                label: '進捗率 (%)',
                requiredField: true,
                fieldKey: _targetProgressKey,
                controller: _targetProgressCtrl,
                keyboardType: TextInputType.number,
                validator: SelfSkillAssetService.validateProgressPercent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ValidatedInputGroup(
          label: '目標時期 (YYYY-MM / YYYY-Q1)',
          requiredField: true,
          fieldKey: _targetPeriodKey,
          controller: _targetPeriodCtrl,
          hintText: '2026-12',
          validator: SelfSkillAssetService.validateTargetPeriod,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _targetNoteCtrl,
          decoration: const InputDecoration(
            labelText: '投資計画・学習リソースメモ（任意）',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillTile(SelfSkillAsset skill) {
    return Container(
      key: Key('self_skill_item_${skill.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${skill.name} (Lv ${skill.proficiencyLevel}/5)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${skill.category} / 経験 ${skill.experienceYears.toStringAsFixed(1)}年 / ${skill.origin.label}'
                  '${skill.note.isEmpty ? '' : ' / ${skill.note}'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '編集',
            onPressed: _saving ? null : () => _startEditSkill(skill),
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            key: Key('self_skill_delete_${skill.id}'),
            tooltip: '削除',
            onPressed: _saving ? null : () => _deleteSkill(skill.id),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetTile(SelfSkillTarget target) {
    return Container(
      key: Key('self_skill_target_item_${target.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${target.skillName} (目標 Lv${target.targetLevel} / 時期 ${target.targetPeriod})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '編集',
                onPressed: _saving ? null : () => _startEditTarget(target),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                key: Key('self_skill_target_delete_${target.id}'),
                tooltip: '削除',
                onPressed: _saving ? null : () => _deleteTarget(target.id),
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (target.currentProgressPercent / 100.0).clamp(0.0, 1.0),
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Text(
            '進捗 ${target.currentProgressPercent}% / ${target.category}'
            '${target.investmentNote.isEmpty ? '' : ' / ${target.investmentNote}'}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
