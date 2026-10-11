# Nova Studio AI — Remote Build & Account Linking Implementation Plan

**Status:** Planning  
**Repository:** `kdbroskii-droid/sertio-ai`  
**Target:** Flutter app for Android + Windows, with the user's own Windows PC acting as the build machine.

## Goals

1. Let users configure multiple AI providers and API keys, choose a default model, and switch providers per task.
2. Link Roblox and Epic Games accounts through official authorization flows.
3. Pair Nova on Android with a Windows companion agent running on the user's own PC.
4. Use the installed Roblox Studio and Unreal Editor/toolchains on that PC to open, edit, test, and build projects where supported.
5. Show queued/running/completed jobs, logs, errors, artifacts, cancellation, and retry in Nova.
6. Make destructive actions and publishing explicit opt-in actions.

## Current baseline (important)

The current Flutter app is a starter: it has one OpenAI-compatible endpoint/model/key setting, starter workspace files, text preview, ZIP import/export, undo snapshots, basic file checks, and GitHub Actions scaffolding. It does **not** yet have multi-provider key management, account OAuth, a Windows agent, real engine automation, or a live game preview. Treat all work below as planned until implemented and tested.

## Proposed architecture

- **Flutter client**: Android and Windows UI, provider settings, account-link status, project browser, job queue, logs, approvals, artifact downloads.
- **Windows companion agent**: a separately installable, user-launched service/app on the user's PC. It discovers configured editor/tool paths, manages isolated workspaces, runs approved engine commands, streams job status, and returns logs/artifacts.
- **Pairing/transport**: pair the phone to the PC with a short-lived one-time pairing code or QR code. Prefer an authenticated, encrypted outbound connection or a trusted private-network connection. Do not expose an unauthenticated command server to the public internet or require router port-forwarding by default.
- **AI provider layer**: provider registry with a display name, base URL, model list, key reference, enabled state, and per-task/default selection. Support OpenAI-compatible endpoints first; add provider-specific adapters only when needed.
- **Account connection layer**: independent Roblox and Epic connection records, least-privilege scopes, visible connected account identity, revoke/disconnect actions, and clear consent screens.
- **Secret storage**: OS-backed secure storage for local secrets (Windows Credential Manager/DPAPI; Android secure storage backed by platform keystore). Never store API keys, OAuth tokens, or client secrets in project files, logs, crash reports, or source control. If a confidential OAuth exchange needs a client secret, keep it in a small trusted backend—not in the Flutter APK or public repository.

## Implementation phases

### Phase 1 — Foundation and configuration model
- Refactor the single AI setting into a provider list and active/default provider.
- Add add/edit/remove/test-provider flows and model selection.
- Migrate existing endpoint/model/key settings without losing user configuration.
- Store secrets using platform secure storage; keep only non-secret provider metadata in preferences.
- Redact authorization headers and secrets from logs and AI prompts.
- Add unit tests for configuration migration, provider selection, and redaction.

**Acceptance:** Multiple provider profiles can be configured, tested, switched, and removed; existing users keep their prior configuration; no key appears in logs or exported projects.

### Phase 2 — Windows companion agent and safe pairing
- Add a separate Windows agent project/process with a first-run setup wizard.
- Detect or let the user browse to Roblox Studio and Unreal Engine installations; show detected versions and readiness.
- Pair the mobile app to the agent with a one-time code/QR, explicit approval on the PC, revocable device identities, and encrypted authenticated transport.
- Implement health/status, capabilities, heartbeat, reconnect, and disconnect.
- Start with a LAN/private-network connection; design a secure outbound relay as a later option if access outside the home network is needed.
- Add an allowlisted command/job API; never expose arbitrary shell execution to unauthenticated clients.

**Acceptance:** The phone can pair, see PC online/offline status, and request only explicitly supported operations. The agent rejects unknown devices, expired pairing codes, unsafe paths, and unapproved commands.

### Phase 3 — Project sync and job queue
- Add per-project workspace mapping and safe file sync between Nova and the Windows agent.
- Prevent path traversal, writes outside the selected workspace, accidental overwrites, and symlink escapes.
- Add queued/running/succeeded/failed/cancelled states, timestamps, progress, log streaming, retry, and cancellation.
- Keep a snapshot/diff before AI or automation writes files; provide review/undo before applying changes.
- Add artifact manifest and download support.

**Acceptance:** A sample project can sync to a selected workspace, run a harmless test job, display live logs, cancel safely, and retrieve a generated text artifact.

### Phase 4 — Roblox workflow
- Register/configure a Roblox OAuth app and implement authorization-code + PKCE, state/nonce checks, secure token storage, refresh/revoke handling, and disconnect.
- Request only the minimum Roblox OAuth scopes required for each feature; show exactly what the app can access before consent.
- Use supported Roblox Open Cloud APIs for authorized resource operations.
- Add a Windows-side Studio integration only for documented/supported workflows; distinguish script/file editing from Studio UI automation.
- Add script linting and project validation first. Add Studio launch/playtest automation only after a reliable, testable adapter exists.
- Publishing or changing live experiences must be a separate explicit action with a confirmation step.

**Acceptance:** User can link and unlink Roblox, see the authorized identity/scopes, and use a permitted read-only API operation. Expired/revoked access is handled cleanly. Do not claim OAuth grants full Roblox Studio control.

### Phase 5 — Epic Games / Unreal workflow
- Confirm the appropriate Epic developer registration, product/application setup, supported sign-in method, and permitted scopes before coding the integration.
- Implement Epic account connection using the currently supported official flow. Do not assume an Epic sign-in token automatically authorizes every Epic service.
- Detect Unreal Engine versions and locate the project's `.uproject`.
- Start with non-destructive validation and editor commandlet tasks.
- Add configurable Unreal Automation Tool / `RunUAT.bat BuildCookRun` jobs for supported target platforms; capture exit code, logs, output folder, and artifact size.
- Add automated tests and packaged-build launch where supported by the installed engine and project.
- Require confirmation before overwriting output, running project-supplied scripts, or deploying/publishing anything.

**Acceptance:** User can link/disconnect Epic where supported; the agent can validate an Unreal project and run a configurable packaging job, then report logs and downloadable artifacts. Missing SDKs, licenses, engine versions, or platform toolchains produce clear errors.

### Phase 6 — Hardening, testing, and release
- Add tests for OAuth state/PKCE, token refresh/revoke, secure storage, device pairing, job authorization, path validation, and secret redaction.
- Add integration tests with mock OAuth responses and a fake build runner; keep actual engine builds as opt-in self-hosted tests because engine installs and licenses vary.
- Add Windows agent signing/package instructions and a least-privilege startup option.
- Document firewall/network setup, supported engine versions, recovery, backups, and disconnecting devices.
- Update GitHub Actions to run Flutter tests and agent tests; publish Android APK and Windows client/agent artifacts only after passing CI.

**Acceptance:** CI passes; setup and recovery are documented; a clean install can pair, link accounts, run a mock job, and show an understandable error when required engine tools are missing.

## Security and product rules

- OAuth is for identity and specifically authorized APIs—not a promise of complete editor control.
- Use PKCE for public clients where supported; validate `state` and redirect URIs. Keep confidential client secrets on a trusted backend.
- Ask for the smallest practical scope. Show account name, permissions, and disconnect/revoke controls.
- Never request or store Roblox/Epic passwords or session cookies.
- Never commit real API keys, OAuth tokens, refresh tokens, or client secrets.
- Require explicit confirmation for publishing, deployment, overwriting files, deleting projects, or executing untrusted project scripts.
- Treat project files, AI output, and build logs as untrusted input. Use workspace isolation, command allowlists, timeouts, resource limits, and cancellation.
- Do not claim full engine support until the corresponding adapter has automated tests on a real installation.

## Suggested initial issue order

1. Multi-provider configuration and secure secret storage.
2. Windows companion agent skeleton and safe device pairing.
3. Project sync, job queue, and log/artifact transport.
4. Roblox OAuth + least-privilege Open Cloud integration.
5. Epic account-linking feasibility spike and Unreal build adapter.
6. End-to-end tests, installer/docs, and release workflow.

## Official references to verify during implementation

- Roblox OAuth 2.0 reference: https://create.roblox.com/docs/cloud/auth/oauth2-reference
- Roblox OAuth 2.0 overview: https://create.roblox.com/docs/cloud/auth/oauth2-overview
- Roblox OAuth app registration/scopes: https://create.roblox.com/docs/cloud/auth/oauth2-registration
- Unreal build/package/deploy/run: https://dev.epicgames.com/documentation/en-us/unreal-engine/build-operations-cooking-packaging-deploying-and-running-projects-in-unreal-engine
- Unreal Automation Tool: https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-automation-tool-overview-for-unreal-engine

Epic account-linking implementation details and requirements must be confirmed against the current Epic developer documentation and the specific services Nova intends to use before implementation.
