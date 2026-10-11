import 'dart:convert';
import 'package:http/http.dart' as http;

/// A compact, deterministic command for Nova's procedural mesh generator.
///
/// Digits are fixed-width fields, not a random ID:
/// V(1) + object(2) + style(2) + size(2) + detail(2) + features(2).
/// Example: 10301201201 = v1, wheel(03), low-poly(01), size 20,
/// detail 12, vehicle features 01.
class NovaMeshCommand {
  const NovaMeshCommand({
    required this.objectId,
    required this.styleId,
    required this.size,
    required this.detail,
    required this.features,
  });

  final int objectId;
  final int styleId;
  final int size; // 05..50, where 20 is default size 2.0
  final int detail; // 08..24
  final int features;

  String encode() {
    String two(int n) => n.toString().padLeft(2, '0');
    return '1${two(objectId)}${two(styleId)}${two(size)}${two(detail)}${two(features)}';
  }

  static NovaMeshCommand decode(String code) {
    if (!RegExp(r'^1\d{10}$').hasMatch(code)) {
      throw const FormatException('Invalid Nova mesh command. Expected 11 digits.');
    }
    final version = int.parse(code.substring(0, 1));
    if (version != 1) throw const FormatException('Unsupported Nova command version.');
    final command = NovaMeshCommand(
      objectId: int.parse(code.substring(1, 3)),
      styleId: int.parse(code.substring(3, 5)),
      size: int.parse(code.substring(5, 7)),
      detail: int.parse(code.substring(7, 9)),
      features: int.parse(code.substring(9, 11)),
    );
    if (command.objectId < 1 || command.objectId > 6 ||
        command.styleId < 1 || command.styleId > 3 ||
        command.size < 5 || command.size > 50 ||
        command.detail < 8 || command.detail > 24 ||
        command.features < 0 || command.features > 99) {
      throw const FormatException('Nova command contains an unsupported field.');
    }
    return command;
  }
}

class GeminiCommandInterpreter {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// Gemini only interprets language into a small schema. Nova itself creates
  /// the geometry and encodes the schema as a stable numeric command.
  static Future<Map<String, dynamic>> interpret({
    required String apiKey,
    required String prompt,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Add your Gemini API key in the 3D Generator settings.');
    }
    final response = await http.post(
      Uri.parse('$_endpoint?key=${Uri.encodeQueryComponent(apiKey.trim())}'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{
          'role': 'user',
          'parts': [{
            'text': 'Convert the user request into JSON only. Allowed object values: cube, sphere, tree, house, sword, barrel, wheel. Allowed style values: low_poly, smooth, chunky. Return keys object, style, size, detail, features, name, description. size is a number from 0.5 to 5.0; detail is integer 8 to 24. features is an integer 0 to 99. For a car wheel use object=wheel, style=low_poly, features=1. Do not return code or markdown. User request: $prompt'
          }]
        }],
        'generationConfig': {
          'temperature': 0,
          'responseMimeType': 'application/json',
          'responseSchema': {
            'type': 'OBJECT',
            'properties': {
              'object': {'type': 'STRING', 'enum': ['cube','sphere','tree','house','sword','barrel','wheel']},
              'style': {'type': 'STRING', 'enum': ['low_poly','smooth','chunky']},
              'size': {'type': 'NUMBER'},
              'detail': {'type': 'INTEGER'},
              'features': {'type': 'INTEGER'},
              'name': {'type': 'STRING'},
              'description': {'type': 'STRING'}
            },
            'required': ['object','style','size','detail','features','name','description']
          }
        }
      }),
    ).timeout(const Duration(seconds: 35));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini HTTP ${response.statusCode}: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (((body['candidates'] as List?)?.first as Map?)?['content'] as Map?)?['parts'];
    if (text is! List || text.isEmpty || text.first is! Map) {
      throw Exception('Gemini returned no command interpretation.');
    }
    final decoded = jsonDecode((text.first as Map)['text'].toString()) as Map<String, dynamic>;
    final object = (decoded['object'] ?? 'cube').toString();
    const objectIds = {'cube': 1, 'sphere': 2, 'tree': 3, 'house': 4, 'sword': 5, 'barrel': 6, 'wheel': 7};
    // Object IDs are stable. IDs 1-6 preserve the original generator; wheel is 07.
    final style = (decoded['style'] ?? 'low_poly').toString();
    const styleIds = {'low_poly': 1, 'smooth': 2, 'chunky': 3};
    final rawSize = (decoded['size'] as num?)?.toDouble() ?? 2.0;
    final size = (rawSize.clamp(0.5, 5.0) * 10).round();
    final detail = ((decoded['detail'] as num?)?.round() ?? 12).clamp(8, 24);
    final features = ((decoded['features'] as num?)?.round() ?? 0).clamp(0, 99);
    final command = NovaMeshCommand(
      objectId: objectIds[object] ?? 1,
      styleId: styleIds[style] ?? 1,
      size: size,
      detail: detail,
      features: features,
    );
    return {
      'command': command.encode(),
      'object': object,
      'style': style,
      'size': size / 10,
      'detail': detail,
      'features': features,
      'name': (decoded['name'] ?? object).toString(),
      'description': (decoded['description'] ?? 'Procedural mesh').toString(),
    };
  }
}
