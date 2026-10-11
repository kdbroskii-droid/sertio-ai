import 'dart:convert';
import 'package:http/http.dart' as http;
import 'nova_command_language.dart';

class NovaVerification {
  const NovaVerification({required this.approved, required this.feedback});
  final bool approved;
  final String feedback;
}

class NovaUniversalInterpreter {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static Future<Map<String, dynamic>> _ask({
    required String apiKey,
    required String prompt,
    required Map<String, dynamic> schema,
  }) async {
    if (apiKey.trim().isEmpty) throw Exception('Gemini API key is empty.');
    final response = await http.post(
      Uri.parse('$_endpoint?key=${Uri.encodeQueryComponent(apiKey.trim())}'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{'role': 'user', 'parts': [{'text': prompt}]}],
        'generationConfig': {
          'temperature': 0,
          'responseMimeType': 'application/json',
          'responseSchema': schema,
        },
      }),
    ).timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini HTTP ${response.statusCode}: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) throw Exception('Gemini returned no interpretation.');
    final parts = ((candidates.first as Map)['content'] as Map?)?['parts'] as List?;
    if (parts == null || parts.isEmpty) throw Exception('Gemini returned an empty interpretation.');
    return jsonDecode((parts.first as Map)['text'].toString()) as Map<String, dynamic>;
  }

  static const _stepSchema = {
    'type': 'OBJECT',
    'properties': {
      'kind': {'type': 'STRING', 'enum': ['mesh','lua','cpp','roblox','unreal','unity','explain','debug','project']},
      'action': {'type': 'STRING'},
      'target': {'type': 'STRING'},
      'task': {'type': 'STRING'},
      'expectedResult': {'type': 'STRING'},
      'optionsId': {'type': 'INTEGER'},
      'detail': {'type': 'INTEGER'},
      'flags': {'type': 'INTEGER'},
    },
    'required': ['kind','action','target','task','expectedResult','optionsId','detail','flags'],
  };

  /// Decomposes the user's intent into small ordered deliverables.
  /// Later steps explicitly depend on earlier verified steps where appropriate.
  static Future<List<NovaPlanStep>> plan({
    required String apiKey,
    required String prompt,
    required String activeEngine,
    required String projectName,
    required String existingFiles,
  }) async {
    final explicit = NovaCommandKind.parseRequest(prompt);
    final userPrompt = explicit?.prompt ?? prompt.trim();
    if (userPrompt.isEmpty) throw Exception('Add a task after the command prefix.');
    final data = await _ask(
      apiKey: apiKey,
      schema: {
        'type': 'OBJECT',
        'properties': {
          'steps': {'type': 'ARRAY', 'items': _stepSchema},
          'reasoning': {'type': 'STRING'},
        },
        'required': ['steps','reasoning'],
      },
      prompt: '''
You are the planner for Nova Studio AI. Break the request into the smallest useful sequence of concrete deliverables (1 to 8 steps). Return JSON only.
The active project already exists and is a $activeEngine project named "$projectName". Use that engine context; do not ask the user to re-create or re-specify it.
Current files (may be truncated): 
$existingFiles

Prefix meanings: #=mesh/model asset, )=Lua/Luau script, *)=C++ script, @=Roblox project operation, &=Unreal project operation, %=Unity/C# operation, ?=explain/research, !=debug/fix, ~=general project operation.
Kinds allowed: mesh, lua, cpp, roblox, unreal, unity, explain, debug, project.
Action IDs: create=1, edit=2, delete=3, explain=4, research=5, debug=6, optimize=7, convert=8, test=9, export=10, import=11, add_feature=12, create_mesh=13, create_script=14, create_project_action=15, generate_tests=16, refactor=17, document=18, analyze=19, configure=20, build=21, run=22.
Target IDs: none=0, roblox_luau=1, lua=2, cpp=3, unreal_cpp=4, unity_csharp=5, mesh_obj=6, roblox_project=7, unreal_project=8, unity_project=9, general=10, flutter_dart=11, web_html_css_js=12, python=13, project_files=14, shader=15, godot_gdscript=16, roblox_model_rbxmx=17, roblox_script=18.
If user asks for a shop in a Roblox game, normally plan separate ordered steps such as (1) create a Roblox-native .rbxmx shop model (not an OBJ) with named parts, (2) create the interaction/proximity logic, (3) create the shop UI and client logic, (4) connect purchasing/data safely if requested, (5) validate references and wiring. Use a # command for the model asset and ) commands for Luau scripts. Do not combine unrelated deliverables into one huge script. Use only steps genuinely needed.
A shop should not be only a static model: ensure interaction and UI are planned. Prefer server-authoritative purchase handling, validate prices/items server-side, and never trust client purchase requests.
For every step provide a specific task and objectively checkable expectedResult. Keep each step small. Order dependencies correctly. Use explicit prefix as the required kind for a single step when the user starts with a prefix; do not override it. For a natural-language multi-part request, select different kinds for different deliverables.
Use action and target names from the registries. Numeric fields must be integers 0..99. Keep step count to 8 max.
Active engine: $activeEngine
User request: $userPrompt
''',
    );
    final rawSteps = data['steps'];
    if (rawSteps is! List || rawSteps.isEmpty) throw Exception('Gemini did not return an execution plan.');
    final steps = <NovaPlanStep>[];
    for (final raw in rawSteps.take(8)) {
      if (raw is! Map) continue;
      final kindName = (raw['kind'] ?? 'project').toString();
      var kind = NovaCommandKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => NovaCommandKind.project,
      );
      if (explicit != null) kind = explicit.kind;
      final task = (raw['task'] ?? userPrompt).toString().trim();
      if (task.isEmpty) continue;
      final actionName = (raw['action'] ?? 'create').toString();
      final actionId = NovaCommandRegistry.action(actionName);
      final engine = activeEngine.toLowerCase();
      final inferredTarget = switch (kind) {
        NovaCommandKind.mesh => engine == 'roblox' ? 'roblox_model_rbxmx' : 'mesh_obj',
        NovaCommandKind.lua => engine == 'roblox' ? 'roblox_luau' : 'lua',
        NovaCommandKind.cpp => engine.contains('unreal') ? 'unreal_cpp' : 'cpp',
        NovaCommandKind.roblox => 'roblox_project',
        NovaCommandKind.unreal => 'unreal_project',
        NovaCommandKind.unity => 'unity_project',
        NovaCommandKind.explain || NovaCommandKind.debug => 'general',
        NovaCommandKind.project => engine == 'roblox' ? 'roblox_project' : engine.contains('unreal') ? 'unreal_project' : engine == 'unity' ? 'unity_project' : 'project_files',
      };
      final targetId = NovaCommandRegistry.target((raw['target'] ?? inferredTarget).toString());
      final command = NovaCommand(
        kind: kind,
        actionId: actionId,
        targetId: targetId,
        optionsId: _number(raw['optionsId']),
        detail: _number(raw['detail']),
        flags: _number(raw['flags']),
        name: task,
        description: (raw['expectedResult'] ?? task).toString(),
      );
      // Verify encoder/decoder agreement before a plan step can run.
      NovaCommand.decode(command.encode(), name: task, description: command.description);
      steps.add(NovaPlanStep(
        command: command,
        task: task,
        expectedResult: command.description,
        dependsOnPrevious: steps.isNotEmpty,
      ));
    }
    if (steps.isEmpty) throw Exception('Gemini plan contained no usable steps.');
    return steps;
  }

  static int _number(Object? value) {
    if (value is! num) return 0;
    return value.round().clamp(0, 99);
  }

  /// Gemini checks generated JSON and file contents against the step acceptance criteria.
  static Future<NovaVerification> verify({
    required String apiKey,
    required String task,
    required String expectedResult,
    required String generatedResponse,
    required String existingFiles,
    required int attempt,
  }) async {
    final data = await _ask(
      apiKey: apiKey,
      schema: {
        'type': 'OBJECT',
        'properties': {
          'approved': {'type': 'BOOLEAN'},
          'feedback': {'type': 'STRING'},
        },
        'required': ['approved','feedback'],
      },
      prompt: '''
Act as a strict code reviewer for a staged Nova Studio AI project change. Review attempt $attempt.
Task: $task
Acceptance criteria: $expectedResult
Existing project files:
$existingFiles
Proposed model response (must be JSON with message and files array; every file needs path and complete content):
$generatedResponse

Approve only if the response is valid JSON of the required shape, file paths are relative and safe, the output actually fulfils this step, and it is consistent with the existing project. For Roblox, check that model/server/client responsibilities are separated sensibly, RemoteEvents are validated server-side, purchases are server-authoritative, and scripts refer to real planned instances or clearly specify what must be created. Do not demand unrelated polish. If there is any substantive error, set approved=false and give concise, actionable correction instructions. Return JSON only.
''',
    );
    return NovaVerification(
      approved: data['approved'] == true,
      feedback: (data['feedback'] ?? 'Review did not approve the change.').toString(),
    );
  }

  /// Compatibility API for single-command callers.
  static Future<NovaCommand> interpret({
    required String apiKey, required String prompt, required String activeEngine,
  }) async {
    final steps = await plan(
      apiKey: apiKey, prompt: prompt, activeEngine: activeEngine,
      projectName: 'Current project', existingFiles: '(not supplied)',
    );
    return steps.first.command;
  }
}
