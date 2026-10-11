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
    final explicit = NovaCommandKind.parseRequest(prompt);
    final userPrompt = explicit?.prompt ?? prompt.trim();
    if (userPrompt.isEmpty) {
      throw Exception('Add a task after the command prefix, for example: # make a car wheel.');
    }

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
Use kind=mesh for making or editing a 3D mesh/model, actionId=13 and targetId=6.
Use kind=lua for Lua or Roblox Luau scripts; actionId=14; targetId=1 for Roblox Luau, 2 for generic Lua.
Use kind=cpp for C++ code; actionId=14; targetId=3 for generic C++, 4 for Unreal C++.
Use kind=roblox for Roblox project operations, targetId=7.
Use kind=unreal for Unreal project operations, targetId=8.
Use kind=unity for Unity/C# project operations, targetId=9.
Use kind=explain for explanations/research and targetId=10.
Use kind=debug for diagnosing/fixing and targetId=10.
Use kind=project for general project operations. Target IDs: Roblox project=7, Unreal project=8, Unity project=9, general=10.
Action IDs: create=1, edit=2, delete=3, explain=4, research=5, debug=6, optimize=7, convert=8, test=9, export=10, import=11, add_feature=12, create_mesh=13, create_script=14, create_project_action=15, generate_tests=16, refactor=17, document=18, analyze=19, configure=20, build=21, run=22.
Use only numeric IDs 0..99 for optionsId/detail/flags. Name and description are short human-readable metadata.
${explicit == null ? 'No explicit prefix was supplied; infer the best kind from the request.' : 'The user explicitly selected prefix "${explicit.kind.prefix}" meaning kind "${explicit.kind.name}". Preserve that kind regardless of the wording.'}
Return keys kind, actionId, targetId, optionsId, detail, flags, name, description.
Current active engine: $activeEngine
User request: $userPrompt
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

    final inferredKind = NovaCommandKind.values.firstWhere(
      (k) => k.name == (data['kind'] ?? 'project').toString(),
      orElse: () => NovaCommandKind.project,
    );
    // An explicit prefix is authoritative; Gemini cannot silently change the task family.
    final kind = explicit?.kind ?? inferredKind;
    int field(String key) {
      final value = (data[key] as num?)?.round() ?? 0;
      return value.clamp(0, 99);
    }

    final defaultAction = switch (kind) {
      NovaCommandKind.mesh => 13,
      NovaCommandKind.lua || NovaCommandKind.cpp => 14,
      NovaCommandKind.explain => 4,
      NovaCommandKind.debug => 6,
      _ => 15,
    };
    final engineTarget = switch (activeEngine.toLowerCase()) {
      'roblox' => 7,
      'unreal' || 'unreal engine' => 8,
      'unity' => 9,
      _ => 10,
    };
    final target = switch (kind) {
      NovaCommandKind.mesh => 6,
      NovaCommandKind.lua => activeEngine.toLowerCase() == 'roblox' ? 1 : 2,
      NovaCommandKind.cpp => activeEngine.toLowerCase().contains('unreal') ? 4 : 3,
      NovaCommandKind.roblox => 7,
      NovaCommandKind.unreal => 8,
      NovaCommandKind.unity => 9,
      NovaCommandKind.explain || NovaCommandKind.debug => 10,
      NovaCommandKind.project => engineTarget,
    };
    final command = NovaCommand(
      kind: kind,
      actionId: switch (kind) {
        NovaCommandKind.mesh || NovaCommandKind.lua || NovaCommandKind.cpp => defaultAction,
        NovaCommandKind.explain => (field('actionId') == 5 ? 5 : 4),
        NovaCommandKind.debug => 6,
        _ => field('actionId') >= 1 ? field('actionId') : defaultAction,
      },
      targetId: target,
      optionsId: field('optionsId'),
      detail: field('detail'),
      flags: field('flags'),
      name: (data['name'] ?? 'Nova task').toString(),
      description: (data['description'] ?? userPrompt).toString(),
    );
    NovaCommand.decode(command.encode(), name: command.name, description: command.description);
    return command;
  }
}
