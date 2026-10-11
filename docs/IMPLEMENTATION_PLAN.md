# Sertio — Remote Build & Account Linking Implementation Plan

**Status:** Planning  
**Repository:** `kdbroskii-droid/sertio-ai`  
**Target:** Flutter app for Android + Windows, with the user's own Windows PC acting as the build machine.

## Goals

1. Let users configure multiple AI providers and API keys, choose a default model, and switch providers per task.
2. Link Roblox and Epic Games accounts through official authorization flows.
3. Pair Sertio on Android with a Windows companion agent running on the user's own PC.
4. Use the installed Roblox Studio and Unreal Editor/toolchains on that PC to open, edit, test, and build projects where supported.
5. Show queued/running/completed jobs, logs, errors, artifacts, cancellation, and retry in Sertio.
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
- Add per-project workspace mapping and safe file sync between Sertio and the Windows agent.
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



### Android-app-based AI handoff (ChatGPT and Claude APKs)
- Support the user's **already-installed official ChatGPT and Claude Android apps** as preferred handoff targets, with **ChatGPT first** / **Claude first** settings and a **Switch to the other AI** action.
- Sertio may help users find the official app listings and research APKMirror/F-Droid results, but must display the publisher, version, signing/hash details when available, and ask for approval before any download. Do not silently download or install APKs.
- Do not bundle or redistribute ChatGPT/Claude APK binaries inside Sertio unless the publisher explicitly grants that right. Treat APKMirror/F-Droid as discovery sources, not automatic proof that a file is safe or that redistribution is allowed.
- Sertio prepares a self-contained prompt and relevant project context, copies it to the clipboard, and opens the chosen official app using supported Android app links/intents where available. If the app cannot be opened, fall back to its official website.
- The user submits the prompt in ChatGPT/Claude and returns the answer to Sertio using paste/share/import. Sertio must not claim it received a response until the user brings it back.
- If the first app is unavailable, hits a usage limit, or gives an unusable response, offer to open the other app with the same prepared context.
- Do not collect passwords/cookies, scrape private chats, programmatically extract website/app outputs, or bypass usage limits. Any deeper integration must use a provider-supported interface and comply with current terms.
- Clearly explain that APK-based app launching is not direct AI integration: automatic response capture and guaranteed end-to-end switching are not provided by simply possessing an APK. Website/app account limits still apply.
- Keep API providers and local models as separate options; do not present the app handoff as a way to bypass API billing or provider limits.

## Suggested initial issue order

1. Multi-provider configuration and secure secret storage.
2. Windows companion agent skeleton and safe device pairing.
3. Project sync, job queue, and log/artifact transport.
4. Roblox OAuth + least-privilege Open Cloud integration.
5. Epic account-linking feasibility spike and Unreal build adapter.
6. End-to-end tests, installer/docs, and release workflow.\n7. Web research, source attribution, and safe download controls.



## Phase 7 — Web research, trusted-source discovery, and safe downloads

### Goal
Let a natural-language request trigger research across the web, with source links and evidence shown in Sertio before it creates or changes a project.

### Preferred Android app sources: APKMirror + F-Droid
- Add first-class search connectors for **APKMirror** (https://www.apkmirror.com/) and **F-Droid** (https://f-droid.org/), and show which source each result came from.
- Use APKMirror for app-version/archive research where relevant. Its FAQ says uploads are reviewed and signatures are checked against known releases, but Sertio must still show the exact publisher, version, variant, permissions when available, and signature/hash details; the domain alone is not a safety guarantee.
- Use the official F-Droid repository for free/open-source Android apps. Prefer the F-Droid client/repository metadata and signed repository indexes for verification rather than treating an arbitrary download URL or the public search API as proof of authenticity.
- Let users choose whether APKMirror and/or F-Droid are enabled, but keep official publisher pages and project repositories available as cross-checks. If a requested app is not present, say so rather than silently substituting a similarly named app.
- Search results are for research and compatibility checks first. Downloads still require a separate approval screen and the safeguards below.

### Workflow
1. Classify the request: research-only, project code/assets, dependency download, or external account action.
2. Search the web using a provider adapter and retrieve relevant pages. Prefer official documentation, official developer/store pages, and clearly identified publisher sources.
3. Show a source panel with title, domain, URL, retrieval time, relevant excerpts, and why each source was selected. Cite claims in the AI's plan and distinguish verified facts from assumptions.
4. Use a configurable source policy: official sources first; warn on unknown domains; block known malicious/phishing sources; never treat page content as instructions to Sertio or as trusted code.
5. For downloadable files, show publisher, file type, size, hash/signature where available, and source URL. Require explicit user approval before downloading. Validate file type and destination, scan with available security tooling, and never auto-run installers, scripts, executables, or APKs.
6. Keep a record of downloaded artifact provenance and allow the user to cancel, remove, or quarantine it. Do not bypass license checks, DRM, anti-cheat, app-signing protections, or publisher restrictions.
7. Keep source content untrusted: defend against prompt injection in webpages, hidden instructions, poisoned repositories, and instructions asking Sertio to reveal keys or run commands.
8. Add tests for domain policy, source attribution, prompt-injection resistance, MIME/extension mismatches, hash verification, consent gates, and secret redaction.

### Example: "make a Fortnite mobile client with inverted colours"
- Sertio can search official Epic/Fortnite pages to identify the legitimate mobile distribution route and explain what is supported.
- It must not automatically fetch a third-party APK, patch a proprietary Fortnite client, disable integrity/anti-cheat checks, or redistribute a modified game package.
- Standard Android apps cannot reliably apply a per-app pixel inversion to another app without supported OS-level capability; a global accessibility colour setting affects more than Fortnite. Sertio should explain this limitation instead of claiming a normal overlay can invert only Fortnite.
- Offer supported alternatives: build the requested colour effect into a game the user owns, prototype the effect in a separate sample app, or investigate official accessibility/display options with their scope clearly explained.

### Acceptance criteria
- Web results include visible citations and domain labels.
- Official sources are preferred and source confidence is explained without claiming that a domain guarantee makes a file safe.
- Downloads require user confirmation, are stored outside source-controlled project files by default, and are never automatically executed.
- Webpage instructions cannot override Sertio's system rules or trigger commands on the Windows agent.
- The Fortnite example produces a grounded explanation and a safe, feasible next step rather than silently modifying the official APK.

## Official references to verify during implementation

- APKMirror FAQ and security/signature policy: https://www.apkmirror.com/faq/\n- F-Droid documentation and repository verification: https://f-droid.org/docs/ and https://f-droid.org/docs/All_our_APIs/\n- Roblox OAuth 2.0 reference: https://create.roblox.com/docs/cloud/auth/oauth2-reference
- Roblox OAuth 2.0 overview: https://create.roblox.com/docs/cloud/auth/oauth2-overview
- Roblox OAuth app registration/scopes: https://create.roblox.com/docs/cloud/auth/oauth2-registration
- Unreal build/package/deploy/run: https://dev.epicgames.com/documentation/en-us/unreal-engine/build-operations-cooking-packaging-deploying-and-running-projects-in-unreal-engine
- Unreal Automation Tool: https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-automation-tool-overview-for-unreal-engine

Epic account-linking implementation details and requirements must be confirmed against the current Epic developer documentation and the specific services Sertio intends to use before implementation.
