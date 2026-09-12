# Monthly paid-interest history

The asset management disposable-balance section includes a 12-month interest chart for signed-in users. Enter **interest/revolving fees actually allocated to payments**, not APR, total repayments, principal, or estimates. One line per account: `Account A=1000`. Evidence is a short statement reference without account numbers or personal information.

Missing months are not zero. The current month is partial even if marked reconciled. A comparison requires adjacent closed months, both reconciled, with identical account-name sets. Keep repaid accounts at zero throughout the comparison period. Account renaming intentionally disables the comparison until both months use the same scope.

## Storage and recovery

Uses existing `asset_pref_mirror` owner RLS and primary key, no migration:

- `pref_key`: `interest_paid_v1_YYYY-MM`
- `value`: `{month, amounts: {accountAlias: integerYen}, complete, evidence}`
- `updated_at`: optimistic concurrency revision

No local-storage fallback, no changes to account balances or paid statuses, no automatically inferred financial history. New rows use insert; edits match the previously read revision. A duplicate or stale write fails rather than overwriting another device. On failure, retain input; cancel and reload to resolve conflicts. A failed read never displays an empty confirmed history. Existing records remain stored beyond the displayed 12-month window.

## Release verification

Synthetic model tests cover missing/current/partial/scope-change/zero/increase/decrease. Widget tests cover 320/1200 pixel widths and failed-save recovery. Mock HTTP repository tests cover owner/key scoping, round-trip restoration, duplicate/stale write rejection, and sign-out protection. These are not proof of a real authenticated production write; verify real statement records only with user-authorized evidence.

This release covers interest history. It does not backfill past interest from net-worth differences, nor capture principal allocation history or claim a cash-availability improvement.
