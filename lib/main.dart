import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const blue = Color(0xFF4F8CFF);
const bg = Color(0xFF0B0D12);
const panel = Color(0xFF131720);
const line = Color(0xFF2B3443);
const muted = Color(0xFF9AA6B8);

void main() => runApp(const NovaStudioApp());

class NovaStudioApp extends StatelessWidget {
  const NovaStudioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nova Studio AI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: blue, surface: panel),
      useMaterial3: true,
    ),
    home: const StudioHome(),
  );
}

class GameProject {
  GameProject(this.name, this.engine, this.files);
  String name;
  String engine;
  Map<String, String> files;
}

class ChatMessage {
  ChatMessage(this.role, this.text);
  final String role;
  final String text;
}

class StudioHome extends StatefulWidget {
  const StudioHome({super.key});
  @override
  State<StudioHome> createState() => _StudioHomeState();
}

class _StudioHomeState extends State<StudioHome> {
  final prompt = TextEditingController();
  final messages = <ChatMessage>[
    ChatMessage('assistant', 'Welcome to Nova Studio AI. Create a project, describe a change, or connect a local AI model in Settings.'),
  ];
  final projects = <GameProject>[];
  final undoStack = <Map<String, String>>[];
  String endpoint = 'http://127.0.0.1:11434/v1/chat/completions';
  String model = 'qwen2.5-coder:7b';
  String apiKey = '';
  String engine = 'Roblox';
  String page = 'Studio';
  String selectedFile = '';
  bool busy = false;
  GameProject? get project => projects.isEmpty ? null : projects.first;

  @override
  void initState() {
    super.initState();
    _load();
    _create('My First Game', 'Roblox', false);
  }

  @override
  void dispose() {
    prompt.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      endpoint = p.getString('endpoint') ?? endpoint;
      model = p.getString('model') ?? model;
      apiKey = p.getString('key') ?? '';
    });
  }

  void _toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Map<String, String> _starter(String e, String name) {
    if (e == 'Roblox') return {
      'README.md': '# $name\nRoblox starter workspace. Add these Luau files in Roblox Studio.',
      'ServerScriptService/GameServer.server.lua': 'local Players = game:GetService("Players")\nPlayers.PlayerAdded:Connect(function(player)\n    print("Welcome, " .. player.Name)\nend)\n',
      'StarterPlayerScripts/GameClient.client.lua': '-- Client-side game logic goes here.\nprint("Nova Studio ready")\n',
    };
    if (e == 'Unity') return {
      'README.md': '# $name\nUnity starter workspace.',
      'Assets/Scripts/GameManager.cs': 'using UnityEngine;\npublic class GameManager : MonoBehaviour {\n    void Start() { Debug.Log("$name is ready"); }\n}\n',
    };
    return {
      'README.md': '# $name\nUnreal Engine C++ starter workspace. Add source files to an Unreal project.',
      'Source/GameStarter.cpp': '#include "CoreMinimal.h"\n// Add your Unreal gameplay classes here.\n',
    };
  }

  void _create(String name, String e, [bool notify = true]) {
    final p = GameProject(name, e, _starter(e, name));
    setState(() {
      projects.insert(0, p);
      engine = e;
      selectedFile = p.files.keys.first;
      page = 'Studio';
    });
    if (notify) _toast('Created $e starter project.');
  }

  Future<void> _newProject() async {
    final name = TextEditingController(text: 'My New Game');
    var e = engine;
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: const Text('New project'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Project name')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: e,
            items: const ['Roblox', 'Unreal Engine', 'Unity'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setDialog(() => e = v ?? e),
            decoration: const InputDecoration(labelText: 'Engine'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create')),
        ],
      ),
    ));
    if (ok == true && name.text.trim().isNotEmpty) _create(name.text.trim(), e);
    name.dispose();
  }

  Future<void> _settings() async {
    final ep = TextEditingController(text: endpoint);
    final mo = TextEditingController(text: model);
    final ky = TextEditingController(text: apiKey);
    await showDialog<void>(context: context, builder: (c) => AlertDialog(
      title: const Text('Local AI settings'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ep, decoration: const InputDecoration(labelText: 'Chat endpoint')),
        const SizedBox(height: 10),
        TextField(controller: mo, decoration: const InputDecoration(labelText: 'Model name')),
        const SizedBox(height: 10),
        TextField(controller: ky, obscureText: true, decoration: const InputDecoration(labelText: 'API key (optional)')),
        const SizedBox(height: 10),
        const Text('On a physical phone, use your PC LAN address if the model runs on your PC.', style: TextStyle(color: muted, fontSize: 12)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('endpoint', ep.text.trim());
          await prefs.setString('model', mo.text.trim());
          await prefs.setString('key', ky.text);
          if (mounted) setState(() { endpoint = ep.text.trim(); model = mo.text.trim(); apiKey = ky.text; });
          if (c.mounted) Navigator.pop(c);
          _toast('Settings saved locally.');
        }, child: const Text('Save')),
      ],
    ));
    ep.dispose(); mo.dispose(); ky.dispose();
  }

  bool _safePath(String p) {
    final normalized = p.replaceAll('\\', '/');
    return normalized.isNotEmpty && !normalized.startsWith('/') && !normalized.contains(':') &&
      !normalized.split('/').any((part) => part == '..' || part.isEmpty);
  }

  Future<void> _send() async {
    final text = prompt.text.trim();
    final p = project;
    if (text.isEmpty || p == null || busy) return;
    prompt.clear();
    setState(() { messages.add(ChatMessage('user', text)); busy = true; });
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (apiKey.isNotEmpty) headers['Authorization'] = 'Bearer $apiKey';
      final contextFiles = p.files.entries.map((e) => '\nFILE: ' + e.key + '\n' + e.value).join('\n');
      final system = 'You are Nova Studio AI for ' + p.engine + '. Return ONLY JSON shaped like {"message":"summary","files":[{"path":"relative/path","content":"complete file"}]}. Use an empty files list if no changes are needed. Never use absolute paths or ../. Use Luau for Roblox, C# for Unity and C++ for Unreal. Do not claim to run builds. Project: ' + p.name + '\nCurrent files:\n' + contextFiles;
      final response = await http.post(Uri.parse(endpoint), headers: headers, body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          ...messages.take(12).map((m) => {'role': m.role, 'content': m.text}),
          {'role': 'user', 'content': text},
        ],
        'temperature': 0.2,
      })).timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('HTTP ' + response.statusCode.toString() + ': ' + response.body);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final answer = data['choices']?[0]?['message']?['content']?.toString() ?? '';
      _applyAnswer(answer);
    } catch (e) {
      if (mounted) setState(() => messages.add(ChatMessage('assistant', 'Could not connect to the local model. Check Settings and confirm the server is running and reachable.\n' + e.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _applyAnswer(String raw) {
    final p = project;
    if (p == null) return;
    try {
      var value = raw.trim();
      if (value.startsWith('```')) {
        value = value.replaceFirst(RegExp(r'^\x60\x60\x60(?:json)?\s*'), '');
        value = value.replaceFirst(RegExp(r'\s*\x60\x60\x60$'), '');
      }
      final data = jsonDecode(value) as Map<String, dynamic>;
      final summary = data['message']?.toString() ?? 'AI response received.';
      final files = data['files'];
      if (files is List && files.isNotEmpty) {
        undoStack.add(Map<String, String>.from(p.files));
        for (final item in files) {
          if (item is! Map) continue;
          final path = (item['path']?.toString() ?? '').replaceAll('\\', '/');
          if (!_safePath(path)) continue;
          p.files[path] = item['content']?.toString() ?? '';
          selectedFile = path;
        }
        setState(() => messages.add(ChatMessage('assistant', summary + '\nUpdated project files. Use Undo to restore the previous revision.')));
      } else {
        setState(() => messages.add(ChatMessage('assistant', summary)));
      }
    } catch (_) {
      setState(() => messages.add(ChatMessage('assistant', raw)));
    }
  }

  void _undo() {
    final p = project;
    if (p == null || undoStack.isEmpty) { _toast('No AI edits to undo.'); return; }
    setState(() {
      p.files = undoStack.removeLast();
      selectedFile = p.files.keys.first;
      messages.add(ChatMessage('assistant', 'Restored the previous file revision.'));
    });
  }

  Future<void> _export() async {
    final p = project;
    if (p == null) return;
    try {
      final zip = Archive();
      for (final entry in p.files.entries) {
        final bytes = utf8.encode(entry.value);
        zip.addFile(ArchiveFile(entry.key, bytes.length, bytes));
      }
      final encoded = ZipEncoder().encode(zip);
      if (encoded == null) throw Exception('Could not create ZIP.');
      final name = p.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export project ZIP',
        fileName: '$name.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: Uint8List.fromList(encoded),
      );
      if (result != null) _toast('ZIP exported.');
    } catch (e) { _toast('Export failed: $e'); }
  }

  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip'], withData: true);
      if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
      final zip = ZipDecoder().decodeBytes(result.files.first.bytes!);
      final files = <String, String>{};
      for (final f in zip.files) {
        if (!f.isFile || !_safePath(f.name)) continue;
        if (f.content is List<int>) files[f.name] = utf8.decode(f.content as List<int>, allowMalformed: true);
      }
      if (files.isEmpty) throw Exception('No readable text files found in ZIP.');
      final name = result.files.first.name.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');
      setState(() { projects.insert(0, GameProject(name, engine, files)); selectedFile = files.keys.first; page = 'Studio'; });
      _toast('Imported text files. Binary assets are not supported yet.');
    } catch (e) { _toast('Import failed: $e'); }
  }

  void _checks() {
    final p = project;
    if (p == null) return;
    final empty = p.files.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key).toList();
    final todo = p.files.entries.where((e) => e.value.contains('TODO')).map((e) => e.key).toList();
    setState(() {
      page = 'Tests';
      messages.add(ChatMessage('assistant', 'Workspace checks for ' + p.name + '\nFiles inspected: ' + p.files.length.toString() + '\nEmpty files: ' + empty.length.toString() + '\n' + empty.join('\n') + '\nTODO markers: ' + todo.length.toString() + '\n' + todo.join('\n') + '\n\nThese are basic checks, not a game-engine build or playtest.'));
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
    final wide = size.maxWidth >= 850;
    return Scaffold(
      body: SafeArea(child: Row(children: [
        if (wide) _sidebar(),
        Expanded(child: Column(children: [
          Container(height: 64, padding: const EdgeInsets.symmetric(horizontal: 18), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))), child: Row(children: [
            if (!wide) const Icon(Icons.auto_awesome, color: blue),
            const SizedBox(width: 8),
            Text(wide ? page : 'Nova Studio AI', style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            const Icon(Icons.circle, size: 8, color: Color(0xFF70D6A0)),
            const SizedBox(width: 6),
            const Text('Local AI', style: TextStyle(color: muted, fontSize: 12)),
            IconButton(onPressed: _settings, icon: const Icon(Icons.tune)),
          ])),
          Expanded(child: page == 'Assets' ? _assetsPage() : page == 'Tests' ? _testsPage() : page == 'Settings' ? _settingsPage() : _studioPage(wide)),
          if (!wide) _bottomNav(),
        ])),
      ])),
      floatingActionButton: !wide && page == 'Studio' ? FloatingActionButton(onPressed: _newProject, backgroundColor: blue, child: const Icon(Icons.add)) : null,
    );
  });

  Widget _sidebar() => Container(
    width: 220, color: panel, padding: const EdgeInsets.all(13),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.auto_awesome, color: blue), SizedBox(width: 8), Text('Nova Studio AI', style: TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 20),
      _nav(Icons.add, 'New project', _newProject),
      _nav(Icons.code, 'Studio', () => setState(() => page = 'Studio')),
      _nav(Icons.view_in_ar, 'Assets', () => setState(() => page = 'Assets')),
      _nav(Icons.fact_check_outlined, 'Tests', _checks),
      _nav(Icons.folder_open, 'Import ZIP', _import),
      _nav(Icons.archive_outlined, 'Export ZIP', _export),
      const SizedBox(height: 14),
      const Text('YOUR PROJECTS', style: TextStyle(color: muted, fontSize: 10)),
      const SizedBox(height: 6),
      Expanded(child: ListView(children: projects.map((p) => _nav(Icons.folder_outlined, p.name, () => setState(() { engine = p.engine; selectedFile = p.files.keys.first; page = 'Studio'; }))).toList())),
      _nav(Icons.settings_outlined, 'Settings', _settings),
    ]),
  );

  Widget _nav(IconData icon, String label, VoidCallback onTap) => ListTile(
    dense: true, visualDensity: VisualDensity.compact, leading: Icon(icon, color: muted, size: 18),
    title: Text(label, style: const TextStyle(fontSize: 12)), onTap: onTap,
  );

  Widget _bottomNav() => Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
    IconButton(onPressed: () => setState(() => page = 'Studio'), icon: Icon(Icons.code, color: page == 'Studio' ? blue : muted)),
    IconButton(onPressed: () => setState(() => page = 'Assets'), icon: Icon(Icons.view_in_ar, color: page == 'Assets' ? blue : muted)),
    IconButton(onPressed: _checks, icon: Icon(Icons.fact_check_outlined, color: page == 'Tests' ? blue : muted)),
    IconButton(onPressed: _settings, icon: const Icon(Icons.settings_outlined, color: muted)),
  ]);

  Widget _studioPage(bool wide) {
    final p = project;
    if (p == null) return const Center(child: Text('Create a project to begin.'));
    if (!wide) return Column(children: [_projectHeader(p), Expanded(child: _chatPanel())]);
    return Row(children: [
      SizedBox(width: 250, child: _fileList(p)),
      const VerticalDivider(width: 1, color: line),
      Expanded(flex: 5, child: _chatPanel()),
      const VerticalDivider(width: 1, color: line),
      Expanded(flex: 4, child: _preview(p)),
    ]);
  }

  Widget _projectHeader(GameProject p) => ListTile(
    leading: const Icon(Icons.videogame_asset_outlined, color: blue),
    title: Text(p.name), subtitle: Text(p.engine, style: const TextStyle(color: muted)),
    trailing: Wrap(children: [
      IconButton(onPressed: _undo, tooltip: 'Undo', icon: const Icon(Icons.undo)),
      IconButton(onPressed: _export, tooltip: 'Export ZIP', icon: const Icon(Icons.archive_outlined)),
    ]),
  );

  Widget _fileList(GameProject p) => Column(children: [
    _projectHeader(p),
    const Padding(padding: EdgeInsets.all(8), child: Text('PROJECT FILES', style: TextStyle(color: muted, fontSize: 10))),
    Expanded(child: ListView(children: p.files.keys.map((path) => ListTile(
      dense: true, selected: path == selectedFile,
      leading: const Icon(Icons.description_outlined, color: blue, size: 17),
      title: Text(path, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => setState(() => selectedFile = path),
    )).toList())),
  ]);

  Widget _chatPanel() => Column(children: [
    Expanded(child: ListView.builder(
      padding: const EdgeInsets.all(14), itemCount: messages.length + (busy ? 1 : 0),
      itemBuilder: (c, i) {
        if (busy && i == messages.length) return const Padding(padding: EdgeInsets.all(14), child: Text('Waiting for local model…', style: TextStyle(color: muted)));
        final m = messages[i];
        final isUser = m.role == 'user';
        return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(
          constraints: const BoxConstraints(maxWidth: 700), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: isUser ? const Color(0xFF20304A) : panel, border: Border.all(color: line), borderRadius: BorderRadius.circular(15)),
          child: SelectableText(m.text, style: const TextStyle(fontSize: 13, height: 1.45)),
        ));
      },
    )),
    Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        ActionChip(label: const Text('Create game loop'), onPressed: () => prompt.text = 'Create a basic game loop'),
        const SizedBox(width: 5),
        ActionChip(label: const Text('Fix bugs'), onPressed: () => prompt.text = 'Review the project and fix likely bugs'),
        const SizedBox(width: 5),
        ActionChip(label: const Text('Multiplayer'), onPressed: () => prompt.text = 'Plan and implement multiplayer support'),
      ])),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(controller: prompt, minLines: 1, maxLines: 4, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Describe a game or change…', filled: true, fillColor: panel))),
        const SizedBox(width: 7),
        IconButton.filled(onPressed: busy ? null : _send, icon: const Icon(Icons.arrow_upward), style: IconButton.styleFrom(backgroundColor: blue)),
      ]),
      const SizedBox(height: 5),
      const Text('Preview shows project files, not a running game.', style: TextStyle(color: muted, fontSize: 10)),
    ])),
  ]);

  Widget _preview(GameProject p) {
    final content = p.files[selectedFile] ?? p.files.values.first;
    return Container(color: const Color(0xFF0E1118), padding: const EdgeInsets.all(16), child: ListView(children: [
      const Row(children: [Icon(Icons.visibility_outlined, color: muted), SizedBox(width: 8), Text('Preview', style: TextStyle(fontWeight: FontWeight.w700))]),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: panel, border: Border.all(color: line), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.auto_awesome, color: blue, size: 28), const SizedBox(height: 12),
        Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5), Text(p.engine, style: const TextStyle(color: muted)),
        const SizedBox(height: 10), Text(p.files.length.toString() + ' project files', style: const TextStyle(color: muted, fontSize: 12)),
      ])),
      const SizedBox(height: 18), const Text('SELECTED FILE', style: TextStyle(color: muted, fontSize: 10)),
      const SizedBox(height: 6), Text(selectedFile, style: const TextStyle(color: blue, fontSize: 12)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)), child: SelectableText(content, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5))),
      const SizedBox(height: 10),
      const Text('Open the project in its engine to run the actual game.', style: TextStyle(color: muted, fontSize: 11)),
    ]));
  }

  Widget _assetsPage() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Asset workshop', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    const Text('Plan characters, fictional game items, environments, materials, vehicles, creatures, rigs and animations. Full mesh and texture generation needs dedicated model integrations.', style: TextStyle(color: muted, height: 1.5)),
    const SizedBox(height: 12),
    ...['Characters', 'Fictional game items', 'Buildings and environments', 'Textures and materials', 'Vehicles', 'Creatures', 'Animations and rigs'].map((name) => Card(color: panel, child: ListTile(
      leading: const Icon(Icons.view_in_ar, color: blue), title: Text(name), trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () { setState(() => page = 'Studio'); prompt.text = 'Plan ' + name.toLowerCase() + ' for my ' + engine + ' game and suggest required project files.'; },
    ))),
  ]);

  Widget _testsPage() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Checks and testing', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    const Text('Basic workspace checks are available. Engine compilation, multiplayer integration tests and automated gameplay tests require engine-specific runners.', style: TextStyle(color: muted, height: 1.5)),
    const SizedBox(height: 14),
    Card(color: panel, child: ListTile(leading: const Icon(Icons.fact_check_outlined, color: blue), title: const Text('Check current workspace'), subtitle: const Text('Find empty files and TODO markers'), onTap: _checks)),
  ]);

  Widget _settingsPage() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
    const SizedBox(height: 12),
    Card(color: panel, child: ListTile(leading: const Icon(Icons.memory, color: blue), title: const Text('Local AI provider'), subtitle: Text('Model: $model\nEndpoint: $endpoint'), onTap: _settings)),
    const Card(color: panel, child: ListTile(leading: Icon(Icons.security_outlined, color: blue), title: Text('Privacy'), subtitle: Text('Prompts go to the endpoint you configure. No hosted AI is used by default.'))),
    const Card(color: panel, child: ListTile(leading: Icon(Icons.integration_instructions_outlined, color: blue), title: Text('Engine integrations'), subtitle: Text('Starter adapters for Roblox, Unreal Engine and Unity. Native engine automation is planned.'))),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: _settings, icon: const Icon(Icons.tune), label: const Text('Configure local model')),
    OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.folder_open), label: const Text('Import ZIP')),
    OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.archive_outlined), label: const Text('Export ZIP')),
  ]);
}
