# Sertio

Flutter app for Android and Windows. Includes local-model chat settings, starter workspaces for Roblox, Unreal Engine and Unity, a procedural low-poly 3D generator with OBJ export, a Gemini-powered universal command interpreter that converts text into deterministic numeric commands for mesh, Lua/Luau, C++, Roblox, Unreal, Unity, explanation/research, debugging and general project actions, project file previews, undo, ZIP import/export, basic workspace checks and GitHub Actions builds.

## Implementation roadmap

The remaining roadmap for Roblox and Epic account linking, a remotely controlled Windows PC with Roblox Studio and Unreal Editor, and web research is documented in [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md). ChatGPT/Claude manual handoff is now available from the Studio project actions menu or the composer. The work is tracked in [GitHub Issues](https://github.com/kdbroskii-droid/sertio-ai/issues).

## Run
Install Flutter, then run:

    flutter create --platforms=android,windows --org ai.novastudio --project-name sertio .
    flutter pub get
    flutter run

## Local AI
Configure an OpenAI-compatible chat completions endpoint, model name and optional API key in Settings. For a local Ollama-compatible server, the endpoint may be http://127.0.0.1:11434/v1/chat/completions. On a physical Android phone, use your PC's LAN address instead of 127.0.0.1 if the model runs on your PC.

The initial engine adapters create starter files; they do not replace the game engines. The 3D generator currently supports procedural low-poly primitives, including a wheel mesh, rather than arbitrary AI-sculpted geometry. Gemini is used only to interpret a prompt into a fixed schema; Sertio encodes version, object, style, size, detail and feature fields into an 11-digit command and decodes it locally. Set the Gemini key once in Settings; the planner, review checks and 3D Generator all read the shared key from `lib/nova_ai_config.dart`. The key is stored in app preferences without encryption in this prototype, so use a restricted key and never commit it to source control. For local builds, the same config supports a `GEMINI_API_KEY` Dart define. Universal command prefixes are # (mesh), ) (Lua/Luau), *) (C++), @ (Roblox project action), & (Unreal project action), % (Unity/C#), ? (explain/research), ! (debug/fix), and ~ (general project action). Each prefix is followed by a versioned numeric payload with stable fields for action, target, options, detail and flags. Gemini interprets the words; Sertio validates and encodes the numeric command. The command system is wired into the main chat when a Gemini key is configured; users can also type a prefix directly (for example, `# make a car wheel`, `) make a Roblox sprint script`, or `*) create a C++ movement component`). Explicit prefixes are preserved by the Gemini interpreter and can be encoded locally without a Gemini key; the configured local AI still generates the actual content. The numeric command is a structured routing hint, not a standalone executor for every engine action. Real engine playtests, engine-native automation, complete 3D asset generation and multiplayer deployment need additional integrations. The preview shows project files, not a running game.

GitHub Actions uploads an Android APK and Windows release ZIP. Do not commit API keys or passwords.

## ChatGPT and Claude handoff

From the project actions menu or the chat composer, choose **ChatGPT / Claude**. Sertio copies a prompt containing the current task and project files, then opens the chosen official web/app link. Submit the prompt there, copy the answer, return to Sertio, and use **Paste reply from clipboard**. Valid Sertio JSON responses can be imported as project edits with Undo support; other responses are shown as text and do not change files. This is a manual handoff, not direct API access or automatic private-chat reading. Review imported code before using it.

## Staged universal commands

With Gemini configured, Sertio breaks a natural-language request into ordered steps, displays their space-separated numeric command chain, and generates one step at a time. Each generated response is checked by Gemini against the step's acceptance criteria. A rejected response is retried with feedback up to three times; if it still fails, later steps are stopped. Each accepted step updates the in-memory project before dependent steps are generated. For Roblox shop requests, planning can separate a Roblox-native `.rbxmx` model, Luau interaction logic, shop UI, and optional server-side purchase logic. This review is an AI review, not a real engine compile or playtest. Without a Gemini key, direct prefixes work locally, but the multi-step review loop is unavailable.
