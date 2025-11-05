import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import '../models/note.dart';
import '../models/category.dart';
import '../models/card_template.dart' as template;
import '../widgets/note_card_widget.dart';
import '../services/note_card_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  template.CardTemplate _selectedTemplate = template.CardTemplate.minimal;
  bool _includeStats = true;
  bool _includeLogo = true;
  bool _isGenerating = false;
  bool _isLoadingPreview = false;

  // 新しいオプション
  template.AspectRatio _selectedAspectRatio = template.AspectRatio.square;
  template.ContentMode _selectedContentMode = template.ContentMode.smart;
  template.FontSizeOption _selectedFontSize = template.FontSizeOption.medium;
  bool _autoHashtags = true;

  // プレビュー用のGlobalKey（複数ページ対応）
  final List<GlobalKey> _repaintKeys = [];
  bool _showPreview = false;
  List<String> _contentChunks = [];

  // プログレス表示用
  int _currentGeneratingIndex = 0;

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
                      const Flexible(
                        child: Text(
                          'メモカードを作成',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                            itemCount: template.CardTemplate.values.length,
                            itemBuilder: (context, index) {
                              final cardTemplate = template.CardTemplate.values[index];
                              final isSelected = _selectedTemplate == cardTemplate;
                              
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTemplate = cardTemplate;
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
                                      _getTemplatePreview(cardTemplate),
                                      const SizedBox(height: 8),
                                      Text(
                                        cardTemplate.label,
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

                        // アスペクト比選択
                        const Text(
                          'アスペクト比',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: template.AspectRatio.values.map((ratio) {
                            final isSelected = _selectedAspectRatio == ratio;
                            return ChoiceChip(
                              label: Text(ratio.label),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedAspectRatio = ratio;
                                  _showPreview = false;
                                  _isLoadingPreview = false;
                                });
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // コンテンツモード選択
                        const Text(
                          'コンテンツモード',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedContentMode.label} - 1ページ最大${_selectedContentMode.maxCharsPerPage}文字',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: template.ContentMode.values.map((mode) {
                            final isSelected = _selectedContentMode == mode;
                            return ChoiceChip(
                              label: Text(mode.label),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedContentMode = mode;
                                  _showPreview = false;
                                  _isLoadingPreview = false;
                                });
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // フォントサイズ選択
                        const Text(
                          'フォントサイズ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: template.FontSizeOption.values.map((fontSize) {
                            final isSelected = _selectedFontSize == fontSize;
                            return ChoiceChip(
                              label: Text(fontSize.label),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFontSize = fontSize;
                                  _showPreview = false;
                                  _isLoadingPreview = false;
                                });
                              },
                            );
                          }).toList(),
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
                                  onPressed: _handlePreview,
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
                      Flexible(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('キャンセル'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Web版ではダウンロードボタンを表示
                      if (kIsWeb)
                        Flexible(
                          child: ElevatedButton.icon(
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
                            label: Text(_isGenerating
                                ? '生成中... ($_currentGeneratingIndex/${_repaintKeys.length})'
                                : 'ダウンロード'),
                            onPressed: (_isGenerating || !_showPreview || _isLoadingPreview)
                                ? null
                                : _generateAndDownload,
                          ),
                        )
                      else
                        // モバイル版では共有ボタン
                        Flexible(
                          child: ElevatedButton.icon(
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
                            label: Text(_isGenerating
                                ? '生成中... ($_currentGeneratingIndex/${_repaintKeys.length})'
                                : '共有する'),
                            onPressed: (_isGenerating || !_showPreview || _isLoadingPreview)
                                ? null
                                : _generateAndShare,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            // プレビュー表示エリア（画面外に配置）
            if (_showPreview)
              ...List.generate(
                _contentChunks.length,
                (index) => Positioned(
                  left: -10000,
                  top: -10000 - (index * 3000), // 各カードを異なる位置に配置
                  child: SizedBox(
                    width: _selectedAspectRatio.width.toDouble(),
                    // 高さの制約を削除し、コンテンツに応じて自動調整
                    child: _buildCardWidget(index),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // コンテンツを複数のチャンクに分割（動的文字数制限）
  List<String> _splitContent(String content) {
    final maxChars = _selectedContentMode.maxCharsPerPage;

    if (content.length <= maxChars) {
      return [content];
    }

    final List<String> chunks = [];
    int startIndex = 0;

    while (startIndex < content.length) {
      int endIndex = startIndex + maxChars;

      // 最後のチャンクの場合
      if (endIndex >= content.length) {
        chunks.add(content.substring(startIndex));
        break;
      }

      // 文の区切りで分割を試みる
      int splitIndex = endIndex;

      // 句点、改行、スペースで区切りを探す
      for (int i = endIndex; i > startIndex + (maxChars ~/ 2); i--) {
        if (i < content.length && (content[i] == '。' || content[i] == '.' ||
            content[i] == '\n' || content[i] == ' ')) {
          splitIndex = i + 1;
          break;
        }
      }

      chunks.add(content.substring(startIndex, splitIndex));
      startIndex = splitIndex;
    }

    return chunks;
  }

  // 初期化または再構築時にキーとチャンクを準備
  void _prepareContentChunks() {
    _contentChunks = _splitContent(widget.note.content);

    // 必要な数のGlobalKeyを生成
    _repaintKeys.clear();
    for (int i = 0; i < _contentChunks.length; i++) {
      _repaintKeys.add(GlobalKey());
    }
  }

  Widget _buildCardWidget(int pageIndex) {
    final cardStyle = template.CardStyle(
      template: _selectedTemplate,
      includeStats: _includeStats,
      includeLogo: _includeLogo,
      aspectRatio: _selectedAspectRatio,
      contentMode: _selectedContentMode,
      fontSize: _selectedFontSize,
      autoHashtags: _autoHashtags,
    );

    // 文字数と単語数を計算
    final characterCount = widget.note.content.length;
    final wordCount = widget.note.content.split(RegExp(r'\s+')).length;

    return RepaintBoundary(
      key: _repaintKeys[pageIndex],
      child: NoteCardWidget(
        note: widget.note,
        category: widget.category,
        cardStyle: cardStyle,
        wordCount: wordCount,
        characterCount: characterCount,
        contentChunk: _contentChunks[pageIndex],
        pageNumber: _contentChunks.length > 1 ? pageIndex + 1 : null,
        totalPages: _contentChunks.length > 1 ? _contentChunks.length : null,
      ),
    );
  }

  Widget _getTemplatePreview(template.CardTemplate cardTemplate) {
    Color color;
    IconData icon;

    switch (cardTemplate) {
      case template.CardTemplate.minimal:
        color = Colors.white;
        icon = Icons.minimize;
        break;
      case template.CardTemplate.modern:
        color = Colors.blue;
        icon = Icons.style;
        break;
      case template.CardTemplate.gradient:
        color = Colors.purple;
        icon = Icons.gradient;
        break;
      case template.CardTemplate.darkMode:
        color = Colors.black87;
        icon = Icons.dark_mode;
        break;
      case template.CardTemplate.colorful:
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
      child: Icon(icon, color: cardTemplate == template.CardTemplate.darkMode
          ? Colors.white : Colors.black54),
    );
  }

  // プレビュー処理（画像数警告付き）
  Future<void> _handlePreview() async {
    // まずコンテンツを分割して枚数を確認
    _prepareContentChunks();
    final imageCount = _contentChunks.length;

    // 5枚以上の場合は警告ダイアログを表示
    if (imageCount >= 5) {
      final shouldContinue = await _showImageCountWarning(imageCount);
      if (!shouldContinue) {
        return;
      }
    }

    // プレビュー生成を開始
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

      final pageCount = _contentChunks.length;
      final message = pageCount > 1
          ? '✓ プレビュー準備完了！$pageCount枚の画像を生成します'
          : '✓ プレビュー準備完了！「ダウンロード」ボタンをクリックしてください';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // 画像数警告ダイアログ
  Future<bool> _showImageCountWarning(int imageCount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('画像数が多いです'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'このメモは $imageCount 枚の画像になります。',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('以下をお勧めします：'),
            const SizedBox(height: 8),
            _buildSuggestion('📝 コンテンツモードを「要約モード」に変更'),
            _buildSuggestion('✂️ 「スマート分割」で適度な枚数に調整'),
            _buildSuggestion('🔗 リンク共有機能を使用'),
            const SizedBox(height: 16),
            const Text(
              '※ 大量の画像生成は時間がかかり、デバイスのメモリを消費します',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('このまま続行'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildSuggestion(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.arrow_right, size: 20, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // Web版: ダウンロード機能
  Future<void> _generateAndDownload() async {
    setState(() {
      _isGenerating = true;
      _currentGeneratingIndex = 0;
    });

    try {
      // 少し待ってからキャプチャ開始
      await Future.delayed(const Duration(milliseconds: 500));

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      int successCount = 0;

      // 各ページをキャプチャしてダウンロード
      for (int i = 0; i < _repaintKeys.length; i++) {
        // プログレス更新
        setState(() {
          _currentGeneratingIndex = i + 1;
        });

        // スクリーンショットを撮る
        final imageBytes = await NoteCardService.captureWidgetSimple(_repaintKeys[i]);

        if (imageBytes == null) {
          throw Exception('画像 ${i + 1}/${_repaintKeys.length} の生成に失敗しました。');
        }

        if (!mounted) {
          return;
        }

        // Web版: ダウンロード
        final blob = html.Blob([imageBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final filename = _repaintKeys.length > 1
            ? 'note_card_${timestamp}_${i + 1}of${_repaintKeys.length}.png'
            : 'note_card_$timestamp.png';

        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();

        html.Url.revokeObjectUrl(url);

        successCount++;

        // 次の画像キャプチャまで少し待つ（WebGLリソースの解放を待つ）
        if (i < _repaintKeys.length - 1) {
          // Web環境ではより長い待機時間が必要
          await Future.delayed(const Duration(milliseconds: 2000));
        }
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      final message = successCount > 1
          ? 'メモカード${successCount}枚をダウンロードしました！'
          : 'メモカードをダウンロードしました！';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e\nもう一度「プレビューを表示」ボタンを押してから再度お試しください。'),
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
      _currentGeneratingIndex = 0;
    });

    try {
      // 少し待ってからキャプチャ開始
      await Future.delayed(const Duration(milliseconds: 500));

      final List<Uint8List> allImageBytes = [];

      // 各ページをキャプチャ
      for (int i = 0; i < _repaintKeys.length; i++) {
        // プログレス更新
        setState(() {
          _currentGeneratingIndex = i + 1;
        });

        // スクリーンショットを撮る
        final imageBytes = await NoteCardService.captureWidgetSimple(_repaintKeys[i]);

        if (imageBytes == null) {
          throw Exception('画像 ${i + 1}/${_repaintKeys.length} の生成に失敗しました。');
        }

        allImageBytes.add(imageBytes);

        // 次の画像キャプチャまで少し待つ（WebGLリソースの解放を待つ）
        if (i < _repaintKeys.length - 1) {
          // Web環境ではより長い待機時間が必要
          await Future.delayed(const Duration(milliseconds: 2000));
        }
      }

      if (!mounted) {
        return;
      }

      // 複数の画像を共有
      await _shareMultipleImages(allImageBytes);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      final message = allImageBytes.length > 1
          ? 'メモカード${allImageBytes.length}枚を共有しました！'
          : 'メモカードを共有しました！';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e\nもう一度「プレビューを表示」ボタンを押してから再度お試しください。'),
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

  // 複数の画像を共有するヘルパー関数
  Future<void> _shareMultipleImages(List<Uint8List> imageBytesList) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final List<XFile> files = [];

      for (int i = 0; i < imageBytesList.length; i++) {
        final filename = imageBytesList.length > 1
            ? 'note_card_${timestamp}_${i + 1}of${imageBytesList.length}.png'
            : 'note_card_$timestamp.png';
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(imageBytesList[i]);
        files.add(XFile(file.path));
      }

      // 共有
      await Share.shareXFiles(
        files,
        text: '📝 ${widget.note.title.isEmpty ? "(タイトルなし)" : widget.note.title}\n\n#マイメモ #メモ習慣',
      );
    } catch (e) {
      debugPrint('Error sharing note cards: $e');
      rethrow;
    }
  }
}