import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/satirical_print_library.dart';
import '../models/campaign_video.dart';
import '../theme/design_tokens.dart';

/// Wikimedia Commons のファイル名から実画像 URL を組み立てる。
/// Special:FilePath は最終的な upload URL へリダイレクトするため、ハッシュ
/// パスを知らなくてもファイル名だけで参照できる。取得失敗時は動画フレーム側で
/// グラデーションにフォールバックする。
String _commonsImageUrl(String file) =>
    'https://commons.wikimedia.org/wiki/Special:FilePath/$file?width=1024';

/// 「酒・煙草・風俗をやめよう」応援キャンペーンの動画シェアページ。
///
/// スクショの X(Twitter) 風 縦スワイプ動画プレイヤーを再現する:
/// - 全画面ダーク背景 + 動画フレーム (ポスター) を大きく表示
/// - 作者行 + フォローボタン
/// - コメント / リポスト / いいね / ブックマーク / 共有 の横並びアクション
/// - 下部の再生シークバー (装飾)
///
/// 実動画ファイルは同梱せず、`videoUrl` があれば共有 / 外部再生で開く。
/// フィードは端末ローカルの seed + ユーザー投稿で成立し、外部 API に依存しない。
class SobrietyCampaignPage extends StatefulWidget {
  const SobrietyCampaignPage({super.key});

  @override
  State<SobrietyCampaignPage> createState() => _SobrietyCampaignPageState();
}

class _SobrietyCampaignPageState extends State<SobrietyCampaignPage> {
  final _pageController = PageController();
  late List<CampaignVideo> _all;
  late final DateTime _today;
  CampaignCategory? _filter; // null = すべて

  final _liked = <String>{};
  final _bookmarked = <String>{};
  final _following = <String>{};
  // ユーザー操作で増減する like / repost の上書き値 (id -> count)。
  final _likeOverride = <String, int>{};
  final _repostOverride = <String, int>{};

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    // 今日の風刺画 (日替わりローテーション) を先頭に、応援クリップ seed を続ける。
    _all = [
      ...SatiricalPrintLibrary.dailyPicks(_today),
      ...CampaignVideo.seed(),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<CampaignVideo> get _visible {
    if (_filter == null) return _all;
    return _all.where((v) => v.category == _filter).toList();
  }

  int _likeCount(CampaignVideo v) => _likeOverride[v.id] ?? v.likes;
  int _repostCount(CampaignVideo v) => _repostOverride[v.id] ?? v.reposts;

  void _toggleLike(CampaignVideo v) {
    setState(() {
      if (_liked.remove(v.id)) {
        _likeOverride[v.id] = _likeCount(v) - 1;
      } else {
        _liked.add(v.id);
        _likeOverride[v.id] = _likeCount(v) + 1;
      }
    });
  }

  void _toggleBookmark(CampaignVideo v) {
    setState(() {
      if (!_bookmarked.remove(v.id)) _bookmarked.add(v.id);
    });
    _snack(_bookmarked.contains(v.id) ? 'ブックマークしました' : 'ブックマークを解除しました');
  }

  void _toggleFollow(CampaignVideo v) {
    setState(() {
      if (!_following.remove(v.creatorHandle)) {
        _following.add(v.creatorHandle);
      }
    });
  }

  void _repost(CampaignVideo v) {
    setState(() => _repostOverride[v.id] = _repostCount(v) + 1);
    _snack('リポストしました 🔁');
  }

  Future<void> _share(CampaignVideo v) async {
    try {
      await SharePlus.instance.share(ShareParams(text: v.shareText()));
    } catch (_) {
      // 共有シートが使えない環境ではクリップボード相当の通知に留める。
      if (mounted) _snack('共有に失敗しました');
    }
  }

  Future<void> _play(CampaignVideo v) async {
    final url = v.videoUrl ??
        (v.imageFile != null ? _commonsImageUrl(v.imageFile!) : null);
    if (url == null || url.isEmpty) {
      _snack('このクリップは再生リンク未設定です');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _snack('リンクを開けませんでした');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _openComposer() async {
    final result = await showModalBottomSheet<CampaignVideo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignTokens.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXl)),
      ),
      builder: (_) => const _ComposerSheet(),
    );
    if (result != null && mounted) {
      setState(() {
        _all = [result, ..._all];
        _filter = null;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _snack('応援クリップを投稿しました 🎬');
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = _visible;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              filter: _filter,
              onFilter: (c) {
                setState(() => _filter = c);
                if (_pageController.hasClients) _pageController.jumpToPage(0);
              },
              onPost: _openComposer,
            ),
            _DailyBanner(date: _today),
            Expanded(
              child: videos.isEmpty
                  ? const Center(
                      child: Text(
                        'このカテゴリのクリップはまだありません',
                        style: TextStyle(color: DesignTokens.textSecondary),
                      ),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: videos.length,
                      itemBuilder: (context, i) {
                        final v = videos[i];
                        return _VideoCard(
                          video: v,
                          liked: _liked.contains(v.id),
                          bookmarked: _bookmarked.contains(v.id),
                          following: _following.contains(v.creatorHandle),
                          likeCount: _likeCount(v),
                          repostCount: _repostCount(v),
                          onLike: () => _toggleLike(v),
                          onBookmark: () => _toggleBookmark(v),
                          onFollow: () => _toggleFollow(v),
                          onRepost: () => _repost(v),
                          onShare: () => _share(v),
                          onComment: () => _snack('コメント機能は近日公開'),
                          onPlay: () => _play(v),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.filter,
    required this.onFilter,
    required this.onPost,
  });

  final CampaignCategory? filter;
  final ValueChanged<CampaignCategory?> onFilter;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.space8,
        DesignTokens.space8,
        DesignTokens.space8,
        DesignTokens.space4,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: '戻る',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'すべて',
                    selected: filter == null,
                    onTap: () => onFilter(null),
                  ),
                  for (final c in CampaignCategory.values)
                    _FilterChip(
                      label: '${c.emoji} ${c.label}',
                      selected: filter == c,
                      onTap: () => onFilter(c),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.space8),
          FilledButton.icon(
            onPressed: onPost,
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: const Icon(Icons.videocam, size: 18),
            label: const Text('投稿'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: DesignTokens.space8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : DesignTokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: DesignTokens.surface2,
        selectedColor: DesignTokens.orange,
        side: BorderSide(
          color: selected ? DesignTokens.orange : DesignTokens.divider,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _DailyBanner extends StatelessWidget {
  const _DailyBanner({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = '今日の風刺画 — ${date.month}月${date.day}日更新 · 毎日ランダムでお届け';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DesignTokens.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(color: DesignTokens.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('🎨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: DesignTokens.space8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: DesignTokens.textOnDark,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.liked,
    required this.bookmarked,
    required this.following,
    required this.likeCount,
    required this.repostCount,
    required this.onLike,
    required this.onBookmark,
    required this.onFollow,
    required this.onRepost,
    required this.onShare,
    required this.onComment,
    required this.onPlay,
  });

  final CampaignVideo video;
  final bool liked;
  final bool bookmarked;
  final bool following;
  final int likeCount;
  final int repostCount;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onFollow;
  final VoidCallback onRepost;
  final VoidCallback onShare;
  final VoidCallback onComment;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 下部パディングでグローバル「AIシェア」ボタン等と行の重なりを避ける。
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 動画フレーム (ポスター) ─────────────────────
          Expanded(
            child: _VideoFrame(video: video, onPlay: onPlay),
          ),
          const SizedBox(height: DesignTokens.space12),
          // ── 作者行 + フォロー ──────────────────────────
          _CreatorRow(
            video: video,
            following: following,
            onFollow: onFollow,
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            video.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: DesignTokens.textOnDark,
              height: 1.5,
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          // ── アクション行 ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: _fmt(video.comments),
                onTap: onComment,
              ),
              _ActionButton(
                icon: Icons.repeat,
                label: _fmt(repostCount),
                color: repostCount > video.reposts ? DesignTokens.green : null,
                onTap: onRepost,
              ),
              _ActionButton(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                label: _fmt(likeCount),
                color: liked ? DesignTokens.red : null,
                onTap: onLike,
              ),
              _ActionButton(
                icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: bookmarked ? DesignTokens.orange : null,
                onTap: onBookmark,
              ),
              _ActionButton(
                icon: Icons.ios_share,
                onTap: onShare,
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          const _Scrubber(),
          const SizedBox(height: DesignTokens.space8),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// Wikimedia Commons の実画像を表示する。読み込み中・取得失敗時は透明を返し、
/// 背後の絵文字土台がそのまま見えるようにする (フレームが空にならない)。
///
/// Web(CanvasKit)は cross-origin 画像を canvas に描けず失敗するため、
/// [WebHtmlElementStrategy.fallback] で失敗時に HTML の `<img>` 要素へ切り替え、
/// CORS 制約下でも Commons 画像を表示できるようにする (非Web環境では無視される)。
class _PrintImage extends StatelessWidget {
  const _PrintImage({required this.file});

  final String file;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _commonsImageUrl(file),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox.shrink();
      },
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
    );
  }
}

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({required this.video, required this.onPlay});

  final CampaignVideo video;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final accent = video.category.accent;
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.35),
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 絵文字＋グラデは常に土台として描画。画像の読込中/失敗時に
            // この土台が見えることで、フレームが空(茶色一色)にならない。
            Center(
              child: Text(
                video.category.emoji,
                style: const TextStyle(fontSize: 120),
              ),
            ),
            // 実際の風刺画を上に重ねる (成功時のみ土台を覆う)。
            if (video.imageFile != null)
              Positioned.fill(child: _PrintImage(file: video.imageFile!)),
            // 下部グラデ + タイトル (スクショの黒帯テロップ再現)。
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DesignTokens.space16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(
                  video.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            // 再生ボタン。
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            // 左上カテゴリバッジ。
            Positioned(
              top: DesignTokens.space12,
              left: DesignTokens.space12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space12,
                  vertical: DesignTokens.space4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusCircle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(video.category.icon, size: 14, color: accent),
                    const SizedBox(width: DesignTokens.space4),
                    Text(
                      video.category.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 右上「今日の風刺画」リボン (日替わりローテーション対象のみ)。
            if (video.id.startsWith('print-'))
              Positioned(
                top: DesignTokens.space12,
                right: DesignTokens.space12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space12,
                    vertical: DesignTokens.space4,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.orange,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusCircle),
                  ),
                  child: const Text(
                    '🎨 今日の風刺画',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreatorRow extends StatelessWidget {
  const _CreatorRow({
    required this.video,
    required this.following,
    required this.onFollow,
  });

  final CampaignVideo video;
  final bool following;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final fg = following ? DesignTokens.textSecondary : Colors.white;
    final bg = following ? Colors.transparent : DesignTokens.surface3;
    final borderColor = following ? DesignTokens.divider : Colors.transparent;
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: video.category.accent.withValues(alpha: 0.25),
          child: Text(
            video.category.emoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        const SizedBox(width: DesignTokens.space8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      video.creatorName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (video.verified) ...[
                    const SizedBox(width: DesignTokens.space4),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: DesignTokens.indigo,
                    ),
                  ],
                ],
              ),
              Text(
                video.creatorHandle,
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: onFollow,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            backgroundColor: bg,
            side: BorderSide(color: borderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
            ),
          ),
          child: Text(following ? 'フォロー中' : 'フォローする'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    this.label,
    this.color,
    required this.onTap,
  });

  final IconData icon;
  final String? label;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? DesignTokens.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space8,
          vertical: DesignTokens.space8,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tint),
            if (label != null && label!.isNotEmpty) ...[
              const SizedBox(width: DesignTokens.space4),
              Text(
                label!,
                style: TextStyle(color: tint, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.play_arrow, color: Colors.white, size: 20),
        SizedBox(width: DesignTokens.space8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignTokens.radiusCircle),
            ),
            child: LinearProgressIndicator(
              value: 0.15,
              minHeight: 4,
              backgroundColor: DesignTokens.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.orange),
            ),
          ),
        ),
        SizedBox(width: DesignTokens.space8),
        Text(
          '0:03',
          style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

/// 「投稿」ボトムシート: 自作の応援クリップ (URL + 一言) を追加する。
class _ComposerSheet extends StatefulWidget {
  const _ComposerSheet();

  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final _title = TextEditingController();
  final _caption = TextEditingController();
  final _url = TextEditingController();
  CampaignCategory _category = CampaignCategory.alcohol;

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final caption = _caption.text.trim();
    if (title.isEmpty || caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルと一言を入力してください')),
      );
      return;
    }
    final url = _url.text.trim();
    Navigator.of(context).pop(
      CampaignVideo(
        id: 'user-${title.hashCode}-${caption.hashCode}',
        category: _category,
        title: title,
        caption: caption,
        creatorName: 'あなた',
        creatorHandle: '@you',
        videoUrl: url.isEmpty ? null : url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space16,
        DesignTokens.space16,
        DesignTokens.space16,
        DesignTokens.space16 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '応援クリップを投稿',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.space4),
          const Text(
            '禁酒・禁煙・脱風俗を後押しする動画をシェアしよう',
            style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: DesignTokens.space16),
          Wrap(
            spacing: DesignTokens.space8,
            children: [
              for (final c in CampaignCategory.values)
                ChoiceChip(
                  label: Text('${c.emoji} ${c.label}'),
                  selected: _category == c,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: _category == c
                        ? Colors.white
                        : DesignTokens.textSecondary,
                  ),
                  backgroundColor: DesignTokens.surface2,
                  selectedColor: DesignTokens.orange,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          _field(_title, 'タイトル (例: 禁酒30日でこう変わる)'),
          const SizedBox(height: DesignTokens.space8),
          _field(_caption, '一言 (本文)'),
          const SizedBox(height: DesignTokens.space8),
          _field(_url, '動画URL (任意)', keyboard: TextInputType.url),
          const SizedBox(height: DesignTokens.space16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.orange,
                padding:
                    const EdgeInsets.symmetric(vertical: DesignTokens.space12),
              ),
              icon: const Icon(Icons.send),
              label: const Text('投稿する'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: DesignTokens.textTertiary),
        filled: true,
        fillColor: DesignTokens.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
