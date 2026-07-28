import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_web_app/services/debt_progress_card_service.dart';
import 'package:my_web_app/services/note_card_service.dart';
import 'package:my_web_app/utils/web_image_downloader.dart';
import 'package:my_web_app/widgets/debt_progress_card.dart';

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
  final GlobalKey _repaintKey = GlobalKey();
  late final TextEditingController _textController;
  bool _saving = false;

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
        FilledButton.icon(
          onPressed: _saving ? null : _downloadCard,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download, size: 16),
          label: const Text('カード画像を保存'),
        ),
      ],
    );
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
