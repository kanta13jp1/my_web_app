# cross-instance-pr: adobe_firefly + 01ai UI追加

作成: Windows版#62 (2026-04-13)
宛先: VSCode版 + PowerShell版
状態: done

---

## VSCode版 への依頼: `gemini_university_v2_page.dart` UI追加

`lib/pages/gemini_university_v2_page.dart` の `_providerMeta` / `_fallback` / `_quizzes` に追加。

### `_providerMeta` への追加

```dart
'adobe_firefly': ProviderMeta(
  displayName: 'Adobe Firefly',
  emoji: '🔥',
  color: Color(0xFFFF0000),
),
'01ai': ProviderMeta(
  displayName: '01.AI (Yi)',
  emoji: '🀄',
  color: Color(0xFF1A73E8),
),
```

### `_fallback` マップへの追加

```dart
'adobe_firefly': '''## Adobe Firefly とは
Adobeが開発するクリエイター向け生成AI。商業利用安全な学習データで差別化。
Photoshop/Illustratorと深く統合。Generative Fill・Generative Expand等の機能。

公式: https://firefly.adobe.com/''',

'01ai': '''## 01.AI (Yi) とは
李開復 (Kai-Fu Lee) が率いる中国AIスタートアップ。Yi-LightningはGPT-4o同等を激安で提供。
OpenAI互換APIで移行が容易。Yi-34B等のオープンソースモデルも公開中。

公式: https://www.01.ai/''',
```

### `_quizzes` マップへの追加

```dart
'adobe_firefly': [
  QuizQuestion(
    question: 'Adobe Fieflyの最大の差別化ポイントは何ですか？',
    options: ['商業利用安全な学習データ', '最高の画質', '無料で使える', '最速の生成速度'],
    correctIndex: 0,
    explanation: 'FireflyはAdobe Stockのライセンス取得コンテンツ等で学習しており、商業利用が安全です。',
  ),
  QuizQuestion(
    question: 'Adobe FireflyのPhotoshop統合機能で、選択範囲をAIで置換する機能は？',
    options: ['Generative Fill', 'Content-Aware Fill', 'Smart Fill', 'Magic Fill'],
    correctIndex: 0,
    explanation: 'Generative Fill (ジェネレーティブ塗りつぶし) はプロンプトで選択範囲を自動生成します。',
  ),
],
'01ai': [
  QuizQuestion(
    question: '01.AIを創業した著名人は誰ですか？',
    options: ['李開復 (Kai-Fu Lee)', '李飛飛 (Fei-Fei Li)', 'Andrew Ng', 'Yann LeCun'],
    correctIndex: 0,
    explanation: '元Google中国社長でSinovation Ventures創業者の李開復が2023年に設立。',
  ),
  QuizQuestion(
    question: '01.AIのYiシリーズLLMのオープンソースライセンスは何ですか？',
    options: ['Apache 2.0', 'MIT', 'GPL', 'LLAMA Community License'],
    correctIndex: 0,
    explanation: 'Yi-6B/34B等はApache 2.0ライセンスで公開され、商用利用が可能です。',
  ),
],
```

---

## PowerShell版 への依頼: `ai-university-update.yml` プロバイダー追加

Adobe FireflyとAdobeは公式RSSなし → 静的seedコンテンツ維持。
01.AIも公式RSSなし → 同様。

ファイル冒頭のプロバイダーリストコメントを更新:
- `現在43社` → `現在45社`
- リストの末尾に `adobe_firefly/01ai` を追加

---

## 根拠

- migrations: `20260413040000_seed_adobe_firefly_ai_university.sql` (44社目)
- migrations: `20260413041000_seed_01ai_ai_university.sql` (45社目)
- Adobe Firefly: 商業利用安全な生成AI。Photoshop統合。Creative Cloudの1億人ユーザー基盤
- 01.AI: 李開復創業。OpenAI互換API。Yi-Lightning $0.14/100万tokenの超低コスト
