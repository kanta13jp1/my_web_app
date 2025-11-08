import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:io';
import '../models/philosopher_quote.dart';
import '../widgets/philosopher_quote_card.dart';
import '../services/note_card_service.dart';
import '../services/app_share_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
// Web用
import 'dart:html' as html;

/// 哲学者の名言をシェアするダイアログ
class SharePhilosopherQuoteDialog extends StatefulWidget {
  final int? userLevel;
  final int? totalPoints;
  final int? currentStreak;
  final String? levelTitle;

  const SharePhilosopherQuoteDialog({
    super.key,
    this.userLevel,
    this.totalPoints,
    this.currentStreak,
    this.levelTitle,
  });

  @override
  State<SharePhilosopherQuoteDialog> createState() =>
      _SharePhilosopherQuoteDialogState();
}

class _SharePhilosopherQuoteDialogState
    extends State<SharePhilosopherQuoteDialog> {
  PhilosopherQuote _selectedQuote = PhilosopherQuote.getRandomAlways();
  int _selectedQuoteId = 0;
  bool _includeAppLogo = true;
  bool _isGenerating = false;
  bool _showPreview = false;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _updateSelectedQuoteId();
  }

  void _updateSelectedQuoteId() {
    // 現在選択されている名言のIDを取得
    _selectedQuoteId = PhilosopherQuote.quotes.indexOf(_selectedQuote);
    if (_selectedQuoteId < 0) _selectedQuoteId = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
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
                      const Icon(Icons.format_quote, color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Text(
                          '哲学者の名言をシェア',
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
                        // 名言選択
                        const Text(
                          '今日の名言',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 名言表示
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.format_quote,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedQuote.author,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedQuote.quote,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                  color: Colors.black87,
                                ),
                              ),
                              if (_selectedQuote.authorDescription != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _selectedQuote.authorDescription!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 名言を変更するボタン
                        Center(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('別の名言に変更'),
                            onPressed: () {
                              setState(() {
                                _selectedQuote = PhilosopherQuote.getRandomAlways();
                                _updateSelectedQuoteId();
                                _showPreview = false;
                              });
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
                          title: const Text('アプリロゴを表示'),
                          subtitle: const Text('「マイメモ」のロゴを含める'),
                          value: _includeAppLogo,
                          onChanged: (value) {
                            setState(() {
                              _includeAppLogo = value ?? true;
                              _showPreview = false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),

                        const SizedBox(height: 16),

                        // プレビューボタン
                        Center(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.visibility),
                            label: Text(_showPreview
                                ? 'プレビュー準備完了 ✓'
                                : 'プレビューを表示'),
                            style: _showPreview
                                ? OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Colors.green, width: 2),
                                    foregroundColor: Colors.green,
                                  )
                                : null,
                            onPressed: _handlePreview,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // SNSシェアセクション
                        const Divider(),
                        const SizedBox(height: 16),

                        const Text(
                          'SNSで直接シェア（OGP画像付き）',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '下のボタンから、哲学者の名言と画像をSNSに直接シェアできます',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // SNSシェアボタン
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            // Twitter
                            ElevatedButton.icon(
                              icon: const Icon(Icons.share, size: 20),
                              label: const Text('Twitter'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DA1F2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _shareToTwitter,
                            ),
                            // Facebook
                            ElevatedButton.icon(
                              icon: const Icon(Icons.share, size: 20),
                              label: const Text('Facebook'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1877F2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _shareToFacebook,
                            ),
                            // LINE
                            ElevatedButton.icon(
                              icon: const Icon(Icons.share, size: 20),
                              label: const Text('LINE'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06C755),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _shareToLine,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // 画像ダウンロードセクション
                        const Text(
                          '画像をダウンロード',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '画像だけをダウンロードしたい場合は、プレビューを表示してからダウンロードしてください',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // シェアメッセージプレビュー
                        const Text(
                          'シェアメッセージプレビュー',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: Text(
                            _getShareMessage(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
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
                          onPressed: (_isGenerating || !_showPreview)
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
                          onPressed:
                              (_isGenerating || !_showPreview) ? null : _generateAndShare,
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
                top: -10000,
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: PhilosopherQuoteCard(
                    quote: _selectedQuote,
                    includeAppLogo: _includeAppLogo,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getShareMessage() {
    if (widget.userLevel != null &&
        widget.totalPoints != null &&
        widget.currentStreak != null) {
      return AppShareService.getPhilosopherQuoteWithStats(
        level: widget.userLevel!,
        totalPoints: widget.totalPoints!,
        currentStreak: widget.currentStreak!,
        levelTitle: widget.levelTitle,
      );
    } else {
      return AppShareService.getPhilosopherQuoteMessage();
    }
  }

  // プレビュー処理
  Future<void> _handlePreview() async {
    setState(() {
      _showPreview = true;
    });

    // レンダリング待機
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ プレビュー準備完了！「ダウンロード」ボタンをクリックしてください'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
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
        throw Exception('画像の生成に失敗しました。');
      }

      if (!mounted) {
        return;
      }

      // Web版: ダウンロード
      final blob = html.Blob([imageBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'philosopher_quote_$timestamp.png';

      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();

      html.Url.revokeObjectUrl(url);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('名言カードをダウンロードしました！'),
          duration: Duration(seconds: 2),
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
    });

    try {
      // 少し待ってからキャプチャ開始
      await Future.delayed(const Duration(milliseconds: 500));

      // スクリーンショットを撮る
      final imageBytes = await NoteCardService.captureWidgetSimple(_repaintKey);

      if (imageBytes == null) {
        throw Exception('画像の生成に失敗しました。');
      }

      if (!mounted) {
        return;
      }

      // 画像を共有
      await _shareImage(imageBytes);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('名言カードを共有しました！'),
          duration: Duration(seconds: 2),
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

  // 画像を共有するヘルパー関数
  Future<void> _shareImage(Uint8List imageBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'philosopher_quote_$timestamp.png';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(imageBytes);

      // 共有
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _getShareMessage(),
      );
    } catch (e) {
      debugPrint('Error sharing philosopher quote card: $e');
      rethrow;
    }
  }

  // SNSシェアメソッド（動的OGP対応）
  Future<void> _shareToTwitter() async {
    try {
      await AppShareService.shareToTwitterWithDynamicOgp(
        quoteId: _selectedQuoteId,
        level: widget.userLevel,
        totalPoints: widget.totalPoints,
        currentStreak: widget.currentStreak,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Twitterシェア画面を開きました！'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _shareToFacebook() async {
    try {
      await AppShareService.shareToFacebookWithDynamicOgp(
        quoteId: _selectedQuoteId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Facebookシェア画面を開きました！'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _shareToLine() async {
    try {
      await AppShareService.shareToLineWithDynamicOgp(
        quoteId: _selectedQuoteId,
        level: widget.userLevel,
        totalPoints: widget.totalPoints,
        currentStreak: widget.currentStreak,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LINEシェア画面を開きました！'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
