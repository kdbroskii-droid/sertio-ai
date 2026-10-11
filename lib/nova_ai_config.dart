import 'package:shared_preferences/shared_preferences.dart';

/// One shared source for Nova's Gemini credential.
///
/// For local builds, an optional build-time fallback can be supplied with:
/// --dart-define=GEMINI_API_KEY=...
/// Prefer entering the key in Nova Settings; never commit a real key to GitHub.
class NovaAiConfig {
  static const String _preferenceKey = 'nova_gemini_api_key';
  static const String buildTimeGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static Future<String> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getString(_preferenceKey) ?? '').trim();
    return saved.isNotEmpty ? saved : buildTimeGeminiApiKey.trim();
  }

  static Future<void> saveGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = key.trim();
    if (value.isEmpty) {
      await prefs.remove(_preferenceKey);
    } else {
      await prefs.setString(_preferenceKey, value);
    }
  }
}
