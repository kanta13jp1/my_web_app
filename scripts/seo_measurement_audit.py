"""Read-only audit of anonymous acquisition counts; never infers causality."""
import argparse
from collections import Counter
from datetime import date, datetime, timedelta
import json
from math import comb
from pathlib import Path
from zoneinfo import ZoneInfo


def count(value):
    if type(value) is not int or value < 0:
        raise ValueError('count must be a nonnegative integer (not bool)')
    return value


def daily_rows(rows):
    seen = set()
    for row in rows:
        day = date.fromisoformat(row['day'])
        if day.isoformat() != row['day'] or day in seen:
            raise ValueError('noncanonical or duplicate date')
        seen.add(day)
        if type(row['daily_row_present']) is not bool:
            raise ValueError('presence must be boolean')
        for metric in ('landing', 'public_memo', 'signup_submit'):
            count(row[metric])
            count(row['receipt_' + metric])
            if row['daily_row_present'] and row[metric] != row['receipt_' + metric]:
                raise ValueError('aggregate/receipt mismatch')
    return rows


def local_day(timestamp, zone):
    instant = datetime.fromisoformat(timestamp)
    if instant.tzinfo is None or instant.utcoffset() is None:
        raise ValueError('timestamp needs an explicit UTC offset')
    return instant.astimezone(ZoneInfo(zone)).date().isoformat()


def sign_test(before, after):
    if len(before) != len(after) or not before:
        raise ValueError('paired nonempty samples required')
    differences = [count(b) - count(a) for a, b in zip(before, after)]
    positive = sum(d > 0 for d in differences)
    negative = sum(d < 0 for d in differences)
    n = positive + negative
    p = min(1.0, 2 * sum(comb(n, k) for k in range(min(positive, negative) + 1)) / 2 ** n)
    return {'positive': positive, 'negative': negative,
            'ties': len(differences) - n, 'two_sided_p': p,
            'assumptions': 'Independent paired signs with probability 0.5 under null; exploratory, not a causal test.'}


def week(rows, start, metric):
    expected = [(date.fromisoformat(start) + timedelta(days=i)).isoformat() for i in range(7)]
    by_day = {r['day']: r for r in rows}
    missing = [d for d in expected if d not in by_day or not by_day[d]['daily_row_present']]
    return {'start': start, 'missing': missing,
            'total': None if missing else sum(by_day[d][metric] for d in expected)}


def audit(data):
    rows = daily_rows(data['daily'])
    by_day = {r['day']: r for r in rows}
    metrics = {}
    for metric in ('landing', 'signup_submit', 'public_memo'):
        weeks = [week(rows, d, metric) for d in ('2026-08-30', '2026-09-06', '2026-09-13', '2026-09-20')]
        if weeks[2]['missing'] or weeks[3]['missing']:
            raise ValueError('target period incomplete')
        before = [by_day[(date(2026, 9, 13) + timedelta(days=i)).isoformat()][metric] for i in range(7)]
        after = [by_day[(date(2026, 9, 20) + timedelta(days=i)).isoformat()][metric] for i in range(7)]
        metrics[metric] = {'weeks': weeks, 'before': before, 'after': after,
            'daily_rate_ratio': sum(after) / sum(before) if sum(before) else None,
            'sign_test': sign_test(before, after),
            'leave_one_pair_out': [{'omitted_pair': i, **sign_test(before[:i]+before[i+1:], after[:i]+after[i+1:])} for i in range(7)]}
    cohort = data['timezone_cohort']
    japan, utc = Counter(), Counter()
    for r in cohort:
        n = count(r['count'])
        if r['event_date'] != r['japan_date']:
            raise ValueError('server date disagrees with Japan receipt date')
        japan[r['japan_date']] += n
        utc[r['utc_date']] += n
    if sum(japan.values()) != sum(metrics['landing']['before'] + metrics['landing']['after']):
        raise ValueError('timezone cohort count mismatch')
    return {'observed_at': data['observed_at'], 'app_commit': data['app_commit'],
        'metrics': metrics,
        'timezone': {'cohort_size': sum(japan.values()),
            'different_calendar_day': sum(r['count'] for r in cohort if r['utc_date'] != r['japan_date']),
            'japan': dict(sorted(japan.items())), 'utc_same_cohort': dict(sorted(utc.items())),
            'scope': 'Same Japan-selected receipt cohort, not a complete UTC-window recount; deduplication remains Japan-day based.'},
        'causal_effect': None,
        'causal_status': 'Not identified: aggregate receipt counts do not establish randomized exposure, stable intervention, loss-free measurement or a valid unchanged control.',
        'seasonal_status': 'Three complete weekly observations cannot estimate annual seasonality or search demand; the preceding week is incomplete.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = json.dumps(audit(json.loads(args.input.read_text(encoding='utf-8'))), ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.write_text(result, encoding='utf-8')
    else:
        print(result, end='')


if __name__ == '__main__':
    main()
