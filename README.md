# Nova Studio AI

Flutter app for Android and Windows. Includes local-model chat settings, starter workspaces for Roblox, Unreal Engine and Unity, project file previews, undo, ZIP import/export, basic workspace checks and GitHub Actions builds.

## Implementation roadmap

The planned next steps for multi-provider AI keys, Roblox and Epic account linking, a remotely controlled Windows PC with Roblox Studio and Unreal Editor, and web research using APKMirror and F-Droid, with citations and safe download approvals are documented in [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md). The work is tracked in [GitHub Issues](https://github.com/kdbroskii-droid/sertio-ai/issues).

## Run
Install Flutter, then run:

    flutter create --platforms=android,windows --org ai.novastudio --project-name nova_studio_ai .
    flutter pub get
    flutter run

## Local AI
Configure an OpenAI-compatible chat completions endpoint, model name and optional API key in Settings. For a local Ollama-compatible server, the endpoint may be http://127.0.0.1:11434/v1/chat/completions. On a physical Android phone, use your PC's LAN address instead of 127.0.0.1 if the model runs on your PC.

The initial engine adapters create starter files; they do not replace the game engines. Real engine playtests, engine-native automation, complete 3D asset generation and multiplayer deployment need additional integrations. The preview shows project files, not a running game.

GitHub Actions uploads an Android APK and Windows release ZIP. Do not commit API keys or passwords.
