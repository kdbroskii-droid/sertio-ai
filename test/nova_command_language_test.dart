import 'package:flutter_test/flutter_test.dart';
import 'package:nova_studio_ai/nova_command_language.dart';

void main() {
  group('Nova command language', () {
    test('encodes and decodes every task prefix deterministically', () {
      for (final kind in NovaCommandKind.values) {
        final command = NovaCommand(
          kind: kind,
          actionId: 14,
          targetId: 10,
          optionsId: 2,
          detail: 12,
          flags: 1,
          name: 'test',
          description: 'round trip',
        );
        final encoded = command.encode();
        final decoded = NovaCommand.decode(encoded);
        expect(decoded.kind, kind);
        expect(decoded.actionId, 14);
        expect(decoded.targetId, 10);
        expect(decoded.optionsId, 2);
        expect(decoded.detail, 12);
        expect(decoded.flags, 1);
        expect(NovaCommand.decode(encoded).encode(), encoded);
      }
    });

    test('recognizes two-character C++ prefix before single-character prefixes', () {
      final parsed = NovaCommandKind.parseRequest('  *) make a movement component');
      expect(parsed?.kind, NovaCommandKind.cpp);
      expect(parsed?.prompt, 'make a movement component');
    });

    test('recognizes each explicit prefix and strips only the prefix', () {
      const prefixes = <String, NovaCommandKind>{
        '#': NovaCommandKind.mesh,
        ')': NovaCommandKind.lua,
        '*)': NovaCommandKind.cpp,
        '@': NovaCommandKind.roblox,
        '&': NovaCommandKind.unreal,
        '%': NovaCommandKind.unity,
        '?': NovaCommandKind.explain,
        '!': NovaCommandKind.debug,
        '~': NovaCommandKind.project,
      };
      for (final entry in prefixes.entries) {
        final parsed = NovaCommandKind.parseRequest('${entry.key} do the task');
        expect(parsed?.kind, entry.value);
        expect(parsed?.prompt, 'do the task');
      }
    });

    test('leaves normal requests without an explicit prefix alone', () {
      expect(NovaCommandKind.parseRequest('make a car wheel'), isNull);
    });

    test('Roblox-native model target has a stable ID', () {
      expect(NovaCommandRegistry.target('roblox_model_rbxmx'), 17);
      expect(NovaCommandRegistry.target('roblox_script'), 18);
    });

    test('command encoding rejects fields wider than two digits', () {
      final command = NovaCommand(
        kind: NovaCommandKind.mesh,
        actionId: 100,
        targetId: 6,
        optionsId: 0,
        detail: 0,
        flags: 0,
        name: 'bad',
        description: 'bad',
      );
      expect(() => command.encode(), throwsRangeError);
    });

    test('rejects malformed numeric payloads', () {
      expect(() => NovaCommand.decode('#bad'), throwsFormatException);
      expect(() => NovaCommand.decode(')100010000000'), throwsFormatException);
    });
  });
}
