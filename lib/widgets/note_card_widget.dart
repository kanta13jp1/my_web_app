import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/category.dart';
import '../models/card_template.dart' as template;
import 'package:intl/intl.dart';

class NoteCardWidget extends StatelessWidget {
  final Note note;
  final Category? category;
  final template.CardStyle cardStyle;
  final int wordCount;
  final int characterCount;
  final String? contentChunk; // 分割されたコンテンツのチャンク（nullの場合は全コンテンツ）
  final int? pageNumber; // 現在のページ番号（1から始まる）
  final int? totalPages; // 総ページ数

  const NoteCardWidget({
    super.key,
    required this.note,
    this.category,
    required this.cardStyle,
    required this.wordCount,
    required this.characterCount,
    this.contentChunk,
    this.pageNumber,
    this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    switch (cardStyle.template) {
      case template.CardTemplate.minimal:
        return _buildMinimalCard();
      case template.CardTemplate.modern:
        return _buildModernCard();
      case template.CardTemplate.gradient:
        return _buildGradientCard();
      case template.CardTemplate.darkMode:
        return _buildDarkModeCard();
      case template.CardTemplate.colorful:
        return _buildColorfulCard();
    }
  }

  // ミニマルテンプレート（全内容表示）
  Widget _buildMinimalCard() {
    final displayContent = contentChunk ?? note.content;
    final fontScale = cardStyle.fontSize.scale;
    final aspectRatio = cardStyle.aspectRatio;

    return Container(
      width: aspectRatio.width.toDouble(),
      constraints: BoxConstraints(minHeight: aspectRatio.height.toDouble()),
      color: Colors.white,
      padding: const EdgeInsets.all(80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル（ページ番号付き）
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.title.isEmpty ? '(タイトルなし)' : note.title,
                  style: TextStyle(
                    fontSize: 64 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
              if (pageNumber != null && totalPages != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pageNumber/$totalPages',
                    style: TextStyle(
                      fontSize: 32 * fontScale,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 40),

          // コンテンツ（全内容またはチャンク）
          Text(
            displayContent,
            style: TextStyle(
              fontSize: 42 * fontScale,
              color: Colors.black54,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 40),

          // フッター
          _buildFooter(Colors.black26, Colors.black54, fontScale),
        ],
      ),
    );
  }

  // モダンテンプレート（全内容表示）
  Widget _buildModernCard() {
    final categoryColor = category != null
        ? Color(int.parse(category!.color.substring(1), radix: 16) + 0xFF000000)
        : Colors.blue;
    final displayContent = contentChunk ?? note.content;
    final fontScale = cardStyle.fontSize.scale;
    final aspectRatio = cardStyle.aspectRatio;

    return Container(
      width: aspectRatio.width.toDouble(),
      constraints: BoxConstraints(minHeight: aspectRatio.height.toDouble()),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: categoryColor, width: 20),
        ),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カテゴリバッジとページ番号
          Row(
            children: [
              if (category != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '# ${category!.name}',
                      style: TextStyle(
                        fontSize: 32 * fontScale,
                        fontWeight: FontWeight.w600,
                        color: categoryColor,
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (pageNumber != null && totalPages != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pageNumber/$totalPages',
                    style: TextStyle(
                      fontSize: 32 * fontScale,
                      fontWeight: FontWeight.bold,
                      color: categoryColor,
                    ),
                  ),
                ),
            ],
          ),

          if (category != null || (pageNumber != null && totalPages != null))
            const SizedBox(height: 30),

          // タイトル
          Text(
            note.title.isEmpty ? '(タイトルなし)' : note.title,
            style: TextStyle(
              fontSize: 56 * fontScale,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 30),

          // コンテンツ（全内容またはチャンク）
          Text(
            displayContent,
            style: TextStyle(
              fontSize: 38 * fontScale,
              color: Colors.black54,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 40),

          // フッター
          _buildFooter(Colors.black26, categoryColor, fontScale),
        ],
      ),
    );
  }

  // グラデーションテンプレート（全内容表示）
  Widget _buildGradientCard() {
    final displayContent = contentChunk ?? note.content;
    final fontScale = cardStyle.fontSize.scale;
    final aspectRatio = cardStyle.aspectRatio;

    return Container(
      width: aspectRatio.width.toDouble(),
      constraints: BoxConstraints(minHeight: aspectRatio.height.toDouble()),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトルとページ番号
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.title.isEmpty ? '(タイトルなし)' : note.title,
                  style: TextStyle(
                    fontSize: 64 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),
              if (pageNumber != null && totalPages != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pageNumber/$totalPages',
                    style: TextStyle(
                      fontSize: 32 * fontScale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 40),

          // コンテンツ（全内容またはチャンク）
          Text(
            displayContent,
            style: TextStyle(
              fontSize: 42 * fontScale,
              color: Colors.white70,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 40),

          // フッター
          _buildFooter(Colors.white24, Colors.white, fontScale),
        ],
      ),
    );
  }

  // ダークモードテンプレート（全内容表示）
  Widget _buildDarkModeCard() {
    final displayContent = contentChunk ?? note.content;
    final fontScale = cardStyle.fontSize.scale;
    final aspectRatio = cardStyle.aspectRatio;

    return Container(
      width: aspectRatio.width.toDouble(),
      constraints: BoxConstraints(minHeight: aspectRatio.height.toDouble()),
      color: const Color(0xFF1a1a1a),
      padding: const EdgeInsets.all(80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトルとページ番号
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.title.isEmpty ? '(タイトルなし)' : note.title,
                  style: TextStyle(
                    fontSize: 64 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),
              if (pageNumber != null && totalPages != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pageNumber/$totalPages',
                    style: TextStyle(
                      fontSize: 32 * fontScale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 40),

          // コンテンツ（全内容またはチャンク）
          Text(
            displayContent,
            style: TextStyle(
              fontSize: 42 * fontScale,
              color: Colors.white60,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 40),

          // フッター
          _buildFooter(Colors.white12, Colors.white70, fontScale),
        ],
      ),
    );
  }

  // カラフルテンプレート（全内容表示）
  Widget _buildColorfulCard() {
    final displayContent = contentChunk ?? note.content;
    final fontScale = cardStyle.fontSize.scale;
    final aspectRatio = cardStyle.aspectRatio;

    return Container(
      width: aspectRatio.width.toDouble(),
      constraints: BoxConstraints(minHeight: aspectRatio.height.toDouble()),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange, width: 8),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトルとページ番号
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.title.isEmpty ? '(タイトルなし)' : note.title,
                  style: TextStyle(
                    fontSize: 64 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFe65100),
                    height: 1.3,
                  ),
                ),
              ),
              if (pageNumber != null && totalPages != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pageNumber/$totalPages',
                    style: TextStyle(
                      fontSize: 32 * fontScale,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFe65100),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 40),

          // コンテンツ（全内容またはチャンク）
          Text(
            displayContent,
            style: TextStyle(
              fontSize: 42 * fontScale,
              color: const Color(0xFF5d4037),
              height: 1.6,
            ),
          ),

          const SizedBox(height: 40),

          // フッター
          _buildFooter(Colors.orange[200]!, const Color(0xFFe65100), fontScale),
        ],
      ),
    );
  }

  // フッター（統計情報 + ロゴ）
  Widget _buildFooter(Color dividerColor, Color textColor, double fontScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 区切り線
        Container(
          height: 2,
          color: dividerColor,
        ),

        const SizedBox(height: 30),

        // 統計情報
        if (cardStyle.includeStats)
          Row(
            children: [
              Icon(
                Icons.text_fields,
                size: 32 * fontScale,
                color: textColor.withOpacity(0.7),
              ),
              const SizedBox(width: 12),
              Text(
                '${characterCount}文字',
                style: TextStyle(
                  fontSize: 28 * fontScale,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 40),
              Icon(
                Icons.calendar_today,
                size: 32 * fontScale,
                color: textColor.withOpacity(0.7),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('yyyy/MM/dd').format(note.createdAt),
                style: TextStyle(
                  fontSize: 28 * fontScale,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),

        if (cardStyle.includeStats && cardStyle.includeLogo)
          const SizedBox(height: 20),

        // ロゴ
        if (cardStyle.includeLogo)
          Row(
            children: [
              Icon(
                Icons.edit_note,
                size: 40 * fontScale,
                color: textColor.withOpacity(0.7),
              ),
              const SizedBox(width: 12),
              Text(
                'マイメモ',
                style: TextStyle(
                  fontSize: 32 * fontScale,
                  fontWeight: FontWeight.bold,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
      ],
    );
  }
}