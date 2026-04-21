import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _progressKeyPrefix = 'onboarding_progress_page';

  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _onboardingDone = false; // 就任承諾完了フラグ（4ページ目表示制御）

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreSavedProgress());
    });
  }

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

      await _clearSavedProgress();

      if (mounted) {
        setState(() => _onboardingDone = true);
        // 4ページ目（スタートガイド）へ
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('就任手続きが完了しました。経営コックピットへ案内します…')),
        );
        // 自動でホームへ遷移（短い遅延）
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/home');
        });
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

  Future<String> _progressKey() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return _progressKeyPrefix;
    return '${_progressKeyPrefix}_$userId';
  }

  Future<void> _restoreSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPage = prefs.getInt(await _progressKey());
    if (!mounted || savedPage == null) return;

    final page = savedPage.clamp(0, 2);
    if (page == _currentPage) return;

    setState(() => _currentPage = page);
    _pageController.jumpToPage(page);
  }

  Future<void> _saveProgress(int page) async {
    if (page < 0 || page > 2) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(await _progressKey(), page);
  }

  Future<void> _clearSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _progressKey());
  }

  void _goToPreviousPage() {
    if (_currentPage <= 0 || _isLoading) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToNextPage() {
    if (_currentPage >= 2 || _isLoading) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  unawaited(_saveProgress(index));
                },
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
          const Icon(
            Icons.business_center,
            size: 80,
            color: Color(0xFF3D5AFE),
          ),
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
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'GPT・Claude・Geminiを統合したMAGIシステムが、\nあなたの専属役員として\n24時間365日、経営をサポートします。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _buildRoleIcon(
                Icons.psychology,
                'CSO',
                '戦略',
                const Color(0xFF607D8B),
              ),
              _buildRoleIcon(
                Icons.attach_money,
                'CFO',
                '財務',
                const Color(0xFF009688),
              ),
              _buildRoleIcon(
                Icons.health_and_safety,
                'CHO',
                '健康',
                const Color(0xFF00695C),
              ),
              _buildRoleIcon(
                Icons.diversity_3,
                'CHRO',
                '人事',
                const Color(0xFFFF6B35),
              ),
              _buildRoleIcon(
                Icons.campaign,
                'CMO',
                '広報',
                const Color(0xFF3D5AFE),
              ),
              _buildRoleIcon(
                Icons.school,
                'CKO',
                '知財',
                const Color(0xFF3D5AFE),
              ),
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
        Text(
          role,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.5,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
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
          Icon(
            Icons.history_edu,
            size: 60,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(height: 24),
          const Text(
            '代表取締役 就任承諾書',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Serif',
              height: 1.5,
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
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
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
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
        const Color(0xFFFFC107),
        'モーニングブリーフィング',
        '今日の最優先タスクをAIが提案します。\nホーム画面「CEO OFFICE」→「モーニングブリーフィング」'
      ),
      (
        Icons.edit_note,
        const Color(0xFF3D5AFE),
        '最初のメモを書く',
        '考えていることを何でも書いてみてください。\nホーム画面「CMO/CKO OFFICE」→「新規事業起案」'
      ),
      (
        Icons.upload_file,
        const Color(0xFF009688),
        'Notionから移行する',
        '既存のデータをそのままインポートできます。\nホーム画面「GROWTH / 成長導線」→「インポート」'
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.rocket_launch,
            size: 64,
            color: Color(0xFF3D5AFE),
          ),
          const SizedBox(height: 20),
          const Text(
            '就任おめでとうございます！',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'まずこの3つから始めましょう',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
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
                          height: 1.5,
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
                                height: 1.5,
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
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
                      ? const Color(0xFF3D5AFE)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              );
            }),
          ),
          // ボタン
          Row(
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: _isLoading ? null : _goToPreviousPage,
                  child: const Text('戻る'),
                ),
              const SizedBox(width: 8),
              if (_currentPage < 2)
                ElevatedButton(
                  onPressed: _isLoading ? null : _goToNextPage,
                  child: const Text('次へ'),
                )
              else
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _finishOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5AFE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
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
        ],
      ),
    );
  }
}
