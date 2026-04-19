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
import '../widgets/growth_trend_card.dart';
import '../widgets/home_back_button.dart';
import '../widgets/leaderboard_card.dart';
import '../widgets/note_search_card.dart';
import '../widgets/growth_roadmap_progress_card.dart';
import '../widgets/profile_progress_card.dart';
import '../widgets/quick_task_input_card.dart';
import '../widgets/referral_share_card.dart';
import '../widgets/social_proof_banner.dart';

class HomeInsightsPage extends StatelessWidget {
  const HomeInsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成長・支援ダッシュボード'),
        // Windows版#94: 戻るボタンで URL も '/' に更新する (リロード時に元ページに戻らない)
        leading: const HomeBackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildHeroCard(context),
          const SizedBox(height: 20),
          const _SectionHeader(
            title: 'AIアシスト',
            subtitle: '検索、入力、思考補助のカードをまとめています。',
            icon: Icons.auto_awesome,
            color: Color(0xFF3D5AFE),
          ),
          const SizedBox(height: 10),
          const NoteSearchCard(),
          const SizedBox(height: 8),
          const QuickTaskInputCard(),
          const SizedBox(height: 8),
          const GoalDecomposerCard(),
          const SizedBox(height: 8),
          const ProfileProgressCard(),
          const SizedBox(height: 16),
          _buildLinkBanner(
            context,
            title: 'ユーザーマニュアル',
            subtitle: '迷ったときの機能一覧と操作手順を確認する',
            icon: Icons.menu_book_outlined,
            color: const Color(0xFF6366F1),
            routeName: '/user-manual',
          ),
          const SizedBox(height: 20),
          const _SectionHeader(
            title: '成長シグナル',
            subtitle: '発信、紹介、競合比較、開発実績を確認します。',
            icon: Icons.rocket_launch,
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          const GrowthTrendCard(),
          const SizedBox(height: 8),
          const NotionFeatureComparisonCard(),
          const SizedBox(height: 8),
          const SocialProofBanner(),
          const SizedBox(height: 8),
          const ReferralShareCard(),
          const SizedBox(height: 8),
          const BuildInPublicShareCard(),
          const SizedBox(height: 8),
          const DevelopmentAchievementsCard(),
          const SizedBox(height: 8),
          const BlogPostSummaryCard(),
          const SizedBox(height: 8),
          const EdgeFunctionSummaryCard(),
          const SizedBox(height: 20),
          const _SectionHeader(
            title: '継続とモチベーション',
            subtitle: '日々の継続、可視化、報酬のカードを並べています。',
            icon: Icons.favorite_outline,
            color: Color(0xFFFF6B35),
          ),
          const SizedBox(height: 10),
          const ActivityCalendarCard(),
          const SizedBox(height: 8),
          const DailyHabitsSummaryCard(),
          const SizedBox(height: 8),
          const LeaderboardCard(),
          const SizedBox(height: 8),
          const DailyMotivationCard(),
          const SizedBox(height: 8),
          const DailyChallengeCard(),
          const SizedBox(height: 16),
          _buildLinkBanner(
            context,
            title: 'アクティビティフィード',
            subtitle: '最近の行動や更新の流れを確認する',
            icon: Icons.dynamic_feed_outlined,
            color: const Color(0xFF3D5AFE),
            routeName: '/activity-feed',
          ),
          const SizedBox(height: 8),
          _buildLinkBanner(
            context,
            title: '報酬・実績バッジ',
            subtitle: '積み上げた報酬とバッジを振り返る',
            icon: Icons.emoji_events_outlined,
            color: const Color(0xFFFFC107),
            routeName: '/rewards',
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ホームから退避した補助カードをここにまとめました。',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '今日の優先順位を邪魔せずに、発信・紹介・継続・支援系の情報へまとめてアクセスできます。',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          children: [
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
                children: [
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
      children: [
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
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
