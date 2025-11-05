import '../models/share_card_content_mode.dart';

/// コンテンツを複数のチャンクに分割するユーティリティクラス
class ContentChunkProcessor {
  /// コンテンツを複数のチャンクに分割（動的文字数制限）
  static List<String> splitContent(
    String content,
    ShareCardContentMode contentMode,
  ) {
    final maxChars = contentMode.maxCharsPerPage;

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
        if (i < content.length &&
            (content[i] == '。' ||
                content[i] == '.' ||
                content[i] == '\n' ||
                content[i] == ' ')) {
          splitIndex = i + 1;
          break;
        }
      }

      chunks.add(content.substring(startIndex, splitIndex));
      startIndex = splitIndex;
    }

    return chunks;
  }
}
