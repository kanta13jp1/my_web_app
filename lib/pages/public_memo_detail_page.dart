import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_memo.dart';
import '../services/growth_acquisition_service.dart';
import '../services/public_memo_service.dart';
import '../utils/seo_meta_helper.dart';
import 'landing_page.dart';

class PublicMemoDetailPage extends StatefulWidget {
  final int memoId;
  final PublicMemoService? publicMemoService;

  const PublicMemoDetailPage({
    super.key,
    required this.memoId,
    this.publicMemoService,
  });

  @override
  State<PublicMemoDetailPage> createState() => _PublicMemoDetailPageState();
}

// Win版#132 part 50: 旧 memo-reactions EF は core-hub に統合済 (b4c91bc2 2026-04-24)
// だが action 完全実装が漏れていたため part 50 で `memo.react.list` /
// `memo.react.toggle` を core-hub に追加 + Flutter 側を切り替え。
const _kAllReactions = ['👍', '❤️', '🔥', '💡', '🎉'];

class _PublicMemoDetailPageState extends State<PublicMemoDetailPage> {
  final GrowthAcquisitionService _acquisitionService =
      const GrowthAcquisitionService();
  late final PublicMemoService _publicMemoService;
  PublicMemo? _memo;
  bool _isLoading = true;
  bool _isLiked = false;

  // Emoji reactions (anonymous, IP-based)
  Map<String, int> _reactionCounts = {};
  Set<String> _userReactions = {};
  bool _reactionsLoading = false;

  @override
  void initState() {
    super.initState();
    _publicMemoService =
        widget.publicMemoService ?? PublicMemoService(Supabase.instance.client);
    _load();
    _loadReactions();
  }

  @override
  void dispose() {
    SeoMetaHelper.resetToDefault();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final memo = await _publicMemoService.getPublicMemoById(widget.memoId);
    if (memo != null) {
      unawaited(_publicMemoService.incrementViewCount(widget.memoId));
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    var isLiked = false;
    if (userId != null) {
      isLiked =
          await _publicMemoService.hasUserLikedMemo(widget.memoId, userId);
    }

    if (!mounted) {
      return;
    }
    // 公開メモの SEO meta タグを動的に更新
    if (memo != null) {
      final rawContent = memo.content ?? '';
      final snippet = rawContent.length > 120
          ? '${rawContent.substring(0, 120)}…'
          : rawContent;
      SeoMetaHelper.setPublicMemoSeo(
        title: memo.title,
        description: snippet,
        url: PublicMemoService.buildPublicMemoAppUrl(widget.memoId),
        imageUrl: PublicMemoService.buildPublicMemoOgpUrl(widget.memoId),
      );
    }

    setState(() {
      _memo = memo;
      _isLiked = isLiked;
      _isLoading = false;
    });
  }

  Future<void> _toggleLike() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showMessage('Log in before liking public memos.');
      return;
    }

    if (_isLiked) {
      await _publicMemoService.unlikeMemo(widget.memoId, userId);
    } else {
      await _publicMemoService.likeMemo(widget.memoId, userId);
    }
    await _load();
  }

  Future<void> _shareMemo() async {
    final memo = _memo;
    if (memo == null) {
      return;
    }

    await SharePlus.instance.share(
      ShareParams(text: PublicMemoService.buildShareMessage(memo)),
    );
    await _publicMemoService.recordShareSignal(
      memoId: widget.memoId,
      signalKey: PublicMemoService.publicMemoShareSignal,
    );
    if (!mounted) {
      return;
    }
    _showMessage('Share sheet opened.');
  }

  Future<void> _copyLink() async {
    final url = PublicMemoService.buildPublicMemoUrl(widget.memoId);
    await Clipboard.setData(ClipboardData(text: url));
    await _publicMemoService.recordShareSignal(
      memoId: widget.memoId,
      signalKey: PublicMemoService.publicMemoCopySignal,
    );
    if (!mounted) {
      return;
    }
    _showMessage('Public memo link copied.');
  }

  Future<void> _loadReactions() async {
    try {
      final body = await _publicMemoService.loadReactions(widget.memoId);
      if (!mounted) {
        return;
      }
      final rawCounts = (body['reactions'] as Map<String, dynamic>?) ?? {};
      final rawUser = (body['userReactions'] as List<dynamic>?) ?? [];
      setState(() {
        _reactionCounts = {
          for (final k in _kAllReactions)
            k: (rawCounts[k] as num?)?.toInt() ?? 0,
        };
        _userReactions = rawUser.map((e) => e.toString()).toSet();
      });
    } catch (_) {
      // Non-critical — reactions are a progressive enhancement
    }
  }

  Future<void> _toggleReaction(String reaction) async {
    if (_reactionsLoading) {
      return;
    }
    setState(() => _reactionsLoading = true);
    try {
      final body = await _publicMemoService.toggleReaction(
        memoId: widget.memoId,
        reaction: reaction,
      );
      if (!mounted) {
        return;
      }
      final added = body['added'] as bool? ?? false;
      final rawCounts = (body['counts'] as Map<String, dynamic>?) ?? {};
      setState(() {
        _reactionCounts = {
          for (final k in _kAllReactions)
            k: (rawCounts[k] as num?)?.toInt() ?? 0,
        };
        if (added) {
          _userReactions = {..._userReactions, reaction};
        } else {
          _userReactions = {..._userReactions}..remove(reaction);
        }
      });
    } catch (_) {
      // Ignore network errors — reactions are non-critical
    } finally {
      if (mounted) {
        setState(() => _reactionsLoading = false);
      }
    }
  }

  Future<void> _openLandingPageForSignUp() async {
    await _acquisitionService.recordPublicMemoSignUpCta();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const LandingPage(),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memo = _memo;
    final currentUser = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public memo detail'),
        // 戻るボタンを明示的に上書き: URL が /public-memo?id=X のまま残るのを防ぐ。
        // 直リンクで来た場合 (Web のディープリンク) も含めて常に '/' に
        // 遷移してブラウザURLを書き換える。
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '戻る',
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            );
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : memo == null
              ? const Center(child: Text('Public memo not found.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      memo.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(memo.category ?? 'Uncategorized')),
                        Chip(
                          label: Text(
                            DateFormat(
                              'yyyy/MM/dd HH:mm',
                            ).format(memo.publishedAt.toLocal()),
                          ),
                        ),
                        Chip(label: Text('${memo.viewCount} views')),
                        Chip(label: Text('${memo.likeCount} likes')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _toggleLike,
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                          ),
                          label: Text(_isLiked ? 'Unlike' : 'Like'),
                        ),
                        FilledButton.icon(
                          onPressed: _shareMemo,
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _copyLink,
                          icon: const Icon(Icons.link),
                          label: const Text('Copy link'),
                        ),
                      ],
                    ),
                    if (currentUser == null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Save ideas like this in your own workspace',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Create an account to save imports, AI suggestions, and public memo ideas in one place.',
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _openLandingPageForSignUp,
                                icon: const Icon(Icons.login),
                                label:
                                    const Text('Create account to save ideas'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SelectableText(
                      memo.content?.trim().isNotEmpty == true
                          ? memo.content!.trim()
                          : 'This memo does not have body text yet.',
                      style: const TextStyle(fontSize: 16, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    _MemoReactionsBar(
                      counts: _reactionCounts,
                      userReactions: _userReactions,
                      loading: _reactionsLoading,
                      onToggle: _toggleReaction,
                    ),
                  ],
                ),
    );
  }
}

class _MemoReactionsBar extends StatelessWidget {
  final Map<String, int> counts;
  final Set<String> userReactions;
  final bool loading;
  final void Function(String) onToggle;

  const _MemoReactionsBar({
    required this.counts,
    required this.userReactions,
    required this.loading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reactions',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kAllReactions.map((emoji) {
            final count = counts[emoji] ?? 0;
            final active = userReactions.contains(emoji);
            return _ReactionChip(
              emoji: emoji,
              count: count,
              active: active,
              loading: loading,
              onTap: () => onToggle(emoji),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool active;
  final bool loading;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.active,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? colorScheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
