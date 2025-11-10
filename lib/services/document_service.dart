import 'package:flutter/services.dart';
import '../models/document.dart';

class DocumentService {
  // ドキュメントのカテゴリとファイルのマッピング
  static const Map<String, List<String>> _documentFiles = {
    'roadmaps': [
      'GROWTH_STRATEGY_ROADMAP.md',
      'BUSINESS_OPERATIONS_PLAN.md',
      'COMPETITOR_ANALYSIS_2025.md',
    ],
    'user-docs': [
      'GAMIFICATION_README.md',
      'GROWTH_FEATURES.md',
    ],
    'session-summaries': [
      'SESSION_SUMMARY_2025-11-10_GROWTH_STRATEGY.md',
      'SESSION_SUMMARY_2025-11-10.md',
      'SESSION_SUMMARY_2025-11-09_TIMER_FEATURE.md',
      'SESSION_SUMMARY_2025-11-09_CRITICAL_BUG_FIXES.md',
      'SESSION_SUMMARY_2025-11-08_GROWTH_ACCELERATION.md',
      'SESSION_SUMMARY_2025-11-08_BUSINESS_PLAN.md',
      'SESSION_SUMMARY_2025-11-08.md',
      'PROJECT_ANALYSIS_2025-11-08.md',
    ],
    'technical': [
      'BACKEND_MIGRATION_PLAN.md',
      'CORS_FIX.md',
      'NETLIFY_DEPLOY.md',
      'SUPABASE_EDGE_FUNCTIONS_DEPLOY.md',
      'IMPROVEMENTS.md',
      'FILE_ATTACHMENT_FIX.md',
      'GEMINI_MIGRATION_GUIDE.md',
      'NETLIFY_COST_OPTIMIZATION.md',
      'SUPABASE_MIGRATION_MANUAL_DEPLOY.md',
      'TIMER_FEATURE_DESIGN.md',
    ],
    'release-notes': [],
  };

  /// すべてのドキュメントのリストを取得
  static List<DocumentItem> getAllDocuments() {
    final List<DocumentItem> documents = [];

    // README.mdを最初に追加
    documents.add(DocumentItem(
      id: 'readme',
      title: 'ドキュメント構成',
      category: 'root',
      path: 'docs/README.md',
    ));

    // 各カテゴリのドキュメントを追加
    _documentFiles.forEach((category, files) {
      for (final file in files) {
        documents.add(DocumentItem(
          id: '${category}_${file}',
          title: _formatTitle(file),
          category: category,
          path: 'docs/$category/$file',
        ));
      }
    });

    return documents;
  }

  /// カテゴリ別にドキュメントを取得
  static Map<String, List<DocumentItem>> getDocumentsByCategory() {
    final Map<String, List<DocumentItem>> categorized = {
      'root': [],
      'release-notes': [],
      'roadmaps': [],
      'user-docs': [],
      'session-summaries': [],
      'technical': [],
    };

    for (final doc in getAllDocuments()) {
      categorized[doc.category]?.add(doc);
    }

    return categorized;
  }

  /// ドキュメントの内容を読み込む
  static Future<String> loadDocument(String path) async {
    try {
      print('📄 [DocumentService] Loading document from path: $path');
      final content = await rootBundle.loadString(path);
      print('✅ [DocumentService] Document loaded successfully: ${content.length} characters');
      return content;
    } catch (e, stackTrace) {
      print('❌ [DocumentService] Failed to load document from path: $path');
      print('❌ [DocumentService] Error: $e');
      print('❌ [DocumentService] Error type: ${e.runtimeType}');
      print('❌ [DocumentService] Stack trace: $stackTrace');

      // 特定のエラーを検出
      if (e.toString().contains('Unable to load asset')) {
        print('⚠️ [DocumentService] Asset not found - check pubspec.yaml assets configuration');
        print('⚠️ [DocumentService] Expected path: $path');
      }

      return '# エラー\n\nドキュメントの読み込みに失敗しました。\n\nパス: $path\nエラー: $e';
    }
  }

  /// ファイル名からタイトルをフォーマット
  static String _formatTitle(String filename) {
    // .md拡張子を削除
    final nameWithoutExtension = filename.replaceAll('.md', '');

    // アンダースコアをスペースに置き換え
    final formatted = nameWithoutExtension.replaceAll('_', ' ');

    return formatted;
  }

  /// IDからドキュメントを検索
  static DocumentItem? findDocumentById(String id) {
    try {
      return getAllDocuments().firstWhere((doc) => doc.id == id);
    } catch (e) {
      return null;
    }
  }

  /// カテゴリの表示名を取得
  static String getCategoryDisplayName(String category) {
    switch (category) {
      case 'root':
        return 'ドキュメントホーム';
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

  /// カテゴリのアイコンを取得
  static String getCategoryIcon(String category) {
    switch (category) {
      case 'root':
        return '🏠';
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
