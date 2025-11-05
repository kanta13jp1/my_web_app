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

  // ミニマルテンプレート
  Widget _buildMinimalCard() {
    return Container(
      width: 1080,
      height: 1080,
      color: Colors.white,
      padding: const EdgeInsets.all(80),
      child: Column(
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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 40),
          
          // コンテンツ
          Expanded(
            child: Text(
              note.content,
              style: const TextStyle(
                fontSize: 42,
                color: Colors.black54,
                height: 1.6,
              ),
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // フッター
          _buildFooter(Colors.black26, Colors.black54),
        ],
      ),
    );
  }

  // モダンテンプレート
  Widget _buildModernCard() {
    final categoryColor = category != null
        ? Color(int.parse(category!.color.substring(1), radix: 16) + 0xFF000000)
        : Colors.blue;

    return Container(
      width: 1080,
      height: 1080,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: categoryColor, width: 20),
        ),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カテゴリバッジ
          if (category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: categoryColor, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category!.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    category!.name,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: categoryColor,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 40),
          
          // タイトル
          Text(
            note.title.isEmpty ? '(タイトルなし)' : note.title,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 40),
          
          // コンテンツ
          Expanded(
            child: Text(
              note.content,
              style: const TextStyle(
                fontSize: 42,
                color: Colors.black54,
                height: 1.6,
              ),
              maxLines: 10,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // フッター
          _buildFooter(Colors.black26, categoryColor),
        ],
      ),
    );
  }

  // グラデーションテンプレート
  Widget _buildGradientCard() {
    final categoryColor = category != null
        ? Color(int.parse(category!.color.substring(1), radix: 16) + 0xFF000000)
        : Colors.blue;

    return Container(
      width: 1080,
      height: 1080,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor,
            categoryColor.withValues(alpha: 0.6),
          ],
        ),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
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
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 40),
          
          // コンテンツ
          Expanded(
            child: Text(
              note.content,
              style: const TextStyle(
                fontSize: 42,
                color: Colors.white,
                height: 1.6,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // フッター
          _buildFooter(Colors.white70, Colors.white),
        ],
      ),
    );
  }

  // ダークモードテンプレート
  Widget _buildDarkModeCard() {
    return Container(
      width: 1080,
      height: 1080,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1a1a1a),
            Color(0xFF0d0d0d),
          ],
        ),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 40),
          
          // コンテンツ
          Expanded(
            child: Text(
              note.content,
              style: const TextStyle(
                fontSize: 42,
                color: Colors.white70,
                height: 1.6,
              ),
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // フッター
          _buildFooter(Colors.white24, Colors.white70),
        ],
      ),
    );
  }

  // カラフルテンプレート
  Widget _buildColorfulCard() {
    return Container(
      width: 1080,
      height: 1080,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF6B6B),
            Color(0xFFFFE66D),
            Color(0xFF4ECDC4),
            Color(0xFF95E1D3),
          ],
          stops: [0.0, 0.33, 0.66, 1.0],
        ),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              note.title.isEmpty ? '(タイトルなし)' : note.title,
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // コンテンツ
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                note.content,
                style: const TextStyle(
                  fontSize: 38,
                  color: Colors.black87,
                  height: 1.6,
                ),
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // フッター
          _buildFooter(Colors.white, Colors.white),
        ],
      ),
    );
  }

  // 共通フッター
  Widget _buildFooter(Color dividerColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: dividerColor, thickness: 2),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 統計情報
            if (cardStyle.includeStats)
              Row(
                children: [
                  Icon(Icons.text_fields, color: textColor, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    '$characterCount文字',
                    style: TextStyle(fontSize: 28, color: textColor),
                  ),
                  const SizedBox(width: 24),
                  Icon(Icons.calendar_today, color: textColor, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy/MM/dd').format(note.createdAt),
                    style: TextStyle(fontSize: 28, color: textColor),
                  ),
                ],
              ),
            
            // ロゴ
            if (cardStyle.includeLogo)
              Row(
                children: [
                  Icon(Icons.note_alt, color: textColor, size: 40),
                  const SizedBox(width: 12),
                  Text(
                    'マイメモ',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}