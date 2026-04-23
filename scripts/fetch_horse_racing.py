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
    NAR 全ページ (race/ horse/ top/) は EUC-JP で確定デコードする。"""
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            # NAR ページは常に EUC-JP — UTF-8 で誤デコードする前に確定デコード
            if "nar.netkeiba.com" in url:
                return raw.decode("euc-jp", errors="replace")
            # その他のページ: Content-Type → meta charset → フォールバック
            charset = resp.headers.get_content_charset()
            if not charset:
                m = re.search(rb"charset=[\"']?\s*([A-Za-z0-9_-]+)", raw[:4096])
                if m:
                    charset = m.group(1).decode("ascii", errors="ignore")
            candidates: list[str] = []
            if charset:
                candidates.append(charset)
            for enc in ("utf-8", "euc-jp", "shift-jis", "cp932"):
                normalized = enc.replace("-", "").lower()
                if not any(normalized == c.replace("-", "").lower() for c in candidates):
                    candidates.append(enc)
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


def tools_hub_call(action: str, extra: dict = None, timeout: int = 300) -> dict:
    """tools-hub Edge Function 呼び出し (Windows版#94b: timeout 120 → 300s)"""
    payload = {"action": action, **(extra or {})}
    body = json.dumps(payload).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }
    req = urllib.request.Request(TOOLS_HUB_URL, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        print(f"[ERROR] tools-hub {action}: {e.code} {err[:300]}", file=sys.stderr)
        return {}
    except TimeoutError as e:
        print(f"[ERROR] tools-hub {action}: read timeout ({timeout}s) — {e}", file=sys.stderr)
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
        href = attr_dict.get("href", "")
        if tag == "tr" and "HorseList" in cls:
            self._in_horse_row = True
            self._cur_horse = {}
            self._col_idx = 0
        if self._in_horse_row and tag == "td":
            self._in_td = True
            self._td_text = ""
            self._col_idx += 1
        # 馬名セル内の <a href="/horse/XXXX/"> から horse_id_ext を取得
        if self._in_horse_row and tag == "a" and "/horse/" in href:
            m = re.search(r"/horse/(\w+)/?", href)
            if m:
                self._cur_horse["horse_id_ext"] = m.group(1)

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
            elif col == 5:
                self._cur_horse["age_sex"] = t or None  # 例: 牡3, 牝4, セ5
            elif col == 6:
                try:
                    self._cur_horse["weight_kg"] = float(t)
                except ValueError:
                    pass
            elif col == 7:
                self._cur_horse["jockey"] = t or None
            elif col == 8:
                self._cur_horse["trainer"] = t or None
            elif col == 9:
                # 馬体重: "480(+2)" or "480(-4)" or "480" or "計不"
                wm = re.search(r"(\d{3,4})", t)
                if wm:
                    self._cur_horse["horse_weight"] = int(wm.group(1))
                cm = re.search(r"\(([+-]?\d+)\)", t)
                if cm:
                    self._cur_horse["horse_weight_change"] = int(cm.group(1))
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
    """結果ページ (result.html) のパーサー (2026-04 HTML構造対応版)

    実際のHTMLは以下の構造:
      データ行: <tr ><td class="Result_Num"><div class="Rank">1</div>...
                <td class="Horse_Info"><span class="Horse_Name"><a ...>馬名</a>
      三連単:   <tr class="Tan3"><th>3連単</th>...<td class="Payout"><span>19,970円</span>
    """

    def __init__(self):
        super().__init__()
        self.results = {}       # place -> horse_name
        self.trifecta_paid = None
        self._in_result_row = False   # data row (class-less <tr>)
        self._cur_place = None        # "1" / "2" / "3" within current row
        self._in_result_num_td = False
        self._in_rank_div = False
        self._in_horse_info_td = False
        self._in_horse_name_a = False
        self._in_tan3_row = False     # <tr class="Tan3">
        self._in_payout_td = False
        self._in_payout_span = False
        self._buf = ""

    def handle_starttag(self, tag, attrs):
        attr_dict = dict(attrs)
        cls = attr_dict.get("class", "")

        if tag == "tr":
            # Data rows have no class; header/payment rows have a class
            self._in_result_row = not cls.strip()
            self._in_tan3_row = "Tan3" in cls
            self._cur_place = None
            self._in_result_num_td = False
            self._in_horse_info_td = False

        if tag == "td":
            if "Result_Num" in cls and self._in_result_row:
                self._in_result_num_td = True
            if "Horse_Info" in cls and self._in_result_row:
                self._in_horse_info_td = True
            if "Payout" in cls and self._in_tan3_row:
                self._in_payout_td = True

        if tag == "div" and attr_dict.get("class") == "Rank" and self._in_result_num_td:
            self._in_rank_div = True
            self._buf = ""

        if tag == "a" and self._in_horse_info_td and not self._in_horse_name_a:
            self._in_horse_name_a = True
            self._buf = ""

        if tag == "span" and self._in_payout_td:
            self._in_payout_span = True
            self._buf = ""

    def handle_endtag(self, tag):
        if tag == "tr":
            self._in_result_row = False
            self._in_tan3_row = False
            self._cur_place = None
            self._in_result_num_td = False
            self._in_horse_info_td = False

        if tag == "td":
            self._in_result_num_td = False
            self._in_horse_info_td = False
            self._in_payout_td = False

        if tag == "div" and self._in_rank_div:
            self._in_rank_div = False
            t = self._buf.strip()
            if t.isdigit():
                self._cur_place = t

        if tag == "a" and self._in_horse_name_a:
            self._in_horse_name_a = False
            horse_name = self._buf.strip()
            if horse_name and self._cur_place in ("1", "2", "3"):
                self.results[self._cur_place] = horse_name

        if tag == "span" and self._in_payout_span:
            self._in_payout_span = False
            self._in_payout_td = False
            m = re.search(r"([\d,]+)円", self._buf)
            if m and self.trifecta_paid is None:
                self.trifecta_paid = int(m.group(1).replace(",", ""))

    def handle_data(self, data):
        if (self._in_rank_div or self._in_horse_name_a or self._in_payout_span):
            self._buf += data



class HorsePageParser(html.parser.HTMLParser):
    """馬個別ページ (netkeiba.com/horse/XXXX/) から前走情報を取得するパーサー。"""

    def __init__(self):
        super().__init__()
        self.prev_race: dict = {}
        self._in_table = False
        self._headers: list[str] = []
        self._rows: list[list[str]] = []
        self._cur_row: list[str] = []
        self._in_td = False
        self._in_th = False
        self._cell_text = ""

    def handle_starttag(self, tag, attrs):
        attr_dict = dict(attrs)
        cls = attr_dict.get("class", "")
        if tag == "table" and "race_table_01" in cls:
            self._in_table = True
            self._headers = []
            self._rows = []
        if self._in_table:
            if tag == "tr":
                self._cur_row = []
            elif tag == "td":
                self._in_td = True
                self._cell_text = ""
            elif tag == "th":
                self._in_th = True
                self._cell_text = ""

    def handle_endtag(self, tag):
        if not self._in_table:
            return
        if tag == "td" and self._in_td:
            self._in_td = False
            self._cur_row.append(self._cell_text.strip())
        elif tag == "th" and self._in_th:
            self._in_th = False
            self._headers.append(self._cell_text.strip())
        elif tag == "tr":
            if self._cur_row:
                self._rows.append(list(self._cur_row))
            self._cur_row = []
        elif tag == "table" and self._in_table:
            self._in_table = False
            self._extract_prev_race()

    def handle_data(self, data):
        if self._in_td or self._in_th:
            self._cell_text += data.strip()

    def _extract_prev_race(self) -> None:
        """成績テーブルの最初のデータ行 (=前走) から情報を抽出する。"""
        if not self._rows:
            return
        col_map: dict[str, int] = {}
        for i, h in enumerate(self._headers):
            col_map[h.replace(" ", "").replace("\u3000", "")] = i

        for row in self._rows:
            if len(row) < 5:
                continue
            date_idx = col_map.get("日付", 0)
            date_str = row[date_idx] if date_idx < len(row) else (row[0] if row else "")
            dm = re.search(r"(\d{4})[/](\d{1,2})[/](\d{1,2})", date_str)
            if not dm:
                continue

            finish_idx = col_map.get("着順", col_map.get("着", 11))
            race_name_idx = col_map.get("レース名", 4)
            venue_idx = col_map.get("開催", 1)
            dist_idx = col_map.get("距離", 14)
            time_idx = col_map.get("タイム", 16)

            def safe_get(r: list, idx: int) -> str:
                return r[idx].strip() if idx < len(r) else ""

            finish_str = safe_get(row, finish_idx)
            finish_clean = re.sub(r"[^\d]", "", finish_str)
            finish = int(finish_clean) if finish_clean else None
            dist_str = safe_get(row, dist_idx)
            dist_m = re.search(r"(芝|ダート|障害|ばんえい)\s*(\d+)", dist_str)
            prev_date = f"{dm.group(1)}-{int(dm.group(2)):02d}-{int(dm.group(3)):02d}"
            self.prev_race = {
                "prev_race_date": prev_date,
                "prev_venue": safe_get(row, venue_idx) or None,
                "prev_race_name": safe_get(row, race_name_idx) or None,
                "prev_finish": finish,
                "prev_course_type": dist_m.group(1) if dist_m else None,
                "prev_distance": int(dist_m.group(2)) if dist_m else None,
                "prev_time": safe_get(row, time_idx) or None,
            }
            break


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



# ─── 前走情報取得 ─────────────────────────────────────────────────────────────
def fetch_prev_race_info(horse_id_ext: str, source: str, race_date: str) -> dict:
    """馬個別ページから前走情報を取得する。"""
    url = (
        f"https://nar.netkeiba.com/horse/{horse_id_ext}/"
        if source == "nar"
        else f"https://db.netkeiba.com/horse/{horse_id_ext}/"
    )
    html_text = http_get(url, timeout=20)
    if not html_text:
        return {}
    p = HorsePageParser()
    p.feed(html_text)
    info = p.prev_race
    if not info:
        return {}
    prev_date_str = info.get("prev_race_date")
    if prev_date_str:
        try:
            prev_dt = datetime.date.fromisoformat(prev_date_str)
            cur_dt = datetime.date.fromisoformat(race_date)
            info["prev_days_ago"] = (cur_dt - prev_dt).days
        except ValueError:
            pass
    return info


def fetch_horse_histories(target_date: str) -> None:
    """当日出走馬の前走情報を馬個別ページから取得してDBを更新する。
    prev_history_fetched が false のエントリのみ対象 (404 済みはスキップ)。"""
    print(f"[INFO] {target_date} の出走馬 前走情報を取得中...")
    races = supabase_rest("GET", "horse_races", params={
        "race_date": f"eq.{target_date}",
        "select": "id,source",
    })
    if not races:
        print("[INFO] 対象レースなし")
        return

    total_updated = 0
    total_skipped = 0
    for race in races:
        race_id = race["id"]
        source = race.get("source", "jra")
        entries = supabase_rest("GET", "horse_entries", params={
            "race_id": f"eq.{race_id}",
            "horse_id_ext": "not.is.null",
            "prev_history_fetched": "eq.false",
            "select": "id,horse_id_ext,horse_name",
        })
        if not entries:
            continue
        failed_ids: list[str] = []
        for entry in entries:
            horse_id_ext = entry.get("horse_id_ext")
            if not horse_id_ext:
                continue
            prev_info = fetch_prev_race_info(horse_id_ext, source, target_date)
            if not prev_info:
                # 404 failures are instant — no sleep needed; batch the PATCH
                failed_ids.append(entry["id"])
                total_skipped += 1
                print(f"    [SKIP] {entry.get('horse_name', '?')}: 前走情報取得失敗 (フラグ設定)")
                continue
            time.sleep(1)  # レート制限: 成功した HTML ページ取得後のみ待機
            supabase_rest("PATCH", f"horse_entries?id=eq.{entry['id']}",
                          {**prev_info, "prev_history_fetched": True})
            print(
                f"    [OK] {entry.get('horse_name', '?')}: "
                f"前走{prev_info.get('prev_finish')}着 "
                f"({prev_info.get('prev_race_name', '?')}, "
                f"{prev_info.get('prev_days_ago')}日前)"
            )
            total_updated += 1
        # 失敗エントリを一括 PATCH (個別 DB コール削減)
        if failed_ids:
            ids_csv = ",".join(failed_ids)
            supabase_rest("PATCH", f"horse_entries?id=in.({ids_csv})",
                          {"prev_history_fetched": True})

    print(f"[DONE] {total_updated}頭更新, {total_skipped}頭スキップ (404済み)")


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

    # 既存レースを1回のクエリで一括取得 (N回DBクエリ → 1回)
    existing_rows = supabase_rest("GET", "horse_races", params={
        "race_date": f"eq.{target_date}",
        "source": f"eq.{source}",
        "select": "race_id_ext",
    }) or []
    existing_ids: set[str] = {r["race_id_ext"] for r in existing_rows if r.get("race_id_ext")}
    skipped = sum(1 for rid in race_ids if rid in existing_ids)
    if skipped:
        print(f"  [{source.upper()}] {skipped} レースをスキップ (既存)")

    saved_races = 0
    saved_entries = 0

    for race_id_ext in race_ids:
        if race_id_ext in existing_ids:
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
            "race_number": venue_info.get("race_number"),
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
    """JRA + NAR の scheduled レースの結果を取得して Supabase に保存

    過去7日間の未確定レース (status=scheduled) も対象にする。
    当日に結果が確定しなかった場合、翌日以降の run で自動リトライされる。
    """
    from_date = (
        datetime.date.fromisoformat(target_date) - datetime.timedelta(days=7)
    ).isoformat()
    print(f"[INFO] {from_date}〜{target_date} のレース結果を取得中...")
    # supabase_rest に list of tuples を渡すことで同一カラムへの複数条件を実現
    races = supabase_rest("GET", "horse_races", params=[
        ("race_date", f"lte.{target_date}"),
        ("race_date", f"gte.{from_date}"),
        ("status", "eq.scheduled"),
        ("race_id_ext", "not.is.null"),
        ("select", "id,race_id_ext,race_name,source,race_date"),
        ("order", "race_date.asc"),
    ])
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
            race_date_label = race.get("race_date", "")
            print(f"  [SKIP] [{source.upper()}] {race_date_label} {race['race_name']}: 結果未確定")
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
        # ensemble 予想の精度をスコアリング → horse_provider_leaderboard に反映
        tools_hub_call("horseracing.evaluate_accuracy", {"race_id": race_db_id})

        mark = "○ 的中" if is_correct else "× 外れ"
        src_label = f"[{source.upper()}]"
        race_date_label = race.get("race_date", "")
        print(
            f"  [OK] {src_label} {race_date_label} {race['race_name']}: {mark} "
            f"1着={parser.results.get('1')} "
            f"2着={parser.results.get('2')} "
            f"3着={parser.results.get('3')}"
        )
        if is_correct:
            hits += 1

    print(f"[DONE] 的中 {hits}件")


def trigger_ai_predictions(target_date: str):
    """tools-hub を呼び出して AI 3連単予想を実行 (multi-provider fallback chain)

    Windows版#94b: EF 150s timeout 対策で batch 処理 (limit=20) をループ実行。
    全レースが予想完了するか、3 batch 連続で進捗 0 になったら停止。"""
    print(f"[INFO] {target_date} のAI予想を実行中...")
    total_results: list = []
    total_failures: list = []
    total_stats: dict = {}
    batch_limit = 20
    max_batches = 10  # 安全上限 (batch_limit 20 × 10 = 200 レースまで)
    no_progress_count = 0
    for i in range(max_batches):
        result = tools_hub_call(
            "horseracing.predict_all",
            {"date": target_date, "limit": batch_limit},
        )
        batch_count = result.get("count", 0)
        remaining = result.get("remaining", 0)
        total_unpredicted = result.get("total_unpredicted", 0)
        print(
            f"[BATCH {i + 1}] {batch_count}件予想 / 残り{remaining}件 / "
            f"全未予想{total_unpredicted}件"
        )
        total_results.extend(result.get("predictions", []))
        total_failures.extend(result.get("failures", []))
        for k, v in (result.get("provider_stats") or {}).items():
            if k not in total_stats:
                total_stats[k] = {"attempts": 0, "hits": 0, "quotas": 0}
            for field in ("attempts", "hits", "quotas"):
                total_stats[k][field] += v.get(field, 0)
        if batch_count == 0:
            no_progress_count += 1
            if no_progress_count >= 2:
                print("[WARN] 2 batch 連続で進捗 0 件 → 停止", file=sys.stderr)
                break
        else:
            no_progress_count = 0
        if remaining == 0 or not result:
            break
    result = {
        "predictions": total_results,
        "count": len(total_results),
        "failures": total_failures,
        "provider_stats": total_stats,
        "exhausted_providers": [],
    }
    count = result.get("count", 0)
    print(f"[DONE] 計 {count}件の予想完了 (全 batch 合計)")
    for pred in result.get("predictions", []):
        provider = pred.get("provider", "?")
        model = pred.get("model", "?")
        print(
            f"  {pred.get('race_name', '?')} [{provider}:{model}]: "
            f"{pred.get('first', '?')}-{pred.get('second', '?')}-{pred.get('third', '?')} "
            f"(信頼度:{pred.get('confidence', 0):.0%})"
        )
    failures = result.get("failures", [])
    if failures:
        print(f"[WARN] 失敗 {len(failures)}件:", file=sys.stderr)
        for f in failures[:20]:
            reason = f.get("reason", "?")
            race_name = f.get("race_name", "?")
            print(f"  - {race_name}: {reason}", file=sys.stderr)
        if len(failures) > 20:
            print(f"  ... (+{len(failures) - 20}件)", file=sys.stderr)
    stats = result.get("provider_stats") or {}
    if stats:
        print("[STATS] プロバイダー別:", file=sys.stderr)
        for provider, s in stats.items():
            print(
                f"  {provider}: 試行{s.get('attempts', 0)} / 成功{s.get('hits', 0)} / quota{s.get('quotas', 0)}",
                file=sys.stderr,
            )
    exhausted = result.get("exhausted_providers") or []
    if exhausted:
        print(f"[WARN] quota 到達プロバイダー: {', '.join(exhausted)}", file=sys.stderr)


# ─── 定期クリーンアップ ───────────────────────────────────────────────────────
def cleanup_stale_races() -> None:
    """過去日付のまま status='scheduled' で残っているレースを 'cancelled' に更新する。
    前日以前のレースは結果取得の機会を逃しているため cancelled にマーク。"""
    yesterday = (datetime.date.today() - datetime.timedelta(days=1)).isoformat()
    stale = supabase_rest("GET", "horse_races", params={
        "status": "eq.scheduled",
        "race_date": f"lt.{yesterday}",
        "select": "id",
    }) or []
    if not stale:
        return
    ids = [r["id"] for r in stale]
    # Supabase REST: id=in.(uuid1,uuid2,...) で一括 PATCH
    ids_csv = ",".join(ids)
    supabase_rest("PATCH", f"horse_races?id=in.({ids_csv})", {"status": "cancelled"})
    print(f"[CLEANUP] {len(ids)} 件の古い scheduled レースを cancelled に更新")


# ─── CLI エントリーポイント ────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="競馬情報自動取得スクリプト (JRA + NAR)")
    parser.add_argument(
        "--mode",
        choices=["entries", "results", "predict", "history", "all"],
        required=True,
        help="実行モード: entries=出走表, results=結果, predict=AI予想, history=前走情報, all=全て実行",
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
    elif args.mode == "history":
        fetch_horse_histories(target_date)
    elif args.mode == "all":
        cleanup_stale_races()
        fetch_entries(target_date)
        fetch_horse_histories(target_date)
        trigger_ai_predictions(target_date)
        fetch_results(target_date)


if __name__ == "__main__":
    main()
