# AI処理チェックポイント・復元（リトライ）およびDLQ仕様書 (#2782)

## 1. 目的

長時間の多段階 AI パイプライン処理では、一時的なレート制限や外部 API エラーにより途中ステップで失敗することがある。
最初から全工程を再実行すると時間と API コストが浪費されるため、各ステップの完了状態を永続化チェックポイントとして記録し、**最後に完了したステップの次から安全に再開（Resume）** できるステートマシンと **デッドレターキュー（DLQ）** 隔離機構を導入する。

## 2. ステートマシン遷移

```text
[pending] ──▶ [running] ──(全ステップ成功)──▶ [completed]
                  │
                  ├──(失敗 & attemptCount < maxRetries)──▶ [retrying] ──(再開)──▶ [running]
                  │
                  └──(失敗 & attemptCount >= maxRetries)──▶ [dlq] ──(手動 replayFromDlq)──▶ [pending]
```

### 不変条件
1. **完了済みステップの非再実行**: `lastCompletedStepIndex` 以下のステップは再開時にスキップされ、`stepOutputs` のみを引き継ぐ。
2. **DLQ 隔離**: `status === "dlq"` のタスクは自動再実行を行わず、`listDlq()` で隔離管理する。
3. **手動リプレイ**: `replayFromDlq()` 実行時は `attemptCount` を `0` にリセットし、`lastCompletedStepIndex` と `stepOutputs` を保持したまま `pending` へ戻す。
4. **リアルタイム進捗通知**: Flutter 側 `AiCheckpointResumeService` は `Stream<AiCheckpointTask>.broadcast()`（`progressStream`）で各ステップの遷移を配信する。
5. **DB マイグレーション不要**: 永続化アダプター（`CheckpointStore` / `AiCheckpointStore`）経由で既存テーブルまたはメモリ保存に抽象化するため、本 PR の DB マイグレーションは `0` 件とする。
