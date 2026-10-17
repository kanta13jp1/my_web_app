"""Read finalized Search Console daily snapshots without storing credentials."""
import argparse
from datetime import date, datetime, timedelta, timezone
import json
import math
import os
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote, urlparse
from urllib.request import Request, build_opener, HTTPRedirectHandler

API_ROOT = 'https://www.googleapis.com/webmasters/v3/sites/'
SCOPE = 'https://www.googleapis.com/auth/webmasters.readonly'


def iso_day(value):
    parsed = date.fromisoformat(value)
    if parsed.isoformat() != value:
        raise ValueError('dates must be YYYY-MM-DD')
    return parsed


def whole_count(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError('counts must be numeric')
    if not math.isfinite(value) or value < 0 or int(value) != value:
        raise ValueError('counts must be finite nonnegative integers')
    return int(value)


def request_body(start, end, page=None):
    first, last = iso_day(start), iso_day(end)
    if last < first or (last-first).days > 499:
        raise ValueError('request must cover 1 to 500 days')
    body = {'startDate': start, 'endDate': end, 'dimensions': ['date'],
            'type': 'web', 'dataState': 'final', 'aggregationType': 'auto',
            'rowLimit': 25000}
    if page:
        parsed = urlparse(page)
        if parsed.scheme not in ('https', 'http') or not parsed.netloc:
            raise ValueError('page needs an absolute HTTP(S) URL')
        body['dimensionFilterGroups'] = [{'groupType': 'and', 'filters': [
            {'dimension': 'page', 'operator': 'equals', 'expression': page}]}]
    return body


class NoRedirect(HTTPRedirectHandler):
    # Do not forward the caller's authorization header to another host.
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def fetch_snapshot(site, body, token, opener=None):
    if not token or '\n' in token or '\r' in token:
        raise ValueError('a valid access token is required in the environment')
    if not (site.startswith('sc-domain:') or urlparse(site).scheme in ('http', 'https')):
        raise ValueError('site must be a Search Console property identifier')
    request = Request(API_ROOT + quote(site, safe='') + '/searchAnalytics/query',
                      data=json.dumps(body).encode(),
                      headers={'Authorization': 'Bearer ' + token,
                               'Content-Type': 'application/json'}, method='POST')
    try:
        with (opener or build_opener(NoRedirect())).open(request, timeout=30) as response:
            return json.load(response)
    except HTTPError as error:
        # Response bodies may contain private configuration; do not print them.
        raise RuntimeError('Search Console request failed (HTTP %s); check property access and API enablement.' % error.code) from None


def normalize(payload, site, start, end, page=None):
    request_body(start, end, page)
    if not isinstance(payload, dict) or 'error' in payload:
        raise ValueError('expected a successful Search Console response')
    rows = payload.get('rows', [])
    if not isinstance(rows, list):
        raise ValueError('rows must be a list')
    if payload.get('metadata', {}).get('first_incomplete_date'):
        raise ValueError('incomplete data cannot be used as a finalized snapshot')
    observed = {}
    for row in rows:
        keys = row.get('keys')
        if not isinstance(keys, list) or len(keys) != 1:
            raise ValueError('expected date-only dimensions; page must be a fixed filter')
        day = keys[0]
        iso_day(day)
        if not start <= day <= end or day in observed:
            raise ValueError('duplicate or out-of-range day')
        clicks, impressions = whole_count(row['clicks']), whole_count(row['impressions'])
        if clicks > impressions:
            raise ValueError('clicks exceed impressions')
        observed[day] = {'day': day, 'clicks': clicks, 'impressions': impressions,
                         'click_rate': clicks/impressions if impressions else None}
    expected = [(iso_day(start)+timedelta(days=i)).isoformat()
                for i in range((iso_day(end)-iso_day(start)).days+1)]
    missing = [day for day in expected if day not in observed]
    return {'schema_version': 1, 'site': site, 'page': page,
            'start': start, 'end': end, 'timezone': 'America/Los_Angeles',
            'data_state': 'final_requested', 'search_type': 'web',
            'aggregation_type': payload.get('responseAggregationType', 'unspecified'),
            'rows': [observed[day] for day in sorted(observed)],
            'missing_days': missing, 'complete_calendar_coverage': not missing,
            'interpretation': 'Missing days remain unknown, not zero. Impressions measure this property visibility, not total search demand. API top-row limitations still apply.'}


def compare(snapshot, before_start, after_start, days):
    if type(days) is not int or days < 1:
        raise ValueError('positive integer days required')
    starts = [iso_day(before_start), iso_day(after_start)]
    if starts[0]+timedelta(days=days) > starts[1]:
        raise ValueError('periods must be ordered and disjoint')
    by_day = {r['day']: r for r in snapshot['rows']}
    periods = []
    for start in starts:
        keys = [(start+timedelta(days=i)).isoformat() for i in range(days)]
        missing = [key for key in keys if key not in by_day]
        periods.append({'start': start.isoformat(), 'days': days, 'missing': missing,
                        'clicks': None if missing else sum(by_day[k]['clicks'] for k in keys),
                        'impressions': None if missing else sum(by_day[k]['impressions'] for k in keys)})
    complete = all(not p['missing'] for p in periods)
    ratios = {metric: periods[1][metric]/periods[0][metric] if complete and periods[0][metric] else None
              for metric in ('clicks', 'impressions')}
    return {'periods': periods, 'ratios': ratios,
            'timezone': snapshot['timezone'],
            'status': 'descriptive_only' if complete else 'incomplete',
            'causal_effect': None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--site', required=True)
    parser.add_argument('--start', required=True)
    parser.add_argument('--end', required=True)
    parser.add_argument('--page')
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--response', type=Path, help='saved date-only finalized API response')
    source.add_argument('--fetch', action='store_true', help='use SEARCH_CONSOLE_ACCESS_TOKEN')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--before')
    parser.add_argument('--after')
    parser.add_argument('--days', type=int, default=7)
    args = parser.parse_args()
    try:
        body = request_body(args.start, args.end, args.page)
        raw = fetch_snapshot(args.site, body, os.environ.get('SEARCH_CONSOLE_ACCESS_TOKEN', '')) if args.fetch else json.loads(args.response.read_text(encoding='utf-8'))
        result = normalize(raw, args.site, args.start, args.end, args.page)
        result['retrieved_at'] = datetime.now(timezone.utc).isoformat()
        result['source'] = 'live_api' if args.fetch else 'saved_response'
        if bool(args.before) != bool(args.after):
            raise ValueError('both --before and --after are required for comparison')
        if args.before:
            result['comparison'] = compare(result, args.before, args.after, args.days)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        print(json.dumps({'status': 'saved', 'rows': len(result['rows']), 'missing_days': len(result['missing_days'])}))
    except (ValueError, KeyError, RuntimeError, OSError) as error:
        parser.exit(2, type(error).__name__ + ': ' + str(error) + '\n')


if __name__ == '__main__':
    main()
