class NoteTemplate {
  final String id;
  final String title;
  final String description;
  final String content;
  final String category;
  final List<String> tags;
  final int usageCount;
  final String? iconEmoji;
  final bool isPremium;

  NoteTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.category,
    required this.tags,
    this.usageCount = 0,
    this.iconEmoji,
    this.isPremium = false,
  });

  factory NoteTemplate.fromJson(Map<String, dynamic> json) {
    return NoteTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
      usageCount: json['usage_count'] as int? ?? 0,
      iconEmoji: json['icon_emoji'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'category': category,
      'tags': tags,
      'usage_count': usageCount,
      'icon_emoji': iconEmoji,
      'is_premium': isPremium,
    };
  }

  // 人気のテンプレート（デフォルト）
  static List<NoteTemplate> getDefaultTemplates() {
    return [
      // 仕事・ビジネス
      NoteTemplate(
        id: 'meeting_notes',
        title: '会議メモ',
        description: '会議の議事録を効率的に記録',
        content: '''# 会議メモ

## 日時
yyyy/mm/dd HH:MM

## 参加者
-

## 議題
1.

## 決定事項
-

## アクションアイテム
- [ ]
- [ ]

## 次回会議
yyyy/mm/dd HH:MM
''',
        category: '仕事',
        tags: ['会議', 'ビジネス', '議事録'],
        iconEmoji: '📝',
      ),

      NoteTemplate(
        id: 'project_plan',
        title: 'プロジェクト計画',
        description: 'プロジェクトの目標とタスクを整理',
        content: '''# プロジェクト計画

## 🎯 目標


## 📅 期限


## 👥 担当者


## 📋 タスクリスト
- [ ]
- [ ]
- [ ]

## 📊 進捗状況
0%

## 📝 メモ

''',
        category: '仕事',
        tags: ['プロジェクト', '計画', 'タスク'],
        iconEmoji: '🎯',
      ),

      // 学習
      NoteTemplate(
        id: 'study_note',
        title: '学習ノート',
        description: '勉強したことを体系的に記録',
        content: '''# 学習ノート

## 📚 教材・参考書


## 🎯 学習目標


## 📝 要点
-
-
-

## 💡 重要ポイント


## 🤔 疑問点
-

## 📌 復習予定
yyyy/mm/dd
''',
        category: '学習',
        tags: ['勉強', '学習', 'ノート'],
        iconEmoji: '📚',
      ),

      NoteTemplate(
        id: 'book_summary',
        title: '読書メモ',
        description: '本の内容を要約して記録',
        content: '''# 読書メモ

## 📖 書籍情報
- タイトル:
- 著者:
- 出版社:

## ⭐ 評価
★★★★★

## 📝 要約


## 💡 印象に残ったこと
-
-
-

## 🎯 実践したいこと
- [ ]
- [ ]

## 📌 引用


''',
        category: '学習',
        tags: ['読書', '本', '要約'],
        iconEmoji: '📖',
      ),

      // 個人
      NoteTemplate(
        id: 'daily_journal',
        title: '日記',
        description: '毎日の記録を残す',
        content: '''# 日記

## 📅 日付
yyyy/mm/dd (曜日)

## ☀️ 今日の天気


## 😊 今日の気分
★★★★★

## 📝 今日の出来事


## 💡 学んだこと


## 🙏 感謝したこと
-
-

## 📅 明日の予定

''',
        category: '個人',
        tags: ['日記', '日常', '記録'],
        iconEmoji: '📔',
      ),

      NoteTemplate(
        id: 'goal_setting',
        title: '目標設定',
        description: '目標を明確にして行動計画を立てる',
        content: '''# 目標設定

## 🎯 メイン目標


## 🗓️ 期限
yyyy/mm/dd

## 📊 現状


## 💪 達成するためのアクション
1. [ ]
2. [ ]
3. [ ]

## 🏆 成功の定義


## 📈 進捗確認方法


## 💭 メモ

''',
        category: '個人',
        tags: ['目標', '計画', '自己啓発'],
        iconEmoji: '🎯',
      ),

      // アイデア
      NoteTemplate(
        id: 'brainstorm',
        title: 'ブレインストーミング',
        description: 'アイデアを自由に書き出す',
        content: '''# ブレインストーミング

## 🎨 テーマ


## 💡 アイデア
-
-
-
-
-

## ⭐ ベストアイデア


## 📝 次のステップ
- [ ]

''',
        category: 'アイデア',
        tags: ['アイデア', 'ブレスト', '発想'],
        iconEmoji: '💡',
      ),

      // 健康・ライフスタイル
      NoteTemplate(
        id: 'workout_log',
        title: '運動記録',
        description: 'トレーニング内容を記録',
        content: '''# 運動記録

## 📅 日付
yyyy/mm/dd

## 🏋️ トレーニング内容
-
-
-

## ⏱️ 運動時間
分

## 💪 体調


## 🎯 次回の目標

''',
        category: '健康',
        tags: ['運動', 'トレーニング', '健康'],
        iconEmoji: '🏋️',
      ),

      NoteTemplate(
        id: 'meal_plan',
        title: '食事記録',
        description: '食事内容と栄養管理',
        content: '''# 食事記録

## 📅 日付
yyyy/mm/dd

## 🌅 朝食


## 🌞 昼食


## 🌙 夕食


## 🍎 間食


## 💧 水分摂取
mL

## 💭 メモ

''',
        category: '健康',
        tags: ['食事', '健康', '栄養'],
        iconEmoji: '🍽️',
      ),

      // 旅行
      NoteTemplate(
        id: 'travel_plan',
        title: '旅行計画',
        description: '旅行の予定と持ち物リスト',
        content: '''# 旅行計画

## 🗺️ 目的地


## 📅 日程
yyyy/mm/dd - yyyy/mm/dd

## 🏨 宿泊先


## ✈️ 交通手段


## 📋 訪問予定地
- [ ]
- [ ]
- [ ]

## 🎒 持ち物リスト
- [ ] パスポート
- [ ] 財布
- [ ] スマホ・充電器
- [ ]

## 💰 予算


## 📝 メモ

''',
        category: '旅行',
        tags: ['旅行', '計画', 'トラベル'],
        iconEmoji: '✈️',
      ),
    ];
  }
}
