# モバイルPWA環境の音声入力とSupabaseを介したクロスデバイス状態同期の検証レポート (#2605)

**関連 Issue**: `#2605`

**一次情報参照**:
- MDN Web Docs `SpeechRecognition`: <https://developer.mozilla.org/docs/Web/API/SpeechRecognition>
- MDN `browser-compat-data` (`api/SpeechRecognition.json`, `api/SpeechGrammar.json`)
- Note: Issue 本文中の競合ツール（Lovable）のモバイル音声開発体験に関する言及はサードパーティ情報であり、独自技術検証の結果として本設計と手動入力フォールバックを定義する。

---

## 1. ブラウザ / PWA 環境別の Web Speech API 一次仕様比較

MDN `SpeechRecognition` および `browser-compat-data` に基づく主要環境比較は以下の通り。

| 環境 | API 公開形式 | バージョン根拠 (MDN BCD) | `SpeechGrammar` / `continuous` | PWA・実運用上の制約 |
| :--- | :--- | :--- | :--- | :--- |
| **Desktop Chromium (Chrome / Edge)** | `SpeechRecognition` / `webkitSpeechRecognition` | `webkit`: Chrome 33+, unprefixed: Chrome 139+ | 両対応 (`webkit` / 標準) | Web サーバー経由 (HTTPS / localhost) が必須。 |
| **Safari (通常ブラウザタブ)** | `webkitSpeechRecognition` | Safari 14.1+ / iOS 14.5+ | `SpeechGrammar`: **非対応 (`false`)**<br>`continuous`: Safari 14.1〜16.x は部分対応 (`false` 指定時でも複数結果返却の場合あり)、17+ で修正 | Siri / OS ディクテーション基盤と連携。ユーザージェスチャー（タップ等）同期呼び出しとマイク許可が必須。`<audio>` 再生直後にハードウェアオーディオセッション競合で無音停止する既知制約に注意。 |
| **iOS Home Screen PWA (Standalone)** | `webkitSpeechRecognition` | iOS 14.5+ (WebKit) | 同上 (`SpeechGrammar`: **非対応**) | iOS の Standalone PWA・`SafariViewController`・アプリ内 WebView では OS 権限持続性や音声入力 API の動作が不安定・制限されるケースがあり、音声認識単独への依存は危険。**手動テキスト入力フォールバックが必須**。 |
| **アプリ内 WebView (SNS 等)** | 環境依存・制限大 | — | 未保証 | マイク権限や `webkitSpeechRecognition` 自体が未提供となる場合が多い。 |

### Flutter Web 実装上の禁止事項・制約

1. **レガシー `dart:html` の利用禁止**: WASM / 最新 Flutter Web 互換性を損なうため、`dart:html` を直接インポートしない。ブラウザ機能判定は `CrossDeviceVoiceSyncService` への注入可能なケイパビリティプローブ (`VoiceCapabilityProbe`) に分離する。
2. **グレースフルデグラデーション**: `!speechRecognitionAvailable` または `isStandalonePwa && isIos` の場合、警告バナーを表示し即座に手動テキストプロンプト入力モードへ切り替える。

---

## 2. Supabase Realtime クロスデバイス状態引き継ぎアーキテクチャ

モバイルで記録した音声テキスト／手動入力プロンプトをデスクトップ等へ喪失せず引き継ぐため、楽観的リビジョン制御とオフラインキューを組み合わせる。

1. **状態テーブル (`public.cross_device_voice_sessions`)**:
   - `(user_id, session_key)` で一意管理し、厳格な所有者 RLS (`(select auth.uid()) = user_id`) の下で保護。
   - `revision` (`bigint >= 1`) を保持し、各同期ごとに単調増加させる。
   - `supabase_realtime` パブリケーションに登録し、他デバイスへの更新伝搬を可能にする。
2. **競合解決ルール (`CrossDeviceVoiceSyncService.applyRemoteSnapshot`)**:
   - ローカルの `revision` より大きい `revision` がリモートから到達した場合、ローカルドラフトが未保存で空でない場合は履歴ノートを保持しつつ `conflict_resolved` として最新リビジョンを採用し、未編集時は `handed_off` としてシームレスに引き継ぐ。
   - ローカルより古い、または同一リビジョンのリモート通知は無視して巻き戻りを防止する。
3. **通信断フォールバック (`VoiceSessionCacheStore`)**:
   - Supabase 同期失敗時はローカルストレージ（`SharedPreferences` / テスト時はインメモリ抽象）へ `sync_status = 'queued_offline'` として退避し、復帰時に `retryPendingSync()` で再同期する。

---

## 3. PoC 実装範囲と検証状況

- **データ層**: `supabase/migrations/20261124001400_create_cross_device_voice_sessions.sql`
- **サービス層**: `lib/services/cross_device_voice_sync_service.dart`
- **UI PoC**: `lib/widgets/pwa_voice_handoff_panel.dart`
- **テスト**: `test/services/cross_device_voice_sync_test.dart`（環境別プローブ・iOS PWA フォールバック表示・楽観的リビジョン競合解決・オフライン再同期・コントローラ破棄・Light/Dark × `390x844` / `1280x800` × `2.0x` textScale WCAG ガイドライン検査）
- **未実施項目 (`not-run`)**: 実機 iOS Safari Standalone PWA および実 Supabase Realtime チャンネルを用いたライブ UAT は本検証環境の制約により `not-run`。
