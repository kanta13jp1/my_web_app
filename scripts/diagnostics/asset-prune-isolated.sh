#!/usr/bin/env bash
# Draft diagnostic: synthetic fixture and loopback only; no production data.
set -euo pipefail
test "$(readlink /proc/self/ns/net)" != "$HOST_NET"
test -z "$(ip -o addr show scope global)"
test "$(ip -o link show | wc -l)" -eq 1
ip link set dev lo up
ip -o link show lo | grep -Eq '<[^>]*UP[,>]'
test -z "$(ip -4 route show table main)"
test -z "$(ip -6 route show table main)"
test "$RUNNER_UID" -ne 0

sdk="$TEMP_ROOT/prune-flutter"
pub_cache="$TEMP_ROOT/prune-pub-cache"
config="$TEMP_ROOT/prune-config"
cache="$TEMP_ROOT/prune-cache"
export PATH="$sdk/bin:/usr/sbin:/usr/bin:/sbin:/bin"
cd "$WORKSPACE"

# The selected widget test seeds only synthetic SharedPreferences entries.
setpriv --reuid="$RUNNER_UID" --regid="$RUNNER_GID" --clear-groups --no-new-privs \
  env -i PATH="$PATH" CI=true FLUTTER_SUPPRESS_ANALYTICS=true \
  PUB_CACHE="$pub_cache" XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" \
  flutter test --no-pub --reporter json \
  --plain-name 'manual prune button cleans expired tombstones' \
  test/widgets/asset_management_page_smoke_test.dart | tee "$TEMP_ROOT/prune-widget.jsonl"
python3 - "$TEMP_ROOT/prune-widget.jsonl" <<'PY'
import json,sys
events=[json.loads(line) for line in open(sys.argv[1],encoding='utf-8')]
target=[x['test'] for x in events if x.get('type')=='testStart' and x['test']['name'].endswith('manual prune button cleans expired tombstones')]
assert len(target)==1, target
done=[x for x in events if x.get('type')=='testDone' and x.get('testID')==target[0]['id']]
assert len(done)==1 and done[0].get('result')=='success' and done[0].get('skipped') is False, done
end=[x for x in events if x.get('type')=='done']
assert len(end)==1 and end[0].get('success') is True, end
print('PASS: one non-skipped synthetic widget test')
PY

driver_log="$TEMP_ROOT/prune-chromedriver.log"
setsid setpriv --reuid="$RUNNER_UID" --regid="$RUNNER_GID" --clear-groups --no-new-privs \
  env -i PATH="$PATH" chromedriver --port=4444 > "$driver_log" 2>&1 &
driver_pid=$!
owned_pgid=''
group_has_live_processes() {
  ps -eo pgid=,stat= | awk -v target="$owned_pgid" \
    '$1 == target && $2 !~ /^Z/ { found=1 } END { exit !found }'
}
cleanup() {
  result=$?
  trap - EXIT
  if [ -z "$owned_pgid" ]; then
    group=$(ps -o pgid= -p "$driver_pid" 2>/dev/null | tr -d '[:space:]' || true)
    if [ "$group" = "$driver_pid" ]; then owned_pgid="$group"; fi
  fi
  if [ -n "$owned_pgid" ]; then
    kill -TERM -- "-$owned_pgid" 2>/dev/null || true
    for attempt in {1..20}; do
      if ! group_has_live_processes; then break; fi
      sleep 0.25
    done
    if group_has_live_processes; then
      kill -KILL -- "-$owned_pgid" 2>/dev/null || true
      for attempt in {1..20}; do
        if ! group_has_live_processes; then break; fi
        sleep 0.25
      done
    fi
    if group_has_live_processes; then
      echo "Owned ChromeDriver group still has live processes after KILL" >&2
      result=1
    fi
  elif kill -0 "$driver_pid" 2>/dev/null; then
    echo "ChromeDriver group could not be verified; cleanup unconfirmed" >&2
    result=1
  fi
  if [ "$result" -ne 0 ] && [ -f "$driver_log" ]; then tail -n 80 "$driver_log" >&2; fi
  exit "$result"
}
trap cleanup EXIT
group=''
for attempt in {1..20}; do
  group=$(ps -o pgid= -p "$driver_pid" 2>/dev/null | tr -d '[:space:]' || true)
  if [ "$group" = "$driver_pid" ]; then break; fi
  sleep 0.1
done
test "$group" = "$driver_pid"
owned_pgid="$group"
for attempt in {1..30}; do
  if curl --fail --silent http://127.0.0.1:4444/status >/dev/null; then break; fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:4444/status >/dev/null
for viewport in desktop mobile; do
  dimensions=1440x1000@1
  mobile=false
  if [ "$viewport" = mobile ]; then dimensions=390x851@2.75; mobile=true; fi
  echo "Synthetic browser viewport=$viewport dimensions=$dimensions"
  timeout --signal=TERM --kill-after=15s 300s \
    setpriv --reuid="$RUNNER_UID" --regid="$RUNNER_GID" --clear-groups --no-new-privs \
    env -i PATH="$PATH" CI=true FLUTTER_SUPPRESS_ANALYTICS=true \
    PUB_CACHE="$pub_cache" XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" \
    flutter drive --verbose --no-pub --no-web-resources-cdn \
      --driver=test_driver/asset_payment_day_prune.dart \
      --target=integration_test/asset_payment_day_prune_test.dart \
      --dart-define="PRUNE_MOBILE=$mobile" --browser-dimension="$dimensions" \
      -d web-server --browser-name=chrome --headless
  echo "Synthetic browser completed viewport=$viewport"
done
