import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../models/note.dart';
import '../models/category.dart';
import '../models/card_template.dart';
import '../widgets/note_card_widget.dart';
import '../services/note_card_service.dart';
// Web用
import 'dart:html' as html;

class ShareNoteCardDialog extends StatefulWidget {
  final Note note;
  final Category? category;

  const ShareNoteCardDialog({
    super.key,
    required this.note,
    this.category,
  });

  @override
  State<ShareNoteCardDialog> createState() => _ShareNoteCardDialogState();
}

class _ShareNoteCardDialogState extends State<ShareNoteCardDialog> {
  CardTemplate _selectedTemplate = CardTemplate.minimal;
  bool _includeStats = true;
  bool _includeLogo = true;
  bool _isGenerating = false;
  bool _isLoadingPreview = false;
  
  // プレビュー用のGlobalKey
  final GlobalKey _repaintKey = GlobalKey();
  bool _showPreview = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
        child: Stack(
          children: [
            // メインコンテンツ
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.share, color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'メモカードを作成',
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
                ),
                
                const Divider(height: 1),
                
                // スクロール可能なコンテンツ
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // テンプレート選択
                        const Text(
                          'テンプレートを選択',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: CardTemplate.values.length,
                            itemBuilder: (context, index) {
                              final template = CardTemplate.values[index];
                              final isSelected = _selectedTemplate == template;
                              
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTemplate = template;
                                    _showPreview = false;
                                    _isLoadingPreview = false;
                                  });
                                },
                                child: Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _getTemplatePreview(template),
                                      const SizedBox(height: 8),
                                      Text(
                                        template.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected ? Colors.blue : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // オプション
                        const Text(
                          'オプション',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        CheckboxListTile(
                          title: const Text('統計情報を表示'),
                          subtitle: const Text('文字数と作成日を含める'),
                          value: _includeStats,
                          onChanged: (value) {
                            setState(() {
                              _includeStats = value ?? true;
                              _showPreview = false;
                              _isLoadingPreview = false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        
                        CheckboxListTile(
                          title: const Text('ロゴを表示'),
                          subtitle: const Text('「マイメモ」のロゴを含める'),
                          value: _includeLogo,
                          onChanged: (value) {
                            setState(() {
                              _includeLogo = value ?? true;
                              _showPreview = false;
                              _isLoadingPreview = false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // プレビューボタン
                        Center(
                          child: _isLoadingPreview
                              ? const Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 8),
                                    Text('プレビューを準備中...'),
                                  ],
                                )
                              : OutlinedButton.icon(
                                  icon: const Icon(Icons.visibility),
                                  label: Text(_showPreview ? 'プレビュー準備完了 ✓' : 'プレビューを表示'),
                                  style: _showPreview
                                      ? OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.green, width: 2),
                                          foregroundColor: Colors.green,
                                        )
                                      : null,
                                  onPressed: () async {
                                    setState(() {
                                      _isLoadingPreview = true;
                                      _showPreview = true;
                                    });
                                    
                                    // レンダリング待機
                                    await Future.delayed(const Duration(milliseconds: 500));
                                    
                                    // フレーム完了を待つ
                                    final completer = Completer<void>();
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      completer.complete();
                                    });
                                    WidgetsBinding.instance.scheduleFrame();
                                    await completer.future;
                                    
                                    // さらに待機
                                    await Future.delayed(const Duration(milliseconds: 1500));
                                    
                                    if (mounted) {
                                      setState(() {
                                        _isLoadingPreview = false;
                                      });
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('✓ プレビュー準備完了！「ダウンロード」ボタンをクリックしてください'),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Divider(height: 1),
                
                // ボタンエリア
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('キャンセル'),
                      ),
                      const SizedBox(width: 12),
                      // Web版ではダウンロードボタンを表示
                      if (kIsWeb)
                        ElevatedButton.icon(
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.download),
                          label: Text(_isGenerating ? '生成中...' : 'ダウンロード'),
                          onPressed: (_isGenerating || !_showPreview || _isLoadingPreview)
                              ? null
                              : _generateAndDownload,
                        )
                      else
                        // モバイル版では共有ボタン
                        ElevatedButton.icon(
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.share),
                          label: Text(_isGenerating ? '生成中...' : '共有する'),
                          onPressed: (_isGenerating || !_showPreview || _isLoadingPreview)
                              ? null
                              : _generateAndShare,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            // プレビュー表示エリア（画面外に配置）
            if (_showPreview)
              Positioned(
                left: -10000,
                top: 0,
                child: _buildCardWidget(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardWidget() {
    final cardStyle = CardStyle(
      template: _selectedTemplate,
      includeStats: _includeStats,
      includeLogo: _includeLogo,
    );

    // 文字数と単語数を計算
    final characterCount = widget.note.content.length;
    final wordCount = widget.note.content.split(RegExp(r'\s+')).length;

    return RepaintBoundary(
      key: _repaintKey,
      child: NoteCardWidget(
        note: widget.note,
        category: widget.category,
        cardStyle: cardStyle,
        wordCount: wordCount,
        characterCount: characterCount,
      ),
    );
  }

  Widget _getTemplatePreview(CardTemplate template) {
    Color color;
    IconData icon;
    
    switch (template) {
      case CardTemplate.minimal:
        color = Colors.white;
        icon = Icons.minimize;
        break;
      case CardTemplate.modern:
        color = Colors.blue;
        icon = Icons.style;
        break;
      case CardTemplate.gradient:
        color = Colors.purple;
        icon = Icons.gradient;
        break;
      case CardTemplate.darkMode:
        color = Colors.black87;
        icon = Icons.dark_mode;
        break;
      case CardTemplate.colorful:
        color = Colors.orange;
        icon = Icons.color_lens;
        break;
    }
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Icon(icon, color: template == CardTemplate.darkMode
          ? Colors.white : Colors.black54),
    );
  }

  // Web版: ダウンロード機能
  Future<void> _generateAndDownload() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      // 少し待ってからキャプチャ開始
      await Future.delayed(const Duration(milliseconds: 500));

      // スクリーンショットを撮る
      final imageBytes = await NoteCardService.captureWidgetSimple(_repaintKey);

      if (imageBytes == null) {
        throw Exception('画像の生成に失敗しました。もう一度「プレビューを表示」ボタンを押してから再度お試しください。');
      }

      if (!mounted) {
        return;
      }

      // Web版: ダウンロード
      final blob = html.Blob([imageBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'note_card_$timestamp.png';
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      
      html.Url.revokeObjectUrl(url);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メモカードをダウンロードしました！'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  // モバイル版: 共有機能
  Future<void> _generateAndShare() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      // 少し待ってからキャプチャ開始
      await Future.delayed(const Duration(milliseconds: 500));

      // スクリーンショットを撮る
      final imageBytes = await NoteCardService.captureWidgetSimple(_repaintKey);

      if (imageBytes == null) {
        throw Exception('画像の生成に失敗しました。もう一度「プレビューを表示」ボタンを押してから再度お試しください。');
      }

      if (!mounted) {
        return;
      }

      // 共有
      await NoteCardService.shareNoteCard(
        imageBytes: imageBytes,
        noteTitle: widget.note.title.isEmpty
            ? '(タイトルなし)'
            : widget.note.title,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メモカードを共有しました！'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}