---
title: "スマホ版Claude Codeで5インスタンス制に移行した話 — モバイルバグをリアルタイムにトリアージ"
tags: ClaudeCode,個人開発,Flutter,buildinpublic,mobile
published: false
---

# スマホ版Claude Codeで5インスタンス制に移行した話

## 3インスタンス → 5インスタンスへ

以前「[3インスタンス並行で月$20の開発](https://dev.to/kanta13jp1/running-3-parallel-claude-code-instances-to-get-200-of-dev-work-for-20month-294a)」を書きました。

今回、**スマホ版 (Claude Code モバイルアプリ)** と **WEB版** を追加して5インスタンス制に移行しました。

### 5インスタンスの役割分担

| インスタンス | 専任タスク |
|-----------|-----------|
| **VSCode版** | UI/デザイン改善 (Rule12/19) |
| **PowerShell版** | CI/CD健全性 (Rule17) + ブログ投稿 |
| **Windowsアプリ版** | AI大学プロバイダー追加 + migration |
| **WEB版** | 競合リサーチ + ブログ下書き (notebooklm) |
| **📱スマホ版** | 実機UAT + モバイル不具合トリアージ |

## スマホ版が解決する問題

### 問題: デスクトップ版はモバイル体験を検出できない

デスクトップの開発環境でいくら `flutter analyze` を通しても、
スマホで実際に触って初めて発覚するバグがある。

**今回の実例:**
- PR #497: ノートエディタでスマホキーボードが開くとボタンが隠れる
- PR #504: コックピット画面のActionChipラベルがダークテーマで読めない

両方とも「デスクトップのChrome開発ツールのモバイルエミュレーション」では発見できず、
実機で触って初めて気づいた問題だった。

### スマホ版の役割: `mobile-bug-triage` スキル

```markdown
# mobile-bug-triage スキル

実機でバグを発見したら:
1. スクリーンショット + 再現手順を記録
2. GitHub Issue を作成 (#priority:high タグ付き)
3. VSCode版への cross-instance-pr を作成
   → VSCode版が次セッションで修正

対象: レイアウト崩れ / keyboard overlap / タップ反応 / スクロール不具合
```

スマホ版は「修正しない」。**発見して報告するだけ**。

修正はデスクトップ版(VSCode版)の専任。

## keyboard overlap の修正パターン

スマホでキーボードが開くと `Scaffold` の `body` が圧縮されて、
固定ボタンがキーボードで隠れる問題。

```dart
// ❌ 問題のある実装
Scaffold(
  body: Column(
    children: [
      Expanded(child: NoteEditor()),
      BottomActionBar(),  // キーボード表示時に隠れる
    ],
  ),
)

// ✅ resizeToAvoidBottomInset で解決
Scaffold(
  resizeToAvoidBottomInset: true,  // デフォルトtrue、明示的に指定
  body: Column(
    children: [
      Expanded(child: NoteEditor()),
      BottomActionBar(),
    ],
  ),
)

// または SafeArea + MediaQuery.viewInsets で動的制御
Padding(
  padding: EdgeInsets.only(
    bottom: MediaQuery.of(context).viewInsets.bottom,
  ),
  child: BottomActionBar(),
)
```

## ActionChip ダークテーマのコントラスト問題

Flutter の `ActionChip` はデフォルトで `Theme.of(context).colorScheme.surface` を背景に使う。
ダークテーマで `surface` が暗いと、ラベルテキストが読めなくなる。

```dart
// ❌ テーマ依存でダークテーマで見えなくなる
ActionChip(
  label: Text(label),
)

// ✅ 明示的なコントラスト確保
ActionChip(
  label: Text(
    label,
    style: const TextStyle(color: Color(0xFFE2E8F0)),  // 明示的な明色
  ),
  backgroundColor: const Color(0xFF334155),  // 明示的な暗色背景
)
```

## まとめ

| インスタンス追加 | 解決した問題 |
|---------------|-------------|
| スマホ版 | デスクトップで検出できないモバイルUX問題 |
| WEB版 | notebooklm + 競合リサーチ (ローカル環境不要) |

5インスタンスで月$20のまま。
専任分業のおかげで、各インスタンスは「自分の担当範囲だけ深く知る」設計になっています。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#ClaudeCode #FlutterWeb #buildinpublic #mobile #個人開発
