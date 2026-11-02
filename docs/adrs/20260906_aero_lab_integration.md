# AERO LAB as a first-party static leaf feature

Status: implementation proposal, not released. 2026-09-06.

## Authority and scope

The owner approved Codex continuing and explicitly authorized a dedicated branch,
draft PR and cloud verification. On 2026-09-06 the owner subsequently requested
production deployment and explicitly permitted proceeding past the unverified
Claude Code design-review gate for this integration. This is a task-specific
owner exception, not a claim that Claude reviewed it or a repository-wide waiver.
Merge and production deployment are authorized only after required checks pass.

Preserve the original AERO LAB, integrate its five-stage procedural engine and
controls in my_web_app, and verify a reviewable branch. No authentication,
database, billing, AI API, automatic publishing, or user-data changes.

## Decision

- `/aero-lab` is a named Flutter leaf route and searchable home-tool entry.
- The page hosts `/labs/aero-lab/index.html`, packaged by Flutter's normal web
  build from `web/`. No localhost or new deployment step is required.
- Reuse the original geometry, teaching metrics, lighting and visual styling.
  Port the small React control layer to native browser controls; do not ship the
  old Vinext/Tailwind/React server scaffold or its unrelated dependencies.
- Vendor the existing Three.js 0.185.1 runtime and two addons with MIT license.
  Modules use explicit local relative imports. No CDN, package installation or
  AI request is performed at runtime. Dependency hashes are in provenance.json.
- This is reviewed first-party code on the application's origin, NOT an isolation
  sandbox for untrusted HTML. There is no message bridge, auth-token forwarding,
  storage access, or dynamic user content. CSP blocks connections and forms;
  iframe camera/microphone/geolocation permissions are denied. Screen capture
  remains a user-initiated browser permission with silent WebM output capped at
  two minutes. Non-tab capture is rejected. It never uploads automatically.
- Lazy route mounting avoids 3D on the homepage. Route coverage/removal unloads
  the iframe. Pagehide stops recordings and disposes WebGL; hidden documents
  suspend animation. Failed loading/WebGL initialization has a readable error.
- The narrow layout stacks controls; the engine uses lower geometry density
  below 600px. The diagram remains explicitly fictional and educational.

## Philosophy and constraints

R&D / active learning: users manipulate reversible settings and observe relative
effects. No competitive rankings, engagement-maximization loops or new automation.
AI/personality/MCP-server principles do not require adding an AI runtime to this
deterministic visualization. The original black/cyan/orange instrument styling
is retained inside the experiment; Flutter supplies its existing app navigation.

PC disk/RAM policy requires cloud validation. No local worktree, dependency
install, build, dev server or browser was used for this integration. The dirty
root checkout is not used for commits; a scoped GitHub tree is based on the
explicit recorded main SHA. Heavy local work, if later needed, additionally
requires the shared round-robin slot and resource checks.

## Validation and release gates

Dedicated Actions checks cover finite engine geometry, relative metrics, browser
controls, desktop/mobile overflow, reload, module errors, recording cancellation,
Flutter fallback, route/catalog linkage, analysis and a release web build.
Generic PR CI remains required. Real Edge screen-sharing and final integrated
browser QA remain manual review gates; automated capture tests are not proof of
the browser's real permission chooser. Keep the PR draft until evidence is read.

Do not merge or deploy without owner approval. Rollback is removal/reversion of
this leaf route/catalog entry and its static directory; no data migration exists.
Future engine models can be separate modules, but none are included in this task.
