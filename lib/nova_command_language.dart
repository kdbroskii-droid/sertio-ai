import 'dart:convert';

enum NovaCommandKind {
  mesh('#'), lua(')'), cpp('*)'), roblox('@'), unreal('&'), unity('%'),
  explain('?'), debug('!'), project('~');
  const NovaCommandKind(this.prefix);
  final String prefix;

  static NovaCommandKind fromPrefix(String prefix) {
    for (final kind in values) {
      if (kind.prefix == prefix) return kind;
    }
    throw FormatException('Unknown Nova command prefix: $prefix');
  }

  static ({NovaCommandKind kind, String prompt})? parseRequest(String request) {
    final trimmed = request.trimLeft();
    final prefix = trimmed.startsWith('*)'
        ? '*)'
        : (trimmed.isNotEmpty && '#)@&%?!~'.contains(trimmed[0]) ? trimmed[0] : null);
    if (prefix == null) return null;
    return (kind: fromPrefix(prefix), prompt: trimmed.substring(prefix.length).trim());
  }
}

class NovaCommand {
  const NovaCommand({
    required this.kind, required this.actionId, required this.targetId,
    required this.optionsId, required this.detail, required this.flags,
    required this.name, required this.description,
  });
  final NovaCommandKind kind;
  final int actionId, targetId, optionsId, detail, flags;
  final String name, description;

  static NovaCommand fromExplicitRequest({
    required NovaCommandKind kind, required String activeEngine, required String task,
  }) {
    final engine = activeEngine.toLowerCase();
    final target = switch (kind) {
      NovaCommandKind.mesh => 6,
      NovaCommandKind.lua => engine == 'roblox' ? 1 : 2,
      NovaCommandKind.cpp => engine.contains('unreal') ? 4 : 3,
      NovaCommandKind.roblox => 7,
      NovaCommandKind.unreal => 8,
      NovaCommandKind.unity => 9,
      NovaCommandKind.explain || NovaCommandKind.debug => 10,
      NovaCommandKind.project => engine == 'roblox' ? 7 : engine.contains('unreal') ? 8 : engine == 'unity' ? 9 : 10,
    };
    final action = switch (kind) {
      NovaCommandKind.mesh => 13,
      NovaCommandKind.lua || NovaCommandKind.cpp => 14,
      NovaCommandKind.explain => 4,
      NovaCommandKind.debug => 6,
      _ => 15,
    };
    return NovaCommand(
      kind: kind, actionId: action, targetId: target, optionsId: 0, detail: 0, flags: 0,
      name: task.trim().isEmpty ? 'Nova task' : task.trim(), description: task.trim(),
    );
  }

  String encode() {
    String two(int n) {
      if (n < 0 || n > 99) throw RangeError('Nova command fields must be 0..99.');
      return n.toString().padLeft(2, '0');
    }
    return '${kind.prefix}1${two(actionId)}${two(targetId)}${two(optionsId)}${two(detail)}${two(flags)}';
  }

  static NovaCommand decode(String code, {String name = '', String description = ''}) {
    final prefix = code.startsWith('*)' ? '*)' : code.isNotEmpty ? code[0] : '';
    final kind = NovaCommandKind.fromPrefix(prefix);
    final payload = code.substring(prefix.length);
    if (!RegExp(r'^1\d{10}$').hasMatch(payload)) {
      throw const FormatException('Invalid Nova command payload.');
    }
    final result = NovaCommand(
      kind: kind, actionId: int.parse(payload.substring(1, 3)),
      targetId: int.parse(payload.substring(3, 5)),
      optionsId: int.parse(payload.substring(5, 7)),
      detail: int.parse(payload.substring(7, 9)),
      flags: int.parse(payload.substring(9, 11)), name: name, description: description,
    );
    if (result.actionId < 1) throw const FormatException('Action ID must be positive.');
    return result;
  }

  /// Decodes a space-separated chain. Each token is a distinct ordered task.
  static List<NovaCommand> decodeChain(String chain) {
    final tokens = chain.trim().split(RegExp(r'\\s+')).where((token) => token.isNotEmpty);
    if (tokens.isEmpty) throw const FormatException('Command chain is empty.');
    return tokens.map((token) => NovaCommand.decode(token)).toList(growable: false);
  }

  Map<String, Object> toJson() => {
    'prefix': kind.prefix, 'kind': kind.name, 'actionId': actionId,
    'targetId': targetId, 'optionsId': optionsId, 'detail': detail,
    'flags': flags, 'name': name, 'description': description, 'command': encode(),
  };
  String toJsonString() => jsonEncode(toJson());
}

class NovaCommandRegistry {
  static const actions = <String, int>{
    'create': 1, 'edit': 2, 'delete': 3, 'explain': 4, 'research': 5,
    'debug': 6, 'optimize': 7, 'convert': 8, 'test': 9, 'export': 10,
    'import': 11, 'add_feature': 12, 'create_mesh': 13, 'create_script': 14,
    'create_project_action': 15, 'generate_tests': 16, 'refactor': 17,
    'document': 18, 'analyze': 19, 'configure': 20, 'build': 21, 'run': 22,
  };
  static const targets = <String, int>{
    'none': 0, 'roblox_luau': 1, 'lua': 2, 'cpp': 3, 'unreal_cpp': 4,
    'unity_csharp': 5, 'mesh_obj': 6, 'roblox_project': 7, 'unreal_project': 8,
    'unity_project': 9, 'general': 10, 'flutter_dart': 11, 'web_html_css_js': 12,
    'python': 13, 'project_files': 14, 'shader': 15, 'godot_gdscript': 16, 'roblox_model_rbxmx': 17, 'roblox_script': 18,
  };
  static int action(String name) => actions[name] ?? actions['create']!;
  static int target(String name) => targets[name] ?? targets['general']!;
}

class NovaPlanStep {
  const NovaPlanStep({
    required this.command, required this.task, required this.expectedResult,
    required this.dependsOnPrevious,
  });
  final NovaCommand command;
  final String task, expectedResult;
  final bool dependsOnPrevious;
  Map<String, Object> toJson() => {
    'command': command.encode(), 'kind': command.kind.name,
    'task': task, 'expectedResult': expectedResult,
    'dependsOnPrevious': dependsOnPrevious,
  };
}
