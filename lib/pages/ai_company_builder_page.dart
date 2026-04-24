import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiCompanyBuilderPage extends StatefulWidget {
  const AiCompanyBuilderPage({super.key});

  @override
  State<AiCompanyBuilderPage> createState() => _AiCompanyBuilderPageState();
}

class _AiCompanyBuilderPageState extends State<AiCompanyBuilderPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _ideaController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  double _threshold = 7;
  List<Map<String, dynamic>> _companies = <Map<String, dynamic>>[];
  Map<String, dynamic>? _detail;
  String? _selectedCompanyId;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _ideaController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  List<String> _asStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _metadataOf(Map<String, dynamic> row) {
    return _asMap(row['metadata']);
  }

  String _shortDate(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.length >= 10) return text.substring(0, 10);
    return text;
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'company_builder.list'},
      );
      final data = _asMap(response.data);
      final companies = _asMapList(data['companies']);
      final selectedId = _selectedCompanyId ??
          (companies.isNotEmpty ? companies.first['id']?.toString() : null);

      if (!mounted) return;
      setState(() {
        _companies = companies;
        _selectedCompanyId = selectedId;
        _isLoading = false;
      });

      if (selectedId != null && selectedId.isNotEmpty) {
        await _loadDetail(selectedId);
      } else if (mounted) {
        setState(() => _detail = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load builder data: $e';
      });
    }
  }

  Future<void> _loadDetail(String companyId) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'company_builder.get',
          'company_id': companyId,
        },
      );
      if (!mounted) return;
      setState(() {
        _selectedCompanyId = companyId;
        _detail = _asMap(response.data);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load company detail: $e';
      });
    }
  }

  Future<void> _bootstrapCompany() async {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      setState(
        () => _errorMessage = 'Enter one sentence to describe the company.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'company_builder.bootstrap',
          'idea': idea,
          'threshold': _threshold,
        },
      );
      final payload = _asMap(response.data);
      final company = _asMap(payload['company']);
      final companyId = company['id']?.toString();

      if (!mounted) return;
      setState(() {
        _detail = payload;
        _selectedCompanyId = companyId;
      });
      _ideaController.clear();
      await _loadCompanies();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Bootstrap failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _copyBlueprintPost(Map<String, dynamic> blueprint) async {
    final text = blueprint['launch_post_prompt']?.toString().trim() ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Build-in-public post copied')),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Company Builder',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Describe a business in one sentence. The system will run a gate review, apply the 30-day SaaS validation blueprint, create manager agents, seed tasks, and write the first vault notes.',
            style: TextStyle(
              color: Color(0xB3E5E7EB),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ideaController,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText:
                  'Example: Build an AI-native online school for Japanese startup founders.',
              hintStyle: const TextStyle(
                color: Color(0x61FFFFFF),
                height: 1.5,
              ),
              filled: true,
              fillColor: const Color(0xFFE5E7EB).withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gate threshold',
                  style: TextStyle(
                    color: Color(0xB3E5E7EB),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              Text(
                _threshold.toStringAsFixed(1),
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
          ),
          Slider(
            value: _threshold,
            min: 5,
            max: 9,
            divisions: 8,
            label: _threshold.toStringAsFixed(1),
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _threshold = value),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _bootstrapCompany,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _isSubmitting ? 'Bootstrapping...' : 'Analyze and Bootstrap',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyList() {
    if (_companies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: const Text(
          'No company instances yet. Run the builder once and the workspace will start storing managers, tool agents, tasks, workflows, and vault notes.',
          style: TextStyle(
            color: Color(0xB3E5E7EB),
            height: 1.5,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company Instances',
          style: TextStyle(
            color: Color(0xFFE5E7EB),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _companies.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final row = _companies[index];
            final metadata = _metadataOf(row);
            final companyId = row['id']?.toString() ?? '';
            final selected = companyId == _selectedCompanyId;
            return InkWell(
              onTap: companyId.isEmpty ? null : () => _loadDetail(companyId),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1D4ED8).withValues(alpha: 0.16)
                      : const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF60A5FA)
                        : const Color(0x1FFFFFFF),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            metadata['company_name']?.toString() ??
                                'Untitled company',
                            style: const TextStyle(
                              color: Color(0xFFE5E7EB),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                        _buildStatusChip(
                          metadata['status']?.toString() ?? 'draft',
                          metadata['passed'] == true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      metadata['summary']?.toString() ??
                          metadata['idea']?.toString() ??
                          '',
                      style: const TextStyle(
                        color: Color(0xB3E5E7EB),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Gate ${(metadata['overall_score'] as num?)?.toStringAsFixed(1) ?? '-'}',
                          style: const TextStyle(
                            color: Color(0xFFE5E7EB),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _shortDate(row['created_at']),
                          style: const TextStyle(
                            color: Color(0x8AE5E7EB),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status, bool passed) {
    final Color tone =
        passed ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: tone,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE5E7EB),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildOverview(Map<String, dynamic> company) {
    final metadata = _metadataOf(company);
    final criteria = _asMapList(metadata['criteria']);
    final channels = (metadata['launch_channels'] is List)
        ? (metadata['launch_channels'] as List)
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metadata['company_name']?.toString() ?? 'Untitled company',
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metadata['offer']?.toString() ??
                metadata['summary']?.toString() ??
                '',
            style: const TextStyle(
              color: Color(0xB3E5E7EB),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill('Audience', metadata['audience']?.toString() ?? '-'),
              _buildPill(
                'Model',
                metadata['business_model']?.toString() ?? '-',
              ),
              for (final channel in channels) _buildPill('Channel', channel),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Gate',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Overall ${(metadata['overall_score'] as num?)?.toStringAsFixed(1) ?? '-'} / threshold ${(metadata['threshold'] as num?)?.toStringAsFixed(1) ?? '-'}',
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final criterion in criteria) ...[
            _buildCriterionRow(criterion),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          Text(
            metadata['recommendation']?.toString() ?? '',
            style: const TextStyle(
              color: Color(0xB3E5E7EB),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlueprintMetric(String label, String value, String note) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0x8AE5E7EB),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(
              color: Color(0xB3E5E7EB),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThirtyDayBlueprint(Map<String, dynamic> company) {
    final metadata = _metadataOf(company);
    final blueprint = _asMap(metadata['thirty_day_saas_blueprint']);
    if (blueprint.isEmpty) return const SizedBox.shrink();

    final pricing = _asMap(blueprint['pricing']);
    final validationTargets = _asMap(blueprint['validation_targets']);
    final weeks = _asMapList(blueprint['weeks']);
    final guardrails = _asStringList(blueprint['guardrails']);
    final publicMetrics = _asStringList(blueprint['build_in_public_metrics']);
    final mrrTarget = (blueprint['mrr_target'] as num?)?.round() ?? 1287;
    final trialTarget =
        (blueprint['trial_signups_target'] as num?)?.round() ?? 312;
    final paidTarget = (blueprint['paid_users_target'] as num?)?.round() ?? 41;
    final interviews = (validationTargets['interviews'] as num?)?.round() ?? 20;

    return _buildDetailSection(
      title: '30-Day SaaS Blueprint',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    blueprint['north_star']?.toString() ??
                        'Validate one painful workflow before expanding scope.',
                    style: const TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy build-in-public post',
                  onPressed: () => _copyBlueprintPost(blueprint),
                  icon: const Icon(Icons.copy_all_outlined),
                  color: const Color(0xFFE5E7EB),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildBlueprintMetric(
                  'MRR target',
                  '\$$mrrTarget',
                  '30-day paid signal',
                ),
                _buildBlueprintMetric(
                  'Trial signups',
                  '$trialTarget',
                  'Launch traffic target',
                ),
                _buildBlueprintMetric(
                  'Paid users',
                  '$paidTarget',
                  'Conversion target',
                ),
                _buildBlueprintMetric(
                  'Interviews',
                  '$interviews',
                  'User-request filter',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Pricing discipline',
              style: TextStyle(
                color: Color(0xFFE5E7EB),
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPill('Free', pricing['free']?.toString() ?? '-'),
                _buildPill('Pro', pricing['pro']?.toString() ?? '-'),
                _buildPill('Team', pricing['team']?.toString() ?? '-'),
                _buildPill('Rule', pricing['rule']?.toString() ?? '-'),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Weekly validation loop',
              style: TextStyle(
                color: Color(0xFFE5E7EB),
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            for (final week in weeks) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x1AFFFFFF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${week['label'] ?? '-'}: ${week['goal'] ?? '-'}',
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final item in _asStringList(week['ship']))
                      Text(
                        '- $item',
                        style: const TextStyle(
                          color: Color(0xB3E5E7EB),
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Exit signal: ${week['exit_signal'] ?? '-'}',
                      style: const TextStyle(
                        color: Color(0x8AE5E7EB),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Guardrails',
              style: TextStyle(
                color: Color(0xFFE5E7EB),
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in guardrails)
              Text(
                '- $item',
                style: const TextStyle(
                  color: Color(0xB3E5E7EB),
                  height: 1.5,
                ),
              ),
            if (publicMetrics.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final metric in publicMetrics)
                    _buildPill('Metric', metric),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xB3E5E7EB),
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildCriterionRow(Map<String, dynamic> criterion) {
    final score = (criterion['score'] as num?)?.toDouble() ?? 0;
    final progress = (score / 10).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                criterion['label']?.toString() ?? '-',
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
            Text(
              '${score.toStringAsFixed(1)} / 10',
              style: const TextStyle(
                color: Color(0xB3E5E7EB),
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0x1FFFFFFF),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          criterion['rationale']?.toString() ?? '',
          style: const TextStyle(color: Color(0x8AE5E7EB), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildAgentsSection(
    String title,
    List<Map<String, dynamic>> agents,
  ) {
    return _buildDetailSection(
      title: title,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: agents.map((agent) {
          final metadata = _metadataOf(agent);
          return Container(
            width: 230,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent['display_name']?.toString() ?? '-',
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  agent['role_title']?.toString() ?? '-',
                  style: const TextStyle(
                    color: Color(0xB3E5E7EB),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  metadata['focus']?.toString() ?? '',
                  style: const TextStyle(color: Color(0x8AE5E7EB), height: 1.4),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildTasksSection(
    List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>> managers,
    List<Map<String, dynamic>> tools,
  ) {
    final managerNames = <String, String>{
      for (final manager in managers)
        manager['id']?.toString() ?? '':
            manager['display_name']?.toString() ?? '-',
    };
    final toolNames = <String, String>{
      for (final tool in tools)
        tool['id']?.toString() ?? '': tool['display_name']?.toString() ?? '-',
    };

    return _buildDetailSection(
      title: 'Initial Task Graph',
      child: Column(
        children: tasks.map((task) {
          final metadata = _metadataOf(task);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task['title']?.toString() ?? '-',
                        style: const TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                    Text(
                      metadata['stage']?.toString() ?? '',
                      style: const TextStyle(
                        color: Color(0x8AE5E7EB),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task['description']?.toString() ?? '',
                  style: const TextStyle(
                    color: Color(0xB3E5E7EB),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${managerNames[task['supervisor_agent_id']?.toString() ?? ''] ?? '-'} -> ${toolNames[task['assignee_agent_id']?.toString() ?? ''] ?? '-'}',
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildVaultSection(List<Map<String, dynamic>> notes) {
    return _buildDetailSection(
      title: 'Vault Notes',
      child: Column(
        children: notes.map((note) {
          final metadata = _metadataOf(note);
          final content = metadata['content']?.toString() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata['title']?.toString() ?? 'Untitled note',
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metadata['path']?.toString() ?? '',
                  style: const TextStyle(
                    color: Color(0x8AE5E7EB),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  content.length > 220
                      ? '${content.substring(0, 220)}...'
                      : content,
                  style: const TextStyle(
                    color: Color(0xB3E5E7EB),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildAuditSection(List<Map<String, dynamic>> entries) {
    return _buildDetailSection(
      title: 'Audit Trail',
      child: Column(
        children: entries.map((entry) {
          final metadata = _metadataOf(entry);
          final details = _asMap(metadata['details']);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata['resource']?.toString() ?? 'event',
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _shortDate(metadata['timestamp'] ?? entry['created_at']),
                  style: const TextStyle(
                    color: Color(0x8AE5E7EB),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  details.entries
                      .map((item) => '${item.key}: ${item.value}')
                      .join('\n'),
                  style: const TextStyle(
                    color: Color(0xB3E5E7EB),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildDetail() {
    if (_detail == null || _detail!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: const Text(
          'Select a company instance to inspect its manager layer, shared tool layer, seeded tasks, and vault notes.',
          style: TextStyle(
            color: Color(0xB3E5E7EB),
            height: 1.5,
          ),
        ),
      );
    }

    final company = _asMap(_detail!['company']);
    final managers = _asMapList(_detail!['manager_agents']);
    final tools = _asMapList(_detail!['tool_agents']);
    final tasks = _asMapList(_detail!['tasks']);
    final notes = _asMapList(_detail!['vault_notes']);
    final auditEntries = _asMapList(_detail!['audit_entries']);
    final blueprint = _asMap(
      _metadataOf(company)['thirty_day_saas_blueprint'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverview(company),
        const SizedBox(height: 24),
        if (blueprint.isNotEmpty) ...[
          _buildThirtyDayBlueprint(company),
          const SizedBox(height: 24),
        ],
        _buildAgentsSection('Business Layer Managers', managers),
        const SizedBox(height: 24),
        _buildAgentsSection('Shared Tool Layer', tools),
        const SizedBox(height: 24),
        _buildTasksSection(tasks, managers, tools),
        const SizedBox(height: 24),
        _buildVaultSection(notes),
        const SizedBox(height: 24),
        _buildAuditSection(auditEntries),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('AI Company Builder'),
        backgroundColor: const Color(0xFF020617),
        foregroundColor: const Color(0xFFE5E7EB),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadCompanies,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCompanies,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildComposer(),
            const SizedBox(height: 20),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildCompanyList(),
              const SizedBox(height: 28),
              _buildDetail(),
            ],
          ],
        ),
      ),
    );
  }
}
