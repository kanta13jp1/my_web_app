#!/usr/bin/env python3
"""fetch_horse_racing.py に前走情報取得機能を追加するパッチスクリプト"""
import re

filepath = "scripts/fetch_horse_racing.py"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# ── 1. http_get: NAR全ページ対応 ─────────────────────────────────────────────
content = content.replace(
    '"""HTML を取得して正しいエンコーディングで文字列に変換する。\n'
    '    NAR shutuba/result ページは EUC-JP を errors=replace で確定デコードする。"""',
    '"""HTML を取得して正しいエンコーディングで文字列に変換する。\n'
    '    NAR 全ページ (race/ horse/ top/) は EUC-JP で確定デコードする。"""'
)
content = content.replace(
    '            if "nar.netkeiba.com/race/" in url:\n'
    '                return raw.decode("euc-jp", errors="ignore")',
    '            if "nar.netkeiba.com/" in url:\n'
    '                return raw.decode("euc-jp", errors="ignore")'
)
print("[1] http_get updated")

# ── 2. ShutubaParser: horse_id_ext / age_sex / horse_weight 追加 ─────────────
OLD_SHUTUBA_STARTTAG = (
    '    def handle_starttag(self, tag, attrs):\n'
    '        attr_dict = dict(attrs)\n'
    '        cls = attr_dict.get("class", "")\n'
    '        if tag == "tr" and "HorseList" in cls:\n'
    '            self._in_horse_row = True\n'
    '            self._cur_horse = {}\n'
    '            self._col_idx = 0\n'
    '        if self._in_horse_row and tag == "td":\n'
    '            self._in_td = True\n'
    '            self._td_text = ""\n'
    '            self._col_idx += 1\n'
    '        if tag == "div" and cls in ("RaceData01", "RaceData02"):\n'
    '            pass\n'
)
NEW_SHUTUBA_STARTTAG = (
    '    def handle_starttag(self, tag, attrs):\n'
    '        attr_dict = dict(attrs)\n'
    '        cls = attr_dict.get("class", "")\n'
    '        href = attr_dict.get("href", "")\n'
    '        if tag == "tr" and "HorseList" in cls:\n'
    '            self._in_horse_row = True\n'
    '            self._cur_horse = {}\n'
    '            self._col_idx = 0\n'
    '        if self._in_horse_row and tag == "td":\n'
    '            self._in_td = True\n'
    '            self._td_text = ""\n'
    '            self._col_idx += 1\n'
    '        # 馬名セル内の <a href="/horse/XXXX/"> から horse_id_ext を取得\n'
    '        if self._in_horse_row and tag == "a" and "/horse/" in href:\n'
    '            m = re.search(r"/horse/(\\w+)/?", href)\n'
    '            if m:\n'
    '                self._cur_horse["horse_id_ext"] = m.group(1)\n'
)
if OLD_SHUTUBA_STARTTAG in content:
    content = content.replace(OLD_SHUTUBA_STARTTAG, NEW_SHUTUBA_STARTTAG)
    print("[2a] ShutubaParser.handle_starttag updated")
else:
    print("[2a] WARN: ShutubaParser.handle_starttag not found")

# Col 5 (age_sex) と col 9 (horse_weight) を追加
OLD_COL_MAPPING = (
    '            if col == 2:\n'
    '                self._cur_horse["horse_number"] = int(t) if t.isdigit() else None\n'
    '            elif col == 4:\n'
    '                self._cur_horse["horse_name"] = t or None\n'
    '            elif col == 6:\n'
    '                try:\n'
    '                    self._cur_horse["weight_kg"] = float(t)\n'
    '                except ValueError:\n'
    '                    pass\n'
    '            elif col == 7:\n'
    '                self._cur_horse["jockey"] = t or None\n'
    '            elif col == 8:\n'
    '                self._cur_horse["trainer"] = t or None\n'
    '            elif col == 10:\n'
    '                try:\n'
    '                    self._cur_horse["win_odds"] = float(t)\n'
    '                except ValueError:\n'
    '                    pass\n'
    '            elif col == 11:\n'
    '                try:\n'
    '                    self._cur_horse["popularity"] = int(t)\n'
    '                except ValueError:\n'
    '                    pass\n'
)
NEW_COL_MAPPING = (
    '            if col == 2:\n'
    '                self._cur_horse["horse_number"] = int(t) if t.isdigit() else None\n'
    '            elif col == 4:\n'
    '                self._cur_horse["horse_name"] = t or None\n'
    '            elif col == 5:\n'
    '                self._cur_horse["age_sex"] = t or None  # 例: 牡3, 牝4, セ5\n'
    '            elif col == 6:\n'
    '                try:\n'
    '                    self._cur_horse["weight_kg"] = float(t)\n'
    '                except ValueError:\n'
    '                    pass\n'
    '            elif col == 7:\n'
    '                self._cur_horse["jockey"] = t or None\n'
    '            elif col == 8:\n'
    '                self._cur_horse["trainer"] = t or None\n'
    '            elif col == 9:\n'
    '                # 馬体重: "480(+2)" or "480(-4)" or "480" or "計不"\n'
    '                wm = re.search(r"(\\d{3,4})", t)\n'
    '                if wm:\n'
    '                    self._cur_horse["horse_weight"] = int(wm.group(1))\n'
    '                cm = re.search(r"\\(([+-]?\\d+)\\)", t)\n'
    '                if cm:\n'
    '                    self._cur_horse["horse_weight_change"] = int(cm.group(1))\n'
    '            elif col == 10:\n'
    '                try:\n'
    '                    self._cur_horse["win_odds"] = float(t)\n'
    '                except ValueError:\n'
    '                    pass\n'
    '            elif col == 11:\n'
    '                try:\n'
    '                    self._cur_horse["popularity"] = int(t)\n'
    '                except ValueError:\n'
    '                    pass\n'
)
if OLD_COL_MAPPING in content:
    content = content.replace(OLD_COL_MAPPING, NEW_COL_MAPPING)
    print("[2b] ShutubaParser col mapping updated")
else:
    print("[2b] WARN: col mapping not found")

# ── 3. HorsePageParser クラスを ResultParser の直後に挿入 ────────────────────
HORSE_PAGE_PARSER = '''

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
            col_map[h.replace(" ", "").replace("\\u3000", "")] = i

        for row in self._rows:
            if len(row) < 5:
                continue
            date_idx = col_map.get("日付", 0)
            date_str = row[date_idx] if date_idx < len(row) else (row[0] if row else "")
            dm = re.search(r"(\\d{4})[/](\\d{1,2})[/](\\d{1,2})", date_str)
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
            finish_clean = re.sub(r"[^\\d]", "", finish_str)
            finish = int(finish_clean) if finish_clean else None
            dist_str = safe_get(row, dist_idx)
            dist_m = re.search(r"(芝|ダート|障害|ばんえい)\\s*(\\d+)", dist_str)
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
'''

MARKER_AFTER_RESULT_PARSER = "\n# ─── race_id パーサー"
if MARKER_AFTER_RESULT_PARSER in content and "HorsePageParser" not in content:
    content = content.replace(
        MARKER_AFTER_RESULT_PARSER,
        HORSE_PAGE_PARSER + "\n\n# ─── race_id パーサー",
        1
    )
    print("[3] HorsePageParser inserted")
elif "HorsePageParser" in content:
    print("[3] HorsePageParser already exists")
else:
    print("[3] WARN: insertion marker not found")

# ── 4. fetch_prev_race_info + fetch_horse_histories を追加 ───────────────────
FETCH_FUNCS = '''

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
    horse_id_ext が設定済みかつ prev_finish が未取得のエントリのみ対象。"""
    print(f"[INFO] {target_date} の出走馬 前走情報を取得中...")
    races = supabase_rest("GET", "horse_races", params={
        "race_date": f"eq.{target_date}",
        "select": "id,source",
    })
    if not races:
        print("[INFO] 対象レースなし")
        return

    total_updated = 0
    for race in races:
        race_id = race["id"]
        source = race.get("source", "jra")
        entries = supabase_rest("GET", "horse_entries", params={
            "race_id": f"eq.{race_id}",
            "horse_id_ext": "not.is.null",
            "prev_finish": "is.null",
            "select": "id,horse_id_ext,horse_name",
        })
        if not entries:
            continue
        for entry in entries:
            horse_id_ext = entry.get("horse_id_ext")
            if not horse_id_ext:
                continue
            prev_info = fetch_prev_race_info(horse_id_ext, source, target_date)
            time.sleep(1)
            if not prev_info:
                print(f"    [SKIP] {entry.get('horse_name', '?')}: 前走情報取得失敗")
                continue
            supabase_rest("PATCH", f"horse_entries?id=eq.{entry['id']}", prev_info)
            print(
                f"    [OK] {entry.get('horse_name', '?')}: "
                f"前走{prev_info.get('prev_finish')}着 "
                f"({prev_info.get('prev_race_name', '?')}, "
                f"{prev_info.get('prev_days_ago')}日前)"
            )
            total_updated += 1

    print(f"[DONE] {total_updated}頭の前走情報を更新")

'''

CLEAN_MARKER = "\n# ─── 文字化けレコード削除"
if CLEAN_MARKER in content and "fetch_horse_histories" not in content:
    content = content.replace(CLEAN_MARKER, FETCH_FUNCS + "\n# ─── 文字化けレコード削除", 1)
    print("[4] fetch functions inserted")
elif "fetch_horse_histories" in content:
    print("[4] fetch functions already exist")
else:
    print("[4] WARN: clean marker not found")

# ── 5. main(): history mode 追加 ─────────────────────────────────────────────
content = content.replace(
    'choices=["entries", "results", "predict", "all"]',
    'choices=["entries", "results", "predict", "history", "all"]'
)
content = content.replace(
    '        help="実行モード: entries=出走表, results=結果, predict=AI予想, all=全て実行"',
    '        help="実行モード: entries=出走表, results=結果, predict=AI予想, history=前走情報, all=全て実行"'
)
content = content.replace(
    '    elif args.mode == "all":\n'
    '        fetch_entries(target_date)\n'
    '        trigger_ai_predictions(target_date)\n'
    '        fetch_results(target_date)',
    '    elif args.mode == "history":\n'
    '        fetch_horse_histories(target_date)\n'
    '    elif args.mode == "all":\n'
    '        fetch_entries(target_date)\n'
    '        fetch_horse_histories(target_date)\n'
    '        trigger_ai_predictions(target_date)\n'
    '        fetch_results(target_date)'
)
print("[5] main() updated")

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
print(f"Done. Total lines: {len(content.splitlines())}")
