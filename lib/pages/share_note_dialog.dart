import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/note.dart';

class ShareNoteDialog extends StatelessWidget {
  final Note note;

  const ShareNoteDialog({super.key, required this.note});

  Future<void> _shareNote(BuildContext context) async {
    final navigator = Navigator.of(context);
    final box = context.findRenderObject() as RenderBox?;
    // シェア実行前にポイント加算などを試行（失敗してもシェアは続行）
    try {
      await supabase.functions.invoke(
        'growth-hub',
        body: <String, dynamic>{
          'action': 'acquisition.signal',
          'signalKey': 'share_note',
          'shareIncrement': 1,
        },
      );
    } catch (_) {
      // エラーは無視
    }

    // シェア内容の作成
    final shareText = '【${note.title}】\n${note.content}\n\n#マイメモ #Gemini';

    // シェア実行
    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: note.title,
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      ),
    );

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.share, color: Color(0xFF3D5AFE)),
          SizedBox(width: 8),
          Text('メモをシェア'),
        ],
      ),
      content: const Text('このメモを外部アプリで共有します。\nAI断捨離コーチの判定も一緒に広めましょう！'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton.icon(
          onPressed: () => _shareNote(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3D5AFE),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.ios_share),
          label: const Text('シェアする'),
        ),
      ],
    );
  }
}
