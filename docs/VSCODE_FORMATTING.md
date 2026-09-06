# Shared editor formatting

Issue: #1357

The workspace enables format on save and selects Dart Code for Dart, Deno for
JavaScript/TypeScript, the built-in JSON formatter for JSON/JSONC, and Red Hat
Java for Java. Install only recommendations needed for your work; recommendations
do not automatically install extensions or start a toolchain. Spring Boot and
ESLint are not dependencies of this Flutter/Deno workspace.

Use the repository-pinned Flutter/Dart version to avoid formatter churn. Keep
machine-specific SDK and JDK paths in your VS Code User settings or local
environment (for example JAVA_HOME), never in committed workspace settings.
Existing terminal and container settings are preserved.

Under the cloud-first resource policy, do not install SDKs or start local
analyzers simply to exercise format on save. Use the cloud formatter profile
when local SDK versions differ. Disable format on save locally for an editing
session if a suitable formatter is unavailable. Inspect the diff before saving
unrelated formatting changes into a commit. CI remains the validation authority.

The lightweight configuration contract runs as part of the existing
`python scripts/vscode_terminal_settings_test.py` CI check. This proves shared
settings and recommendation IDs, not the extension-install prompt or actual
interactive editor formatting. Those require a resource-safe VS Code session
with the selected extensions installed.

References:
- https://code.visualstudio.com/docs/configure/settings
- https://docs.deno.com/runtime/reference/vscode/
- https://dartcode.org/docs/recommended-settings/
