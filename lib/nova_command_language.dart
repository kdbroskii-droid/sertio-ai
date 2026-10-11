import 'dart:convert';

/// Universal command envelope used by Nova for every supported task type.
///
/// The visible prefix selects the execution family:
/// # mesh, ) Lua/Luau, *) C++, @ Roblox, & Unreal, % Unity/C#,
/// ? explain/research, ! debug/fix, ~ general project action.
/// Numeric fields are deterministic and versioned, not random IDs.
enum NovaCommandKind {
  mesh('#'),
  lua(')'),
  cpp('*)'),
  roblox('@'),
  unreal('&'),
  unity('%'),
  explain('?'),
  debug('!'),
  project('~');

  const NovaCommandKind(this.prefix);
  final String prefix;

  static NovaCommandKind fromPrefix(String prefix) {
    for (final kind in values) {
      if (kind.prefix == prefix) return kind;
    }
    throw FormatException('Unknown Nova command prefix: $prefix');
  }

  /// Detects an optional user-written prefix at the start of a request.
  /// C++ must be checked before the one-character prefixes.
  static ({NovaCommandKind kind, String prompt})? parseRequest(String request) {
    final trimmed = request.trimLeft();
    final prefix = trimmed.startsWith('*)'
        ? '*)'
        : (trimmed.isNotEmpty && '#)@&%?!~'.contains(trimmed[0])
            ? trimmed[0]
            : null);
    if (prefix == null) return null;
    return (kind: fromPrefix(prefix), prompt: trimmed.substring(prefix.length).trim());
  }
}

class NovaCommand {
  const NovaCommand({
    required this.kind,
    required this.actionId,
    required this.targetId,
    required this.optionsId,
    required this.detail,
    required this.flags,
    required this.name,
    required this.description,
  });

  final NovaCommandKind kind;
  final int actionId;
  final int targetId;
  final int optionsId;
  final int detail;
  final int flags;
  final String name;
  final String description;

  /// Format: prefix + version(1) + action(2) + target(2) + options(2) + detail(2) + flags(2).
  String encode() {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${kind.prefix}1${two(actionId)}${two(targetId)}${two(optionsId)}${two(detail)}${two(flags)}';
  }

  static NovaCommand decode(String code, {String name = '', String description = ''}) {
    final prefix = code.startsWith('*)' ? '*)' : code.isNotEmpty ? code[0] : '';
    final kind = NovaCommandKind.fromPrefix(prefix);
    final payload = code.substring(prefix.length);
    if (!RegExp(r'^1\\d{10}$').hasMatch(payload)) {
      throw const FormatException('Invalid Nova command payload.');
    }
    final result = NovaCommand(
      kind: kind,
      actionId: int.parse(payload.substring(1, 3)),
      targetId: int.parse(payload.substring(3, 5)),
      optionsId: int.parse(payload.substring(5, 7)),
      detail: int.parse(payload.substring(7, 9)),
      flags: int.parse(payload.substring(9, 11)),
      name: name,
      description: description,
    );
    if (result.actionId < 1 || result.actionId > 99 ||
        result.targetId > 99 || result.optionsId > 99 ||
        result.detail > 99 || result.flags > 99) {
      throw const FormatException('Nova command contains unsupported fields.');
    }
    return result;
  }

  Map<String, Object> toJson() => {
    'prefix': kind.prefix,
    'kind': kind.name,
    'actionId': actionId,
    'targetId': targetId,
    'optionsId': optionsId,
    'detail': detail,
    'flags': flags,
    'name': name,
    'description': description,
    'command': encode(),
  };

  String toJsonString() => jsonEncode(toJson());
}

/// Stable registries. Never recycle an ID after publishing it.
class NovaCommandRegistry {
  static const actions = <String, int>{
    'create': 1,
    'edit': 2,
    'delete': 3,
    'explain': 4,
    'research': 5,
    'debug': 6,
    'optimize': 7,
    'convert': 8,
    'test': 9,
    'export': 10,
    'import': 11,
    'add_feature': 12,
    'create_mesh': 13,
    'create_script': 14,
    'create_project_action': 15,
    'generate_tests': 16,
    'refactor': 17,
    'document': 18,
    'analyze': 19,
    'configure': 20,
    'build': 21,
    'run': 22,
  };

  static const targets = <String, int>{
    'none': 0,
    'roblox_luau': 1,
    'lua': 2,
    'cpp': 3,
    'unreal_cpp': 4,
    'unity_csharp': 5,
    'mesh_obj': 6,
    'roblox_project': 7,
    'unreal_project': 8,
    'unity_project': 9,
    'general': 10,
    'flutter_dart': 11,
    'web_html_css_js': 12,
    'python': 13,
    'project_files': 14,
    'shader': 15,
    'godot_gdscript': 16,
  };

  static int action(String name) => actions[name] ?? actions['create']!;
  static int target(String name) => targets[name] ?? targets['general']!;
}
