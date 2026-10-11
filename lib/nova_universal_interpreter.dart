import 'dart:convert';
import 'package:http/http.dart' as http;
import 'nova_command_language.dart';

class NovaUniversalInterpreter {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static Future<NovaCommand> interpret({
    required String apiKey,
    required String prompt,
    required String activeEngine,
  }) async {
    if (apiKey.trim().isEmpty) throw Exception('Gemini API key is empty.');
    final response = await http.post(
      Uri.parse('$_endpoint?key=${Uri.encodeQueryComponent(apiKey.trim())}'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{
          'role': 'user',
          'parts': [{
            'text': '''
Classify the user's request for Nova Studio AI. Return JSON only.
Choose kind from: mesh, lua, cpp, roblox, unreal, unity, explain, debug, project.
Use kind=mesh for making or editing a 3D mesh/model.
Use kind=lua for a Lua or Roblox Luau script; targetId=1 for Roblox Luau, 2 for generic Lua.
Use kind=cpp for C++ code; targetId=3 for generic C++, 4 for Unreal C++.
Use kind=roblox for a Roblox project-level operation, targetId=7.
Use kind=unreal for an Unreal project-level operation, targetId=8.
Use kind=unity for a Unity/C# project-level operation, targetId=9.
Use kind=explain for explanations or research.
Use kind=debug for diagnosing/fixing an existing issue.
Use kind=project for general project operations.
Action IDs: create=1, edit=2, delete=3, explain=4, research=5, debug=6, optimize=7, convert=8, test=9, export=10, import=11, add_feature=12, create_mesh=13, create_script=14, create_project_action=15.
For mesh, actionId=13 and targetId=6. For Lua/C++ scripts, actionId=14.
Use numeric IDs only in these fields. optionsId/detail/flags are 0..99. Name and description are short human-readable metadata.
Return keys kind, actionId, targetId, optionsId, detail, flags, name, description.
Current active engine: $activeEngine
User request: $prompt
'''
          }]
        }],
        'generationConfig': {
          'temperature': 0,
          'responseMimeType': 'application/json',
          'responseSchema': {
            'type': 'OBJECT',
            'properties': {
              'kind': {'type': 'STRING', 'enum': ['mesh','lua','cpp','roblox','unreal','unity','explain','debug','project']},
              'actionId': {'type': 'INTEGER'},
              'targetId': {'type': 'INTEGER'},
              'optionsId': {'type': 'INTEGER'},
              'detail': {'type': 'INTEGER'},
              'flags': {'type': 'INTEGER'},
              'name': {'type': 'STRING'},
              'description': {'type': 'STRING'}
            },
            'required': ['kind','actionId','targetId','optionsId','detail','flags','name','description']
          }
        }
      }),
    ).timeout(const Duration(seconds: 35));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini HTTP ${response.statusCode}: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) throw Exception('Gemini returned no interpretation.');
    final content = (candidates.first as Map)['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) throw Exception('Gemini returned an empty interpretation.');
    final data = jsonDecode((parts.first as Map)['text'].toString()) as Map<String, dynamic>;
    final kindName = (data['kind'] ?? 'project').toString();
    final kind = NovaCommandKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => NovaCommandKind.project,
    );
    int field(String key) {
      final value = (data[key] as num?)?.round() ?? 0;
      return value.clamp(0, 99);
    }
    final command = NovaCommand(
      kind: kind,
      actionId: field('actionId').clamp(1, 99),
      targetId: field('targetId'),
      optionsId: field('optionsId'),
      detail: field('detail'),
      flags: field('flags'),
      name: (data['name'] ?? 'Nova task').toString(),
      description: (data['description'] ?? prompt).toString(),
    );
    // Round-trip validates the command shape before Nova uses it.
    NovaCommand.decode(command.encode(), name: command.name, description: command.description);
    return command;
  }
}
