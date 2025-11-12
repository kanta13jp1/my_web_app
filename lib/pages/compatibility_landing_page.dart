import 'package:flutter/material.dart';
import '../services/personality_test_service.dart';
import '../models/personality_test.dart';
import 'compatibility_check_page.dart';

/// 恋愛相性診断のランディングページ
class CompatibilityLandingPage extends StatefulWidget {
  const CompatibilityLandingPage({Key? key}) : super(key: key);

  @override
  State<CompatibilityLandingPage> createState() =>
      _CompatibilityLandingPageState();
}

class _CompatibilityLandingPageState extends State<CompatibilityLandingPage> {
  final PersonalityTestService _testService = PersonalityTestService();
  PersonalityTest? _userTest;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPersonalityType();
  }

  Future<void> _loadUserPersonalityType() async {
    try {
      final test = await _testService.getLatestTestResult();
      setState(() {
        _userTest = test;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('性格タイプの取得に失敗しました')),
        );
      }
    }
  }

  void _startCompatibilityCheck() {
    if (_userTest?.personalityType == null) {
      // 性格診断が未実施の場合、診断ページに誘導
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('性格診断が必要です'),
          content: const Text(
              'まず、あなたの性格タイプを診断してください。性格診断は約5分で完了します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/personality-test');
              },
              child: const Text('診断を始める'),
            ),
          ],
        ),
      );
      return;
    }

    // 相性診断ページに進む
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompatibilityCheckPage(
          myType: _userTest!.personalityType!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('恋愛相性診断'),
        backgroundColor: Colors.pink.shade100,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ヘッダーセクション
                    _buildHeader(),
                    const SizedBox(height: 32),

                    // あなたのタイプ表示
                    if (_userTest?.personalityType != null) ...[
                      _buildYourTypeCard(),
                      const SizedBox(height: 32),
                    ],

                    // 機能説明
                    _buildFeaturesList(),
                    const SizedBox(height: 32),

                    // CTAボタン
                    _buildCTAButton(),
                    const SizedBox(height: 24),

                    // 補足情報
                    _buildFooterNote(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.pink.shade100,
            Colors.purple.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite,
            size: 64,
            color: Colors.pink.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            '💘 恋愛相性診断',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.pink.shade900,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'MBTIの性格タイプから\n2人の恋愛相性を診断します',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.pink.shade800,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildYourTypeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'あなたの性格タイプ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Text(
                    _userTest?.personalityType ?? '',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                          letterSpacing: 2,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '（${_getPersonalityTypeName(_userTest?.personalityType ?? '')}）',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPersonalityTypeName(String code) {
    final types = PersonalityTestService.personalityTypes;
    final type = types.firstWhere(
      (t) => t.code == code,
      orElse: () => types[0],
    );
    return type.nameJa;
  }

  Widget _buildFeaturesList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'この診断でわかること',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              icon: Icons.favorite_border,
              title: '相性スコア',
              description: '0〜100点で2人の相性を数値化',
              color: Colors.pink,
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.star_border,
              title: '関係性の強み',
              description: 'お二人の関係で活かせる長所',
              color: Colors.amber,
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.psychology_outlined,
              title: '乗り越えるべき課題',
              description: '注意すべきポイントと対処法',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.tips_and_updates_outlined,
              title: '関係を深めるヒント',
              description: '2人の絆を強めるためのアドバイス',
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required MaterialColor color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color.shade700, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCTAButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _startCompatibilityCheck,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink.shade400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, size: 24),
            const SizedBox(width: 8),
            Text(
              '相性診断を始める',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                'ご注意',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'この診断は、MBTIの性格タイプに基づいた一般的な相性の傾向を示すものです。'
            '実際の人間関係は個人の経験や価値観など、多くの要素によって形成されます。'
            '診断結果は参考程度にとどめ、相手との関係を大切に育んでください。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
