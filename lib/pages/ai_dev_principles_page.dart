import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/platform_view.dart' as platform_view;

/// AI 開発 7 原則ページ (Rule 23)
///
/// docs/AI_DEV_PRINCIPLES.md の 7 原則を可視化し、NotebookLM 動画 5 本を埋め込む。
/// PHILOSOPHY (Rule 22 = what/why) と並列で本原則 (Rule 23 = how) は AI 機能の
/// 実装方法を規定する。両方クリアした機能のみ実装可。
class AiDevPrinciplesPage extends StatefulWidget {
  const AiDevPrinciplesPage({super.key});

  @override
  State<AiDevPrinciplesPage> createState() => _AiDevPrinciplesPageState();
}

class _AiDevPrinciplesPageState extends State<AiDevPrinciplesPage> {
  int _selectedVideoIdx = 1; // default = A 完全版
  int _selectedDevLessonIdx = 1; // default = A 字幕付き完全版 (開発教訓シリーズ #1)
  int _selectedDevLesson2Idx = 1; // default = A (開発教訓シリーズ #2)

  @override
  void initState() {
    super.initState();
    for (final v in _videos) {
      platform_view.registerIframeViewFactory(
        'aidev-youtube-${v.id}',
        'https://www.youtube.com/embed/${v.id}',
      );
    }
    for (final v in _devLessonsVideos) {
      platform_view.registerIframeViewFactory(
        'aidev-devlesson-${v.id}',
        'https://www.youtube.com/embed/${v.id}',
      );
    }
    for (final v in _devLessonsVideos2) {
      platform_view.registerIframeViewFactory(
        'aidev-devlesson2-${v.id}',
        'https://www.youtube.com/embed/${v.id}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _videos[_selectedVideoIdx];
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'AI 開発 7 原則 — 自分株式会社',
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroHeader(),
                  const SizedBox(height: 32),
                  _videoSelector(),
                  const SizedBox(height: 16),
                  _videoEmbed(video),
                  const SizedBox(height: 12),
                  _videoMeta(video),
                  const SizedBox(height: 48),
                  _sevenPrinciplesSection(),
                  const SizedBox(height: 48),
                  _existingFeaturesSection(),
                  const SizedBox(height: 48),
                  _devLessonsSection(),
                  const SizedBox(height: 48),
                  _devLessons2Section(),
                  const SizedBox(height: 48),
                  _checklistSection(),
                  const SizedBox(height: 48),
                  _ctaSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
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
          colors: [Color(0xFF1A1A1A), Color(0xFF0A1F1F)],
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
              color: const Color(0xFF26A69A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'AI 開発 7 原則',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFAFAFA),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Perils of Invisible Defaults',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF26A69A),
              letterSpacing: 0.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'AI ツールで開発スピードが圧倒的に上がる一方、'
            '目に見えない欠陥 (API キー上書き / ハルシネーションループ /\n'
            '自動投稿スパム化 等) が大代償を生む。\n'
            '強力な監視・制御・記憶の組み合わせで AI 開発を安全に高速化する 7 つの必守原則。',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFFCBD5E1),
              height: 1.8,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x33FF6B35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '⚠️ PHILOSOPHY 9 原則 (Rule 22 = what/why) と本 7 原則 (Rule 23 = how) '
              '両方クリアした機能のみ実装可',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFFF8C5A),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Video selector ───────────────────────────────────────────────
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
              selectedColor: const Color(0xFF26A69A),
              backgroundColor: const Color(0xFF2A2A2A),
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFFCBD5E1),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                height: 1.5,
              ),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF26A69A)
                    : const Color(0xFF444444),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _videoEmbed(_Video v) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: HtmlElementView(viewType: 'aidev-youtube-${v.id}'),
      ),
    );
  }

  Widget _videoMeta(_Video v) {
    return Row(
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
            Uri.parse('https://youtu.be/${v.id}'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('YouTube で見る'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF26A69A),
          ),
        ),
      ],
    );
  }

  // ─── 7 原則 ───────────────────────────────────────────────────────
  Widget _sevenPrinciplesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, color: const Color(0xFF26A69A)),
            const SizedBox(width: 12),
            const Text(
              'AI 開発 7 原則',
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
          '全 AI 機能・改修はこの 7 原則に照らして実装方法を必ず確認します。',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.7),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final cols = isWide ? 2 : 1;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _principles.map((p) {
                final cardW = (constraints.maxWidth - (cols - 1) * 16) / cols;
                return SizedBox(
                  width: cardW,
                  child: _principleCard(p),
                );
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
                  color: const Color(0x3326A69A),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${p.number}',
                  style: const TextStyle(
                    color: Color(0xFF26A69A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFAFAFA),
                        height: 1.4,
                      ),
                    ),
                    Text(
                      p.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7986CB),
                        height: 1.4,
                      ),
                    ),
                  ],
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x1AFF6B35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '違反例: ${p.violationExample}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFFF8C5A),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 既存機能スコア表 ─────────────────────────────────────────────
  Widget _existingFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, color: const Color(0xFF7986CB)),
            const SizedBox(width: 12),
            const Text(
              '既存機能の 7 原則スコア',
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
          '本サービスの既存 AI 機能を 7 原則で評価。低スコア機能は要至急改善。',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.7),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF333333), width: 1),
          ),
          child: Column(
            children: _features.map((f) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        f.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFAFAFA),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: f.score >= 6
                            ? const Color(0x334ADE80)
                            : f.score >= 4
                                ? const Color(0x33FACC15)
                                : const Color(0x33F97316),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${f.score}/7',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: f.score >= 6
                              ? const Color(0xFF4ADE80)
                              : f.score >= 4
                                  ? const Color(0xFFFACC15)
                                  : const Color(0xFFF97316),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Text(
                        f.improvement,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── チェックリスト ───────────────────────────────────────────────
  Widget _checklistSection() {
    const checklistMd = '''
新 AI 機能設計時に必ず以下を確認:

- [ ] **原則 1 (Auth)**: API キー source of truth は明確か?
- [ ] **原則 2 (Deny-default)**: 認証・rate limit・サイズ制限は最初から組み込んだか?
- [ ] **原則 3 (Observability)**: trace_id + 5秒超検出は入っているか?
- [ ] **原則 4 (Circuit breaker)**: 4 段階のコスト上限を設定したか?
- [ ] **原則 5 (Memory)**: 成功・失敗パターンを memory に記録するか?
- [ ] **原則 6 (Checkpoint)**: 長時間処理は再開可能か? dead letter queue ある?
- [ ] **原則 7 (Quality gate)**: 自動出力に Sentinel/Warden を通すか?

**判定基準**:

- 6+ ✅ → 即実装可
- 4-5 ✅ → 設計再考
- 3 以下 ✅ → 実装見送り or 大幅再設計
''';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, color: const Color(0xFFFF6B35)),
            const SizedBox(width: 12),
            const Text(
              '実装前チェックリスト',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFAFAFA),
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF333333), width: 1),
          ),
          child: MarkdownBody(
            data: checklistMd,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontSize: 14,
                color: Color(0xFFCBD5E1),
                height: 1.9,
              ),
              listBullet: const TextStyle(
                color: Color(0xFFCBD5E1),
                height: 1.5,
              ),
              strong: const TextStyle(
                color: Color(0xFFFAFAFA),
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── CTA ──────────────────────────────────────────────────────────
  // ─── 開発教訓動画シリーズ (Win版#125-127 自動生成) ─────────────
  Widget _devLessonsSection() {
    final video = _devLessonsVideos[_selectedDevLessonIdx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x33FF6B35),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '📺 開発教訓動画シリーズ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF8C5A),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'カオスから教義へ：高速開発の教訓',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFAFAFA),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'NotebookLM Master Brain (Win版 100+ セッションの蓄積) から自動生成された動画。'
          '混沌としていた開発プロセスから自己改善するパターンへ進化した過程を AI が解説。 '
          '5 variant (原版 + 字幕付き4パターン) を埋め込み。',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFCBD5E1),
            height: 1.8,
          ),
        ),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_devLessonsVideos.length, (i) {
              final v = _devLessonsVideos[i];
              final selected = i == _selectedDevLessonIdx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${v.label}  •  ${v.duration}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedDevLessonIdx = i),
                  selectedColor: const Color(0xFFFF6B35),
                  backgroundColor: const Color(0xFF2A2A2A),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFCBD5E1),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: HtmlElementView(viewType: 'aidev-devlesson-${video.id}'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                video.description,
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
                Uri.parse('https://youtu.be/${video.id}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('YouTube で見る'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF6B35),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 開発教訓動画シリーズ #2 (Win版#129 自動生成) ─────────────
  Widget _devLessons2Section() {
    final video = _devLessonsVideos2[_selectedDevLesson2Idx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x33EC4899),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '📺 開発教訓動画シリーズ #2',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF472B6),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '欠陥の修正：コメントがコードを変えた',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFAFAFA),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'NotebookLM Master Brain から自動生成された動画 #2。 '
          'ある欠陥を修正する過程で AI コメントがコードそのものを変えた瞬間を深掘り解説。'
          '5 variant (原版 + 字幕付き4パターン) を埋め込み。',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFCBD5E1),
            height: 1.8,
          ),
        ),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_devLessonsVideos2.length, (i) {
              final v = _devLessonsVideos2[i];
              final selected = i == _selectedDevLesson2Idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${v.label}  •  ${v.duration}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedDevLesson2Idx = i),
                  selectedColor: const Color(0xFFEC4899),
                  backgroundColor: const Color(0xFF2A2A2A),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFCBD5E1),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFFEC4899)
                        : const Color(0xFF444444),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: HtmlElementView(viewType: 'aidev-devlesson2-${video.id}'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                video.description,
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
                Uri.parse('https://youtu.be/${video.id}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('YouTube で見る'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEC4899),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _ctaSection() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF26A69A), Color(0xFF00897B)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'AI を強力な味方にする実装規律',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '基本理念 (what/why) と AI 開発 7 原則 (how) を両立した安全な高速化を',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white, height: 1.7),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed('/philosophy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF00695C),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '基本理念 9 原則を見る',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'サービスを試す',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// データ
// ─────────────────────────────────────────────────────────────────────

class _Video {
  final String id;
  final String label;
  final String duration;
  final String description;
  const _Video({
    required this.id,
    required this.label,
    required this.duration,
    required this.description,
  });
}

const _videos = [
  _Video(
    id: 'UuANU6UoMCs',
    label: '編集前 (NotebookLM 原版)',
    duration: '6:30',
    description: 'NotebookLM の Video Overview 機能のみで生成した完全 AI 動画。字幕無し。',
  ),
  _Video(
    id: 'ftxG_dPyq4E',
    label: 'A: 完全版 (字幕付き)',
    duration: '6:30',
    description: '日本語字幕焼き込み・全 130 字幕エントリ。LP 埋め込み・最忠実版。',
  ),
  _Video(
    id: 'ResUPNjwzVA',
    label: 'B: 3 分ハイライト',
    duration: '3:27',
    description: '序章 + 中盤 2 セクション + 締めの要点版。字幕付き。',
  ),
  _Video(
    id: 'HBUBKanjK4k',
    label: 'C: 60 秒 SNS 版',
    duration: '1:00',
    description: 'Cost Circuit Breaker (4段階上限) 編。SNS シェア用。',
  ),
  _Video(
    id: 'PCtlJKpYPJc',
    label: 'D: プレミアム版',
    duration: '6:37',
    description: 'intro/outro カード + カラーグレード + 字幕。公式映像・ピッチ用途。',
  ),
];

/// 開発教訓動画シリーズ「カオスから教義へ：高速開発の教訓」
/// (Win版#125 追加・NotebookLM jibun-master-brain artifact dedb6b24)
const _devLessonsVideos = [
  _Video(
    id: 'hU477Zds9kQ',
    label: '編集前 (NotebookLM 原版)',
    duration: '7:01',
    description: 'NotebookLM Master Brain の蓄積 (Win版 100+ セッション) から自動生成された動画。'
        '混沌としていた開発プロセスから自己改善するパターンへ進化した過程を解説。字幕無し。',
  ),
  _Video(
    id: 'Dmx51fPeE6A',
    label: 'A: 完全版 (字幕付き)',
    duration: '7:01',
    description: '日本語字幕焼き込み・全 169 字幕エントリ。LP 埋め込み・最忠実版。',
  ),
  _Video(
    id: 'bVytf2lbxjQ',
    label: 'B: warm cinematic',
    duration: '7:01',
    description:
        '暖色グレード (brightness -3% / contrast +10% / saturation -15%) + 字幕。映画調。',
  ),
  _Video(
    id: 'mwTOsWb-OpM',
    label: 'C: neutral punch',
    duration: '7:01',
    description: 'クリアグレード (contrast +15% / saturation +5%) + 字幕。プレゼン向け視認性最大化。',
  ),
  _Video(
    id: 'AVd00T92YHE',
    label: 'D: プレミアム字幕版',
    duration: '7:01',
    description: '太字 22pt + 半透明黒背景 + Outline=3。SNS シェア・スマホ視聴用。',
  ),
];

/// 開発教訓動画シリーズ #2「欠陥の修正：コメントがコードを変えた」
/// (Win版#129 追加・NotebookLM Per-Business Scoring artifact 1bded015)
const _devLessonsVideos2 = [
  _Video(
    id: 'nsBoA0Z0BNk',
    label: '編集前 (NotebookLM 原版)',
    duration: '10:40',
    description:
        'NotebookLM Master Brain (Per-Business Scoring) から自動生成された動画 #2。'
        'ある欠陥を修正する過程で AI コメントがコードそのものを変えた瞬間を深掘り。字幕無し。',
  ),
  _Video(
    id: 'OJgmkQVnO70',
    label: 'A: 完全版 (字幕付き)',
    duration: '10:40',
    description: '日本語字幕焼き込み・全 275 字幕エントリ。LP 埋め込み・最忠実版。',
  ),
  _Video(
    id: 'XulNKygolcQ',
    label: 'B: warm cinematic',
    duration: '10:40',
    description:
        '暖色グレード (brightness -3% / contrast +10% / saturation -15%) + 字幕。映画調。',
  ),
  _Video(
    id: '9hjJOx6ZLoY',
    label: 'C: neutral punch',
    duration: '10:40',
    description: 'クリアグレード (contrast +15% / saturation +5%) + 字幕。プレゼン向け視認性最大化。',
  ),
  _Video(
    id: 'pbw9rIOB9X0',
    label: 'D: プレミアム字幕版',
    duration: '10:40',
    description: '太字 22pt + 半透明黒背景 + Outline=3。SNS シェア・スマホ視聴用。',
  ),
];

class _Principle {
  final int number;
  final String title;
  final String subtitle;
  final String summary;
  final String violationExample;
  const _Principle({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.violationExample,
  });
}

const _principles = [
  _Principle(
    number: 1,
    title: 'Auth Layer Discipline',
    subtitle: '認証情報の source of truth 単一化',
    summary: 'API キー・認証情報は単一の信頼できる source of truth で管理し、'
        '古い値が新しい設定を黙って上書きしないようにする。',
    violationExample: '古い .env が新しい Supabase Secrets を上書き → 数時間ロス',
  ),
  _Principle(
    number: 2,
    title: 'Deny-by-default Security',
    subtitle: 'リリース前から堅牢に',
    summary: 'MVP 段階から「明示的に許可されない限り全てブロック」のミドルウェアを組み込む。'
        '後付けセキュリティは禁止。',
    violationExample: 'パストラバーサル放置 → 初日にサーバ制御を奪われる',
  ),
  _Principle(
    number: 3,
    title: 'Trace-based Observability',
    subtitle: 'trace_id で完全可視化',
    summary: '全 HTTP リクエストに trace_id を付与し、各エージェント呼び出しを span として記録。'
        '5 秒超検出を必須化。',
    violationExample: '可観測性なし → ボトルネック特定が「当て推量」化',
  ),
  _Principle(
    number: 4,
    title: 'Cost Circuit Breaker',
    subtitle: '4 段階上限で予算暴走防止',
    summary: 'リクエスト/エージェント/ビジネス/プラットフォーム の 4 段階上限値を設定し、'
        '超過時自動遮断する non-negotiable 機能。',
    violationExample: 'ハルシネーションループで月予算を数分で消費',
  ),
  _Principle(
    number: 5,
    title: 'Team Memory + Effectiveness Score',
    subtitle: '蓄積 → 減衰 → 自動注入',
    summary: '成功・失敗・最適化パターンを蓄積。各記憶に有効性スコア (0.0〜1.0) を付与し、'
        '低スコアは減衰、高スコアは自動注入。',
    violationExample: 'memory なし → 毎セッション同じミスを繰り返す',
  ),
  _Principle(
    number: 6,
    title: 'Checkpoint + Retry + Dead Letter Queue',
    subtitle: '中間状態保存 + 再試行ポリシー',
    summary: 'エージェント連鎖の各ステップで状態保存。can_resume: true で失敗箇所から再開。'
        '全失敗時の DLQ 整備。',
    violationExample: '長時間ジョブ途中失敗 → 全消滅 → 時間とコスト浪費',
  ),
  _Principle(
    number: 7,
    title: 'Quality Gate (Sentinel + Warden)',
    subtitle: '自動出力前に事実確認 + 品質確認',
    summary: '自動投稿・メール送信などの前段に必ず Sentinel (事実確認) + Warden (品質確認) '
        'の関所を設ける。',
    violationExample: 'Qiita 自己連投ループ (本サービス Win#98 で修正)',
  ),
];

class _Feature {
  final String name;
  final int score;
  final String improvement;
  const _Feature({
    required this.name,
    required this.score,
    required this.improvement,
  });
}

const _features = [
  _Feature(
    name: 'ai-assistant (3-柱)',
    score: 5,
    improvement: 'obs / memory / gate 強化候補',
  ),
  _Feature(
    name: 'blog-engagement',
    score: 5,
    improvement: 'Win#98 で Quality Gate 強化済',
  ),
  _Feature(
    name: 'ai-hub provider.chat',
    score: 4,
    improvement: 'circuit / memory / gate',
  ),
  _Feature(
    name: 'cs-check',
    score: 4,
    improvement: 'circuit / retry',
  ),
  _Feature(
    name: 'competitor-monitoring',
    score: 3,
    improvement: '🔴 要至急: circuit + retry + memory',
  ),
  _Feature(
    name: 'blog-publish',
    score: 2,
    improvement: '🔴 要至急: gate + circuit + memory',
  ),
];
