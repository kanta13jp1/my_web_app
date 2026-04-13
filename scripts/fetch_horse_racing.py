#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
競馬情報自動取得スクリプト
JRA/NAR の出走表と結果を netkeiba.com からスクレイピングして Supabase に保存する。

使用方法:
  python fetch_horse_racing.py --mode entries [--date YYYY-MM-DD]   # 出走表取得
  python fetch_horse_racing.py --mode results [--date YYYY-MM-DD]   # 結果取得
  python fetch_horse_racing.py --mode predict                        # AI予想実行 (EF呼び出し)

必須環境変数:
  SUPABASE_URL          (例: https://xxxx.supabase.co)
  SUPABASE_SERVICE_KEY  (service_role キー)

オプション環境変数:
  TOOLS_HUB_URL         (デフォルト: SUPABASE_URL/functions/v1/tools-hub)
"""

import os
import sys
import json
import time
import argparse
import datetime
import urllib.request
import urllib.parse
import urllib.error
import html.parser
import re
from typing import Optional

# ─── 設定 ────────────────────────────────────────────────────────────────────
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://smmkxxavexumewbfaqpy.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
TOOLS_HUB_URL = os.environ.get(
    "TOOLS_HUB_URL", f"{SUPABASE_URL}/functions/v1/tools-hub"
)

# netkeiba URL テンプレート
RACE_LIST_URL = "https://race.netkeiba.com/top/race_list_sub.html?kaisai_date={date}"
SHUTUBA_URL   = "https://race.netkeiba.com/race/shutuba.html?race_id={race_id}"
RESULT_URL    = "https://race.netkeiba.com/race/result.html?race_id={race_id}"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "ja,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}


# ─── HTTP ヘルパー ─────────────────────────────────────────────────────────────
def http_get(url: str, timeout: int = 15) -> Optional[str]:
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            charset = "utf-8"
            ct = resp.headers.get_content_charset()
            if ct:
                charset = ct
            return resp.read().decode(charset, errors="replace")
    except Exception as e:
        print(f"[WARN] GET {url} failed: {e}", file=sys.stderr)
        return None


def supabase_rest(method: str, table: str, data=None, params: dict = None):
    """Supabase REST API 呼び出し"""
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    body = json.dumps(data).encode("utf-8") if data else None
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation,resolution=merge-duplicates",
    }
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        print(f"[ERROR] {method} {table}: {e.code} {err[:200]}", file=sys.stderr)
        return None


def tools_hub_call(action: str, extra: dict = None) -> dict:
    """tools-hub Edge Function 呼び出し"""
    payload = {"action": action, **(extra or {})}
    body = json.dumps(payload).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }
    req = urllib.request.Request(TOOLS_HUB_URL, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        print(f"[ERROR] tools-hub {action}: {e.code} {err[:300]}", file=sys.stderr)
        return {}


# ─── HTML パーサー ─────────────────────────────────────────────────────────────
class RaceListParser(html.parser.HTMLParser):
    """netkeiba レース一覧ページのパーサー"""

    def __init__(self):
        super().__init__()
        self.races = []
        self._in_race_cell = False
        self._cur = {}
        self._text_buf = ""

    def handle_starttag(self, tag, attrs):
        attr_dict = dict(attrs)
        cls = attr_dict.get("class", "")
        href = attr_dict.get("href", "")
        if tag == "td" and "RaceList_ItemTitle" in cls:
            self._in_race_cell = True
            self._cur = {}
        if self._in_race_cell and tag == "a" and "race_id=" in href:
            m = re.search(r"race_id=(\d+)", href)
            if m:
                self._cur["race_id_ext"] = m.group(1)

    def handle_endtag(self, tag):
        if tag == "td" and self._in_race_cell:
            self._in_race_cell = False
            if self._cur.get("race_id_ext"):
                self.races.append(dict(self._cur))
            self._cur = {}

    def handle_data(self, data):
        if self._in_race_cell:
            t = data.strip()
            if t:
                self._text_buf += t + " "
                # レース名の候補として収集
                if not self._cur.get("race_name") and len(t) > 1:
                    self._cur["race_name"] = t


class ShutubaParser(html.parser.HTMLParser):
    """出走表ページ (shutuba.html) のパーサー"""

    def __init__(self):
        super().__init__()
        self.entries = []
        self.race_info = {}
        self._in_horse_row = False
        self._cur_horse = {}
        self._col_idx = 0
        self._in_td = False
        self._td_text = ""

    def handle_starttag(self, tag, attrs):
        attr_dict = dict(attrs)
        cls = attr_dict.get("class", "")
        if tag == "tr" and "HorseList" in cls:
            self._in_horse_row = True
            self._cur_horse = {}
            self._col_idx = 0
        if self._in_horse_row and tag == "td":
            self._in_td = True
            self._td_text = ""
            self._col_idx += 1
        # レース情報
        if tag == "div" and cls in ("RaceData01", "RaceData02"):
            pass  # テキスト取得は handle_data で

    def handle_endtag(self, tag):
        if tag == "td" and self._in_td:
            self._in_td = False
            t = self._td_text.strip()
            col = self._col_idx
            # 列マッピング (netkeiba shutuba.html の標準列順)
            # 1:枠 2:馬番 3:印 4:馬名 5:性齢 6:斤量 7:騎手 8:厩舎 9:馬体重 10:単勝 11:人気
            if col == 2:
                self._cur_horse["horse_number"] = int(t) if t.isdigit() else None
            elif col == 4:
                self._cur_horse["horse_name"] = t or None
            elif col == 6:
                try:
                    self._cur_horse["weight_kg"] = float(t)
                except ValueError:
                    pass
            elif col == 7:
                self._cur_horse["jockey"] = t or None
            elif col == 8:
                self._cur_horse["trainer"] = t or None
            elif col == 10:
                try:
                    self._cur_horse["win_odds"] = float(t)
                except ValueError:
                    pass
            elif col == 11:
                try:
                    self._cur_horse["popularity"] = int(t)
                except ValueError:
                    pass
        if tag == "tr" and self._in_horse_row:
            self._in_horse_row = False
            if self._cur_horse.get("horse_name"):
                self.entries.append(dict(self._cur_horse))

    def handle_data(self, data):
        if self._in_td:
            self._td_text += data


class ResultParser(html.parser.HTMLParser):
    """結果ページ (result.html) のパーサー"""

    def __init__(self):
        super().__init__()
        self.results = {}  # place -> horse_name
        self.trifecta_paid = None
        self._in_result_row = False
        self._cur_row = {}
        self._col_idx = 0
        self._in_td = False
        self._td_text = ""
        self._in_pay_row = False
        self._pay_col = 0
        self._pay_type = ""

    def handle_starttag(self, tag, attrs):
        attr_dict = dict(attrs)
        cls = attr_dict.get("class", "")
        if tag == "tr" and "Result_Num" in cls:
            self._in_result_row = True
            self._cur_row = {}
            self._col_idx = 0
        if self._in_result_row and tag == "td":
            self._in_td = True
            self._td_text = ""
            self._col_idx += 1
        if tag == "tr" and "Payout" in cls:
            self._in_pay_row = True
            self._pay_col = 0

    def handle_endtag(self, tag):
        if tag == "td" and self._in_td:
            self._in_td = False
            t = self._td_text.strip()
            if self._in_result_row:
                col = self._col_idx
                if col == 1:
                    self._cur_row["place"] = t
                elif col == 3:
                    self._cur_row["horse_name"] = t
        if tag == "tr" and self._in_result_row:
            self._in_result_row = False
            place = self._cur_row.get("place", "")
            name = self._cur_row.get("horse_name", "")
            if place in ("1", "2", "3") and name:
                self.results[place] = name

    def handle_data(self, data):
        if self._in_td:
            self._td_text += data
        # 3連単配当を検出
        t = data.strip()
        if "三連単" in t:
            self._pay_type = "trifecta"
        if self._pay_type == "trifecta" and re.search(r"[\d,]+円", t):
            m = re.search(r"([\d,]+)円", t)
            if m:
                self.trifecta_paid = int(m.group(1).replace(",", ""))
                self._pay_type = ""


# ─── netkeiba レース ID から情報取得 ──────────────────────────────────────────
def parse_race_id(race_id: str, race_date: str) -> dict:
    """netkeiba race_id から開催場・ラウンド等を解析"""
    # 形式: YYYYMMDDAABBCC  AA=競馬場コード BB=回 CC=レース番号
    venue_map = {
        "01": "札幌", "02": "函館", "03": "福島", "04": "新潟",
        "05": "東京", "06": "中山", "07": "中京", "08": "京都",
        "09": "阪神", "10": "小倉",
    }
    if len(race_id) >= 12:
        venue_code = race_id[8:10]
        race_num = race_id[12:14] if len(race_id) >= 14 else ""
        venue = venue_map.get(venue_code, "不明")
        return {
            "venue": venue,
            "race_number": int(race_num) if race_num.isdigit() else None,
        }
    return {}


# ─── メイン処理 ───────────────────────────────────────────────────────────────
def fetch_entries(target_date: str):
    """指定日の出走表を取得して Supabase に保存"""
    print(f"[INFO] {target_date} の出走表を取得中...")
    date_nodash = target_date.replace("-", "")
    url = RACE_LIST_URL.format(date=date_nodash)
    html_text = http_get(url)
    if not html_text:
        print("[WARN] レース一覧の取得に失敗しました。")
        return

    # レース ID リストを抽出
    race_id_pattern = re.compile(r'race_id=(\d{12,})')
    race_ids = list(dict.fromkeys(race_id_pattern.findall(html_text)))
    print(f"[INFO] {len(race_ids)} レースを検出")

    saved_races = 0
    saved_entries = 0

    for race_id_ext in race_ids:
        # レースが既に登録済みか確認
        existing = supabase_rest("GET", "horse_races", params={"race_id_ext": f"eq.{race_id_ext}", "select": "id"})
        if existing:
            race_db_id = existing[0]["id"]
            print(f"  [SKIP] {race_id_ext} は既存 (id={race_db_id})")
        else:
            # 出走表ページを取得
            shutuba_html = http_get(SHUTUBA_URL.format(race_id=race_id_ext))
            time.sleep(1)  # サーバー負荷軽減

            venue_info = parse_race_id(race_id_ext, target_date)
            race_name = f"第{venue_info.get('race_number', '?')}レース" if venue_info.get("race_number") else f"レース {race_id_ext[-4:]}"

            # HTML からレース名を抽出
            if shutuba_html:
                m = re.search(r'<title>([^<]+)</title>', shutuba_html)
                if m:
                    title = m.group(1).strip()
                    # "東京1R 新馬 | race.netkeiba.com" のような形式
                    race_name_match = re.search(r'\d+R\s+([^\s|]+)', title)
                    if race_name_match:
                        race_name = race_name_match.group(1)

                # 距離・コース種別を抽出
                dist_match = re.search(r'(芝|ダート|障害)\s*(\d+)m', shutuba_html)
                course_type = dist_match.group(1) if dist_match else "芝"
                distance = int(dist_match.group(2)) if dist_match else None

                # グレードを抽出
                grade_match = re.search(r'(G1|G2|G3|リステッド|オープン|3勝|2勝|1勝|未勝利|新馬)', shutuba_html)
                grade = grade_match.group(1) if grade_match else "未勝利"

                # 発走時刻を抽出
                time_match = re.search(r'(\d{1,2}:\d{2})発走', shutuba_html)
                post_time = time_match.group(1) if time_match else None
            else:
                course_type = "芝"
                distance = None
                grade = "未勝利"
                post_time = None

            # レース登録
            race_row = {
                "source": "jra",
                "race_id_ext": race_id_ext,
                "race_name": race_name,
                "race_date": target_date,
                "venue": venue_info.get("venue"),
                "post_time": post_time,
                "course_type": course_type,
                "distance": distance,
                "grade": grade,
                "status": "scheduled",
            }
            result = supabase_rest("POST", "horse_races", race_row)
            if not result:
                print(f"  [ERROR] {race_id_ext} のレース登録失敗")
                continue
            race_db_id = result[0]["id"]
            saved_races += 1
            print(f"  [OK] レース登録: {race_name} ({race_id_ext}) id={race_db_id}")

            # 出走馬を登録
            if shutuba_html:
                parser = ShutubaParser()
                parser.feed(shutuba_html)
                for entry in parser.entries:
                    entry["race_id"] = race_db_id
                    supabase_rest("POST", "horse_entries", entry)
                    saved_entries += 1
                if parser.entries:
                    print(f"    {len(parser.entries)} 頭の出走馬を登録")
                # 出走頭数を更新
                supabase_rest("PATCH", f"horse_races?id=eq.{race_db_id}",
                              {"num_horses": len(parser.entries)})

    print(f"[DONE] レース {saved_races}件, 出走馬 {saved_entries}件 を登録")


def fetch_results(target_date: str):
    """指定日の completed でないレースの結果を取得して Supabase に保存"""
    print(f"[INFO] {target_date} のレース結果を取得中...")
    races = supabase_rest("GET", "horse_races", params={
        "race_date": f"eq.{target_date}",
        "status": "eq.scheduled",
        "race_id_ext": "not.is.null",
        "select": "id,race_id_ext,race_name",
    })
    if not races:
        print("[INFO] 対象レースなし")
        return

    hits = 0
    for race in races:
        race_id_ext = race["race_id_ext"]
        race_db_id = race["id"]
        result_html = http_get(RESULT_URL.format(race_id=race_id_ext))
        time.sleep(1)
        if not result_html:
            continue

        parser = ResultParser()
        parser.feed(result_html)

        if not (parser.results.get("1") and parser.results.get("2") and parser.results.get("3")):
            print(f"  [SKIP] {race['race_name']}: 結果未確定")
            continue

        # 予想との照合
        pred = supabase_rest("GET", "horse_predictions", params={
            "race_id": f"eq.{race_db_id}",
            "select": "first_pick,second_pick,third_pick",
        })
        is_correct = False
        if pred:
            p = pred[0]
            is_correct = (
                p.get("first_pick") == parser.results["1"] and
                p.get("second_pick") == parser.results["2"] and
                p.get("third_pick") == parser.results["3"]
            )

        result_row = {
            "race_id": race_db_id,
            "first_place": parser.results.get("1"),
            "second_place": parser.results.get("2"),
            "third_place": parser.results.get("3"),
            "trifecta_paid": parser.trifecta_paid,
            "is_prediction_correct": is_correct,
        }
        supabase_rest("POST", "horse_results", result_row)
        supabase_rest("PATCH", f"horse_races?id=eq.{race_db_id}", {"status": "completed"})

        mark = "○ 的中" if is_correct else "× 外れ"
        print(f"  [OK] {race['race_name']}: {mark} 1着={parser.results.get('1')} 2着={parser.results.get('2')} 3着={parser.results.get('3')}")
        if is_correct:
            hits += 1

    print(f"[DONE] 的中 {hits}件")


def trigger_ai_predictions(target_date: str):
    """tools-hub を呼び出して AI 3連単予想を実行"""
    print(f"[INFO] {target_date} のAI予想を実行中...")
    result = tools_hub_call("horseracing.predict_all", {"date": target_date})
    count = result.get("count", 0)
    msg = result.get("message", "")
    print(f"[DONE] {count}件の予想完了 {msg}")
    for pred in result.get("predictions", []):
        print(f"  {pred.get('race_name', '?')}: {pred.get('first', '?')}-{pred.get('second', '?')}-{pred.get('third', '?')} (信頼度:{pred.get('confidence', 0):.0%})")


# ─── CLI エントリーポイント ────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="競馬情報自動取得スクリプト")
    parser.add_argument(
        "--mode",
        choices=["entries", "results", "predict", "all"],
        required=True,
        help="実行モード: entries=出走表, results=結果, predict=AI予想, all=全て実行",
    )
    parser.add_argument(
        "--date",
        default=None,
        help="対象日付 YYYY-MM-DD (省略時は今日)",
    )
    args = parser.parse_args()

    if not SUPABASE_KEY:
        print("[ERROR] SUPABASE_SERVICE_KEY が設定されていません", file=sys.stderr)
        sys.exit(1)

    target_date = args.date or datetime.date.today().isoformat()

    if args.mode == "entries":
        fetch_entries(target_date)
    elif args.mode == "results":
        fetch_results(target_date)
    elif args.mode == "predict":
        trigger_ai_predictions(target_date)
    elif args.mode == "all":
        fetch_entries(target_date)
        trigger_ai_predictions(target_date)
        fetch_results(target_date)


if __name__ == "__main__":
    main()
