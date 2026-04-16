# Windowsアプリ版#Opus47-2 完了 (2026-04-17)

## 達成内容

### AI大学 65-66社目追加
- **Scale AI** (scale_ai): EGP / Data Engine / Scale Evaluation / Scale Labs 2026-03
- **Poolside AI** (poolside): Malibu flagship + Point completion / AWS Bedrock / オンプレ
- migration番号帯: 090000 / 091000 (Windowsアプリ版 000700-000899 内)

### Opus 4.7 統合完了
- ai-assistant/index.ts: `DEFAULT_EXTENDED_THINKING_MODEL = 'claude-opus-4-7'`
- COMPRESSED_PROMPT_V3: WEB版行を Opus 4.7 + ultrathink=Sonnet 4.6 必須に修正
- Rule 22: バージョンチェック + release notes確認 + devフロー組み込み手順

### docs修正
- INSTANCE_CONFIG.md: "(明日) 退役" stale相対日付を削除
- MULTI_INSTANCE_COORDINATION.md: WEB版行に notebooklm CLI 不可・WebSearch専任・Opus4.7明記
- cross-instance-prs/20260417_opus47_multi_instance_update.md: 完了マーク付加

## 現在の状態
- AI大学: 66社 (commit: 12f72458)
- EF: 15本 (ハードキャップ50本以内)
- 最新プロバイダーリスト末尾: lmsys, falcon_tii, black_forest_labs, liquid_ai, snowflake, cognition, scale_ai, poolside

## 次回候補 (Windowsアプリ版)
1. AI大学 67-68社目: Harvey AI (法律特化) / Typeface / Writer
2. frosty-hamilton ブランチのマージ (PS版担当)
3. Voice AI チャットページ cross-instance-pr → VSCode版
