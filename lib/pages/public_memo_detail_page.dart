import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_memo.dart';
import '../services/public_memo_service.dart';

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

class _PublicMemoDetailPageState extends State<PublicMemoDetailPage> {
  late final PublicMemoService _publicMemoService;
  PublicMemo? _memo;
  bool _isLoading = true;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _publicMemoService =
        widget.publicMemoService ?? PublicMemoService(Supabase.instance.client);
    _load();
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memo = _memo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public memo detail'),
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
                    const SizedBox(height: 20),
                    SelectableText(
                      memo.content?.trim().isNotEmpty == true
                          ? memo.content!.trim()
                          : 'This memo does not have body text yet.',
                      style: const TextStyle(fontSize: 16, height: 1.6),
                    ),
                  ],
                ),
    );
  }
}
