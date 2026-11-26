# スクレイピング耐障害性・バックオフ・DLQ 標準仕様

対象: Issue #2775 連携 / Issue #2779。

## 1. 安全・ToS 遵守原則（CAPTCHA 回避の全面禁止）

外部サイトへの自動取得処理（`supabase/functions/_shared/scraping_resilience.ts`）では、
対象サービスの可用性と利用規約（ToS）を最優先し、以下を強制します。

1. **即時中断（`abortedImmediately: true`）**:
   - HTTP `503`、HTTP `429`（`Retry-After` 尊重）、または本文中の CAPTCHA / anti-bot 検知
     （`captcha` / `recaptcha` / `hcaptcha` / `cf-challenge` / `verify you are human` 等）を検出した場合、
     その場でアクセスを即座に中断します。
   - CAPTCHA 突破・自動クリック・回避試行は一切実装しません。CAPTCHA 検知時は
     `manualReviewRequired: true`（`nextRetryAt: null`）として自動再試行キューから除外します。
2. **透過的な `User-Agent` ヘッダー**:
   - `buildCompliantUserAgent` によりブラウザ偽装を行わず、サービス識別名と連絡先 URL を明示した
     `User-Agent` を常に付与します。
3. **指数バックオフ + Dead Letter Queue（DLQ）**:
   - 一時的障害・レート制限時は指数バックオフを算出し、`InMemoryDlqStore` / `DlqStore` 契約を通じて
     既定 1 時間後（`DEFAULT_DLQ_RETRY_DELAY_MS = 3600000`）の `nextRetryAt` で `processDueDlqTasks`
     による遅延再試行をスケジュールします。
   - 本変更は `0` DB マイグレーションの共通ヘルパーであり、対象サイト別の法務・ToS 適合性は個別 Cron 導入時に確認します。
