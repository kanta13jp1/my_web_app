import 'package:flutter/material.dart';

/// 「酒・煙草・風俗をやめよう」応援キャンペーンの動画シェア機能で扱う
/// 1 本の動画を表す純データモデル。
///
/// Supabase 非依存 (プレーンな値オブジェクト) にして単体テストを VM 上で
/// そのまま走らせられるようにしている。フィードは端末ローカルの seed +
/// ユーザー投稿で構成し、外部バックエンドが無くても成立する。
enum CampaignCategory {
  /// 禁酒
  alcohol,

  /// 禁煙
  tobacco,

  /// 脱・風俗 (性的依存からの回復)
  fuzoku,
}

extension CampaignCategoryX on CampaignCategory {
  /// フィルタチップ等に出す日本語ラベル。
  String get label {
    switch (this) {
      case CampaignCategory.alcohol:
        return '禁酒';
      case CampaignCategory.tobacco:
        return '禁煙';
      case CampaignCategory.fuzoku:
        return '脱・風俗';
    }
  }

  /// 動画フレームや見出しに添える絵文字。
  String get emoji {
    switch (this) {
      case CampaignCategory.alcohol:
        return '🍺';
      case CampaignCategory.tobacco:
        return '🚬';
      case CampaignCategory.fuzoku:
        return '🌙';
    }
  }

  IconData get icon {
    switch (this) {
      case CampaignCategory.alcohol:
        return Icons.no_drinks;
      case CampaignCategory.tobacco:
        return Icons.smoke_free;
      case CampaignCategory.fuzoku:
        return Icons.self_improvement;
    }
  }

  /// 動画フレームのグラデーションに使うアクセント色。
  Color get accent {
    switch (this) {
      case CampaignCategory.alcohol:
        return const Color(0xFFFF8C5A); // orangeLight 系
      case CampaignCategory.tobacco:
        return const Color(0xFF4CAF50); // green
      case CampaignCategory.fuzoku:
        return const Color(0xFF7986CB); // indigoLight
    }
  }

  /// シェア文に付けるハッシュタグ。
  String get hashtag {
    switch (this) {
      case CampaignCategory.alcohol:
        return '#禁酒チャレンジ';
      case CampaignCategory.tobacco:
        return '#禁煙チャレンジ';
      case CampaignCategory.fuzoku:
        return '#脱風俗';
    }
  }
}

class CampaignVideo {
  const CampaignVideo({
    required this.id,
    required this.category,
    required this.title,
    required this.caption,
    required this.creatorName,
    required this.creatorHandle,
    this.videoUrl,
    this.verified = false,
    this.likes = 0,
    this.comments = 0,
    this.reposts = 0,
  });

  final String id;
  final CampaignCategory category;

  /// 動画フレームに大きく重ねるタイトル (例: 『ビール通りとジン横丁』)。
  final String title;

  /// 作者の投稿本文 (例: 【衝撃】18世紀ロンドンの風刺画…)。
  final String caption;

  final String creatorName;
  final String creatorHandle;

  /// 共有 / 再生に使う URL。null の場合はローカル生成の応援メッセージのみ。
  final String? videoUrl;

  final bool verified;
  final int likes;
  final int comments;
  final int reposts;

  /// シェアシートに渡す本文を組み立てる。
  String shareText() {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln(caption)
      ..writeln()
      ..writeln('酒・煙草・風俗をやめよう応援キャンペーン ${category.hashtag}');
    if (videoUrl != null && videoUrl!.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(videoUrl);
    }
    return buffer.toString().trimRight();
  }

  CampaignVideo copyWith({int? likes, int? reposts}) {
    return CampaignVideo(
      id: id,
      category: category,
      title: title,
      caption: caption,
      creatorName: creatorName,
      creatorHandle: creatorHandle,
      videoUrl: videoUrl,
      verified: verified,
      likes: likes ?? this.likes,
      comments: comments,
      reposts: reposts ?? this.reposts,
    );
  }

  /// キャンペーン初期フィード (端末ローカル seed)。
  static List<CampaignVideo> seed() {
    return const [
      CampaignVideo(
        id: 'seed-alcohol-hogarth',
        category: CampaignCategory.alcohol,
        title: '『ビール通りとジン横丁』',
        caption: '【衝撃】18世紀ロンドンの風刺画が今も刺さる。安酒に溺れた街の末路とは。',
        creatorName: '最適な食べ物たち',
        creatorHandle: '@sobriety_lab',
        verified: true,
        likes: 3658,
        comments: 53,
        reposts: 364,
      ),
      CampaignVideo(
        id: 'seed-alcohol-30days',
        category: CampaignCategory.alcohol,
        title: '禁酒30日でこう変わる',
        caption: '睡眠の質・肌・貯金・集中力。1ヶ月やめただけで戻ってきたもの。',
        creatorName: 'しらふ研究所',
        creatorHandle: '@no_drink_days',
        likes: 1284,
        comments: 41,
        reposts: 96,
      ),
      CampaignVideo(
        id: 'seed-tobacco-lungs',
        category: CampaignCategory.tobacco,
        title: '最後の一本にする理由',
        caption: '禁煙20分後から体は回復を始める。今日が一番若い日。',
        creatorName: 'クリーンエア',
        creatorHandle: '@smoke_free_jp',
        verified: true,
        likes: 2041,
        comments: 88,
        reposts: 210,
      ),
      CampaignVideo(
        id: 'seed-tobacco-money',
        category: CampaignCategory.tobacco,
        title: 'タバコ代を10年で計算した',
        caption: '1日1箱で約190万円。何に使えたかを可視化してみた。',
        creatorName: '節約ドクター',
        creatorHandle: '@quit_and_save',
        likes: 908,
        comments: 27,
        reposts: 73,
      ),
      CampaignVideo(
        id: 'seed-fuzoku-recovery',
        category: CampaignCategory.fuzoku,
        title: '依存から抜けた人の1年',
        caption: '性的依存は意志の弱さではなく仕組みの問題。回復のための3ステップ。',
        creatorName: 'リカバリーノート',
        creatorHandle: '@recovery_note',
        verified: true,
        likes: 1562,
        comments: 64,
        reposts: 118,
      ),
    ];
  }
}
