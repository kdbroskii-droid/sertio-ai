import 'package:flutter_test/flutter_test.dart';
import 'package:nova_studio_ai/nova_project_validator.dart';

void main() {
  group('NovaProjectValidator path checks', () {
    test('accepts ordinary relative paths', () {
      expect(NovaProjectValidator.isSafeRelativePath('src/Game.lua'), isTrue);
      expect(NovaProjectValidator.isSafeRelativePath('Assets/Shop.rbxmx'), isTrue);
    });

    test('normalizes Windows separators and rejects traversal', () {
      expect(NovaProjectValidator.normalizePath(r'folder\script.lua'), 'folder/script.lua');
      expect(NovaProjectValidator.isSafeRelativePath('../secret.txt'), isFalse);
      expect(NovaProjectValidator.isSafeRelativePath(r'folder\..\secret.txt'), isFalse);
      expect(NovaProjectValidator.isSafeRelativePath('/absolute/file.lua'), isFalse);
      expect(NovaProjectValidator.isSafeRelativePath(r'C:\secret.txt'), isFalse);
      expect(NovaProjectValidator.isSafeRelativePath('folder//file.lua'), isFalse);
    });
  });

  group('NovaProjectValidator generated files', () {
    test('accepts a valid simple file list', () {
      expect(
        NovaProjectValidator.validateGeneratedFiles([
          {'path': 'Server/Main.server.lua', 'content': 'print("hello")'},
        ]),
        isEmpty,
      );
    });

    test('rejects unsafe and duplicate paths', () {
      final errors = NovaProjectValidator.validateGeneratedFiles([
        {'path': '../escape.lua', 'content': 'print(1)'},
        {'path': 'same.lua', 'content': 'print(1)'},
        {'path': 'same.lua', 'content': 'print(2)'},
      ]);
      expect(errors.any((e) => e.contains('Unsafe relative path')), isTrue);
      expect(errors.any((e) => e.contains('Duplicate file path')), isTrue);
    });

    test('rejects empty files and malformed Roblox model XML', () {
      final errors = NovaProjectValidator.validateGeneratedFiles([
        {'path': 'empty.lua', 'content': ''},
        {'path': 'Shop.rbxmx', 'content': '<xml>not a Roblox model</xml>'},
      ]);
      expect(errors.any((e) => e.contains('File is empty')), isTrue);
      expect(errors.any((e) => e.contains('Roblox model XML')), isTrue);
    });

    test('rejects files exceeding per-file and workspace limits', () {
      final large = List.filled(NovaProjectValidator.maxFileBytes + 1, 'x').join();
      final errors = NovaProjectValidator.validateGeneratedFiles([
        {'path': 'large.txt', 'content': large},
      ]);
      expect(errors.any((e) => e.contains('exceeds 1 MiB')), isTrue);
      final chunk = List.filled(900 * 1024, 'x').join();
      final workspaceErrors = NovaProjectValidator.validateGeneratedFiles([
        for (var i = 0; i < 6; i++) {'path': 'file$i.txt', 'content': chunk},
      ]);
      expect(workspaceErrors.any((e) => e.contains('5 MiB total limit')), isTrue);
    });

    test('checks existing workspace files too', () {
      final errors = NovaProjectValidator.validateWorkspace({
        '../bad.lua': 'print(1)',
      });
      expect(errors.any((e) => e.contains('Unsafe relative path')), isTrue);
    });
  });
}
