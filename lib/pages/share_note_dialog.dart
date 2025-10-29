import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/shared_note.dart';

class ShareNoteDialog extends StatefulWidget {
  final Note note;

  const ShareNoteDialog({super.key, required this.note});

  @override
  State<ShareNoteDialog> createState() => _ShareNoteDialogState();
}

class _ShareNoteDialogState extends State<ShareNoteDialog> {
  List<SharedNote> _shares = [];
  bool _isLoading = true;
  String _selectedPermission = 'read';
  DateTime? _expiresAt;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  Future<void> _loadShares() async {
    try {
      final response = await supabase
          .from('shared_notes')
          .select()
          .eq('note_id', widget.note.id)
          .order('created_at', ascending: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _shares = (response as List)
            .map((json) => SharedNote.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  Future<void> _createShare() async {
    setState(() {
      _isCreating = true;
    });

    try {
      // トークンを生成
      final tokenResponse = await supabase.rpc('generate_share_token');

      // tokenResponseから文字列を取得
      final token = tokenResponse.toString();

      if (!mounted) {
        return;
      }

      debugPrint('Generated token: $token'); // デバッグ用

      // 共有リンクを作成
      final response = await supabase.from('shared_notes').insert({
        'note_id': widget.note.id,
        'share_token': token,
        'permission': _selectedPermission,
        'created_by': supabase.auth.currentUser!.id,
        'expires_at': _expiresAt?.toIso8601String(),
      }).select();

      if (!mounted) {
        return;
      }

      debugPrint('Insert response: $response'); // デバッグ用

      await _loadShares();

      if (!mounted) {
        return;
      }

      setState(() {
        _isCreating = false;
        _expiresAt = null;
      });

      if (!context.mounted) {
        // ← contextチェックを追加
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('共有リンクを作成しました')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      debugPrint('Error creating share: $error'); // デバッグ用

      setState(() {
        _isCreating = false;
      });

      if (!context.mounted) {
        // ← contextチェックを追加
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  Future<void> _deleteShare(String shareId) async {
    try {
      await supabase.from('shared_notes').delete().eq('id', shareId);

      if (!mounted) {
        return;
      }

      _loadShares();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('共有リンクを削除しました')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  void _copyShareLink(String token) {
    // 現在のURLから自動的にベースURLを取得
    final currentUrl = Uri.base;

    // ベースURL構築（開発環境と本番環境の自動判定）
    final baseUrl = currentUrl.host == 'localhost'
        ? 'http://localhost:${currentUrl.port}'
        : 'https://my-web-app-b67f4.web.app';

    // 共有リンクを生成（#を含める）
    final link = '$baseUrl/#/shared/$token';

    Clipboard.setData(ClipboardData(text: link));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('リンクをコピーしました'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.share, color: Colors.blue),
                const SizedBox(width: 12),
                const Text(
                  'メモを共有',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.note.title.isEmpty ? '(タイトルなし)' : widget.note.title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const Divider(height: 32),

            // 新規共有リンク作成
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '新しい共有リンクを作成',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 権限選択
                  Row(
                    children: [
                      const Text('権限: '),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'read',
                              label: Text('閲覧のみ'),
                              icon: Icon(Icons.visibility, size: 16),
                            ),
                            ButtonSegment(
                              value: 'write',
                              label: Text('編集可能'),
                              icon: Icon(Icons.edit, size: 16),
                            ),
                          ],
                          selected: {_selectedPermission},
                          onSelectionChanged: (Set<String> selected) {
                            setState(() {
                              _selectedPermission = selected.first;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 有効期限設定
                  Row(
                    children: [
                      const Text('有効期限: '),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: Icon(_expiresAt != null
                            ? Icons.event
                            : Icons.event_available),
                        label: Text(_expiresAt != null
                            ? '${_expiresAt!.year}/${_expiresAt!.month}/${_expiresAt!.day}'
                            : '無期限'),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _expiresAt ??
                                DateTime.now().add(
                                  const Duration(days: 7),
                                ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (date != null) {
                            setState(() {
                              _expiresAt = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                23,
                                59,
                                59,
                              );
                            });
                          }
                        },
                      ),
                      if (_expiresAt != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _expiresAt = null;
                            });
                          },
                          tooltip: '期限をクリア',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 作成ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isCreating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_link),
                      label: Text(_isCreating ? '作成中...' : 'リンクを作成'),
                      onPressed: _isCreating ? null : _createShare,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 既存の共有リンク一覧
            Row(
              children: [
                const Text(
                  '共有リンク一覧',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _shares.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_shares.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: const Center(
                  child: Text(
                    '共有リンクがありません',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _shares.length,
                  itemBuilder: (context, index) {
                    final share = _shares[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: share.isExpired
                                ? Colors.grey.withValues(alpha: 0.2)
                                : (share.canWrite
                                    ? Colors.orange.withValues(alpha: 0.2)
                                    : Colors.blue.withValues(alpha: 0.2)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            share.isExpired
                                ? Icons.link_off
                                : (share.canWrite
                                    ? Icons.edit
                                    : Icons.visibility),
                            color: share.isExpired
                                ? Colors.grey
                                : (share.canWrite
                                    ? Colors.orange
                                    : Colors.blue),
                          ),
                        ),
                        title: Row(
                          children: [
                            Icon(
                              share.canWrite ? Icons.edit : Icons.visibility,
                              size: 16,
                              color:
                                  share.canWrite ? Colors.orange : Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              share.canWrite ? '編集可能' : '閲覧のみ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: share.isExpired ? Colors.grey : null,
                              ),
                            ),
                            if (share.isExpired) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '期限切れ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '作成: ${_formatDate(share.createdAt)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (share.expiresAt != null)
                              Text(
                                '期限: ${_formatDate(share.expiresAt!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: share.isExpired ? Colors.red : null,
                                ),
                              ),
                            if (share.accessCount > 0)
                              Text(
                                'アクセス数: ${share.accessCount}回',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!share.isExpired)
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () =>
                                    _copyShareLink(share.shareToken),
                                tooltip: 'リンクをコピー',
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 20),
                              onPressed: () => _deleteShare(share.id),
                              tooltip: '削除',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
