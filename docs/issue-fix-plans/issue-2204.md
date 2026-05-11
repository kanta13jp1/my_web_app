# Issue Fix Plan #2204

- Issue: [[追加要望][P1] Google Calendar 全機能 段階導入 EPIC (= calendar-events page)](https://github.com/kanta13jp1/my_web_app/issues/2204)
- Labels: enhancement,priority:high,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25645364199

## Goal

[追加要望][P1] Google Calendar 全機能 段階導入 EPIC (= calendar-events page)

## Current Context

```text
## Goal

`https://my-web-app-b67f4.web.app/calendar-events` ????? Google Calendar ??????????

## ?? (= 2026-05-09 / part 188-b ??)

- ? ?? view + ?????????? (`table_calendar` package)
- ? Add/Delete event (= ?? + ???? / `app-hub` EF `calendar.create` + `calendar.delete`)
- ? ??/?? TimePicker + `HH:MM - HH:MM` range ?? (PR #2202 / part 188-b ???)
- ? Color tag (= 5 ?)
- ? Backend = `hub_data.metadata` JSONB ?? (= schema ???????????)

## ??????????? (= sub-issue ?)

### Phase 1 ? View / ?? (= P1)

- [x] #2205 Day/Week view ?? (= TableCalendar format toggle ?? + ???????)
- [x] #2206 ???????? (= ?? event ? dialog ?? update)
- [x] #2207 ???????? ? ???? (= bottom sheet or full-screen)

### Phase 2 ? ?? / ?? / ??????? (= P2)

- [ ] #2208 ???????? (= N ?? push or in-app notification)
- [ ] #2209 ?????? (= title/description full-text ??)
- [ ] #2210 ??????? (= calendar list + filter + per-calendar default color)
- [ ] #2211 ???????? (= RRULE ?? daily/weekly/monthly/yearly/custom)

### Phase 3 ? Advanced (= P3)

- [ ] #2212 ????&???? (= drag event card to new time/date)
- [ ] #2213 iCal export/import (= .ics file format ???)
- [ ] #22050 ???????? (= per-event TZ + display TZ setting)
- [ ] #22051 Quick add NL parse (= "?? 14:00 ??????" ? event auto-create)

### Phase 4 ? ?? (= future)

- [ ] ??? + ????? (= attendee + RSVP)
- [ ] Google Meet/Zoom URL auto-attach
- [ ] Working hours / appointment slot
- [ ] ??????? (Holiday / ?????)

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
