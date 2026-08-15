import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_web_app/services/debt_progress_card_service.dart';
import 'package:my_web_app/services/note_card_service.dart';
import 'package:my_web_app/utils/web_image_downloader.dart';
import 'package:my_web_app/widgets/debt_progress_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 返済進捗カードの共有ダイアログ。
///
/// 🔴 **HITL 厳守**: ここから自動投稿はしない。カード画像と下書き文面を
/// 用意するだけで、実際に X へ投稿するかどうか・何を書くかは必ず本人が
/// 決める。公開すると取り消せない個人情報なので、自動化してはいけない。
class DebtProgressShareDialog extends StatefulWidget {
  final DebtProgressCardData data;
  final DateTime month;

  const DebtProgressShareDialog({
    super.key,
    required this.data,
    required this.month,
  });

  @override
  State<DebtProgressShareDialog> createState() =>
      _DebtProgressShareDialogState();
}

class _DebtProgressShareDialogState extends State<DebtProgressShareDialog> {
  /// 返済カード専用の公開バケット (RLS で書き込みは所有者フォルダのみ)。
  static const String _cardBucket = 'debt-progress-cards';

  final GlobalKey _repaintKey = GlobalKey();
  late final TextEditingController _textController;
  bool _saving = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    const service = DebtProgressCardService();
    _textController = TextEditingController(
      text: service.buildDraftText(widget.data, month: widget.month),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('今月の返済報告を作る'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '公開前に必ず内容を確認してください。投稿は自動では行いません。',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Center(
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: DebtProgressCard(
                    data: widget.data,
                    month: widget.month,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '投稿文(編集できます)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        TextButton.icon(
          onPressed: _copyText,
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('文面をコピー'),
        ),
        TextButton.icon(
          onPressed: _saving ? null : _downloadCard,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download, size: 16),
          label: const Text('画像を保存'),
        ),
        FilledButton.icon(
          onPressed: _posting ? null : _postToX,
          icon: _posting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 16),
          label: const Text('Xへ投稿する'),
        ),
      ],
    );
  }

  /// 編集後の文面とカード画像を X へ投稿する。
  ///
  /// 🔴 ここで下書きを再生成せず `_textController.text` を送るのが要点 —
  /// 再生成すると本人の編集が捨てられ、意図しない内容が公開される。
  /// 画像は付けば添付し、失敗したらテキストのみで投稿する。
  Future<void> _postToX() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿文が空です')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('この内容でXへ投稿します'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('投稿する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _posting = true);
    try {
      const service = DebtProgressCardService();
      // 画像は「付けば嬉しい」もの。アップロードに失敗しても投稿は続行する
      // (数字が伝われば報告として機能する)。
      final mediaUrl = await _uploadCardImage();
      if (!mounted) return;
      final res = await Supabase.instance.client.functions.invoke(
        'growth-hub',
        body: service.buildPostPayload(
          widget.data,
          month: widget.month,
          text: text,
          mediaUrl: mediaUrl,
        ),
      );
      if (!mounted) return;
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final posted = data['posted'] == true;
      final tweetId = data['tweetId']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            posted
                ? '返済報告を投稿しました'
                    '${tweetId.isNotEmpty ? ' https://x.com/i/status/$tweetId' : ''}'
                : '投稿に失敗しました: ${data['error'] ?? data['code'] ?? '不明'}',
          ),
        ),
      );
      if (posted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('投稿に失敗しました: $error')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  /// カードを PNG 化して公開バケットへ上げ、公開 URL を返す。
  ///
  /// 失敗したら null を返して**投稿は続行**する (画像なしのテキスト投稿)。
  /// ここで例外を投げると、画像の都合で報告そのものが出せなくなる。
  Future<String?> _uploadCardImage() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      // 描画完了を待ってからキャプチャする (未確定フレームだと空画像になる)。
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final bytes = await NoteCardService.captureWidgetSimple(_repaintKey);
      if (bytes == null) return null;
      const service = DebtProgressCardService();
      final path = service.buildCardStoragePath(
        userId: userId,
        month: widget.month,
        // 同月に作り直しても衝突させない (upsert だと投稿済み画像が差し替わる)。
        uniqueSuffix: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await client.storage.from(_cardBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: false,
            ),
          );
      return client.storage.from(_cardBucket).getPublicUrl(path);
    } catch (error) {
      debugPrint('debt progress card image upload failed: $error');
      return null;
    }
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _textController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('投稿文をコピーしました')));
  }

  Future<void> _downloadCard() async {
    setState(() => _saving = true);
    try {
      // 描画完了を待ってからキャプチャする (未確定フレームだと空画像になる)。
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final bytes = await NoteCardService.captureWidgetSimple(_repaintKey);
      if (bytes == null) throw Exception('画像の生成に失敗しました');
      final name = 'debt_progress_${widget.month.year}'
          '${widget.month.month.toString().padLeft(2, '0')}.png';
      downloadImageFile(bytes, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カード画像を保存しました。Xに添付して投稿してください')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
