import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/platform_view.dart' as platform_view;
import '../utils/route_document_title.dart';

/// 自分株式会社 — 基本理念ページ
///
/// docs/PHILOSOPHY.md の 9 原則を可視化し、NotebookLM 動画 8 本を埋め込む。
/// 全機能はこのページに記載された理念に照らして方向性を検証する (CLAUDE.md Rule 22)。
class PhilosophyPage extends StatefulWidget {
  const PhilosophyPage({super.key});

  @override
  State<PhilosophyPage> createState() => _PhilosophyPageState();
}

class _PhilosophyPageState extends State<PhilosophyPage> {
  int _selectedVideoIdx = 1; // default = A 完全版

  @override
  void initState() {
    super.initState();
    for (final v in _videos) {
      final src = v.mp4Url ?? 'https://www.youtube.com/embed/${v.id}';
      platform_view.registerIframeViewFactory('youtube-${v.id}', src);
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _videos[_selectedVideoIdx];
    return Title(
      key: const Key('philosophy_document_title'),
      title: philosophyDocumentTitle,
      color: const Color(0xFF7986CB),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            '基本理念 — 自分株式会社',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 18,
              height: 1.5,
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFFE5E7EB)),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroHeader(),
                    const SizedBox(height: 32),
                    _operatingGuideSection(),
                    const SizedBox(height: 48),
                    _inventoryExampleSection(),
                    const SizedBox(height: 48),
                    _editorialPolicySection(),
                    const SizedBox(height: 48),
                    _videoSelector(),
                    const SizedBox(height: 16),
                    _videoEmbed(video),
                    const SizedBox(height: 12),
                    _videoMeta(video),
                    const SizedBox(height: 48),
                    _ninePrinciplesSection(),
                    const SizedBox(height: 48),
                    _transcriptSection(),
                    const SizedBox(height: 48),
                    _ctaSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 実践ガイド ───────────────────────────────────────────────────
  Widget _operatingGuideSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideHeading('自分株式会社を30日で運営する実践ガイド'),
        const SizedBox(height: 8),
        const Text(
          '自分株式会社は法人設立の話ではありません。自分をCEOと捉え、'
          '時間・お金・健康・スキルを経営資源として配分する自己経営のフレームワークです。',
          style: TextStyle(fontSize: 14, color: Color(0xFFCBD5E1), height: 1.8),
        ),
        const SizedBox(height: 24),
        const Text(
          '個人の P/L・B/S',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFAFAFA),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '金額だけでなく、時間・集中力・健康・信用まで含めて、短期の成果と長期の価値を分けて見ます。',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.7),
        ),
        const SizedBox(height: 16),
        _guideGrid(_businessGuideMetrics, wideColumns: 4),
        const SizedBox(height: 32),
        const Text(
          '人生を6部署に分けて点検する',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFAFAFA),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '問題を一つの尺度で判断せず、役割ごとに分けると、次にどこへ資源を配分するか決めやすくなります。',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.7),
        ),
        const SizedBox(height: 16),
        _guideGrid(_operatingDepartments, wideColumns: 3),
        const SizedBox(height: 32),
        const Text(
          '30日の運営サイクル',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFAFAFA),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '人生計画を一度で完成させず、観察・判断・実行・振り返りを短い周期で繰り返します。',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.7),
        ),
        const SizedBox(height: 16),
        _guideGrid(_operatingCycle, wideColumns: 4),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0x1A7986CB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x667986CB)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AIはCEOの代わりではなく伴走役',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFAFAFA),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'AIは状況を整理し、理由と選択肢を示します。どの提案を採用し、'
                '何を実行するかを決めるのは常にあなたです。迷う時間を減らし、'
                '生活へ戻れることを重視します。',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guideHeading(String title) {
    return Row(
      children: [
        Container(width: 4, height: 24, color: const Color(0xFF4DB6AC)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFAFAFA),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _guideGrid(List<_GuideItem> items, {required int wideColumns}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? wideColumns : 1;
        final cardWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.icon, size: 20, color: item.color),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFAFAFA),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFCBD5E1),
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  // ─── 記入例 ────────────────────────────────────────────────────────
  Widget _inventoryExampleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideHeading('3分でできる棚卸しの記入例'),
        const SizedBox(height: 8),
        const Text(
          '以下は、仕事に追われて学習時間を確保できない会社員を想定した架空の例です。'
          '実在する利用者の体験談や成果ではありません。',
          style: TextStyle(fontSize: 14, color: Color(0xFFCBD5E1), height: 1.8),
        ),
        const SizedBox(height: 16),
        _guideGrid(_inventoryExample, wideColumns: 3),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0x1A4DB6AC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x664DB6AC)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'この例で選ぶ「今月の1件」',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFAFAFA),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '最優先課題は「睡眠不足で学習が続かない」。最初の行動は、'
                '今夜23時にスマートフォンを充電場所へ置くこと。成果指標は、'
                '学習時間の長さではなく、翌朝の体調と週2回着手できたかで確認します。',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          '架空ケース：30日でどう見直すか',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFAFAFA),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '目標を達成した物語ではなく、判断を小さく更新する手順の例です。結果を保証するものではありません。',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.7),
        ),
        const SizedBox(height: 16),
        _guideGrid(_thirtyDayExample, wideColumns: 4),
      ],
    );
  }

  // ─── 編集方針 ──────────────────────────────────────────────────────
  Widget _editorialPolicySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'このページの編集方針',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFAFAFA),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '自分株式会社の考え方を、日々の意思決定に使える独自の運用ガイドとして整理しています。'
            '記入例はすべて説明用の架空例です。医療・法律・投資など専門判断の代わりにはならず、'
            '必要な場合は各分野の専門家へ相談してください。最終更新: 2026年8月23日',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFCBD5E1),
              height: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed('/development-achievements'),
                icon: const Icon(Icons.history, size: 16),
                label: const Text('開発実績と更新履歴'),
              ),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://github.com/kanta13jp1'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('GitHub @kanta13jp1'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/privacy'),
                icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                label: const Text('データの取り扱い'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Hero ──────────────────────────────────────────────────────────
  Widget _heroHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF0F0F1F)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '自分株式会社',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFAFAFA),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The Enterprise of Self',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF7986CB),
              letterSpacing: 0.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'あなたの人生を、あなただけの会社として経営する。\n'
            'ユーザーは自分の人生という会社の唯一の株主・社長 (CEO)。\n'
            '自分株式会社はその経営をサポートするフレームワーク・道具です。',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFFCBD5E1),
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Video selector tabs ───────────────────────────────────────────
  Widget _videoSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_videos.length, (i) {
          final v = _videos[i];
          final selected = i == _selectedVideoIdx;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${v.label}  •  ${v.duration}'),
              selected: selected,
              onSelected: (_) => setState(() => _selectedVideoIdx = i),
              selectedColor: const Color(0xFFFF6B35),
              backgroundColor: const Color(0xFF2A2A2A),
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFFCBD5E1),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                height: 1.5,
              ),
              side: BorderSide(
                color: selected
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF444444),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _videoEmbed(_Video v) {
    if (!kIsWeb) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Color(0xFF111827),
          child: Center(
            child: Text(
              '動画はWeb版で視聴できます',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: HtmlElementView(viewType: 'youtube-${v.id}'),
      ),
    );
  }

  Widget _videoMeta(_Video v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                v.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  height: 1.7,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(v.mp4Url ?? 'https://youtu.be/${v.id}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(v.mp4Url != null ? 'MP4 で見る' : 'YouTube で見る'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF6B35),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'AI で生成された動画',
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, size: 12, color: Color(0xFF94A3B8)),
              SizedBox(width: 4),
              Text(
                'AI 生成',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 9 原則 ───────────────────────────────────────────────────────
  Widget _ninePrinciplesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, color: const Color(0xFFFF6B35)),
            const SizedBox(width: 12),
            const Text(
              '基本理念 9 原則',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFAFAFA),
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '全機能・改修はこの 9 原則に照らして方向性が一致しているか必ず確認します。',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.7),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final cols = isWide ? 3 : 1;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _principles.map((p) {
                final cardW = (constraints.maxWidth - (cols - 1) * 16) / cols;
                return SizedBox(width: cardW, child: _principleCard(p));
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _principleCard(_Principle p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0x33FF6B35),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${p.number}',
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFAFAFA),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.summary,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFCBD5E1),
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 完全文字起こし (8章) ─────────────────────────────────────────
  Widget _transcriptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, color: const Color(0xFF7986CB)),
            const SizedBox(width: 12),
            const Text(
              '完全文字起こし',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFAFAFA),
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '動画ナレーションを 8 章に整理。各章をタップで展開。',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.7),
        ),
        const SizedBox(height: 24),
        ..._chapters.map((c) => _chapterTile(c)),
      ],
    );
  }

  Widget _chapterTile(_Chapter c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          unselectedWidgetColor: const Color(0xFF94A3B8),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          collapsedIconColor: const Color(0xFF7986CB),
          iconColor: const Color(0xFF7986CB),
          title: Text(
            c.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFAFAFA),
              height: 1.5,
            ),
          ),
          subtitle: Text(
            c.timestamp,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7986CB),
              height: 1.5,
            ),
          ),
          children: [
            MarkdownBody(
              data: c.body,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFCBD5E1),
                  height: 2.0,
                ),
                h3: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFAFAFA),
                  height: 1.6,
                ),
                blockquote: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFFF6B35),
                  fontStyle: FontStyle.italic,
                  height: 1.8,
                ),
                blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                blockquoteDecoration: const BoxDecoration(
                  color: Color(0x1AFF6B35),
                  border: Border(
                    left: BorderSide(color: Color(0xFFFF6B35), width: 3),
                  ),
                ),
                listBullet: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  height: 1.5,
                ),
                tableHead: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFAFAFA),
                  height: 1.5,
                ),
                tableBody: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  height: 1.5,
                ),
                tableBorder: TableBorder.all(color: const Color(0xFF444444)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CTA ──────────────────────────────────────────────────────────
  Widget _ctaSection() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFCC4A1A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'あなたも、CEO になろう',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '自分株式会社で、あなたの人生のミッション・KPI・バランスシートを可視化',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white, height: 1.7),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFCC4A1A),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'サービスを試す',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// データ
// ─────────────────────────────────────────────────────────────────────

class _GuideItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _GuideItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const _businessGuideMetrics = [
  _GuideItem(
    title: '売上',
    description: '給与だけでなく、仕事・学習・発信で相手へ届けた価値。',
    icon: Icons.trending_up,
    color: Color(0xFF66BB6A),
  ),
  _GuideItem(
    title: '経費',
    description: 'お金に加えて、使った時間・集中力・回復力。',
    icon: Icons.timer_outlined,
    color: Color(0xFFFFB74D),
  ),
  _GuideItem(
    title: '資産',
    description: 'スキル・健康・信用・人間関係・再利用できる知識。',
    icon: Icons.account_balance_outlined,
    color: Color(0xFF4DB6AC),
  ),
  _GuideItem(
    title: '利益',
    description: '次の選択に使える、お金・時間・心の余白。',
    icon: Icons.spa_outlined,
    color: Color(0xFF7986CB),
  ),
];

const _operatingDepartments = [
  _GuideItem(
    title: '本社',
    description: 'ミッション、目標、優先順位を決める。',
    icon: Icons.apartment_outlined,
    color: Color(0xFFFF6B35),
  ),
  _GuideItem(
    title: '人事',
    description: '健康、睡眠、休養、習慣を整える。',
    icon: Icons.favorite_outline,
    color: Color(0xFFEF5350),
  ),
  _GuideItem(
    title: 'R&D',
    description: '学習、実験、スキル開発を進める。',
    icon: Icons.science_outlined,
    color: Color(0xFF42A5F5),
  ),
  _GuideItem(
    title: '財務',
    description: '収入、支出、資産、負債を把握する。',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF66BB6A),
  ),
  _GuideItem(
    title: 'マーケ営業',
    description: '価値を伝え、人との接点を育てる。',
    icon: Icons.campaign_outlined,
    color: Color(0xFFAB47BC),
  ),
  _GuideItem(
    title: '横断',
    description: 'AIや自動化で部署間の情報を整理する。',
    icon: Icons.hub_outlined,
    color: Color(0xFF26A69A),
  ),
];

const _operatingCycle = [
  _GuideItem(
    title: '1週目 観察',
    description: '時間・お金・体調・未完了タスクを記録する。',
    icon: Icons.visibility_outlined,
    color: Color(0xFF42A5F5),
  ),
  _GuideItem(
    title: '2週目 判断',
    description: 'ミッションに照らして最優先課題を一つ選ぶ。',
    icon: Icons.rule_outlined,
    color: Color(0xFFFFB74D),
  ),
  _GuideItem(
    title: '3週目 実行',
    description: '48時間以内に始められる最小の一手へ分解する。',
    icon: Icons.play_arrow_outlined,
    color: Color(0xFF66BB6A),
  ),
  _GuideItem(
    title: '4週目 振り返り',
    description: '昨日の自分からの変化を確認し、翌月の配分を決める。',
    icon: Icons.replay_outlined,
    color: Color(0xFF7986CB),
  ),
];

const _inventoryExample = [
  _GuideItem(
    title: '本社｜今月の方針',
    description: '残業を増やさず、週2回だけ学習を始められる状態をつくる。',
    icon: Icons.flag_outlined,
    color: Color(0xFFFF6B35),
  ),
  _GuideItem(
    title: '人事｜土台',
    description: '平均睡眠6時間。まず23時以降のスマートフォン利用を減らす。',
    icon: Icons.bedtime_outlined,
    color: Color(0xFFEF5350),
  ),
  _GuideItem(
    title: 'R&D｜学習',
    description: '教材を増やさず、購入済み講座を火曜と土曜に20分だけ進める。',
    icon: Icons.school_outlined,
    color: Color(0xFF42A5F5),
  ),
  _GuideItem(
    title: '財務｜固定費',
    description: '未利用のサブスクを1件確認し、続ける理由がなければ停止する。',
    icon: Icons.receipt_long_outlined,
    color: Color(0xFF66BB6A),
  ),
  _GuideItem(
    title: 'マーケ営業｜価値',
    description: '学んだことを業務改善メモ1枚にし、同僚へ共有する。',
    icon: Icons.record_voice_over_outlined,
    color: Color(0xFFAB47BC),
  ),
  _GuideItem(
    title: '横断｜振り返り',
    description: 'AIに週次ログを要約させ、採用する次の行動は自分で決める。',
    icon: Icons.auto_awesome_outlined,
    color: Color(0xFF26A69A),
  ),
];

const _thirtyDayExample = [
  _GuideItem(
    title: '1週目｜事実を集める',
    description: '就寝時刻、残業、学習を始められた日だけを記録する。',
    icon: Icons.edit_note_outlined,
    color: Color(0xFF42A5F5),
  ),
  _GuideItem(
    title: '2週目｜一つに絞る',
    description: '教材不足ではなく睡眠不足を、今月の最優先課題にする。',
    icon: Icons.filter_1_outlined,
    color: Color(0xFFFFB74D),
  ),
  _GuideItem(
    title: '3週目｜小さく試す',
    description: '就寝前の置き場所を変え、火曜に20分だけ教材を開く。',
    icon: Icons.science_outlined,
    color: Color(0xFF66BB6A),
  ),
  _GuideItem(
    title: '4週目｜配分を直す',
    description: '体調と着手回数を確認し、続ける行動を一つだけ残す。',
    icon: Icons.tune_outlined,
    color: Color(0xFF7986CB),
  ),
];

class _Video {
  final String id;
  final String label;
  final String duration;
  final String description;

  /// 自前ホスト MP4 URL (= YouTube アップロード前の暫定動画).
  /// 設定時は YouTube iframe ではなく `<iframe src=mp4Url>` で直再生する.
  /// YouTube アップロード完了後 `id` を実 YouTube ID に書き換えて null 戻し.
  final String? mp4Url;

  const _Video({
    required this.id,
    required this.label,
    required this.duration,
    required this.description,
    this.mp4Url,
  });
}

const _videos = [
  _Video(
    id: '2l1WOajHEPE',
    label: '編集前 (NotebookLM 原版)',
    duration: '6:42',
    description: 'NotebookLM の Video Overview 機能のみで生成した完全 AI 動画。字幕無し。',
  ),
  _Video(
    id: 'kSxe5fKRkAQ',
    label: 'A: 完全版 (字幕付き)',
    duration: '6:42',
    description: '日本語字幕焼き込み・ASR 誤り修正済み。LP 埋め込み・最忠実版。',
  ),
  _Video(
    id: 'giaX9ogVY3M',
    label: 'B: 3 分ハイライト',
    duration: '4:23',
    description: '要点 (CEO・3 STEP・バランスシート・IPO) のみに絞った短縮版。',
  ),
  _Video(
    id: '5cO9AmLOcyA',
    label: 'C: 60 秒 SNS 版',
    duration: '1:11',
    description: 'バランスシート編 (資産 vs 負債) のみ。SNS シェア用。',
  ),
  _Video(
    id: 'mqz7ZJzM2n0',
    label: 'D: プレミアム版',
    duration: '6:49',
    description: 'intro/outro カード + カラーグレード + 字幕。公式映像・ピッチ用途。',
  ),
  _Video(
    id: 'Zclp_zK9cYM',
    label: '番外: AnthropicのClaude Apps 解説 (D variant)',
    duration: '7:10',
    description: 'NotebookLM Deep Research + intro/outro + カラーグレード + 字幕焼き込み。'
        'Anthropic Claude Apps の MCP オープン化戦略・市場シェア 18→29%・3500億ドル評価・'
        'ChatGPT との設計思想の違いを 7 分で解説。AI大学シリーズ #1。',
  ),
  _Video(
    id: 'di5SbHouAVY',
    label: '番外: Google Gemini で暮らしを整える 8 つのコツ (D variant)',
    duration: '6:27',
    description: 'NotebookLM Deep Research + intro/outro + カラーグレード + 字幕焼き込み。'
        'Google Gemini の agentic AI で Gmail / Google Calendar / Photos / Lens / Keep を横断する'
        '実践テクニック 8 つを解説。AI大学シリーズ #2。',
  ),
  _Video(
    id: 'shdsy9qqcNM',
    label: '番外: Nomic Platform — 建設・設計業界特化 AI (D variant)',
    duration: '8:17',
    description: 'NotebookLM Deep Research + intro/outro + カラーグレード + 字幕焼き込み。'
        'Nomic Platform (Nomic AEC) — 建築 / エンジニアリング / 建設 業界向け Domain-Specific AI。'
        '3000 ページ規模の RFI / RFP / 仕様書を AI で横断検索・分析。BIM / Revit / Procore 統合。'
        'AI大学シリーズ #3。',
  ),
  _Video(
    id: 'multi-agent-convergence',
    mp4Url: '/assets/videos/multi-agent-convergence.mp4',
    label: '番外: 2026年AIのパラダイムシフト — Multi-Agent Convergence (暫定MP4)',
    duration: '9:19',
    description:
        'NotebookLM Video Overview 原版 (= 720p H.264 圧縮 / 12MB / 暫定 self-host)。'
        '2026 AI Agent Blueprint + 多エージェント収束トレンド + 思考コスト 97% 減のインパクト。'
        'YouTube アップロードは GHA secrets (GITHUB_PAT / YOUTUBE_*) 設定後に実施予定 → 完了後 id を YouTube ID に置換。'
        'AI大学シリーズ #4。',
  ),
];

class _Principle {
  final int number;
  final String title;
  final String summary;
  const _Principle({
    required this.number,
    required this.title,
    required this.summary,
  });
}

const _principles = [
  _Principle(
    number: 1,
    title: 'ユーザーは自分の人生の CEO',
    summary: '機能はユーザーが「自分でコントロールできる」感覚を強化する方向に作る。'
        '自動化・AI 提案は最終決定権をユーザーに残す。',
  ),
  _Principle(
    number: 2,
    title: 'ミッション・コアバリュー駆動',
    summary: '機能はユーザーが自分のミッション・価値観を明確化・追跡できる助けになる。'
        'ノート・タスク・目標機能はミッションとの繋がりを可視化する。',
  ),
  _Principle(
    number: 3,
    title: '取締役会 = 信頼できる伴走者',
    summary: 'AI / 通知 / コーチングは優しい mentor であって、監視・命令する存在ではない。'
        '罪悪感を与える表現は使わない。',
  ),
  _Principle(
    number: 4,
    title: '6 部署バランス (人事最優先)',
    summary: '新機能は R&D / 財務 / マーケ営業 / 人事 / 本社 の 5 部署のどれに貢献するか分類する。'
        '人事 (健康) は最優先。',
  ),
  _Principle(
    number: 5,
    title: '商品 = ユーザー自身の価値',
    summary: '機能はユーザーの価値を高める・可視化する方向に作る。'
        '時間消費・無限スクロール風の機能は避ける。',
  ),
  _Principle(
    number: 6,
    title: '資本 = 時間',
    summary: '機能は時間の使い方を可視化・配分を最適化する。操作時間を最小化し、'
        '使い終わって後悔させない。',
  ),
  _Principle(
    number: 7,
    title: 'バランスシート (資産 vs 負債)',
    summary: '機能は資産を増やす・負債を減らすのどちらかに位置づく。'
        '悪い習慣・否定的思考の可視化機能も価値がある。',
  ),
  _Principle(
    number: 8,
    title: 'KPI = 昨日の自分',
    summary: '比較対象は他人ではなく過去の自分。ランキングでも自己進捗を主軸にし、'
        '他人比較は副次的に。',
  ),
  _Principle(
    number: 9,
    title: 'ゴール = IPO / ウェルビーイング',
    summary: '短期 KPI (DAU・滞在時間) より長期ウェルビーイング指標を最優先。'
        '使う時間を減らして幸福感を高める設計を喜ぶ。',
  ),
];

class _Chapter {
  final String title;
  final String timestamp;
  final String body;
  const _Chapter({
    required this.title,
    required this.timestamp,
    required this.body,
  });
}

const _chapters = [
  _Chapter(
    title: '序章 — 自分株式会社という考え方',
    timestamp: '00:00 - 01:06',
    body: '''
どうも。今日はですね、ちょっと面白い考え方を紹介したいんですよ。自分の人生をガラッと違う角度から見てみるっていう。

**自分株式会社**って言うんですけど、これかなりパワフルな考え方なんで、早速一緒に見ていきましょう。

で、いきなりなんですけど、ちょっと想像してみてください。

もし、あなたの人生が、一つの会社だったら... どうしますか？

そう、あなたのキャリアとか、健康、友達との関係、新しいことの勉強、ぜーんぶが、あなたっていうたった一つの会社がやってる事業だとしたらね。面白くないですか？

はい、それこそがまさにこの**自分株式会社のキモ**なんですよね。自分の人生を、自分だけの会社に見立てちゃう。で、その会社のたった一人の株主で、しかも社長、つまり**CEO は、他の誰でもないあなた自身**。

もちろんね、本当に会社作るわけじゃないですよ。これは、自分の人生のいろんなことを、もっと自分でコントロールして、成長させていこうぜ、っていう、そういうための、まあ考え方の道具、**フレームワーク**ってやつですね。
''',
  ),
  _Chapter(
    title: '第1章 — 鏡の中の CEO',
    timestamp: '01:06 - 01:46',
    body: '''
じゃあまず、最初のめちゃくちゃ大事なポイントからいきましょうか。この考え方における、あなたの役割です。そう、鏡の中にいる CEO、まあもちろん、あなた自身のことなんですけどね。

**そう、あなたが CEO なんです。**

あなたの人生っていう会社の、すべての決定権はあなたが握ってる。そして、その責任も全部、あなたが引き受ける。

この、自分がオーナーなんだっていう感覚、これがね、すべての変化のスタート地点になるわけです。
''',
  ),
  _Chapter(
    title: '第2章 — CEO 就任 3 STEP',
    timestamp: '01:46 - 02:33',
    body: '''
じゃあ、CEO になったとして、まず最初に何をやればいいのかってことですよね。

会社だったらまず、うちの会社はこれをやるぞっていうのを決めますよね。

### STEP 1: ミッションを決める
それがステップワン。**あなたの人生のミッションを決めること。** まあ、会社の経営理念みたいなもんですね。自分は結局何がしたいんだっけ？っていう、道に迷わないための目印です。

### STEP 2: コアバリューを決める
ステップツーは、**会社のコアバリューを決めること。** これは、何かを選ぶときに、自分はこれを大事にするんだったって立ち返れる、自分だけのルールみたいなものです。

### STEP 3: 取締役会を置く
ステップスリー、**取締役会、つまり相談役を置くこと。** あなたのことを本気で考えてくれて、時にはそれ違うんじゃないって言ってくれるような、信頼できるメンターとか友達。そういう人たちを、あなたの会社の役員に任命するんです。
''',
  ),
  _Chapter(
    title: '第3章 — 会社運営 (4部署マッピング)',
    timestamp: '02:33 - 03:10',
    body: '''
社長としての心構えができたら、次は会社の具体的な運営の話です。つまり、いろんな部署をどうやって回していくかってことですね。

ここ、僕すごく面白いと思うんですけど、**会社の部署って、僕たちの人生のいろんな活動に、びっくりするくらい当てはまる**んですよ。

| 部署 | 人生の活動 |
| --- | --- |
| 研究開発部 (R&D) | 新しいことを学んだり、スキルを身につけたりする自己投資 |
| 財務部 | お給料の管理とか、将来のための貯金 |
| マーケティング営業部 | 自分の良さをアピールしたり、人と繋がったりすること |
| 人事部 | あなた自身の心と体の健康管理 |

そして意外と忘れがちだけど、**一番大事かもしれないのが人事部**。これは会社のたった一人の社員、つまりあなた自身の心と体の健康管理です。

いや、ほんと**ここがダメになったら、全部の部署が機能停止しちゃいます**からね。
''',
  ),
  _Chapter(
    title: '第4章 — 商品 = あなた自身の価値',
    timestamp: '03:10 - 03:34',
    body: '''
じゃあ、あなたの会社が売る商品って何だと思いますか？

それは、他の誰でもない、**あなた自身が持ってる価値、そのもの**なんです。

- あなたが持ってるスキル
- これまでの経験
- 勉強してきた知識
- あとはあなただけのキャラクターとか、アイデア

それぜーんぶが、あなたの会社の、他のどこにもない、めちゃくちゃ強力な**商品リスト**になるんですよ。
''',
  ),
  _Chapter(
    title: '第5章 — 資本 = 時間',
    timestamp: '03:34 - 04:02',
    body: '''
会社をやるにはお金、つまり資本が要りますけど、自分株式会社にとっての一番大事な資本って何だと思いますか？

そう、**時間**なんです。

時間をどういうふうに投資してるかっていうポートフォリオの一例:

- 仕事に 40%
- 勉強とかに 25%
- 健康とか友達付き合いに 20%

さて、あなた自身の時間の使い方って、今、どうなってますか? あなたの円グラフはどんな形をしてるでしょうね。
''',
  ),
  _Chapter(
    title: '第6章 — バランスシート (資産 vs 負債)',
    timestamp: '04:02 - 05:19',
    body: '''
さあ、ここからは会社の**健康診断**の話です。単に仕事がうまくいってるだけじゃなくて、もっと広い視点で、あなたの会社の本当の価値をどうやって測るか、見ていきましょう。

これ、めちゃくちゃ大事なポイントなんですけど、**ゴールは、目先の利益、例えばお給料がちょっと上がったとか、そういうことだけじゃない**んです。

本当に目指すべきは、**長く続く成長と、心からの幸福感、つまりウェルビーイング**ですよね。良い会社も良い人生も、結局はそこがゴールだと思うんですよ。

これが自分株式会社の、まあ会社の財産目録みたいなもんですね。**バランスシート**ってやつです。

### 資産 (左側) — プラスの要素
- スキル
- 健康な体
- 良い友達

### 負債 (右側) — マイナスの要素
- 借金みたいな分かりやすいもの
- ついつい夜更かししちゃうみたいな悪い癖
- 自分なんてダメだみたいな考え方の癖
- 気づかないうちにあなたのエネルギーを吸い取っていくもの

会社の経営って、結局は**資産を増やして、負債を減らす、この繰り返し**。人生も意外とシンプルに考えられると思いませんか?
''',
  ),
  _Chapter(
    title: '第7章 — KPI (昨日の自分との比較)',
    timestamp: '05:19 - 05:49',
    body: '''
普通の会社と一緒で、自分株式会社の成長だって、ちゃんと数字で測れるんですよ。それが、**KPI**っていうやつです。

例えば:

- このスキルが前よりできるようになった
- 健康診断の結果がよくなった
- 新しい友達ができた

ここで一番大事なのは、**自分だけの目標を立てること**。誰かと比べる必要なんて全然ないんです。

> **比べる相手はいつだって、昨日の自分。それだけでいいんです。**
''',
  ),
  _Chapter(
    title: '第8章 — 最終ゴール = IPO',
    timestamp: '05:49 - 06:42',
    body: '''
じゃあ、この会社の最終的なゴールって何なのか。

それはズバリ、**IPO を成功させること**です。

IPO って、普通は会社が株を公開することですけど、ここでの意味は、もっと深いです。つまり:

- 自分の人生がすごく充実してて
- ちゃんと自分でコントロールできてて
- こういう人生を送るぞっていう意図を持って生きてる状態
- 自分の価値を最高まで高めて、それを周りの人や社会のために使えてる

いやー、これ最高のゴールじゃないですか?

さて、話は以上です。**あなたの会社は、もう今この瞬間から、営業開始です。**
''',
  ),
];
