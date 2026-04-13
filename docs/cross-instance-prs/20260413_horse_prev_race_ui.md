# cross-instance-pr: 競馬 前走情報UI表示

作成: Windows版#68 (2026-04-13)
宛先: VSCode版
状態: done

## 概要
horse_entries テーブルに前走情報カラムを追加。Flutter UIで出走馬カードに表示してほしい。

## 追加されたカラム (migration 20260413051000)
```
horse_id_ext      text       -- netkeiba 馬ID
age_sex           text       -- 性齢 (例: 牡3, 牝4)
horse_weight      integer    -- 馬体重 (kg)
horse_weight_change integer  -- 増減 (例: +2, -4)
prev_finish       integer    -- 前走着順 (1〜18)
prev_race_name    text       -- 前走レース名
prev_race_date    date       -- 前走日付
prev_venue        text       -- 前走場所
prev_course_type  text       -- 前走コース種別
prev_distance     integer    -- 前走距離 (m)
prev_time         text       -- 前走タイム
prev_days_ago     integer    -- 前走からの経過日数
```

## 表示案 (horse racing page の馬カード内)
```
フークレグルス  牡3  480kg(+2)
騎手: 田中  斤量: 56kg  オッズ: 75.2倍
前走: 2着 / 大井 ダート1400m / 12日前
```

## 対象ファイル (VSCode版担当)
- `lib/pages/horse_racing_page.dart` — 出走馬リストの馬カードに prev_finish / age_sex / horse_weight を追加表示
- tools-hub EF の `horseracing.get_entries` action があれば horse_id_ext 等の新カラムを返すよう更新

## 前走着順の色分け提案
- 1着: 金色 (#FFD700)
- 2-3着: 緑色 (Colors.green)
- 4-5着: 通常色
- 6着以下 / null: グレー
