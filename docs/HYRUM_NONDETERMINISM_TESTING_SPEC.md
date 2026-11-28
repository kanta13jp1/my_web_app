# Hyrum の法則に基づく非決定性テスト仕様 (#2792)

## 1. 背景と目的

「Hyrum の法則」により、API やデータベースクエリが明示的なソート順を保証していない場合でも、呼び出し側が暗黙の返却順序や非同期完了順序に依存してしまうリスクがある。本仕様は、決定論的シードを用いた順序揺らぎ（permutation / async completion jitter）テストを標準化し、暗黙的依存を早期検知することを目的とする。

## 2. テスト構成

1. **再現可能な順序揺らぎヘルパー (`test/utils/hyrum_order_jitter_helper.dart`)**:
   - `hyrumDefaultSeeds = [11, 29, 47, 83, 131]` を用いた `permuteWithSeed` と `resolveInSeededOrder` を提供する。
   - 失敗時はログに出力された `seed` 値を固定してローカル再現できる。
2. **データ集計・順序不変性テスト (`test/services/hyrum_order_invariance_test.dart`, `supabase/functions/_shared/hyrum_order_jitter_test.ts`)**:
   - Supabase 由来の未ソートモック行を複数シードでシャッフルし、集計・正規化結果が完全一致することを検証する。
3. **非同期完了順序・高文字倍率ウィジェットテスト (`test/widgets/hyrum_async_order_widget_test.dart`)**:
   - 複数の `Completer` をシード順で完了させ、完了順序が前後しても `2.0x` textScale 環境でクラッシュやレイアウトオーバーフローが発生しないことを検証する。
