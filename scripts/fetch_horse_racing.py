#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
競馬情報自動取得スクリプト
JRA / NAR (地方競馬) の出走表と結果を netkeiba.com からスクレイピングして Supabase に保存する。

使用方法:
  python fetch_horse_racing.py --mode entries [--date YYYY-MM-DD]   # 出走表取得
  python fetch_horse_racing.py --mode results [--date YYYY-MM-DD]   # 結果取得
  python fetch_horse_racing.py --mode predict                        # AI予想実行 (EF呼び出し)
  python fetch_horse_racing.py --mode all                            # 全て実行

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

# JRA (中央競馬) URL テンプレート
JRA_RACE_LIST_URL = "https://race.netkeiba.com/top/race_list_sub.html?kaisai_date={date}"
JRA_SHUTUBA_URL   = "https://race.netkeiba.com/race/shutuba.html?race_id={race_id}"
JRA_RESULT_URL    = "https://race.netkeiba.com/race/result.html?race_id={race_id}"

# NAR (地方競馬) URL テンプレート
NAR_RACE_LIST_URL = "https://nar.netkeiba.com/top/race_list_sub.html?kaisai_date={date}"
NAR_SHUTUBA_URL   = "https://nar.netkeiba.com/race/shutuba.html?race_id={race_id}"
NAR_RESULT_URL    = "https://nar.netkeiba.com/race/result.html?race_id={race_id}"

# JRA 競馬場コード (race_id の 9-10 桁目 = positions [8:10])
# JRA race_id 構造: YYYY(4) + kai(2) + day(2) + venue(2) + race(2) = 14桁
JRA_VENUE_MAP = {
    "01": "札幌", "02": "函館", "03": "福島", "04": "新潟",
    "05": "東京", "06": "中山", "07": "中京", "08": "京都",
    "09": "阪神", "10": "小倉",
}

# NAR 競馬場コード (race_id の 5-6 桁目 = positions [4:6])
# NAR race_id 構造: YYYY(4) + venue(2) + MM(2) + DD(2) + race(2) = 12桁
NAR_VENUE_MAP = {
    "30": "門別", "35": "盛岡", "36": "水沢", "42": "浦和",
    "43": "船橋", "44": "大井", "45": "川崎", "46": "金沢",
    "48": "笠松", "50": "名古屋", "54": "園田", "55": "姫路",
    "61": "高知", "63": "佐賀", "68": "帯広",
}

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "ja,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

# U+FFFD 置換文字 と CJK Extension A 先頭 (文字化け検出用)
# nar.netkeiba.com の EUC-JP バイト列が UTF-8 として偶然デコードされると
# CJK Extension A (U+3400-U+4DBF) の文字になる
_REPLACEMENT_CHAR = chr(0xFFFD)
_CJK_EXT_A_START = 0x3400
_CJK_EXT_A_END = 0x4DBF


# ─── HTTP ヘルパー ─────────────────────────────────────────────────────────────
def http_get(url: str, timeout: int = 15) -> Optional[str]:
    """HTML を取得して正しいエンコーディングで文字列に変換する。
    nar.netkeiba.com は EUC-JP を使うため多段フォールバックで検出する。"""
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            # 1. nar.netkeiba.com は EUC-JP 固定 (meta charset が UTF-8 と誤申告しても上書き)
            if "nar.netkeiba.com" in url:
                charset = "euc-jp"
            else:
                # Content-Type ヘッダーの charset
                charset = resp.headers.get_content_charset()
                # HTML の <meta charset=...> タグを先頭 4KB から検索
                if not charset:
                    m = re.search(rb"charset=[\"']?\s*([A-Za-z0-9_-]+)", raw[:4096])
                    if m:
                        charset = m.group(1).decode("ascii", errors="ignore")
            # 2. 検出 charset -> UTF-8 -> EUC-JP -> Shift-JIS の順で試す
            candidates: list[str] = []
            if charset:
                candidates.append(charset)
            for enc in ("utf-8", "euc-jp", "shift-jis", "cp932"):
                normalized = enc.replace("-", "").lower()
                if not any(normalized == c.replace("-", "").lower() for c in candidates):
                    candidates.append(enc)
            meta_pos = raw.find(b'charset')
            meta_ctx = raw[max(0, meta_pos - 5):meta_pos + 25] if meta_pos >= 0 else b""
            ct_hdr = resp.headers.get_content_charset()
            print(f"    [DEBUG] {url[-55:]} ct={ct_hdr!r} forced={charset!r} meta_raw={meta_ctx!r}", file=sys.stderr)
            for enc in candidates:
                try:
                    return raw.decode(enc)
                except (UnicodeDecodeError, LookupError):
                    continue
            return raw.decode("utf-8", errors="replace")
    except Exception as e:
        print(f"[WARN] GET {url} failed: {e}", file=sys.stderr)
        return None


def supabase_rest(method: str, table: str, data=None, params: dict = None):
    """Supabase REST API 呼び出し"""
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    body = json.dumps(data).encode("utf-8") if data else None
    prefer = (
        "return=representation"
        if method == "DELETE"
        else "return=representation,resolution=merge-duplicates"
    )
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": prefer,
    }
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body_bytes = resp.read()
            return json.loads(body_bytes.decode("utf-8")) if body_bytes else []
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
        if tag == "div" and cls in ("RaceData01", "RaceData02"):
            pass

    def handle_endtag(self, tag):
        if tag == "td" and self._in_td:
            self._in_td = False
            t = self._td_text.strip()
            col = self._col_idx
            # 列マッピング: 1:枠 2:馬番 3:印 4:馬名 5:性齢 6:斤量 7:騎手 8:厩舎 9:馬体重 10:単勝 11:人気
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
            self._pay_type = ""

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
        t = data.strip()
        if "三連単" in t:
            self._pay_type = "trifecta"
        if self._pay_type == "trifecta" and re.search(r"[\d,]+円", t):
            m = re.search(r"([\d,]+)円", t)
            if m:
                self.trifecta_paid = int(m.group(1).replace(",", ""))
                self._pay_type = ""


# ─── race_id パーサー ─────────────────────────────────────────────────────────
def parse_race_id(race_id: str, source: str) -> dict:
    """netkeiba race_id から開催場・レース番号等を解析

    JRA: YYYY(4) + kai(2) + day(2) + venue(2) + race(2) = 14桁  venue=[8:10]
    NAR: YYYY(4) + venue(2) + MM(2) + DD(2) + race(2)   = 12桁  venue=[4:6]
    """
    if source == "nar":
        if len(race_id) < 12:
            return {}
        venue_code = race_id[4:6]
        race_num = race_id[10:12]
        venue = NAR_VENUE_MAP.get(venue_code, "不明")
    else:
        if len(race_id) < 12:
            return {}
        venue_code = race_id[8:10]
        race_num = race_id[12:14] if len(race_id) >= 14 else ""
        venue = JRA_VENUE_MAP.get(venue_code, "不明")
    return {
        "venue": venue,
        "race_number": int(race_num) if race_num.isdigit() else None,
    }


# ─── 文字化けレコード削除 ────────────────────────────────────────────────────
def _clean_garbled_races(target_date: str, source: str) -> int:
    """文字化けしている horse_races レコードを削除してリフェッチを可能にする。
    NAR サイトが EUC-JP で配信するため、エンコーディング修正前に保存されたレコードを
    U+FFFD 置換文字の有無で検出して削除する。"""
    races = supabase_rest("GET", "horse_races", params={
        "race_date": f"eq.{target_date}",
        "source": f"eq.{source}",
        "select": "id,race_name",
    })
    if not races:
        return 0

    deleted = 0
    for race in races:
        race_name = race.get("race_name", "") or ""
        is_garbled = _REPLACEMENT_CHAR in race_name or any(
            _CJK_EXT_A_START <= ord(c) <= _CJK_EXT_A_END for c in race_name
        )
        if is_garbled:
            race_db_id = race["id"]
            supabase_rest("DELETE", f"horse_entries?race_id=eq.{race_db_id}")
            supabase_rest("DELETE", f"horse_predictions?race_id=eq.{race_db_id}")
            supabase_rest("DELETE", f"horse_results?race_id=eq.{race_db_id}")
            supabase_rest("DELETE", f"horse_races?id=eq.{race_db_id}")
            print(f"    [CLEAN] 文字化けレコード削除: {race_name!r} (id={race_db_id})")
            deleted += 1

    return deleted


# ─── 出走表取得 (JRA / NAR 共通ロジック) ──────────────────────────────────────
def _fetch_entries_for_source(
    target_date: str,
    source: str,
    race_list_url: str,
    shutuba_url: str,
) -> tuple[int, int]:
    """指定ソースの出走表を取得して Supabase に保存。(saved_races, saved_entries) を返す"""
    date_nodash = target_date.replace("-", "")

    # エンコーディング修正前に保存された文字化けレコードを削除してリフェッチを可能にする
    cleaned = _clean_garbled_races(target_date, source)
    if cleaned > 0:
        print(f"  [{source.upper()}] {cleaned}件の文字化けレコードを削除しました")

    url = race_list_url.format(date=date_nodash)
    html_text = http_get(url)
    if not html_text:
        print(f"  [WARN] {source.upper()} レース一覧の取得に失敗")
        return 0, 0

    race_id_pattern = re.compile(r'race_id=(\d{12,})')
    race_ids = list(dict.fromkeys(race_id_pattern.findall(html_text)))
    print(f"  [{source.upper()}] {len(race_ids)} レースを検出")

    saved_races = 0
    saved_entries = 0

    for race_id_ext in race_ids:
        existing = supabase_rest("GET", "horse_races", params={
            "race_id_ext": f"eq.{race_id_ext}", "select": "id",
        })
        if existing:
            print(f"    [SKIP] {race_id_ext} は既存")
            continue

        shutuba_html = http_get(shutuba_url.format(race_id=race_id_ext))
        time.sleep(1)

        venue_info = parse_race_id(race_id_ext, source)
        race_name = (
            f"第{venue_info.get('race_number', '?')}レース"
            if venue_info.get("race_number")
            else f"レース {race_id_ext[-4:]}"
        )

        course_type = "芝"
        distance = None
        grade = "未勝利"
        post_time = None

        if shutuba_html:
            m = re.search(r'<title>([^<]+)</title>', shutuba_html)
            if m:
                title = m.group(1).strip()
                race_name_match = re.search(r'\d+R\s+([^\s|]+)', title)
                if race_name_match:
                    race_name = race_name_match.group(1)

            dist_match = re.search(r'(芝|ダート|障害|ばんえい)\s*(\d+)m?', shutuba_html)
            if dist_match:
                course_type = dist_match.group(1)
                if dist_match.group(2):
                    distance = int(dist_match.group(2))
            grade_match = re.search(r'(G1|G2|G3|リステッド|オープン|3勝|2勝|1勝|未勝利|新馬|重賞)', shutuba_html)
            grade = grade_match.group(1) if grade_match else "一般"
            time_match = re.search(r'(\d{1,2}:\d{2})発走', shutuba_html)
            post_time = time_match.group(1) if time_match else None

        race_row = {
            "source": source,
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
            print(f"    [ERROR] {race_id_ext} のレース登録失敗")
            continue
        race_db_id = result[0]["id"]
        saved_races += 1
        print(f"    [OK] {source.upper()} レース登録: {race_name} ({race_id_ext})")

        if shutuba_html:
            parser = ShutubaParser()
            parser.feed(shutuba_html)
            for entry in parser.entries:
                entry["race_id"] = race_db_id
                supabase_rest("POST", "horse_entries", entry)
                saved_entries += 1
            if parser.entries:
                print(f"      {len(parser.entries)} 頭の出走馬を登録")
            supabase_rest("PATCH", f"horse_races?id=eq.{race_db_id}",
                          {"num_horses": len(parser.entries)})

    return saved_races, saved_entries


# ─── メイン処理 ───────────────────────────────────────────────────────────────
def fetch_entries(target_date: str):
    """JRA + NAR (地方競馬) の出走表を取得して Supabase に保存"""
    print(f"[INFO] {target_date} の出走表を取得中...")

    jra_races, jra_entries = _fetch_entries_for_source(
        target_date, "jra", JRA_RACE_LIST_URL, JRA_SHUTUBA_URL,
    )
    nar_races, nar_entries = _fetch_entries_for_source(
        target_date, "nar", NAR_RACE_LIST_URL, NAR_SHUTUBA_URL,
    )

    total_races = jra_races + nar_races
    total_entries = jra_entries + nar_entries
    print(
        f"[DONE] JRA: {jra_races}レース/{jra_entries}頭  "
        f"NAR: {nar_races}レース/{nar_entries}頭  "
        f"合計: {total_races}レース/{total_entries}頭 を登録"
    )


def fetch_results(target_date: str):
    """JRA + NAR の scheduled レースの結果を取得して Supabase に保存"""
    print(f"[INFO] {target_date} のレース結果を取得中...")
    races = supabase_rest("GET", "horse_races", params={
        "race_date": f"eq.{target_date}",
        "status": "eq.scheduled",
        "race_id_ext": "not.is.null",
        "select": "id,race_id_ext,race_name,source",
    })
    if not races:
        print("[INFO] 対象レースなし")
        return

    hits = 0
    for race in races:
        race_id_ext = race["race_id_ext"]
        race_db_id = race["id"]
        source = race.get("source", "jra")

        # ソースに応じて正しいURLを選択
        result_url_template = NAR_RESULT_URL if source == "nar" else JRA_RESULT_URL
        result_html = http_get(result_url_template.format(race_id=race_id_ext))
        time.sleep(1)
        if not result_html:
            continue

        parser = ResultParser()
        parser.feed(result_html)

        if not (parser.results.get("1") and parser.results.get("2") and parser.results.get("3")):
            print(f"  [SKIP] [{source.upper()}] {race['race_name']}: 結果未確定")
            continue

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
        src_label = f"[{source.upper()}]"
        print(
            f"  [OK] {src_label} {race['race_name']}: {mark} "
            f"1着={parser.results.get('1')} "
            f"2着={parser.results.get('2')} "
            f"3着={parser.results.get('3')}"
        )
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
        print(
            f"  {pred.get('race_name', '?')}: "
            f"{pred.get('first', '?')}-{pred.get('second', '?')}-{pred.get('third', '?')} "
            f"(信頼度:{pred.get('confidence', 0):.0%})"
        )


# ─── CLI エントリーポイント ────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="競馬情報自動取得スクリプト (JRA + NAR)")
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
