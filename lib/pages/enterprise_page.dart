import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// B2B エンタープライズ向けランディングページ
/// 法人・チーム導入を促進するための専用ページ
class EnterprisePage extends StatefulWidget {
  const EnterprisePage({super.key});

  @override
  State<EnterprisePage> createState() => _EnterprisePageState();
}

class _EnterprisePageState extends State<EnterprisePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _companyController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitInquiry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.from('enterprise_inquiries').insert({
        'email': _emailController.text.trim(),
        'company_name': _companyController.text.trim(),
        'message': _messageController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() => _submitted = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'お問い合わせの送信に失敗しました。後ほど再度お試しください。';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('自分株式会社 for Teams'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/'),
            child: const Text(
              '個人プランを見る',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(isMobile),
            _buildCostSavingsSection(isMobile),
            _buildUseCasesSection(isMobile),
            _buildFeatureTableSection(isMobile),
            _buildInquiryFormSection(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: isMobile ? 48 : 80,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF3949AB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🏢 法人・チーム向け',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Slack・Chatwork・ジョブカン・\nMoneyForwardを\n1つに統合。完全無料。',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 28 : 40,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'チームのコミュニケーション・タスク管理・経費管理・AI支援を\n1つのプラットフォームで。月額0円。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: isMobile ? 15 : 18,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  final formContext = context;
                  Scrollable.ensureVisible(
                    formContext,
                    duration: const Duration(milliseconds: 600),
                  );
                },
                icon: const Icon(Icons.business),
                label: const Text('無料で導入相談する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/'),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('デモを見る'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostSavingsSection(bool isMobile) {
    const tools = [
      _ToolCost(
        name: 'Slack',
        icon: '💬',
        monthlyPerUser: 750,
        category: 'チャット',
      ),
      _ToolCost(
        name: 'Chatwork',
        icon: '💼',
        monthlyPerUser: 700,
        category: 'チャット',
      ),
      _ToolCost(name: 'ジョブカン', icon: '📋', monthlyPerUser: 500, category: 'HR'),
      _ToolCost(
        name: 'MoneyForward',
        icon: '💰',
        monthlyPerUser: 500,
        category: '経費',
      ),
      _ToolCost(
        name: 'Notion',
        icon: '📝',
        monthlyPerUser: 1650,
        category: 'ノート',
      ),
    ];

    final totalCost = tools.fold<int>(0, (sum, t) => sum + t.monthlyPerUser);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 56,
      ),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💸 コスト削減シミュレーション',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '1人あたり月額コストの比較 (10人チームで計算)',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const SizedBox(height: 24),
          ...tools.map(
            (tool) => _CostComparisonRow(tool: tool),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '競合ツール合計 (1人あたり/月)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '¥${totalCost.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFFEF4444),
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '自分株式会社 (全機能込み)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '10人チームで年間¥${(4100 * 10 * 12).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}の節約',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const Text(
                  '¥0',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUseCasesSection(bool isMobile) {
    const useCases = [
      _UseCase(
        icon: Icons.chat_bubble_outline,
        title: 'チームコミュニケーション',
        description: 'Slack・Chatwork 相当のチャット機能。プロジェクト別チャンネル管理。',
        replaces: 'Slack / Chatwork',
      ),
      _UseCase(
        icon: Icons.task_alt,
        title: 'タスク・プロジェクト管理',
        description: 'カンバンボード・テーブルビューでタスクを可視化。ジョブカン相当の勤怠連携も。',
        replaces: 'ジョブカン / Asana',
      ),
      _UseCase(
        icon: Icons.account_balance_wallet_outlined,
        title: '経費・資産管理',
        description: 'MoneyForward 相当の経費申請・資産管理。AI が自動カテゴリ分類。',
        replaces: 'MoneyForward / freee',
      ),
      _UseCase(
        icon: Icons.auto_awesome,
        title: 'AI 組織OS',
        description: 'CEO/CFO/CMO/HR の AI 役員会議。毎朝のブリーフィングで意思決定を加速。',
        replaces: '※独自機能',
      ),
      _UseCase(
        icon: Icons.description_outlined,
        title: 'ドキュメント・ナレッジ管理',
        description: 'Notion 相当のリッチドキュメント。バージョン履歴・テンプレート・全文検索。',
        replaces: 'Notion / Confluence',
      ),
      _UseCase(
        icon: Icons.analytics_outlined,
        title: '経営コックピット',
        description: 'KPI・財務・習慣・成長指標を1画面で俯瞰。経営の透明性を確保。',
        replaces: '※独自機能',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 56,
      ),
      color: Color(0xFFF8FAFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏗️ 主な活用シーン',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          isMobile
              ? Column(
                  children:
                      useCases.map((u) => _UseCaseCard(useCase: u)).toList(),
                )
              : GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  children:
                      useCases.map((u) => _UseCaseCard(useCase: u)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildFeatureTableSection(bool isMobile) {
    const comparisons = [
      _EnterpriseFeature('チームチャット', true, true, false, false, false),
      _EnterpriseFeature('タスク管理', true, true, true, false, false),
      _EnterpriseFeature('ドキュメント共有', true, false, false, true, false),
      _EnterpriseFeature('経費管理', false, false, false, false, true),
      _EnterpriseFeature('AI アシスタント', true, false, false, false, false),
      _EnterpriseFeature('勤怠管理', false, false, true, false, false),
      _EnterpriseFeature('マインドマップ', true, false, false, false, false),
      _EnterpriseFeature('性格診断', true, false, false, false, false),
      _EnterpriseFeature('完全無料', true, false, false, false, false),
    ];

    if (isMobile) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 56),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 機能比較表',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          Table(
            border: TableBorder.all(
              color: Color(0xFFE2E8F0),
              width: 1,
            ),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
              5: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF1E293B)),
                children: [
                  _tableHeader('機能'),
                  _tableHeader('自分株式会社', highlight: true),
                  _tableHeader('Slack'),
                  _tableHeader('ジョブカン'),
                  _tableHeader('Notion'),
                  _tableHeader('MoneyForward'),
                ],
              ),
              ...comparisons.map(
                (c) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        c.feature,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    _tableCell(c.us, highlight: true),
                    _tableCell(c.slack),
                    _tableCell(c.jobcan),
                    _tableCell(c.notion),
                    _tableCell(c.moneyforward),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          color: highlight ? Color(0xFF34D399) : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _tableCell(bool has, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(
        has ? Icons.check_circle : Icons.remove,
        color: has
            ? (highlight ? Color(0xFF10B981) : Color(0xFF6B7280))
            : Color(0xFFD1D5DB),
        size: 20,
      ),
    );
  }

  Widget _buildInquiryFormSection(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 56,
      ),
      color: Color(0xFF1E293B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📩 無料 導入相談',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'チームの課題をお聞かせください。導入サポートから移行代行まで無料でご支援します。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          if (_submitted)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF10B981)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'お問い合わせを受け付けました。2営業日以内にご連絡いたします。',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormField(
                      controller: _emailController,
                      label: '会社メールアドレス *',
                      hint: 'example@company.co.jp',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'メールアドレスを入力してください';
                        }
                        if (!v.contains('@')) return '有効なメールアドレスを入力してください';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _companyController,
                      label: '会社名 *',
                      hint: '株式会社〇〇',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return '会社名を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _messageController,
                      label: '現在の課題・お問い合わせ内容',
                      hint:
                          '例: 現在Slack + ジョブカンを使用中で、コスト削減と一元管理を検討しています。チーム規模は20名です。',
                      maxLines: 4,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitInquiry,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(_isSubmitting ? '送信中...' : '無料で相談する'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '※ スパムには使用しません。いつでも登録解除できます。',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helper models
// ---------------------------------------------------------------------------

class _ToolCost {
  final String name;
  final String icon;
  final int monthlyPerUser;
  final String category;

  const _ToolCost({
    required this.name,
    required this.icon,
    required this.monthlyPerUser,
    required this.category,
  });
}

class _UseCase {
  final IconData icon;
  final String title;
  final String description;
  final String replaces;

  const _UseCase({
    required this.icon,
    required this.title,
    required this.description,
    required this.replaces,
  });
}

class _EnterpriseFeature {
  final String feature;
  final bool us;
  final bool slack;
  final bool jobcan;
  final bool notion;
  final bool moneyforward;

  const _EnterpriseFeature(
    this.feature,
    this.us,
    this.slack,
    this.jobcan,
    this.notion,
    this.moneyforward,
  );
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _CostComparisonRow extends StatelessWidget {
  final _ToolCost tool;

  const _CostComparisonRow({required this.tool});

  @override
  Widget build(BuildContext context) {
    final percent = (tool.monthlyPerUser / 4100 * 100).clamp(0.0, 100.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(tool.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              tool.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percent / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              '¥${tool.monthlyPerUser}/月',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _UseCaseCard extends StatelessWidget {
  final _UseCase useCase;

  const _UseCaseCard({required this.useCase});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF3949AB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  useCase.icon,
                  color: Color(0xFF3949AB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  useCase.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            useCase.description,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '代替: ${useCase.replaces}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
