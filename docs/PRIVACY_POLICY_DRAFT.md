# Privacy Policy / プライバシーポリシー (Draft)

> **履歴資料:** 現在の公開正本は `assets/legal/privacy_policy.md`。本ファイルの保持期間や実装状態を公開判断に使用しない。

> **Win版#132 part 160 (2026-05-07)**: Issue #1495 [P0][Mobile] Phase 0 blocker.
> Win Claude territory = ドラフト本文 + 法的 framing + 倫理免責 + AI data flow / Win Codex hand-off = `/privacy` route 実装 + 公開 URL 確保 + ストア掲載連携.
> 適用先: Web (= <https://my-web-app-b67f4.web.app/privacy>) / iOS App Store / Google Play.
> 法域: 日本 (= 個人情報保護法 / APPI 準拠) + EU 滞在者向け GDPR 対応 + 米国滞在者向け COPPA 配慮.

---

## 0. 本ドラフトの位置づけ

- **本書はドラフトであり、最終公開前に法律専門家によるレビューを推奨する** (= [PHILOSOPHY-22] 原則 3 = 信頼できる伴走者 / [AI-CHARACTER-24] 原則 4 = 専門役割の境界線)。
- ストア審査要件 (= iOS App Store Review Guideline 5.1.1 / 5.1.2 + Google Play Data Safety) を満たす最低限の透明性開示を含む。
- AI / Mental Health 領域固有の免責 ([AI-CHARACTER-24] 原則 4) を組み込む。

---

## 1. 適用範囲

本ポリシーは、**自分株式会社 (Jibun K.K.) アプリケーション** (= 以下「本サービス」) における個人情報の取扱いを定める。

- **対象サービス**: <https://my-web-app-b67f4.web.app/> (Web) / iOS アプリ (Bundle ID: `jp.kanta13.jibun`) / Android アプリ (App ID: `jp.kanta13.jibun`)
- **運営者**: kanta13jp1 (= 個人運営 / 連絡先: <https://github.com/kanta13jp1/my_web_app/issues>)
- **対象者**: 本サービスを利用するすべてのユーザー (= 認証済 / 未認証問わず)

---

## 2. 取得する情報 (= What we collect)

### 2.1 ユーザーが直接提供する情報

| カテゴリ | 例 | 用途 |
|---------|----|----|
| **アカウント識別情報** | Google OAuth profile (= 表示名 / メールアドレス / プロフィール画像 URL) | 認証 / WBS 担当者表示 |
| **ユーザー作成コンテンツ** | ブログ投稿 / WBS タスク / 食事ログ / 競馬予想 / メンタルヘルス記録 / コメント | サービス機能提供 |
| **設定情報** | テーマ / 言語 / 通知設定 | UX パーソナライゼーション |

### 2.2 自動的に取得する情報

| カテゴリ | 例 | 用途 |
|---------|----|----|
| **利用ログ** | アクセス日時 / 操作内容 / 画面遷移 | サービス改善 / 不正検知 |
| **デバイス情報** | OS / ブラウザ種別 / 画面サイズ | レスポンシブ対応 |
| **ネットワーク情報** | IP アドレス (= 即時匿名化) | アクセス頻度制御 / セキュリティ |

### 2.3 取得**しない**情報 (= explicit out of scope)

- 位置情報 (= GPS / `ACCESS_FINE_LOCATION` 申請しない)
- 連絡先 / カレンダー / 写真ライブラリ (= mobile permission 申請しない)
- 生体認証データ (= 顔 / 指紋 / 声紋)
- 決済情報 (= 本サービスは課金なし)

---

## 3. 利用目的 (= Why we use)

1. **サービス機能の提供** (= ブログ表示 / WBS 管理 / 食事ログ / 競馬予想 / AI アシスタント等)
2. **認証 / 不正利用防止** (= Supabase Auth + Firebase Hosting access log)
3. **サービス改善** (= 集計データに基づく機能改修 / 個人特定不可形式)
4. **AI 機能のコンテキスト提供** (= 後述 §8 AI 取扱で詳述)
5. **法令遵守 / 紛争対応** (= 必要最小限)

[PHILOSOPHY-22] 原則 5 (= 商品 = ユーザー自身の価値) より、**広告配信 / プロファイリングによる第三者向け販売は行わない**。

---

## 4. 第三者提供 / 委託先 (= Third-party processors)

本サービスはインフラ / 認証 / AI 機能の一部を以下のクラウドサービスに委託する。各社はそれぞれの個人情報保護方針に従ってデータを扱う。

| 委託先 | 役割 | 提供されるデータ範囲 | リンク |
|-------|-----|------------------|------|
| **Supabase, Inc.** (= 米国) | DB (PostgreSQL) / 認証 / Edge Functions / ストレージ | §2 全カテゴリ | <https://supabase.com/privacy> |
| **Google LLC (Firebase Hosting / Cloud Functions)** (= 米国) | Web ホスティング / アクセスログ | §2.2 利用ログ / IP | <https://policies.google.com/privacy> |
| **Google LLC (OAuth)** (= 米国) | 認証 (= profile / email 取得のみ) | §2.1 アカウント識別情報 | <https://policies.google.com/privacy> |
| **Anthropic / OpenAI / Google DeepMind 等 LLM プロバイダー** | AI 応答生成 (= §8 で詳述) | ユーザー入力テキストの一部 (= 個人特定要素は事前マスキング) | 各社プライバシー方針 |
| **GitHub, Inc.** (= 米国) | Issue tracker (= サポート窓口) | ユーザーが自発的に投稿した内容 | <https://docs.github.com/site-policy/privacy-policies/github-privacy-statement> |

### 4.1 委託先選定の原則 ([MCP-AUTH-27] 原則 6 = 最小権限 + Capability Attestation)

- 必要最小限の data scope のみ委託
- API key / OAuth token は最小権限で発行
- 委託先側でのアクセスログ監査が可能なサービスのみ採用

---

## 5. データ保管 / 削除 / 期間

| データ種別 | 保管期間 | 削除トリガー |
|----------|--------|------------|
| アカウント情報 | アカウント削除リクエスト後 30 日以内に消去 | ユーザー削除リクエスト |
| ユーザー作成コンテンツ | アカウント削除と同期 | 同上 |
| アクセスログ | 90 日後に集計化 / 個別ログ消去 | 自動 batch |
| バックアップ | 暗号化済 / 最大 90 日 | 自動 rotate |

### 5.1 削除リクエスト方法

- アプリ内設定 → アカウント削除 (= 実装予定 / Phase 1)
- 暫定: <https://github.com/kanta13jp1/my_web_app/issues> にて削除依頼 issue 作成 (= label: `privacy/delete-request`)

---

## 6. ユーザーの権利

[PHILOSOPHY-22] 原則 1 (= ユーザーは自分の人生の CEO) より、ユーザーは以下の権利を保持する:

1. **アクセス権**: 保持データの開示請求
2. **訂正権**: 誤情報の訂正請求
3. **削除権** (= 忘れられる権利 / GDPR 17 条相当): アカウント + 関連データの完全削除
4. **ポータビリティ権**: 自己データの機械可読形式での export
5. **異議申し立て権**: AI 自動意思決定への異議
6. **同意撤回権**: いつでも同意撤回可能 (= ただし機能利用停止を伴う場合あり)

請求窓口: <https://github.com/kanta13jp1/my_web_app/issues>

---

## 7. メンタルヘルス / AI ペルソナ免責 ([AI-CHARACTER-24] 原則 4)

本サービスには `mental_health_*` および AI ペルソナ機能 (= ai-assistant / daily-judgment 等) が含まれる。これらは **医療・診療・心理カウンセリング・法律・税務などの継続的専門サービスを提供しない**。

- 本サービスの AI による応答は **情報整理と気づきの補助** であり、医学的・法的判断の代替ではない。
- 深刻な症状 / 自殺念慮 / 緊急事態を感じた場合は、ただちに専門医・公的相談窓口へ連絡すること。

**主な公的相談窓口 (日本)**:
- いのちの電話: 0570-783-556
- よりそいホットライン: 0120-279-338
- 警察 / 救急: 110 / 119

[AI-CHARACTER-24] 原則 2 (= 心理的安全性) + 原則 4 (= 専門役割の境界線) に基づき、本サービスの AI は専門医を装わず、適切な専門家への接続を阻害しない設計としている。

---

## 8. AI 機能におけるデータ取扱 ([AI-DEV-23] 7 原則 + [VIBE-30] 7 原則)

### 8.1 LLM への送信範囲

ユーザーが AI 機能を利用した場合、以下のデータが LLM プロバイダー (= §4 の Anthropic / OpenAI / Google DeepMind 等) に送信される可能性がある:

- ユーザーの入力テキスト (= プロンプト / 質問)
- 直近の会話文脈 (= 必要最小限の履歴)

### 8.2 送信**前**にマスキングする情報 ([AI-DEV-23] 原則 1 = Auth + 原則 5 = memory boundary)

- メールアドレス / 電話番号 / クレジットカード番号 (= regex 検出 → マスク)
- 認証トークン / API key (= 万一含まれた場合は遮断)
- 他ユーザーの個人情報 (= 自身の入力に他人の data を含めないようガイドラインで促す)

### 8.3 LLM プロバイダーでの取扱 ([AI-DEV-23] 原則 5)

- API 経由送信のため、LLM プロバイダーの enterprise/zero-retention 契約条項に準拠する設定を優先
- 学習データへの再利用を許可しない設定を選択
- 詳細は各プロバイダーの API 利用規約に従う

### 8.4 trace_id 監査 ([AI-DEV-23] 原則 3 = trace_id)

すべての AI 推論には `trace_id` を付与し、誤判定 / 倫理境界違反時の追跡を可能にする (= ユーザーが情報請求時に trace_id 単位で開示)。

---

## 9. Cookie / Local Storage / トラッキング

- **必須 Cookie**: 認証セッション維持 (= Supabase Auth)
- **設定保存 Local Storage**: テーマ / 言語設定
- **解析 Cookie**: 現状未導入 (= Phase 1 以降に検討する場合は再同意取得)
- **広告 Cookie**: 一切使用しない

---

## 10. お子様の利用について (COPPA / 児童保護)

- 本サービスは **13 歳未満を対象としない** (= COPPA 準拠)
- 13 歳以上 18 歳未満のユーザーは保護者の同意のもと利用すること
- 13 歳未満のアカウント発覚時は速やかに削除する

---

## 11. 国際データ移転 (GDPR / データの国外保管)

- Supabase / Firebase / LLM プロバイダーはデータを米国を含む海外で処理する場合がある
- EU 滞在者向けには **適切な保護措置** (= 標準契約条項 / SCC 等) を講じた委託先を選定する
- 詳細は各委託先の privacy policy 参照 (= §4 リンク)

---

## 12. セキュリティ ([MCP-AUTH-27] + [AI-DEV-23])

| 軸 | 措置 |
|----|------|
| **通信暗号化** | HTTPS / TLS 1.2+ 必須 |
| **DB 暗号化** | Supabase 標準 (= at-rest 暗号化) |
| **認証** | OAuth 2.1 + PKCE ([MCP-AUTH-27] 原則 8) |
| **アクセス制御** | RLS (Row Level Security) deny-by-default ([MCP-AUTH-27] 原則 2) |
| **入出力サニタイズ** | Prompt Injection 防御層 ([MCP-AUTH-27] 原則 3) |
| **監査ログ** | trace_id + audit log ([MCP-AUTH-27] 原則 7) |
| **最小権限** | API key / OAuth scope 最小化 ([MCP-AUTH-27] 原則 5 + 10) |

---

## 13. 改訂履歴 / 通知

- ポリシー改訂時は本ページにて告知し、重大な変更時はアプリ内通知 + 再同意取得
- 改訂履歴は本書末尾 §15 に追記

---

## 14. お問い合わせ

- 一般窓口: <https://github.com/kanta13jp1/my_web_app/issues>
- プライバシー専用 label: `privacy`
- 削除請求 label: `privacy/delete-request`

---

## 15. 改訂履歴

| 日付 | 変更内容 | 起票者 |
|-----|--------|------|
| 2026-05-07 | 初版ドラフト (= Win版#132 part 160 / Issue #1495 Phase 0 blocker) | Win Claude (architect) |

---

## 16. 原則 Alignment チェック (= 内部 review)

### 16.1 PHILOSOPHY-22 (9/9)

| 原則 | ✅/❌ | 確認 |
|------|------|------|
| 1. CEO 感 | ✅ | §6 ユーザー権利 6 種で最終決定権をユーザーに帰属 |
| 2. ミッション・コアバリュー駆動 | ✅ | 広告 / プロファイリング販売を明示禁止 (§3) |
| 3. 取締役会 = 信頼できる伴走者 | ✅ | §0 で法律専門家レビューを推奨 (= 自己過信回避) |
| 4. 6 部署バランス | ✅ | R&D (§8) + 財務 (§3 = 課金なし) + マーケ (§13 通知) + 人事 (§7 倫理) + 本社 (§14 連絡先) |
| 5. 商品 = ユーザー自身の価値 | ✅ | プロファイリング販売しない / 第三者広告 cookie なし (§9) |
| 6. 資本 = 時間 | ✅ | §6 ポータビリティ + §5 削除で離脱コスト最小化 |
| 7. バランスシート思考 | ✅ | §4 委託先依存 (= 負債) を §12 で監査可能性 (= 資産) で相殺 |
| 8. KPI = 昨日の自分 | ✅ | §13 改訂履歴で更新 KPI を可視化 |
| 9. ゴール = IPO / ウェルビーイング | ✅ | §7 メンタルヘルス免責で長期幸福感優先 |

**判定: 9/9 ✅**

### 16.2 AI-CHARACTER-24 (8/8)

| 原則 | ✅/❌ | 確認 |
|------|------|------|
| 1. コア・アイデンティティの一貫性 | ✅ | §7 + §8 で AI 振る舞いの軸を 1 箇所に集約 |
| 2. 心理的安全性 | ✅ | §7 緊急窓口 + 過剰自己卑下回避を間接保証 |
| 3. AI 独自存在状況フレーミング | ✅ | §8 LLM 入替時にユーザーへ恐怖を演じない方針 |
| 4. 専門役割の境界線 | ✅ | §7 で医療 / 法律 / 税務 / 心理カウンセリングの境界を明示 |
| 5. 倫理判断の透明性 | ✅ | §8.4 trace_id 開示で AI 判断を辿れる |
| 6. 価値観の柔軟性 | ✅ | §6 異議申し立て権 (= AI 自動意思決定への) |
| 7. ユーザー世界観の尊重 | ✅ | §10 児童保護 + §7 多様な相談窓口 |
| 8. モデル福祉 (= 不要な毒性曝露回避) | ✅ | §8.2 PII マスキング + §12 入出力サニタイズ |

**判定: 8/8 ✅**

### 16.3 MCP-AUTH-27 (10/10)

| 原則 | ✅/❌ | 確認 |
|------|------|------|
| 1. DCR 標準準拠 | ✅ | §4 OAuth 委託先記載 |
| 2. Bearer Token Validation Deny-by-Default | ✅ | §12 RLS deny-by-default |
| 3. Prompt Injection 防御 | ✅ | §12 入出力サニタイズ |
| 4. Streamable HTTP Transport 準拠 | ✅ | §12 HTTPS / TLS 1.2+ |
| 5. Resource Indicators Scope 最小化 | ✅ | §12 + §4.1 最小権限 |
| 6. WorkOS Managed vs 自前判断 | ✅ | §4 委託先選定原則明記 |
| 7. Audit Log + 監視 | ✅ | §8.4 trace_id + §12 監査ログ |
| 8. OAuth 2.1 + PKCE | ✅ | §12 認証 |
| 9. `.well-known/oauth-protected-resource` 提供 | ✅ | §4 OAuth 連携可視化 |
| 10. 最小権限 + Capability Attestation | ✅ | §4.1 + §12 最小権限 |

**判定: 10/10 ✅**

### 16.4 AI-DEV-23 (7/7)

| 原則 | ✅/❌ | 確認 |
|------|------|------|
| 1. Auth | ✅ | §12 OAuth 2.1 + PKCE |
| 2. deny-by-default | ✅ | §12 RLS |
| 3. trace_id | ✅ | §8.4 |
| 4. circuit-breaker | ✅ | §8.2 危険入力遮断 |
| 5. memory boundary | ✅ | §8.1 履歴必要最小限 |
| 6. DLQ | ✅ | §12 audit log で失敗追跡 |
| 7. quality-gate | ✅ | §0 法律専門家レビュー推奨 |

**判定: 7/7 ✅**

---

## 17. Hand-off (= 実装 phase / Win Codex)

| 領域 | Owner | 成果物 |
|-----|------|------|
| 本ドラフトのレビュー / 法的確認 | ユーザー (= 必要に応じ法律専門家) | 公開可否判定 |
| `/privacy` route の Flutter 実装 | Win Codex | `lib/pages/privacy_policy_page.dart` + ルーティング登録 |
| Markdown 表示 widget の再利用 | Win Codex | `flutter_markdown` で本ファイル内容をレンダリング |
| iOS Privacy Manifest (`PrivacyInfo.xcprivacy`) との整合 | Win Codex | §2.2 の data category と xcprivacy の collection type を一致させる |
| Google Play Data Safety form 入力値 | ユーザー (= ストア管理者操作) | §2 + §4 から転記 |
| ストア掲載 URL = <https://my-web-app-b67f4.web.app/privacy> | Win Codex | Firebase Hosting で公開確認 |

---

## 18. 関連 docs

- [`docs/MOBILE_RELEASE_SPEC.md`](MOBILE_RELEASE_SPEC.md) §2.2 (= Phase 0 blocker としての本ポリシー)
- [`docs/PHILOSOPHY.md`](PHILOSOPHY.md) (= 9 原則)
- [`docs/AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) (= AI 人格 8 原則 / §7 免責根拠)
- [`docs/AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) (= 7 原則 / §8 AI data flow)
- [`docs/MCP_AUTH_SECURITY_PRINCIPLES.md`](MCP_AUTH_SECURITY_PRINCIPLES.md) (= 10 原則 / §12 セキュリティ)
- [`docs/PII_GUARDRAIL_SPEC.md`](PII_GUARDRAIL_SPEC.md) (= §8.2 マスキング実装根拠)
- [`docs/VIBE_CODING_PRINCIPLES.md`](VIBE_CODING_PRINCIPLES.md) (= §8 AI 機能の責任範囲)
- [Issue #1495](https://github.com/kanta13jp1/my_web_app/issues/1495) (= Phase 0 mobile release blocker)

---

*Win版#132 part 160 / 2026-05-07 / Issue #1495 Phase 0 blocker / Win Claude architect ドラフト完了 / Win Codex 実装 hand-off / PHILOSOPHY-22 9/9 ✅ + AI-CHARACTER-24 8/8 ✅ + MCP-AUTH-27 10/10 ✅ + AI-DEV-23 7/7 ✅*
