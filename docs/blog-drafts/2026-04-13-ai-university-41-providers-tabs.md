# blog draft 2026-04-13

## title candidates

1. AI大学41社体制 + ノートエディタにタブブロック追加
2. Flutter Web で実現する AI 大学 -- 41社のプロバイダーをDB駆動で管理する方法
3. Notion の /tabs コマンドを Flutter ノートエディタに移植してみた

## targets

- Zenn
- dev.to (English)

## draft

### introduction

2026-04-13 の自分株式会社開発ログ。本日は2実装を完了。

1. AI大学 41社体制完成 -- Qwen (Alibaba) と Moonshot AI (Kimi) を追加
2. ノートエディタに /tabs コマンド追加 -- Notion 3.4 タブブロック機能パリティ実装

---

### AI大学 41社体制完成

AI大学はDB駆動タブで主要 AI プロバイダーを学習できるコンテンツです。
Qwen (Alibaba Cloud) と Moonshot AI を追加し、計 41社体制になりました。

#### Qwen (Alibaba Cloud)

特徴:
- Qwen2.5-72B は HuggingFace 公開のオープンソース LLM 最強クラス
- DashScope API は OpenAI SDK 互換 -- base_url 変更のみで移行可能
- 29言語ネイティブ対応 (日本語・中国語・英語)
- Apache 2.0 ライセンスで商用利用可

#### Moonshot AI (Kimi)

特徴:
- Kimi v1-128k: 128K トークンのコンテキスト対応
- PDF/Word ファイルを直接アップロードして処理可能
- OpenAI API 完全互換

#### DB 駆動アーキテクチャ

ai_university_content テーブルで管理。
GitHub Actions の ai-university-update.yml が2時間毎に RSS から自動更新。

---

### ノートエディタ /tabs コマンド追加

Notion 3.4 のタブブロック機能に相当する /tabs コマンドを Flutter ノートエディタに実装。

```dart
void _appendTabsBlock() {
  const tabsTemplate = '## Tab 1\n\n(content here)\n\n---\n\n'
      '## Tab 2\n\n(content here)\n\n---\n\n'
      '## Tab 3\n\n(content here)';
  final current = _contentController.text.trimRight();
  final nextContent =
      current.isEmpty ? tabsTemplate : '$current\n\n$tabsTemplate';
  _setContentText(nextContent);
}
```

Markdown ベースなので Zenn・GitHub・Notion にエクスポートしても壊れない。

---

### summary

| impl | effect |
|------|--------|
| AI university 41 providers (Qwen, Moonshot) | Asia AI provider coverage |
| /tabs command | Notion parity -- quick tab structure notes |

URL: https://my-web-app-b67f4.web.app/

#FlutterWeb #Supabase #buildinpublic
