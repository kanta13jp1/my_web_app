import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/corporate_site_readiness_service.dart';

class CorporateSiteReadinessPage extends StatefulWidget {
  const CorporateSiteReadinessPage({
    super.key,
    this.gateway,
  });

  final CorporateSiteReadinessGateway? gateway;

  @override
  State<CorporateSiteReadinessPage> createState() =>
      _CorporateSiteReadinessPageState();
}

class _CorporateSiteReadinessPageState
    extends State<CorporateSiteReadinessPage> {
  static const _teal = Color(0xFF0F766E);
  static const _officialSources = <(String, String)>[
    (
      'GMOあおぞらネット銀行：事業内容確認',
      'https://gmo-aozora.com/business/account/identification-companyprofile.html',
    ),
    (
      'GMOあおぞらネット銀行：法人口座FAQ',
      'https://gmo-aozora.com/business/contents/faq.html',
    ),
    (
      '楽天銀行：必要書類',
      'https://www.rakuten-bank.co.jp/business/account/document/index.html',
    ),
    (
      'PayPay銀行：事業内容を確認できるホームページ',
      'https://www.paypay-bank.co.jp/business/account/homepage.html',
    ),
  ];

  final _urlController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _representativeController = TextEditingController();
  final _addressController = TextEditingController();
  final _businessPlanController = TextEditingController();
  final _wbsController = TextEditingController();
  final _contactController = TextEditingController();

  late final CorporateSiteReadinessGateway _gateway;
  bool _virtualOffice = false;
  bool _isReviewing = false;
  bool _isGenerating = false;
  String? _error;
  CorporateSiteReadinessReport? _report;
  String? _generatedHtml;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ??
        CorporateSiteReadinessService(
          supabaseClient: Supabase.instance.client,
        );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _companyNameController.dispose();
    _representativeController.dispose();
    _addressController.dispose();
    _businessPlanController.dispose();
    _wbsController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  CorporateSiteReadinessInput get _input => CorporateSiteReadinessInput(
        url: _urlController.text,
        companyName: _companyNameController.text,
        representativeName: _representativeController.text,
        registeredAddress: _addressController.text,
        businessPlanSummary: _businessPlanController.text,
        contact: _contactController.text,
        wbsMilestones: _wbsController.text
            .split(RegExp(r'\r?\n'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        virtualOffice: _virtualOffice,
      );

  String? _validate({required bool needsUrl, required bool needsContact}) {
    final fields = <(String, TextEditingController)>[
      ('法人名', _companyNameController),
      ('代表者名', _representativeController),
      ('登記上の本店所在地', _addressController),
      ('事業計画・事業内容', _businessPlanController),
      if (needsContact) ('WBSの主なマイルストーン', _wbsController),
      if (needsContact) ('問い合わせ先', _contactController),
    ];
    for (final (label, controller) in fields) {
      if (controller.text.trim().isEmpty) return '$labelを入力してください。';
    }
    if (needsUrl) {
      final uri = Uri.tryParse(_urlController.text.trim());
      if (uri == null ||
          !uri.hasAuthority ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        return '公開されているHTTP/HTTPSのサイトURLを入力してください。';
      }
    }
    return null;
  }

  Future<void> _review() async {
    final validation = _validate(needsUrl: true, needsContact: false);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _isReviewing = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await _gateway.review(_input);
      if (!mounted) return;
      setState(() => _report = report);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'サイトを確認できませんでした: $error');
    } finally {
      if (mounted) setState(() => _isReviewing = false);
    }
  }

  Future<void> _generate() async {
    final validation = _validate(needsUrl: false, needsContact: true);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final html = await _gateway.generateHtml(_input);
      if (!mounted) return;
      setState(() => _generatedHtml = html);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'HTMLを生成できませんでした: $error');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F7),
      appBar: AppBar(
        title: const Text('法人口座サイト準備チェック'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final form = _buildForm();
            final output = _buildOutput();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildIntro(),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: form),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: output),
                          ],
                        )
                      else ...[
                        form,
                        const SizedBox(height: 16),
                        output,
                      ],
                      const SizedBox(height: 16),
                      _buildSources(),
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

  Widget _buildIntro() {
    return Card(
      elevation: 0,
      color: const Color(0xFFE6FFFA),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '公開サイトの記載漏れを、申込前に確認',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              '登記上の法人名・代表者名・本店所在地と具体的な事業内容を照合します。結果は提出書類の代替ではなく、銀行の審査通過を保証しません。',
              style: TextStyle(height: 1.55),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '法人・事業情報',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text('照合する正しい登記情報を入力してください。'),
            const SizedBox(height: 16),
            _field(
              key: const Key('corporate-site-url'),
              controller: _urlController,
              label: '公開サイトURL（チェック時に必須）',
              hint: 'https://example.com/company',
              keyboardType: TextInputType.url,
            ),
            _field(
              key: const Key('corporate-company-name'),
              controller: _companyNameController,
              label: '登記上の法人名',
            ),
            _field(
              key: const Key('corporate-representative-name'),
              controller: _representativeController,
              label: '代表者名',
            ),
            _field(
              key: const Key('corporate-registered-address'),
              controller: _addressController,
              label: '登記上の本店所在地',
            ),
            CheckboxListTile(
              key: const Key('corporate-virtual-office'),
              contentPadding: EdgeInsets.zero,
              value: _virtualOffice,
              activeColor: _teal,
              title: const Text('バーチャルオフィス／レンタルオフィスを利用'),
              subtitle: const Text('該当時は追加資料の目視確認項目を表示します。'),
              onChanged: (value) =>
                  setState(() => _virtualOffice = value ?? false),
            ),
            _field(
              key: const Key('corporate-business-plan'),
              controller: _businessPlanController,
              label: '事業計画・具体的な事業内容',
              hint: '商品・サービス、対象顧客、提供方法、料金など',
              maxLines: 5,
            ),
            _field(
              key: const Key('corporate-wbs'),
              controller: _wbsController,
              label: 'WBSの主なマイルストーン（1行1件）',
              hint: 'β版公開\n初回顧客へ納品',
              maxLines: 4,
            ),
            _field(
              key: const Key('corporate-contact'),
              controller: _contactController,
              label: '問い合わせ先（HTML生成時に必須）',
              hint: 'contact@example.com',
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                key: const Key('corporate-site-error'),
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  key: const Key('corporate-review-button'),
                  onPressed: _isReviewing || _isGenerating ? null : _review,
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  icon: _isReviewing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: const Text('公開サイトをチェック'),
                ),
                OutlinedButton.icon(
                  key: const Key('corporate-generate-button'),
                  onPressed: _isReviewing || _isGenerating ? null : _generate,
                  icon: _isGenerating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.code),
                  label: const Text('簡易HTML/CSSを生成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: key,
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildOutput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_report == null && _generatedHtml == null)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.domain_verification_outlined,
                    size: 48,
                    color: Colors.teal.shade700,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'チェック結果と生成HTMLがここに表示されます。',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        if (_report != null) _buildReport(_report!),
        if (_report != null && _generatedHtml != null)
          const SizedBox(height: 16),
        if (_generatedHtml != null) _buildGeneratedHtml(_generatedHtml!),
      ],
    );
  }

  Widget _buildReport(CorporateSiteReadinessReport report) {
    final ready = report.readyForDocumentReview;
    return Card(
      key: const Key('corporate-readiness-report'),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ready ? Icons.check_circle : Icons.warning_amber_rounded,
                  color:
                      ready ? const Color(0xFF067647) : const Color(0xFFB54708),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ready ? '必須記載を確認しました' : '不足している必須記載があります',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${report.score}点',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (report.sourceTitle.isNotEmpty ||
                report.canonicalUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                report.sourceTitle.isNotEmpty
                    ? '確認元: ${report.sourceTitle}'
                    : '確認元: ${report.canonicalUrl}',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
            const Divider(height: 28),
            ...report.checks.map(_buildCheck),
            const SizedBox(height: 8),
            Text(
              report.disclaimer,
              style: const TextStyle(
                color: Color(0xFF7A2E0E),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheck(CorporateSiteReadinessCheck check) {
    final color = check.isPresent
        ? const Color(0xFF067647)
        : check.isMissing
            ? const Color(0xFFB42318)
            : const Color(0xFFB54708);
    final icon = check.isPresent
        ? Icons.check_circle_outline
        : check.isMissing
            ? Icons.cancel_outlined
            : Icons.visibility_outlined;
    final status = check.isPresent
        ? '記載あり'
        : check.isMissing
            ? '不足'
            : '目視確認';
    return Container(
      key: Key('corporate-check-${check.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${check.label} — $status',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                if (check.evidence != null) ...[
                  const SizedBox(height: 4),
                  Text('確認箇所: ${check.evidence}'),
                ],
                if (!check.isPresent && check.guidance.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(check.guidance),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedHtml(String html) {
    return Card(
      key: const Key('corporate-generated-html'),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '生成したHTML/CSS',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'HTMLをコピー',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: html));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('HTMLをコピーしました。')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                ),
              ],
            ),
            const Text(
              '内容を確認・修正し、自社ドメインの公開環境へ配置してください。',
              style: TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 420),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101828),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  html,
                  style: const TextStyle(
                    color: Color(0xFFE4E7EC),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSources() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '判断基準と注意事項',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '銀行はサイトだけでなく事業の具体性・運営実態などを総合判断します。新設法人やバーチャルオフィス利用時は、サイトがあっても契約書・請求書等を求められる場合があります。',
              style: TextStyle(height: 1.55),
            ),
            const SizedBox(height: 8),
            ..._officialSources.map(
              (source) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.open_in_new, size: 18),
                title: Text(source.$1),
                onTap: () => launchUrl(
                  Uri.parse(source.$2),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
