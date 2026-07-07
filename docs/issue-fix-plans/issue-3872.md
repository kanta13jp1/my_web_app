# Issue Fix Plan #3872

- Issue: [[R13b] X fallback poll should obey subject-lock/current-state rules](https://github.com/kanta13jp1/my_web_app/issues/3872)
- Parent rounds: R12 #3871, R13 media axis #3764 / #3867
- Branch: `agent/r13b-fallback-poll-policy`

## Goal

Make the deterministic Dart fallback poll obey the same quality bar as the R12 LLM prompt:

- subject-lock to the actual thread/lead subject
- first-person current-state/action options
- omit weak polls rather than forcing generic interest polls
- keep media-axis measurement from R13 clean by implementing this as a separate PR

## Current defect

R12 added strong prompt constraints for LLM-generated polls, but fallback polls are built in Dart and bypass `_buildDraftPrompt` entirely.

Current fallback shape:

```dart
question: '今日の注目「$topic」、あなたは？'
options: ['詳しく知りたい', '様子見', '仕事に関係あり', '関係なし']
```

This violates the spirit of R12 because it can:

1. use a top trend the thread does not substantively cover,
2. ask an abstract interest/opinion question,
3. produce generic low-vote options,
4. revive the Fable 5-style 0-vote poll problem when LLM drafting fails.

## 10-hypothesis adversarial verification

| # | Hypothesis | Verdict | Consequence |
| --- | --- | --- | --- |
| H1 | R12 prompt rules do not affect fallback poll | Survives | Must change Dart fallback, not only prompt |
| H2 | Top-trend-derived fallback poll can drift from the actual thread subject | Survives | Subject must be tied to fallback lead topic or omitted |
| H3 | `あなたは？` + interest options is not current-state self-location | Survives | Replace with state/action options |
| H4 | Generic option sets recreate the 0-vote poll failure mode | Survives | Remove `詳しく知りたい/関係なし` patterns |
| H5 | A weak poll is worse than no poll | Survives | Non-domain trends may return null |
| H6 | R13 media-axis PR should not be mixed with poll behavior changes | Survives | Separate PR, separate measurement |
| H7 | Deterministic fallback must remain safe when trends are empty | Survives | Keep null when no honest subject exists |
| H8 | The test can be implementation-independent | Survives | Assert `buildGrowthDraft(...).poll` public output |
| H9 | Poll options must stay within X limits | Survives | Keep 2-4 options, <=25 runes |
| H10 | This is a small isolated change | Survives | Touch `_fallbackPollFor` + service test only |

## Proposed code change

### 1. Replace generic option sets with domain-shaped current-state sets

Example current-state sets:

```dart
const aiWorkflowOptions = <String>[
  '毎日AIで整理している',
  '必要な時だけ使っている',
  'メモが散らかっている',
  'これから整えたい',
];

const moneyWorkflowOptions = <String>[
  '給料日基準で見ている',
  '月初〜月末で見ている',
  '支出を把握していない',
  '見直したい',
];

const sportsWorkflowOptions = <String>[
  '試合後にメモしている',
  'ハイライトだけ見る',
  '感想だけ流している',
  '次戦前に整理したい',
];
```

### 2. Make question stems behavioral, not opinion/interest

Good examples:

```dart
'AIニュース、普段どう残してる?'
'支出、いつ基準で見てる?'
'試合の論点、どう残してる?'
```

Banned examples:

```dart
'今日の注目「$topic」、あなたは？'
'どの程度追っていますか?'
'どう感じますか?'
'興味ありますか?'
```

### 3. Domain gate

Return a poll only when the trend can be honestly mapped to one of the app's fallback briefing domains:

- AI/work/productivity/info organization
- money/personal finance
- sports/event info organization

For unrelated entertainment/product/model-name trends that the fallback lead does not substantively explain, return `null`.

## Suggested implementation sketch

```dart
static UniversalXPoll? _fallbackPollFor(
  List<UniversalXTrendTopic> trends,
  int seed,
) {
  if (trends.isEmpty) return null;
  final rawName = trends.first.name.trim();
  if (rawName.isEmpty) return null;
  final lower = rawName.toLowerCase();

  if (_isMoneyTrend(rawName, lower)) {
    return const UniversalXPoll(
      question: '支出、いつ基準で見てる?',
      options: [
        '給料日基準で見ている',
        '月初〜月末で見ている',
        '支出を把握していない',
        '見直したい',
      ],
      durationMinutes: 1440,
    );
  }

  if (_isAiWorkTrend(rawName, lower)) {
    return const UniversalXPoll(
      question: 'AIニュース、普段どう残してる?',
      options: [
        '毎日AIで整理している',
        '必要な時だけ使っている',
        'メモが散らかっている',
        'これから整えたい',
      ],
      durationMinutes: 1440,
    );
  }

  if (_isSportsTrend(rawName, lower)) {
    return const UniversalXPoll(
      question: '試合の論点、どう残してる?',
      options: [
        '試合後にメモしている',
        'ハイライトだけ見る',
        '感想だけ流している',
        '次戦前に整理したい',
      ],
      durationMinutes: 1440,
    );
  }

  return null;
}
```

## Tests

Add Dart tests to `test/services/universal_x_share_service_test.dart`:

1. AI/work trend returns a behavioral current-state poll.
2. Money trend returns a finance behavior poll.
3. Unrelated trend returns null.
4. Poll question/options do not contain banned stems:
   - `あなたは？`
   - `どう感じますか`
   - `どの程度`
   - `興味`
   - `関係あり`
   - `関係なし`
5. Every option is <=25 runes and options length is 3-4.

## Minimal E2E Gate

- UI routes unchanged.
- Public behavior is covered by `UniversalXShareService.buildGrowthDraft(...)` output tests.
- E2E-Exception: deterministic Dart fallback generator; no browser route or layout change.

## High-risk Gate

- Low-risk copy/poll fallback behavior only.
- No auth, billing, DB, storage, edge function, or migration changes.
- Rollback is one small Dart service/test commit.

## Done criteria

- [ ] `_fallbackPollFor` no longer emits the generic `今日の注目「$topic」、あなたは？` shape.
- [ ] Generic interest options are removed from fallback.
- [ ] Non-domain trends omit poll.
- [ ] Dart tests pass.
- [ ] PR references and closes #3872.
