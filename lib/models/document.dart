class DocumentItem {
  final String id;
  final String title;
  final String category;
  final String path;
  final DateTime? lastModified;

  DocumentItem({
    required this.id,
    required this.title,
    required this.category,
    required this.path,
    this.lastModified,
  });

  String get categoryDisplayName {
    switch (category) {
      case 'release-notes':
        return 'リリースノート';
      case 'roadmaps':
        return 'ロードマップ';
      case 'user-docs':
        return 'ユーザードキュメント';
      case 'session-summaries':
        return 'セッションサマリー';
      case 'technical':
        return '技術ドキュメント';
      default:
        return 'その他';
    }
  }

  String get categoryIcon {
    switch (category) {
      case 'release-notes':
        return '📝';
      case 'roadmaps':
        return '🗺️';
      case 'user-docs':
        return '📚';
      case 'session-summaries':
        return '📊';
      case 'technical':
        return '🔧';
      default:
        return '📄';
    }
  }
}
