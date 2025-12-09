import 'package:flutter/material.dart';
import '../main.dart';
import '../models/user_stats.dart';
import '../services/gamification_service.dart';
import '../widgets/page_view_stats.dart';
import '../utils/app_logger.dart';

// UserStats モデルやその他の依存関係は変更なしとして扱います。

class EnhancedStatisticsPage extends StatefulWidget {
  const EnhancedStatisticsPage({super.key});

  @override
  State<EnhancedStatisticsPage> createState() => _EnhancedStatisticsPageState();
}

class _EnhancedStatisticsPageState extends State<EnhancedStatisticsPage> {
  late final GamificationService _gamificationService;
  UserStats? _userStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _gamificationService = GamificationService(supabase);
    _loadUserStats();
    // 隠しページボーナス演出（1回のみ実行される想定だが、今回は演出として毎回表示）
    _giveVisitBonus();
  }

// ボーナス付与メソッド（演出と記録）
  Future<void> _giveVisitBonus() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // ✅ 修正後のユーザー名取得ロジック
    // emailの@より前の部分を取得し、それがnullまたは空の場合は '匿名ユーザー' を使用
    final emailPrefix = supabase.auth.currentUser?.email?.split('@').first;

    // ユーザー名が取得できた場合はそれを使用し、そうでない場合は '匿名ユーザー' を使用
    final userName = (emailPrefix != null && emailPrefix.isNotEmpty)
        ? emailPrefix
        : '匿名ユーザー';

    try {
      // ✅ description には、整形済みの文言を渡す (userName はすでに適切な値)
      final description = '$userName が統計・実績ページを訪問しました';

      await _gamificationService.recordActivity(
        userId: userId,
        type: 'stats_page_visit',
        description: description,
        timestamp: DateTime.now().toUtc(),
      );

      // Bonus UI (SnackBar) の表示
      if (mounted) {
        // 少し遅延させて表示し、ユーザーに気づかせる
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.celebration, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('隠しページ発見ボーナス！ 経験値を獲得しました✨')),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: '確認',
              textColor: Colors.white,
              onPressed: _loadUserStats, // ステータス更新（再読み込み）
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error recording activity or giving bonus', error: e);
      // RLSやDBエラーの場合、ボーナス表示は行わず、静かに失敗させる
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      var stats = await _gamificationService.getUserStats(userId);
      stats ??= await _gamificationService.initializeUserStats(userId);

      if (mounted) {
        setState(() {
          _userStats = stats;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error loading stats', error: e, stackTrace: stackTrace);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // 背景色を白に変更し、よりクリーンな印象に
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
            const Text('統計・実績', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        // elevation を 4 に設定し、AppBarにわずかな影をつける
        elevation: 4,
        backgroundColor: Colors.white, // AppBarの背景色を白に
        foregroundColor: Colors.black87,
        shadowColor: Colors.black.withOpacity(0.1), // 影の色を薄く設定
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0), // 垂直方向のパディングを増やして、上部のスペースを確保
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. レベル・経験値カード
                  if (_userStats != null) _buildLevelHeader(theme, _userStats!),

                  const SizedBox(height: 32), // スペースを広げる

                  // 来訪感謝メッセージ (下に移動して、メインコンテンツとの区切りをつける)
                  _buildWelcomeMessage(),

                  const SizedBox(height: 32),

                  // 2. 今日のミッション (訪問者数カウンター)
                  _buildSectionHeader(
                    title: '🔥 今日のミッション',
                    subtitle: 'このページへの訪問者数に応じてボーナス獲得！',
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: const PageViewStats(pagePath: '/statistics'),
                    ),
                  ),

                  const SizedBox(height: 32), // スペースを広げる

                  // 3. 詳細統計グリッド
                  _buildSectionHeader(
                    title: '📊 活動データ',
                    subtitle: 'これまでの活動のサマリーです。', // サブタイトルを追加
                  ),
                  const SizedBox(height: 16),
                  if (_userStats != null) _buildStatsGrid(_userStats!),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // セクションヘッダーを共通化
  Widget _buildSectionHeader({required String title, String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20, // フォントサイズを少し大きく
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 14, color: Colors.grey), // フォントサイズを調整
            ),
          ),
      ],
    );
  }

  // 来訪感謝メッセージを独立したウィジェットに
  Widget _buildWelcomeMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightBlue.withOpacity(0.05), // 色を青系に変更し、より清潔感のあるデザインに
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightBlue.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.lightBlue[800], size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎉 ここを見つけたあなたはレアユーザー！',
                  style: TextStyle(
                    color: Colors.lightBlue[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '訪問者数もカウントされています。素敵な発見です✨',
                  style: TextStyle(
                    color: Colors.lightBlue[700],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelHeader(ThemeData theme, UserStats stats) {
    const int pointsPerLevel = 1000;
    final int currentLevelBasePoints = stats.currentLevel * pointsPerLevel;
    final int progressPoints = stats.totalPoints - currentLevelBasePoints;
    final double progress = (progressPoints / pointsPerLevel).clamp(0.0, 1.0);

    // Primary Colorを基調としたグラデーションを保持
    final levelColor = theme.primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            levelColor,
            levelColor.withOpacity(0.8), // 標準的な withOpacity を使用
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: levelColor.withOpacity(0.4), // シャドウの濃さを上げる
            blurRadius: 16, // シャドウをより広げる
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '現在のレベル',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // 修正
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${stats.currentLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 60, // 大きく強調
                          fontWeight: FontWeight.w900, // さらに太く
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LEVEL',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18, // サイズを調整
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // アイコンを少し調整
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events,
                    color: Colors.white, size: 40), // アイコンサイズも大きく
              ),
            ],
          ),
          const SizedBox(height: 32), // スペースを広げる
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '次のレベルまで',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 14),
                  ),
                  Text(
                    '${progressPoints} / ${pointsPerLevel} XP', // XP表記を追加
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10, // プログレスバーの高さを上げる
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(UserStats stats) {
    // 画面幅に基づいてクロス軸の数を決定
    // 画面幅が広い場合は3列、狭い場合は2列など、レスポンシブに対応可能
    // 今回は ConstrainedBox を使用し、最大幅を考慮したグリッドに
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4, // 統計項目の数
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // モバイルでは2列に固定
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2, // アスペクト比を少し狭くし、カードの高さを調整
      ),
      itemBuilder: (context, index) {
        // データリストを作成して itemBuilder で使用
        final data = [
          {
            'icon': Icons.note_alt,
            'color': Colors.blue,
            'label': '作成したメモ',
            'value': '${stats.notesCreated}',
          },
          {
            'icon': Icons.local_fire_department,
            'color': Colors.red, // 連続記録なので赤に変更
            'label': '連続記録',
            'value': '${stats.currentStreak}日',
          },
          {
            'icon': Icons.star, // アイコンを星に変更
            'color': Colors.purple, // 色を紫に変更
            'label': '総ポイント',
            'value': '${stats.totalPoints}',
          },
          {
            'icon': Icons.share,
            'color': Colors.green,
            'label': 'シェア回数',
            'value': '未実装', // 仮の値 (Check! より具体的に)
          },
        ];

        final item = data[index];
        return _buildStatCard(
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          label: item['label'] as String,
          value: item['value'] as String,
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)), // 非常に薄いボーダーを追加
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // シャドウを少し濃く
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10), // パディングを増やし、アイコンを少し大きく
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24), // アイコンサイズを大きく
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28, // 値を大きく強調
                  fontWeight: FontWeight.w900,
                  color: Colors.black, // 濃い色に
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700], // 濃い目のグレーに
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
