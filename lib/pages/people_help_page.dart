import 'package:flutter/material.dart';

import 'note_editor_page.dart';
import 'note_list_page.dart';
import 'rewards_page.dart';
import 'stats_page.dart';

class PeopleHelpPage extends StatelessWidget {
  final Widget? onboardingNotePage;

  const PeopleHelpPage({
    super.key,
    this.onboardingNotePage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('people_help_page_scaffold'),
      appBar: AppBar(
        title: const Text(
          'People Help',
          key: Key('people_help_page_title'),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 16),
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context,
            tileKey: const Key('people_help_quick_notes'),
            title: 'Support notes',
            subtitle: '既存のオンボーディング・サポートメモを確認する。',
            icon: Icons.sticky_note_2_outlined,
            color: Colors.blue,
            page: const NoteListPage(),
          ),
          _buildActionCard(
            context,
            tileKey: const Key('people_help_quick_onboarding'),
            title: 'Create onboarding memo',
            subtitle: '初日対応のメモをすぐ作成する。',
            icon: Icons.edit_note,
            color: Colors.indigo,
            page: onboardingNotePage ??
                const NoteEditorPage(
                  initialTitle: 'オンボーディングメモ',
                  initialContent:
                      '目的:\n- \n\n初日チェック:\n- アカウント発行\n- 必須ルール共有\n\n1週間以内:\n- 役割確認\n- 次回1on1予約\n',
                ),
          ),
          _buildActionCard(
            context,
            tileKey: const Key('people_help_quick_rewards'),
            title: 'Rewards',
            subtitle: '報酬・インセンティブの見える化を確認する。',
            icon: Icons.card_giftcard,
            color: Colors.amber.shade800,
            page: const RewardsPage(),
          ),
          _buildActionCard(
            context,
            tileKey: const Key('people_help_quick_stats'),
            title: 'Stats',
            subtitle: '人事系メトリクスを開いて詰まりを特定する。',
            icon: Icons.bar_chart,
            color: Colors.teal,
            page: const StatsPage(),
          ),
          const SizedBox(height: 24),
          _buildChecklistSection(
            title: '運用チェックリスト',
            icon: Icons.checklist,
            color: Colors.indigo,
            items: const [
              '新規参加者には初日タスクを 3 件以内に絞る。',
              '1on1 の次回日時を終了前に固定する。',
              '支援メモは個人依存にせず、必ずノートへ残す。',
            ],
          ),
          const SizedBox(height: 16),
          _buildChecklistSection(
            title: '次に見る指標',
            icon: Icons.insights,
            color: Colors.deepPurple,
            items: const [
              'オンボーディング完了率',
              '初週の離脱・未着手件数',
              '報酬確認後の実行率',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      key: const Key('people_help_hero_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.people_alt_outlined, color: Colors.indigo),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'CHRO 実務を止めないための最短導線',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'オンボーディング、支援メモ、報酬確認、指標確認を 1 画面にまとめ、'
            'People Help の未実装状態を解消しました。',
            style: TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required Key tileKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget page,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        key: tileKey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        ),
      ),
    );
  }

  Widget _buildChecklistSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(height: 1.5),
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
}
