import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/category.dart';
import '../models/card_template.dart';
import 'package:intl/intl.dart';

class NoteCardWidget extends StatelessWidget {
  final Note note;
  final Category? category;
  final CardStyle cardStyle;
  final int wordCount;
  final int characterCount;

  const NoteCardWidget({
    super.key,
    required this.note,
    this.category,
    required this.cardStyle,
    required this.wordCount,
    required this.characterCount,
  });

  @override
  Widget build(BuildContext context) {
    switch (cardStyle.template) {
      case CardTemplate.minimal:
        return _buildMinimalCard();
      case CardTemplate.modern:
        return _buildModernCard();
      case CardTemplate.gradient:
        return _buildGradientCard();
      case CardTemplate.darkMode:
        return _buildDarkModeCard();
      case CardTemplate.colorful:
        return _buildColorfulCard();
    }
  }

  // ミニマルテンプレート（全内容表示）
  Widget _buildMinimalCard() {
    return Container(
      width: 1080,
      constraints: const BoxConstraints(minHeight: 1080),
      color: Colors.white,
      padding: const EdgeInsets.all(80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル
          Text(
            note.title.isEmpty ? '(タイトルなし)' : note.title,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 40),
          
          // コンテンツ（全内容）
          Text(
            note.content,
            style: const TextStyle(
              fontSize: 42,
              color: Colors.black54,
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // フッター
          _buildFooter(Colors.black26, Colors.black54),
        ],
      ),
    );
  }

  // モダンテンプレート（全内容表示）
  Widget _buildModernCard() {
    final categoryColor = category != null
        ? Color(int.parse(category!.color.substring(1), radix: 16) + 0xFF000000)
        : Colors.blue;

    return Container(
      width: 1080,
      constraints: const BoxConstraints(minHeight: 1080),
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
          // カテゴリバッジ
          if (category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '# ${category!.name}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: categoryColor,
                ),
              ),
            ),
          
          if (category != null) const SizedBox(height: 30),
          
          // タイトル
          Text(
            note.title.isEmpty ? '(タイトルなし)' : note.title,
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          
          const SizedBox(height: 30),
          
          // コンテンツ（全内容）
          Text(
            note.content,
            style: const TextStyle(
              fontSize: 38,
              color: Colors.black54,
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // フッター
          _buildFooter(Colors.black26, categoryColor),
        ],
      ),
    );
  }

  // グラデーションテンプレート（全内容表示）
  Widget _buildGradientCard() {
    return Container(
      width: 1080,
      constraints: const BoxConstraints(minHeight: 1080),
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
          // タイトル
          Text(
            note.title.isEmpty ? '(タイトルなし)' : note.title,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // コンテンツ（全内容）
          Text(
            note.content,
            style: const TextStyle(
              fontSize: 42,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // フッター
          _buildFooter(Colors.white24, Colors.white),
        ],
      ),
    );
  }

  // ダークモードテンプレート（全内容表示）
  Widget _buildDarkModeCard() {
    return Container(
      width: 1080,
      constraints: const BoxConstraints(minHeight: 1080),
      color: const Color(0xFF1a1a1a),
      padding: const EdgeInsets.all(80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル
          Text(
            note.title.isEmpty ? '(タイトルなし)' : note.title,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // コンテンツ（全内容）
          Text(
            note.content,
            style: const TextStyle(
              fontSize: 42,
              color: Colors.white60,
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // フッター
          _buildFooter(Colors.white12, Colors.white70),
        ],
      ),
    );
  }

  // カラフルテンプレート（全内容表示）
  Widget _buildColorfulCard() {
    return Container(
      width: 1080,
      constraints: const BoxConstraints(minHeight: 1080),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange, width: 8),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル
          Text(
            note.title.isEmpty ? '(タイトルなし)' : note.title,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Color(0xFFe65100),
              height: 1.3,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // コンテンツ（全内容）
          Text(
            note.content,
            style: const TextStyle(
              fontSize: 42,
              color: Color(0xFF5d4037),
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // フッター
          _buildFooter(Colors.orange[200]!, const Color(0xFFe65100)),
        ],
      ),
    );
  }

  // フッター（統計情報 + ロゴ）
  Widget _buildFooter(Color dividerColor, Color textColor) {
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
                size: 32,
                color: textColor.withOpacity(0.7),
              ),
              const SizedBox(width: 12),
              Text(
                '${characterCount}文字',
                style: TextStyle(
                  fontSize: 28,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 40),
              Icon(
                Icons.calendar_today,
                size: 32,
                color: textColor.withOpacity(0.7),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('yyyy/MM/dd').format(note.createdAt),
                style: TextStyle(
                  fontSize: 28,
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
                size: 40,
                color: textColor.withOpacity(0.7),
              ),
              const SizedBox(width: 12),
              Text(
                'マイメモ',
                style: TextStyle(
                  fontSize: 32,
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