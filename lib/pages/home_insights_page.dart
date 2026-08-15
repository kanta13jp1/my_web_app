import 'package:flutter/material.dart';

import '../widgets/activity_calendar_card.dart';
import '../widgets/blog_post_summary_card.dart';
import '../widgets/build_in_public_share_card.dart';
import '../widgets/daily_challenge_card.dart';
import '../widgets/daily_habits_summary_card.dart';
import '../widgets/daily_motivation_card.dart';
import '../widgets/development_achievements_card.dart';
import '../widgets/edge_function_summary_card.dart';
import '../widgets/goal_decomposer_card.dart';
import '../widgets/growth_roadmap_progress_card.dart';
import '../widgets/growth_trend_card.dart';
import '../widgets/home_back_button.dart';
import '../widgets/leaderboard_card.dart';
import '../widgets/note_search_card.dart';
import '../widgets/profile_progress_card.dart';
import '../widgets/quick_task_input_card.dart';
import '../widgets/referral_share_card.dart';
import '../widgets/social_proof_banner.dart';

class HomeInsightsPage extends StatelessWidget {
  const HomeInsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<WidgetBuilder> sections = _buildSections();
    return Scaffold(
      appBar: AppBar(
        title: const Text('成長・支援ダッシュボード'),
        // Windows版#94: 戻るボタンで URL も '/' に更新する (リロード時に元ページに戻らない)
        leading: const HomeBackButton(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: sections.length,
        itemBuilder: (BuildContext context, int index) =>
            sections[index](context),
      ),
    );
  }

  List<WidgetBuilder> _buildSections() {
    return <WidgetBuilder>[
      _buildHeroCard,
      (_) => const SizedBox(height: 20),
      (_) => const _SectionHeader(
            title: 'AI アシスト',
            subtitle: '検索、整理、分解、プロフィール改善のカードをまとめて確認できます。',
            icon: Icons.auto_awesome,
            color: Color(0xFF3D5AFE),
          ),
      (_) => const SizedBox(height: 10),
      (_) => const NoteSearchCard(),
      (_) => const SizedBox(height: 8),
      (_) => const QuickTaskInputCard(),
      (_) => const SizedBox(height: 8),
      (_) => const GoalDecomposerCard(),
      (_) => const SizedBox(height: 8),
      (_) => const ProfileProgressCard(),
      (_) => const SizedBox(height: 16),
      (BuildContext context) => _buildLinkBanner(
            context,
            title: 'ユーザーマニュアル',
            subtitle: '実装済み機能の操作手順と導線をここから確認できます。',
            icon: Icons.menu_book_outlined,
            color: const Color(0xFF6366F1),
            routeName: '/user-manual',
          ),
      (_) => const SizedBox(height: 20),
      (_) => const _SectionHeader(
            title: '成長シグナル',
            subtitle: '登録、比較、共有、開発実績まわりのカードを遅延描画で軽く表示します。',
            icon: Icons.rocket_launch,
            color: Color(0xFF4CAF50),
          ),
      (_) => const SizedBox(height: 10),
      (_) => const GrowthTrendCard(),
      (_) => const SizedBox(height: 8),
      (_) => const NotionFeatureComparisonCard(),
      (_) => const SizedBox(height: 8),
      (_) => const SocialProofBanner(),
      (_) => const SizedBox(height: 8),
      (_) => const ReferralShareCard(),
      (_) => const SizedBox(height: 8),
      (_) => const BuildInPublicShareCard(),
      (_) => const SizedBox(height: 8),
      (_) => const DevelopmentAchievementsCard(),
      (_) => const SizedBox(height: 8),
      (_) => const BlogPostSummaryCard(),
      (_) => const SizedBox(height: 8),
      (_) => const EdgeFunctionSummaryCard(),
      (_) => const SizedBox(height: 20),
      (_) => const _SectionHeader(
            title: '習慣とモチベーション',
            subtitle: '日々の活動、連続記録、励ましのカードを必要になった順で描画します。',
            icon: Icons.favorite_outline,
            color: Color(0xFFFF6B35),
          ),
      (_) => const SizedBox(height: 10),
      (_) => const ActivityCalendarCard(),
      (_) => const SizedBox(height: 8),
      (_) => const DailyHabitsSummaryCard(),
      (_) => const SizedBox(height: 8),
      (_) => const LeaderboardCard(),
      (_) => const SizedBox(height: 8),
      (_) => const DailyMotivationCard(),
      (_) => const SizedBox(height: 8),
      (_) => const DailyChallengeCard(),
      (_) => const SizedBox(height: 16),
      (BuildContext context) => _buildLinkBanner(
            context,
            title: 'アクティビティフィード',
            subtitle: '最近の更新や追加の流れをまとめて確認できます。',
            icon: Icons.dynamic_feed_outlined,
            color: const Color(0xFF3D5AFE),
            routeName: '/activity-feed',
          ),
      (_) => const SizedBox(height: 8),
      (BuildContext context) => _buildLinkBanner(
            context,
            title: '成果・実績バッジ',
            subtitle: '積み上げた成果とバッジの状態を確認できます。',
            icon: Icons.emoji_events_outlined,
            color: const Color(0xFFFFC107),
            routeName: '/rewards',
          ),
    ];
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0F172A), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'ホームから到達できる主要カードをここでまとめて確認できます。',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '初期表示で全部を同時に起動せず、必要なカードから順に描画する構成です。',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkBanner(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String routeName,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).pushNamed(routeName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2233) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
