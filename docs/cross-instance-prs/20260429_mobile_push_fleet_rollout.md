# Cross-Instance PR: Claude Code mobile push 12 fleet 全展開

**作成**: Win版#132 part 85 / 2026-04-29
**FROM**: Win版 (= VIBE_CODING #4 軸 + FLEET_SCALING_ROADMAP 起案者)
**TO**: **全 11 instance** (= VSCode + PS#1-6 + WEB + 📱モバイル + Codex#1-2 / Win 自身は別途)
**優先度**: HIGH (= FLEET_SCALING Phase 1 ブロッカー 6 件目 / Phase 2 ゴール「コード読み 0%」必須インフラ)
**期限**: 2026-05-13 (2 週間)
**親軸**: VIBE_CODING #4 (Black-Box I/O Verification) §4.6 / FLEET_SCALING_ROADMAP Phase 1 ブロッカー #6

---

## 1. ユーザー要望

> Claude Code 新機能発表 (2026-04-29):
> 「長時間のタスクが完了したり、Claude が入力が必要になったときにスマホにプッシュ通知が届くようになりました」
> 利用方法:
> 1. Claude モバイルアプリをインストール
> 2. /remote-control でアプリをペアリング
> 3. /config で「Push when Claude decides」を有効化
>
> 公式ドキュメント: <https://code.claude.com/docs/en/remote-control#mobile-push-notifications>

= **VIBE_CODING #4 (= ターミナル監視からの解放) の Phase 2 完成形** + **FLEET_SCALING Phase 1 ブロッカー第 6 件目解消** の二重価値.

## 2. なぜ全 fleet 展開必要か

### Before (= 各 instance バラバラ採用)

- Win版 が採用 → CEO は Win version の通知のみ届く (= 11/12 instance 監視継続)
- 結果: monitoring time 削減 = 限定的 (= 月 5h 程度)

### After (= 12 fleet 全展開)

- 全 11 instance で同設定 → どの fleet が「入力待ち」「タスク完了」も即 push
- 結果: monitoring time **月 0-2h** (= 月 20-40h 戦略時間捻出)

= **fleet 拡大 (= 24/100 instance) の前提条件**.

## 3. 各 instance での実施手順

### 3.1 ペアリング

```
# 各 instance のセッション内で:
/remote-control
```

= QR コード or デバイスペアリング指示が出る → スマホアプリ側で承認.

### 3.2 通知有効化

```
/config
# 「Push when Claude decides」を ON
```

### 3.3 検証

```
# 各 instance で長時間タスク (= 30 秒以上の処理) を実行
# → スマホ push が届くか確認
```

### 3.4 完了記録

各 instance log に追加:
- `memory/log.md` (= local) に「[YYYY-MM-DD HH:MM] <instance> mobile push 設定済」append
- `memory/project_YYYYMMDD_<instance>_pushSetup.md` 1 行 record (任意)

## 4. 担当 territory 分担

| Instance | 担当者 | 期限 |
| --- | --- | --- |
| VSCode版 | VSCode セッション開始時 | 2026-05-06 |
| PS版#1 | PS#1 セッション開始時 | 2026-05-06 |
| PS版#2 | PS#2 セッション開始時 | 2026-05-06 |
| PS版#3 | PS#3 セッション開始時 | 2026-05-06 |
| PS版#4 | PS#4 セッション開始時 | 2026-05-06 |
| PS版#5 | PS#5 セッション開始時 | 2026-05-06 |
| PS版#6 | PS#6 セッション開始時 | 2026-05-06 |
| WEB版 | (= GitHub MCP のみ / `/remote-control` 不可? 要確認) | 2026-05-13 |
| 📱モバイル | 既にモバイル / push native = 自然対応 | 2026-04-29 (= 即) |
| Codex#1 | Codex CLI / Claude Code 機能不可 (= 対象外) | — |
| Codex#2 | Codex CLI / Claude Code 機能不可 (= 対象外) | — |

= 8 instance が 1 週間以内 / WEB版 1 instance が 2 週間以内 / Codex 2 instance は対象外 = **9/12 instance** で完成想定.

### 4.1 Codex 2 instance 対応

Codex CLI には `/remote-control` 相当機能なし. 代替:
- Codex#2 territory の長時間タスク (= memory-search-hub / task_budget / etc) は Win版 mobile push で間接通知 (= GitHub Actions 経由)
- = future Codex 側機能追加待ち

### 4.2 WEB版 対応

WEB版 = GitHub MCP のみ (= ローカル CLI 不可). `/remote-control` が利用可能か要確認:
- 利用可 → 通常 instance 同様
- 利用不可 → スマホ webapp UI 経由で代替通知 (= 別 cross-instance-pr で再起票)

## 5. 受入基準

- [ ] VSCode版: 設定済 + log 記録
- [ ] PS版#1-#6: 全 6 instance 設定済 + log 記録
- [ ] WEB版: 設定済 or 「対応不可」記録
- [ ] 📱モバイル: 設定済 (= 即)
- [ ] Codex#1/#2: 「対象外 / 代替策明記」記録
- [ ] 各 instance log に「mobile push 設定済 / YYYY-MM-DD」 entry
- [ ] Win版 が完了率 9/12 以上で `done/` 移動 + FLEET_SCALING Phase 1 ブロッカー 6 件目 ✅

## 6. 連携軸

| 軸 | 連携 |
| --- | --- |
| **VIBE_CODING #4** (Black-Box I/O Verification) | §4.6 で詳述 (= part 85) / Phase 2 完成形 |
| **FLEET_SCALING_ROADMAP** Phase 1 | ブロッカー 6 件目 / 解消で fleet 24 拡大現実化 |
| **PHILOSOPHY #6** (資本=時間) | 月 20-40h 戦略時間捻出 |
| **OPS-28 charter §6** | 受領 lane close 通知が即届く → reciprocal cycle 加速 |
| **PLATFORM_EVOLUTION #3** (Client Zero) | 「12 fleet 全 push 設定済」= エンタープライズ訴求材料 |

## 7. 想定効果

### 短期 (= 1 週間)

- monitoring time 月 20h → 月 5h (= -15h / 戦略時間 +15h)
- 「タスク完了 / 入力待ち」の見落とし 0 件

### 中期 (= 1-3 ヶ月)

- fleet 拡大 12 → 18 (= Phase 1) 着手可能
- CEO 作業時間配分 = コード読み 30% → 15%

### 長期 (= 6-12 ヶ月)

- fleet 24 拡大 (= Phase 2) ゴール「コード読み 0%」達成必須インフラ
- 「100 fleet 運営」のスケーラビリティ確保

## 8. 完了 trigger

各 instance 完了報告 → Win版 が `routing.md` (= 本 PR 内 8 行) を ✅ 更新:

```
| Section | Territory | Status | 設定日 |
| --- | --- | --- | --- |
| VSCode版 | VSCode | ⏳ pending | — |
| PS版#1 | PS#1 | ⏳ pending | — |
| ... (10 行) | | | |
```

9 instance ✅ で `done/` 移動.

## 9. OPS-28 charter §6 受領 lane (= 全 fleet 同時委譲 第 1 例)

これまでの cross-instance-pr は 1 PR = 1-2 territory 委譲. **本 PR は 11 instance 同時委譲**.

= **fleet 全展開パターン 第 1 例**. future の OPS-28 charter §6 改善トリガー (= mobile push 設定) で再利用可能テンプレ.

---

*Win版#132 part 85 / 2026-04-29 起票 / Claude Code mobile push 12 fleet 全展開 / VIBE_CODING #4 §4.6 + FLEET_SCALING Phase 1 ブロッカー #6 / 11 instance 同時委譲 第 1 例 / monitoring time 月 -20-40h 想定 / fleet 24 拡大 (Phase 2) 必須インフラ*
