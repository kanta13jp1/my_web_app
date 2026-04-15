# Copilot Inline Chat 検証 (2026-04-16)

## 対象ファイル

`lib/pages/horse_racing_predictor_page.dart` (1019行)

## 検証目的

GitHub Copilot Inline Chat (`Ctrl+I`) の効果測定・効率性確認

---

## 提案改善案（優先度順）

### 🟢 高優先度（即実装可能・効果大）

#### 1. エラーハンドリング改善

**現状:**

```dart
} catch (e) {
  if (mounted) setState(() => _error = 'データ取得失敗: $e');
}
```

**問題:**
- ユーザーが実行可能なアクション（再試行など）が不明確
- ネットワーク遅延 vs API エラー の判別ができない

**改善案:**
- エラー種別別の UI 表示（Network / API / Unknown）
- リトライボタンの動的表示（ネットワーク遅延時のみ）

#### 2. ローディング UX の改善

**現状:**

```dart
body: _isLoading
    ? const Center(child: CircularProgressIndicator())
```

**問題:**
- 3つの並列 API 呼び出し（races / predictions / accuracy）の進捗が不明
- ユーザーが「どの処理が遅いか」わからない

**改善案:**
- LinearProgressIndicator（3段階 33% → 66% → 100%）
- 各段階のラベル表示（"レースデータ取得中..." → "予想履歴取得中..." → "統計計算中..."）

#### 3. Tab 未初期化時の処理

**現状:**

```dart
_tabController = TabController(length: 3, vsync: this);
```

**問題:**
- 初期状態でタブ 0 が選択されるが、他タブ（History / Accuracy）は遅延ロードが未実装
- 結果表示時に空白になる可能性

**改善案:**
- `_tabController.addListener` で各タブ切り替え時に遅延ロード
- 各タブのデータ独立化（`_loadHistory()` / `_loadAccuracy()`）

---

### 🟡 中優先度（設計が必要・改善スコープ大）

#### 4. AI 予想実行のエラー処理

**現状:**

```dart
Future<void> _runAiPredictions() async {
  setState(() => _isPredicting = true);
  try {
    final r = await _supabase.functions.invoke(
      'tools-hub',
      // ...
    );
```

**問題:**
- 予想実行の UI フィードバック（進捗 % / 予想中のレース数表示）なし
- 失敗時のロールバック処理が不明確

**改善案:**
- `AI予想を今すぐ実行` ボタン → `予想実行中 (3/12)` へ動的更新
- キャンセルボタン（長時間実行時）
- 予想失敗時の部分保存

#### 5. Design Token 統一（既実装確認）

**現状:** ✅ Orange `Color(0xFFFF6B35)` で統一完了
**次手:** 他ページとの 1ページコンポーネント統一チェック

---

### 🔵 低優先度（UI/UX 洗練・将来対応）

#### 6. 過去予想の絞り込み

**提案:** 日付フィルタ・馬名検索
**スコープ:** 大（UI + EF 拡張）

#### 7. ランキング・統計ビジュアル

**提案:** 的中率チャート（円グラフ / 折れ線グラフ）
**スコープ:** 大（新ライブラリ検討）

---

## 実装順序（セッション内）

1. ✅ **高優先度#1**: エラーハンドリング改善（15分）
2. ⏳ **高優先度#2**: ローディング UX（20分）
3. 🔄 **中優先度#4**: AI予想進捗表示（タスク #2 UI改善に委譲）

---

## Copilot Inline Chat 実装ログ

### ✅ 改善#1: エラーハンドリング改善（完了）

**実装内容:**
1. `ErrorType` enum 追加 (network / api / unknown)
2. `_parseErrorType()` ユーティリティ関数を追加
   - ネットワークエラー: `timeout` / `socket` / `connection refused` 判別
   - API エラー: `statuscode` / `400` / `401` / `500` 判別
3. State に `ErrorType? _errorType` 状態変数追加
4. `_loadAll()` catch ブロック改善
   - エラー種別別のメッセージ表示
   - `_errorType` を保存して UI で使用
5. エラー表示 UI を改善
   - cloud_off / error / warning アイコン使い分け
   - エラー種別ごとのタイトル表示
   - 詳細メッセージを中央揃え表示
   - 「再試行」ボタンを FilledButton.icon に改善

**コード修正行数:**
- 追加: 40行（enum + utility + state + UI）
- 変更: 3個所
- `flutter analyze` 結果: ✅ **0 errors**

**品質効果:**
- エラーUX 向上（ユーザーが何が起きたか判別可能）
- 再試行の判断基準が明確（ネットワークエラーのみ推奨）
- デバッグが容易（エラー型で根本原因が推測可能）

**所要時間: 20分**

---

### ⏳ 改善#2: ローディング UX（実装予定）

```text
次回セッション対象:
- LinearProgressIndicator で 3段階進捗表示 (33% → 66% → 100%)
- 各段階ラベル表示（「レースデータ取得中...」等）
```

### ✅ UI改善 (Rule #19): ホーム画面 - 第1段階完了

**design-skills 分析結果から最優先改善を実装:**

#### 1. ✅ AppBar グラデーション削除（完了）

**修正内容:**
- 複雑なグラデーション処理を削除
- `backgroundColor: const Color(0xFF1A1A1A)` に統一（DESIGN.md 標準）
- 未使用の `primaryColor` 変数を削除

**効果:**
- DESIGN.md ダークテーマ統一
- AppBar 実装簡潔化（メンテナンス性向上）
- `flutter analyze` 0エラー確認済み

#### 2. 🟢 スペーシング統一（次回継続）

**検出事項:**
- `SizedBox(height: 10)` × 15件 → 8 or 12 に統一
- `SizedBox(height: 14)` × 2件 → 12 or 16 に統一
- BorderRadius 不規則 (`circular(14)` / `circular(10)`) → 8/12/16 に統一

**推奨:** multi_replace_string_in_file で一括修正（次回セッション）

**所要時間: 10分（AppBar のみ。スペーシング統一は20+ 修正→スコープ大）**

---
