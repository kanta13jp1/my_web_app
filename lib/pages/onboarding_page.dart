import 'package:flutter/material.dart';
import '../main.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _onboardingDone = false; // 就任承諾完了フラグ（4ページ目表示制御）

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('署名（お名前）を入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. プロフィール（CEO名）を登録
      await supabase.from('user_profiles').upsert({
        'user_id': user.id,
        'display_name': name,
        'role': 'CEO', // 役職をCEOに設定
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. オンボーディング完了フラグを更新
      await supabase.from('user_stats').upsert(
        {
          'user_id': user.id,
          'metadata': {'onboarding_completed': true},
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      ); // 既存データがあればマージ更新される想定

      try {
        await supabase.from('user_stats').update({
          'metadata': {'onboarding_completed': true},
        }).eq('user_id', user.id);
      } catch (_) {}

      if (mounted) {
        setState(() => _onboardingDone = true);
        // 4ページ目（スタートガイド）へ
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('就任手続きに失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerLow, // 高級感のあるオフホワイト
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildPhilosophyPage(),
                  _buildBoardMemberPage(),
                  _buildContractPage(),
                  _buildFirstStepsPage(),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  // 1. 経営理念ページ
  Widget _buildPhilosophyPage() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.business_center, size: 80, color: Colors.indigo),
          const SizedBox(height: 32),
          Text(
            'あなたの人生を\n「経営」する',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '本日より「自分株式会社」が設立されました。\n\n資本は、あなたの「時間」「資産」「健康」。\n目的は、これらを最大化し、\n豊かな人生（利益）を生み出すことです。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  // 2. 経営体制（役員紹介）ページ
  Widget _buildBoardMemberPage() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '最強の経営布陣',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'GPT・Claude・Geminiを統合したMAGIシステムが、\nあなたの専属役員として\n24時間365日、経営をサポートします。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _buildRoleIcon(Icons.psychology, 'CSO', '戦略', Colors.blueGrey),
              _buildRoleIcon(Icons.attach_money, 'CFO', '財務', Colors.teal),
              _buildRoleIcon(
                Icons.health_and_safety,
                'CHO',
                '健康',
                Colors.teal.shade800,
              ),
              _buildRoleIcon(Icons.diversity_3, 'CHRO', '人事', Colors.pink),
              _buildRoleIcon(Icons.campaign, 'CMO', '広報', Colors.purple),
              _buildRoleIcon(Icons.school, 'CKO', '知財', Colors.indigo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleIcon(IconData icon, String role, String label, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 4),
        Text(role, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // 3. 就任承諾（署名）ページ
  Widget _buildContractPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu,
              size: 60, color: Theme.of(context).colorScheme.onSurface,),
          const SizedBox(height: 24),
          const Text(
            '代表取締役 就任承諾書',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Serif',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '私（下記署名人）は、自分株式会社の代表取締役（CEO）に就任し、以下のミッションを遂行することを誓います。',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              border: Border.all(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. 昨日の自分より成長すること'),
                SizedBox(height: 8),
                Text('2. 不要なもの（負債）を断捨離すること'),
                SizedBox(height: 8),
                Text('3. 心身の健康（資本）を維持すること'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '氏名（CEO名）を入力',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'この名前はAI役員からの報告書に使用されます',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // 4. スタートガイドページ（就任完了後に表示）
  Widget _buildFirstStepsPage() {
    final steps = [
      (
        Icons.wb_sunny,
        Colors.amber,
        'モーニングブリーフィング',
        '今日の最優先タスクをAIが提案します。\nホーム画面「CEO OFFICE」→「モーニングブリーフィング」'
      ),
      (
        Icons.edit_note,
        Colors.blue,
        '最初のメモを書く',
        '考えていることを何でも書いてみてください。\nホーム画面「CMO/CKO OFFICE」→「新規事業起案」'
      ),
      (
        Icons.upload_file,
        Colors.teal,
        'Notionから移行する',
        '既存のデータをそのままインポートできます。\nホーム画面「GROWTH / 成長導線」→「インポート」'
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.rocket_launch, size: 64, color: Colors.indigo),
          const SizedBox(height: 20),
          const Text(
            '就任おめでとうございます！',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'まずこの3つから始めましょう',
            style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,),
          ),
          const SizedBox(height: 28),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final (icon, color, title, desc) = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 15, color: color),
                            const SizedBox(width: 4),
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed('/home'),
              icon: const Icon(Icons.business_center),
              label: const Text(
                '経営コックピットへ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    // 4ページ目（スタートガイド）はボタンをページ内に持つため非表示
    if (_onboardingDone) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // インジケーター（3ページ分のみ）
          Row(
            children: List.generate(3, (index) {
              return Container(
                margin: const EdgeInsets.only(right: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Colors.indigo
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              );
            }),
          ),
          // ボタン
          if (_currentPage < 2)
            ElevatedButton(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('次へ'),
            )
          else
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _finishOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.verified_user),
              label: const Text('就任を承諾して開始'),
            ),
        ],
      ),
    );
  }
}
