import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_command_interpreter.dart';

const _blue = Color(0xFF4F8CFF);
const _panel = Color(0xFF131720);
const _line = Color(0xFF2B3443);
const _muted = Color(0xFF9AA6B8);

class _V3 {
  const _V3(this.x, this.y, this.z);
  final double x, y, z;
}
class _Face {
  const _Face(this.indices);
  final List<int> indices;
}
class _Mesh {
  final List<_V3> vertices = [];
  final List<_Face> faces = [];

  void box(double cx, double cy, double cz, double sx, double sy, double sz) {
    final b = vertices.length;
    final x0=cx-sx/2, x1=cx+sx/2, y0=cy-sy/2, y1=cy+sy/2, z0=cz-sz/2, z1=cz+sz/2;
    vertices.addAll([_V3(x0,y0,z0),_V3(x1,y0,z0),_V3(x1,y1,z0),_V3(x0,y1,z0),_V3(x0,y0,z1),_V3(x1,y0,z1),_V3(x1,y1,z1),_V3(x0,y1,z1)]);
    for (final f in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]) {
      faces.add(_Face(f.map((i)=>b+i).toList()));
    }
  }

  void sphere(double radius, int segments) {
    final rings = math.max(5, segments ~/ 2).toInt(), b = vertices.length;
    for (var r=0;r<=rings;r++) {
      final lat=-math.pi/2+math.pi*r/rings;
      for (var s=0;s<segments;s++) {
        final lon=2*math.pi*s/segments;
        vertices.add(_V3(radius*math.cos(lat)*math.cos(lon),radius*math.sin(lat),radius*math.cos(lat)*math.sin(lon)));
      }
    }
    for (var r=0;r<rings;r++) for (var s=0;s<segments;s++) {
      final a=b+r*segments+s, n=b+r*segments+(s+1)%segments, c=b+(r+1)*segments+(s+1)%segments, d=b+(r+1)*segments+s;
      faces.add(_Face([a,n,c,d]));
    }
  }

  void cone(double radius,double height,int segments,{double cy=0}) {
    final b=vertices.length, bottom=cy-height/2, top=cy+height/2;
    vertices.add(_V3(0,top,0));
    for(var i=0;i<segments;i++){final a=2*math.pi*i/segments;vertices.add(_V3(radius*math.cos(a),bottom,radius*math.sin(a)));}
    vertices.add(_V3(0,bottom,0)); final center=vertices.length-1;
    for(var i=0;i<segments;i++){final n=(i+1)%segments;faces.add(_Face([b,b+1+i,b+1+n]));faces.add(_Face([center,b+1+n,b+1+i]));}
  }

  void cylinder(double radius,double height,int segments) {
    final b=vertices.length;
    for(final y in [-height/2,height/2]) for(var i=0;i<segments;i++){final a=2*math.pi*i/segments;vertices.add(_V3(radius*math.cos(a),y,radius*math.sin(a)));}
    for(var i=0;i<segments;i++){final n=(i+1)%segments;faces.add(_Face([b+i,b+n,b+segments+n,b+segments+i]));}
    faces.add(_Face(List.generate(segments,(i)=>b+i).reversed.toList()));
    faces.add(_Face(List.generate(segments,(i)=>b+segments+i)));
  }

  void wheel(double size, int detail, int features) {
    final outerRadius = size * .48;
    final innerRadius = outerRadius * .48;
    final depth = size * .22;
    final b = vertices.length;
    // Outer and inner rings on each side form a tyre with a visible central hub.
    for (final z in [-depth / 2, depth / 2]) {
      for (final radius in [outerRadius, innerRadius]) {
        for (var i = 0; i < detail; i++) {
          final a = 2 * math.pi * i / detail;
          vertices.add(_V3(radius * math.cos(a), radius * math.sin(a), z));
        }
      }
    }
    for (var i = 0; i < detail; i++) {
      final n = (i + 1) % detail;
      faces.add(_Face([b + i, b + n, b + detail + n, b + detail + i]));
      faces.add(_Face([b + detail + i, b + detail + n, b + 3 * detail + n, b + 3 * detail + i]));
      faces.add(_Face([b + i, b + 2 * detail + i, b + 2 * detail + n, b + n]));
      faces.add(_Face([b + detail + i, b + detail + n, b + 3 * detail + n, b + 3 * detail + i]));
    }
    // A simple hub is deliberately generated as geometry, not a texture.
    cylinder(innerRadius * .48, depth * 1.15, math.max(8, detail ~/ 2).toInt());
    if (features > 0) {
      final spokeCount = math.min(8, math.max(3, detail ~/ 3)).toInt();
      for (var i = 0; i < spokeCount; i++) {
        final a = 2 * math.pi * i / spokeCount;
        box(math.cos(a) * innerRadius * .24, math.sin(a) * innerRadius * .24, 0,
            innerRadius * .75, innerRadius * .09, depth * 1.22);
      }
    }
  }

  void house(double scale) {
    box(0,-.12*scale,0,1.6*scale,1.2*scale,1.3*scale); final b=vertices.length;
    vertices.addAll([_V3(-.95*scale,.48*scale,-.78*scale),_V3(.95*scale,.48*scale,-.78*scale),_V3(0,1.25*scale,-.78*scale),_V3(-.95*scale,.48*scale,.78*scale),_V3(.95*scale,.48*scale,.78*scale),_V3(0,1.25*scale,.78*scale)]);
    for(final f in [[0,1,2],[3,5,4],[0,3,4,1],[0,2,5,3],[1,4,5,2]]) faces.add(_Face(f.map((i)=>b+i).toList()));
  }

  void build(String type,double size,int detail) {
    if(type=='Cube') box(0,0,0,size,size,size);
    else if(type=='Sphere') sphere(size/2,detail);
    else if(type=='Tree'){box(0,-size*.1,0,size*.13,size*.7,size*.13);cone(size*.34,size*.68,detail,cy:size*.28);cone(size*.27,size*.58,detail,cy:size*.57);}
    else if(type=='House'){house(size/2);}
    else if(type=='Sword'){box(0,size*.28,0,size*.12,size*.62,size*.08);box(0,-size*.08,0,size*.42,size*.07,size*.13);box(0,-size*.31,0,size*.11,size*.36,size*.11);box(0,-size*.51,0,size*.19,size*.07,size*.17);}
    else if(type=='Barrel'){cylinder(size*.32,size*.8,detail);}\n    else if(type=='Wheel'){wheel(size,detail,1);}
    else box(0,0,0,size,size,size);
  }

  String toObj(String name) {
    final safe=name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'),'_');
    final out=StringBuffer('# Generated by Nova Studio AI 3D Generator\n');
    out.writeln('o $safe');
    for(final v in vertices) out.writeln('v \${v.x.toStringAsFixed(5)} \${v.y.toStringAsFixed(5)} \${v.z.toStringAsFixed(5)}');
    for(final f in faces) out.writeln('f \${f.indices.map((i)=>i+1).join(' ')}');
    return out.toString();
  }
}

class ThreeDGeneratorPage extends StatefulWidget {
  const ThreeDGeneratorPage({super.key,required this.onAddToProject});
  final void Function(String name,String obj) onAddToProject;
  @override
  State<ThreeDGeneratorPage> createState()=>_ThreeDGeneratorPageState();
}
class _ThreeDGeneratorPageState extends State<ThreeDGeneratorPage> {
  final _name=TextEditingController(text:'My 3D Asset');
  String _type='Cube';
  double _size=2, _detail=12;
  _Mesh _mesh=_Mesh();
  final _request = TextEditingController();
  final _geminiKey = TextEditingController();
  String _command = '';
  String _interpretation = '';
  bool _interpreting = false;

  @override void initState(){super.initState();_loadGeminiKey();_generate();}
  @override void dispose(){_name.dispose();_request.dispose();_geminiKey.dispose();super.dispose();}

  Future<void> _loadGeminiKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _geminiKey.text = prefs.getString('nova_gemini_api_key') ?? '';
  }

  Future<void> _interpretPrompt() async {
    if (_request.text.trim().isEmpty || _interpreting) return;
    setState(() => _interpreting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _geminiKey.text.trim().isNotEmpty
          ? _geminiKey.text.trim()
          : (prefs.getString('nova_gemini_api_key') ?? '');
      if (key.isEmpty) throw Exception('Enter your Gemini API key below first.');
      await prefs.setString('nova_gemini_api_key', key);
      final result = await GeminiCommandInterpreter.interpret(apiKey: key, prompt: _request.text.trim());
      final code = result['command'].toString();
      final decoded = NovaMeshCommand.decode(code);
      const objects = {1:'Cube',2:'Sphere',3:'Tree',4:'House',5:'Sword',6:'Barrel',7:'Wheel'};
      if (!mounted) return;
      setState(() {
        _command = code;
        _type = objects[decoded.objectId] ?? 'Cube';
        _size = decoded.size / 10;
        _detail = decoded.detail.toDouble();
        _name.text = result['name'].toString();
        _interpretation = result['description'].toString();
      });
      _generate();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gemini interpretation failed: $e')));
    } finally {
      if (mounted) setState(() => _interpreting = false);
    }
  }
  void _generate(){final m=_Mesh();m.build(_type,_size,_detail.round().clamp(8,24).toInt());setState(()=>_mesh=m);}

  Future<void> _export() async {
    _generate();
    final safe=_name.text.trim().isEmpty?'GeneratedAsset':_name.text.trim();
    final bytes=Uint8List.fromList(utf8.encode(_mesh.toObj(safe)));
    try {
      final path=await FilePicker.platform.saveFile(dialogTitle:'Export 3D model as OBJ',fileName:'\${safe.replaceAll(RegExp(r"[^a-zA-Z0-9_-]"),"_")}.obj',type:FileType.custom,allowedExtensions:['obj'],bytes:bytes);
      if(path!=null&&mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('OBJ model exported.')));
    } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Export failed: $e')));}
  }

  @override Widget build(BuildContext context) {
    final safe=_name.text.trim().isEmpty?'GeneratedAsset':_name.text.trim();
    return ListView(padding:const EdgeInsets.all(18),children:[
      const Text('3D Generator',style:TextStyle(fontSize:26,fontWeight:FontWeight.w800)),
      const SizedBox(height:6),
      const Text('Describe a model in words. Gemini maps it to a stable numeric command; Nova decodes the command and builds the mesh locally.',style:TextStyle(color:_muted,height:1.5)),
      const SizedBox(height:16),
      TextField(controller:_request, minLines:1, maxLines:3, decoration:const InputDecoration(labelText:'Describe a 3D model', hintText:'e.g. make a car wheel')),
      const SizedBox(height:8),
      TextField(controller:_geminiKey, obscureText:true, decoration:const InputDecoration(labelText:'Gemini API key', hintText:'Stored in app preferences on this device')),
      const SizedBox(height:8),
      FilledButton.icon(onPressed:_interpreting?null:_interpretPrompt, icon:_interpreting?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.translate), label:Text(_interpreting?'Interpreting…':'Interpret prompt with Gemini')),
      if(_command.isNotEmpty) ...[
        const SizedBox(height:8),
        Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(12),border:Border.all(color:_line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('NOVA NUMERIC COMMAND',style:TextStyle(color:_muted,fontSize:10)),
          SelectableText(_command,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:_blue)),
          Text('Decoded locally · ${_interpretation}',style:const TextStyle(color:_muted,fontSize:12)),
        ])),
      ],
      const SizedBox(height:16),
      Container(height:270,decoration:BoxDecoration(color:const Color(0xFF0E1118),borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:ClipRRect(borderRadius:BorderRadius.circular(18),child:CustomPaint(painter:_MeshPainter(_mesh),child:const SizedBox.expand()))),
      const SizedBox(height:8),
      Text('\${_mesh.vertices.length} vertices · \${_mesh.faces.length} faces',textAlign:TextAlign.center,style:const TextStyle(color:_muted,fontSize:12)),
      const SizedBox(height:16),
      TextField(controller:_name,decoration:const InputDecoration(labelText:'Asset name',hintText:'e.g. Crystal Sword')),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(value:_type,decoration:const InputDecoration(labelText:'Starting shape'),items:const ['Cube','Sphere','Tree','House','Sword','Barrel','Wheel'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v){if(v!=null)setState(()=>_type=v);}),
      const SizedBox(height:14),
      Row(children:[const Expanded(child:Text('Overall size')),Text(_size.toStringAsFixed(1),style:const TextStyle(color:_blue))]),
      Slider(value:_size,min:.5,max:5,divisions:18,onChanged:(v)=>setState(()=>_size=v)),
      Row(children:[const Expanded(child:Text('Mesh detail')),Text(_detail.round().toString(),style:const TextStyle(color:_blue))]),
      Slider(value:_detail,min:8,max:24,divisions:8,onChanged:(v)=>setState(()=>_detail=v)),
      const SizedBox(height:8),
      FilledButton.icon(onPressed:_generate,icon:const Icon(Icons.auto_awesome),label:const Text('Generate 3D model')),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:(){_generate();widget.onAddToProject(safe,_mesh.toObj(safe));},icon:const Icon(Icons.add_to_photos_outlined),label:const Text('Add OBJ to current project')),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:_export,icon:const Icon(Icons.file_download_outlined),label:const Text('Export .OBJ file')),
      const SizedBox(height:14),
      const Text('Gemini interprets language only. The numeric command uses fixed fields for version, object, style, size, detail and features; Nova builds the mesh locally. The Gemini key is stored in app preferences and is not encrypted by this prototype. Import OBJ into Blender to convert to FBX or GLB.',style:TextStyle(color:_muted,fontSize:12,height:1.5)),
    ]);
  }
}

class _MeshPainter extends CustomPainter {
  const _MeshPainter(this.mesh);
  final _Mesh mesh;
  @override void paint(Canvas canvas,Size size) {
    final cx=size.width/2, cy=size.height/2+12, scale=math.min(size.width,size.height)*.24;
    Offset project(_V3 v)=>Offset(cx+(v.x-v.z)*scale*.72,cy+(v.x+v.z)*scale*.36-v.y*scale*.9);
    final fill=Paint()..style=PaintingStyle.fill;
    final edge=Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=const Color(0xFF9DBDFF).withOpacity(.8);
    final ordered=<MapEntry<double,_Face>>[];
    for(final f in _mesh.faces){final depth=f.indices.map((i){final v=_mesh.vertices[i];return v.x+v.y*.3+v.z;}).reduce((a,b)=>a+b)/f.indices.length;ordered.add(MapEntry(depth,f));}
    ordered.sort((a,b)=>a.key.compareTo(b.key));
    for(var i=0;i<ordered.length;i++){final f=ordered[i].value;final path=Path();for(var j=0;j<f.indices.length;j++){final p=project(_mesh.vertices[f.indices[j]]);if(j==0){path.moveTo(p.dx,p.dy);}else{path.lineTo(p.dx,p.dy);}}path.close();fill.color=Color.lerp(const Color(0xFF244D8F),const Color(0xFF80B5FF),(i%5)/5)!;canvas.drawPath(path,fill);canvas.drawPath(path,edge);}
  }
  @override bool shouldRepaint(covariant _MeshPainter oldDelegate)=>oldDelegate.mesh!=mesh;
}
