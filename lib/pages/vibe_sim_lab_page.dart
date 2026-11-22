import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/vibe_sim_diagnostic_service.dart';

/// MuJoCo「Vibe Sim」3段階検証に基づく純クライアント診断・試算ページ。
///
/// 外部 API・Supabase・認証・課金に依存しないリーフルートとして動作する。
class VibeSimLabPage extends StatefulWidget {
  const VibeSimLabPage({super.key});

  @override
  State<VibeSimLabPage> createState() => _VibeSimLabPageState();
}

class _VibeSimLabPageState extends State<VibeSimLabPage> {
  VibeSimPreset _selectedPreset = VibeSimPreset.v1Naive;
  late VibeSimRawFormValues _rawValues;
  late VibeSimDiagnosticResult _result;

  late final TextEditingController _timestepController;
  late final TextEditingController _impratioController;
  late final TextEditingController _rootOffsetController;
  late final TextEditingController _geomMarginController;
  late final TextEditingController _solrefTimeconstController;
  late final TextEditingController _solrefDampratioController;

  @override
  void initState() {
    super.initState();
    _rawValues = VibeSimDiagnosticService.rawValuesForPreset(_selectedPreset);
    _result = VibeSimDiagnosticService.evaluateRaw(_rawValues);
    _timestepController = TextEditingController(text: _rawValues.timestepText);
    _impratioController = TextEditingController(text: _rawValues.impratioText);
    _rootOffsetController = TextEditingController(
      text: _rawValues.rootOffsetMmText,
    );
    _geomMarginController = TextEditingController(
      text: _rawValues.geomMarginMmText,
    );
    _solrefTimeconstController = TextEditingController(
      text: _rawValues.solrefTimeconstText,
    );
    _solrefDampratioController = TextEditingController(
      text: _rawValues.solrefDampratioText,
    );
  }

  @override
  void dispose() {
    _timestepController.dispose();
    _impratioController.dispose();
    _rootOffsetController.dispose();
    _geomMarginController.dispose();
    _solrefTimeconstController.dispose();
    _solrefDampratioController.dispose();
    super.dispose();
  }

  void _applyPreset(final VibeSimPreset preset) {
    final nextRaw = VibeSimDiagnosticService.rawValuesForPreset(preset);
    _timestepController.text = nextRaw.timestepText;
    _impratioController.text = nextRaw.impratioText;
    _rootOffsetController.text = nextRaw.rootOffsetMmText;
    _geomMarginController.text = nextRaw.geomMarginMmText;
    _solrefTimeconstController.text = nextRaw.solrefTimeconstText;
    _solrefDampratioController.text = nextRaw.solrefDampratioText;
    setState(() {
      _selectedPreset = preset;
      _rawValues = nextRaw;
      _result = VibeSimDiagnosticService.evaluateRaw(nextRaw);
    });
  }

  void _updateRaw(final VibeSimRawFormValues nextRaw) {
    setState(() {
      _rawValues = nextRaw;
      _result = VibeSimDiagnosticService.evaluateRaw(nextRaw);
    });
  }

  Future<void> _copySnippet() async {
    if (!_result.isValid || _result.snippet.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _result.snippet));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('MjSpec 修正スニペットをクリップボードにコピーしました。'),
      ),
    );
  }

  Color _colorForRiskLevel(final VibeSimRiskLevel level) => switch (level) {
        VibeSimRiskLevel.safe => const Color(0xFF4CAF50),
        VibeSimRiskLevel.caution => const Color(0xFFFFC107),
        VibeSimRiskLevel.danger => const Color(0xFFE53935),
      };

  IconData _iconForRiskLevel(final VibeSimRiskLevel level) => switch (level) {
        VibeSimRiskLevel.safe => Icons.check_circle,
        VibeSimRiskLevel.caution => Icons.warning_amber,
        VibeSimRiskLevel.danger => Icons.error,
      };

  Color _colorForSeverity(final VibeSimSeverity severity) => switch (severity) {
        VibeSimSeverity.critical => const Color(0xFFE53935),
        VibeSimSeverity.high => const Color(0xFFFF6B35),
        VibeSimSeverity.warning => const Color(0xFFFFC107),
        VibeSimSeverity.info => const Color(0xFF3D5AFE),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibe Sim 物理破綻診断ラボ'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (final context, final constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildDisclaimerBanner(theme),
                      const SizedBox(height: 16),
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: 5,
                              child: _buildFormPanel(theme),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 7,
                              child: _buildResultPanel(theme),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _buildFormPanel(theme),
                            const SizedBox(height: 16),
                            _buildResultPanel(theme),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDisclaimerBanner(final ThemeData theme) {
    final surfaceColor = theme.colorScheme.surfaceContainerHighest;
    return Card(
      color: surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'MuJoCo シミュレーション設定の事前診断・試算（オフライン計算）',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '本診断は MuJoCo 実機計算の代替ではなく、設定ミスを事前検出するための静的点検・試算ツールです。入力データはブラウザ内のみで計算され、外部サーバーへ送信されません。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormPanel(final ThemeData theme) {
    final errors = _result.validationErrors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '1. プリセット選択（3段階の比較）',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  key: const Key('vibe-sim-preset-v1'),
                  label: Text(
                    VibeSimDiagnosticService.presetLabel(VibeSimPreset.v1Naive),
                  ),
                  selected: _selectedPreset == VibeSimPreset.v1Naive,
                  onSelected: (_) => _applyPreset(VibeSimPreset.v1Naive),
                ),
                ChoiceChip(
                  key: const Key('vibe-sim-preset-v2'),
                  label: Text(
                    VibeSimDiagnosticService.presetLabel(
                      VibeSimPreset.v2SpecTuned,
                    ),
                  ),
                  selected: _selectedPreset == VibeSimPreset.v2SpecTuned,
                  onSelected: (_) => _applyPreset(VibeSimPreset.v2SpecTuned),
                ),
                ChoiceChip(
                  key: const Key('vibe-sim-preset-v3'),
                  label: Text(
                    VibeSimDiagnosticService.presetLabel(
                      VibeSimPreset.v3Audited,
                    ),
                  ),
                  selected: _selectedPreset == VibeSimPreset.v3Audited,
                  onSelected: (_) => _applyPreset(VibeSimPreset.v3Audited),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '2. 物理・構造パラメータ入力',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('vibe-sim-field-timestep'),
              controller: _timestepController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: '時間刻み timestep (s) [0.0001〜0.1]',
                border: const OutlineInputBorder(),
                errorText: errors['timestep'],
                errorMaxLines: 3,
              ),
              onChanged: (final value) => _updateRaw(
                _rawValues.copyWith(timestepText: value),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '積分法 (integrator)',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VibeSimIntegrator.values.map((final item) {
                return ChoiceChip(
                  label: Text(VibeSimDiagnosticService.integratorLabel(item)),
                  selected: _rawValues.integrator == item,
                  onSelected: (_) => _updateRaw(
                    _rawValues.copyWith(integrator: item),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            Text(
              '接触摩擦次元 (condim)',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>[1, 3, 4, 6].map((final dim) {
                return ChoiceChip(
                  label: Text('condim = $dim'),
                  selected: _rawValues.condim == dim,
                  onSelected: (_) => _updateRaw(
                    _rawValues.copyWith(condim: dim),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            Text(
              '摩擦円錐 (cone)',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VibeSimCone.values.map((final item) {
                return ChoiceChip(
                  label: Text(VibeSimDiagnosticService.coneLabel(item)),
                  selected: _rawValues.cone == item,
                  onSelected: (_) => _updateRaw(
                    _rawValues.copyWith(cone: item),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('vibe-sim-field-impratio'),
              controller: _impratioController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '摩擦・法線比 impratio [0.1〜100.0]',
                border: const OutlineInputBorder(),
                errorText: errors['impratio'],
                errorMaxLines: 3,
              ),
              onChanged: (final value) => _updateRaw(
                _rawValues.copyWith(impratioText: value),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '中空トレイのジオム構成',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VibeSimTrayGeometryMode.values.map((final mode) {
                return ChoiceChip(
                  label: Text(VibeSimDiagnosticService.trayModeLabel(mode)),
                  selected: _rawValues.trayGeometryMode == mode,
                  onSelected: (_) => _updateRaw(
                    _rawValues.copyWith(trayGeometryMode: mode),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('vibe-sim-field-root-offset'),
              controller: _rootOffsetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'ルート原点ずれ (mm) [0.0〜500.0]',
                border: const OutlineInputBorder(),
                errorText: errors['rootOffsetMm'],
                errorMaxLines: 3,
              ),
              onChanged: (final value) => _updateRaw(
                _rawValues.copyWith(rootOffsetMmText: value),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('vibe-sim-field-geom-margin'),
              controller: _geomMarginController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '接触マージン margin (mm) [0.0〜100.0]',
                border: const OutlineInputBorder(),
                errorText: errors['geomMarginMm'],
                errorMaxLines: 3,
              ),
              onChanged: (final value) => _updateRaw(
                _rawValues.copyWith(geomMarginMmText: value),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('vibe-sim-field-solref-timeconst'),
              controller: _solrefTimeconstController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'solref 時定数 (s) [0.0005〜1.0]',
                border: const OutlineInputBorder(),
                errorText: errors['solrefTimeconst'],
                errorMaxLines: 3,
              ),
              onChanged: (final value) => _updateRaw(
                _rawValues.copyWith(solrefTimeconstText: value),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('vibe-sim-field-solref-dampratio'),
              controller: _solrefDampratioController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'solref 減衰比 [0.05〜5.0]',
                border: const OutlineInputBorder(),
                errorText: errors['solrefDampratio'],
                errorMaxLines: 3,
              ),
              onChanged: (final value) => _updateRaw(
                _rawValues.copyWith(solrefDampratioText: value),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ルートボディ名を modelname と一致させる'),
              value: _rawValues.rootMatchesModelName,
              onChanged: (final value) => _updateRaw(
                _rawValues.copyWith(rootMatchesModelName: value),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('mujoco==4.0.1 / Studio API 互換チェックを含める'),
              value: _rawValues.mujoco401Compat,
              onChanged: (final value) => _updateRaw(
                _rawValues.copyWith(mujoco401Compat: value),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const Key('vibe-sim-recover-v3'),
                onPressed: () => _applyPreset(VibeSimPreset.v3Audited),
                icon: const Icon(Icons.restore),
                label: const Text('推奨プリセット（v3_audited）で復元'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('vibe-sim-reload-selected'),
                onPressed: () => _applyPreset(_selectedPreset),
                icon: const Icon(Icons.refresh),
                label: const Text('選択プリセットを再読込'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPanel(final ThemeData theme) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!_result.isValid)
            _buildErrorBanner(theme)
          else
            _buildRiskSummaryCard(theme),
          const SizedBox(height: 16),
          if (_result.isValid) ...<Widget>[
            _buildFindingsCard(theme),
            const SizedBox(height: 16),
          ],
          _buildSnippetCard(theme),
          const SizedBox(height: 16),
          _buildBenchmarkReferenceCard(theme),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(final ThemeData theme) {
    const errorColor = Color(0xFFE53935);
    return Card(
      key: const Key('vibe-sim-error-banner'),
      color: errorColor.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: errorColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.error_outline, color: errorColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '入力エラーがあります（診断結果と修正コードの生成を停止中）',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '入力エラーを修正すると診断結果と修正コードが更新されます。ワンクリックで戻す場合は「推奨プリセット（v3_audited）で復元」を押してください。',
            ),
            const SizedBox(height: 8),
            for (final msg in _result.validationErrors.values)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('・$msg'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskSummaryCard(final ThemeData theme) {
    final color = _colorForRiskLevel(_result.riskLevel);
    final icon = _iconForRiskLevel(_result.riskLevel);
    final label = VibeSimDiagnosticService.riskLevelLabel(_result.riskLevel);
    return Card(
      key: const Key('vibe-sim-risk-summary'),
      color: color.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'リスクスコア: ${_result.riskScore} / 100 点（検出 ${_result.findings.length} 件）',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindingsCard(final ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '診断結果と根拠 (${_result.findings.length} 件)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_result.findings.isEmpty)
              const Text(
                '主要な物理破綻リスクは検出されませんでした。ローカル環境のベンチマークと mujoco-audit で最終確認してください。',
              )
            else
              for (final finding in _result.findings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _colorForSeverity(finding.severity)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '[${VibeSimDiagnosticService.severityLabel(finding.severity)}] ${finding.title}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: _colorForSeverity(finding.severity),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(finding.detail),
                        const SizedBox(height: 4),
                        Text(
                          '推奨対策: ${finding.recommendation}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnippetCard(final ThemeData theme) {
    final canCopy = _result.isValid && _result.snippet.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'MjSpec 修正コードスニペット',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    key: const Key('vibe-sim-copy-snippet'),
                    onPressed: canCopy ? _copySnippet : null,
                    icon: const Icon(Icons.copy),
                    label: const Text('スニペットをコピー'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!canCopy)
              const Text('入力エラーを修正すると診断結果と修正コードが更新されます。')
            else
              SelectionArea(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      _result.snippet,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkReferenceCard(final ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '一次実測ベンチマーク対比（Windows 11 / mujoco==4.0.1 / 3シード × 3.0s）',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('ステージ')),
                  DataColumn(label: Text('timestep')),
                  DataColumn(label: Text('積分法')),
                  DataColumn(label: Text('捕獲率')),
                  DataColumn(label: Text('10度傾斜保持')),
                  DataColumn(label: Text('収束時間')),
                  DataColumn(label: Text('静止めり込み')),
                  DataColumn(label: Text('QACC警告')),
                  DataColumn(label: Text('自動監査')),
                ],
                rows: VibeSimDiagnosticService.benchmarkRows
                    .map(
                      (final row) => DataRow(
                        cells: <DataCell>[
                          DataCell(Text(row.stageLabel)),
                          DataCell(Text(row.timestepLabel)),
                          DataCell(Text(row.integratorLabel)),
                          DataCell(Text(row.captureRateLabel)),
                          DataCell(Text(row.tiltRetentionLabel)),
                          DataCell(Text(row.settledTimeLabel)),
                          DataCell(Text(row.restingPenetrationLabel)),
                          DataCell(Text(row.qaccWarningsLabel)),
                          DataCell(Text(row.auditLabel)),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
