# Edge Function integration: UI-first test and handoff

Issue #2817. This guide covers a UI whose backend contract is not yet available. Historical “Tier 2” labels described deployment tiers; the current production workflow says those tiers were retired. Do not infer a deployed endpoint or entitlement from that label.

## Work agreement

1. Before UI implementation, record an Issue with owner, purpose, action/function name, request and response examples, validation, auth and ownership boundaries, loading/empty/error/retry states, tracking task ID, rollout evidence and a recovery owner. Link the Issue and WBS task in both directions. Mark the endpoint `not implemented` until the deployed revision and contract are verified; do not mark the WBS complete for a fake.
2. Define a typed adapter around the existing service layer, and inject the invoker in tests. Existing examples are `lib/services/edge_llm_playground_service.dart` and `test/services/edge_llm_playground_service_test.dart`. Keep fake responses synthetic, deterministic, in memory and reachable only via explicit test/development injection. Do not fall back from a real authentication, authorization, billing, write or network failure to a fake success.
3. UI states must distinguish loading, a successful empty result, a failure, and explicit mock/unavailable mode. Loading can use an accessible progress indicator; successful empty results can show a neutral empty state. An error states that the operation did not complete, preserves user input and offers a safe retry where applicable. Never represent an unknown result as zero or an unpersisted change as saved.
4. Validate request construction, successful and empty responses, malformed responses, auth/error handling, retry, and stale response/disposal behavior as applicable. A widget or browser test should assert user-visible outcomes. Test doubles are not proof of real JWT validation, RLS, remote persistence, performance, or provider charges.
5. Before enabling the real endpoint, validate the contract on an isolated nonproduction environment with synthetic accounts and data, including two-owner isolation and invalid-auth cases when user data is involved. Record exact code revision, workflow run, environment, result and skipped tests on the Issue/PR. For authentication, database/RLS, billing, secrets or permissions, record the required human review acknowledgement. Deployment requires the appropriate release authority.

## Reusable contract and fake template

Adapt the names and data to the feature; this is a test-only illustration, not a production fallback. A runnable widget-test fixture using the same pattern is `test/examples/edge_ui_mock_template_test.dart`. Put the fake in the feature test, and inject a real implementation at the composition root for deployed behavior.

```dart
abstract interface class ExampleReader {
  Future<List<String>> load();
}

class FakeExampleReader implements ExampleReader {
  FakeExampleReader({this.items = const [], this.error});
  final List<String> items;
  final Exception? error;

  @override
  Future<List<String>> load() async {
    if (error case final failure?) throw failure;
    return List.unmodifiable(items);
  }
}
```

Use `FakeExampleReader(items: ['example'])`, `FakeExampleReader()` and `FakeExampleReader(error: Exception('offline'))` for success, empty and error tests. Assert the actual screen distinguishes all three and that a failed write is never presented as persisted. Add an independently controlled `Completer` when testing loading, cancellation and out-of-order results. Integrate the adapter with the actual endpoint only after its request/response contract is agreed; replace neither server validation nor security review with this fake.

## Tracking template

```text
Endpoint / action:
Owner and WBS task ID:
Issue / PR:
Status: planned | mock-only | deployed-unverified | verified
Contract and expected error states:
Authentication / owner isolation:
Test evidence: SHA, workflow URL, cases, explicit skips
Nonproduction environment and release evidence:
Remaining blocker, recovery owner and next check:
```

Use GitHub Actions for Flutter/Dart tests, analysis and builds under `AGENTS.md`; avoid package hydration or local builds merely to exercise this template. A mock-only milestone is progress, not completion of the backend feature.
