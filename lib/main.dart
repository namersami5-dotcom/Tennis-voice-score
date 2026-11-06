import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const lime = Color(0xFFB8F34A), bg = Color(0xFF101610), panel = Color(0xFF202A20);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DB.instance.init();
  runApp(const TennisApp());
}

class DB {
  DB._(); static final instance = DB._(); late Database db;
  Future<void> init() async {
    db = await openDatabase(path.join(await getDatabasesPath(), 'tennis_voice.db'),
      version: 1, onCreate: (d, v) async {
        await d.execute('CREATE TABLE players(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL COLLATE NOCASE UNIQUE)');
        await d.execute('CREATE TABLE matches(id INTEGER PRIMARY KEY AUTOINCREMENT,p1 INTEGER,p2 INTEGER,s1 INTEGER,s2 INTEGER,winner INTEGER,playedAt TEXT,venue TEXT)');
        await d.execute('CREATE TABLE active(id INTEGER PRIMARY KEY CHECK(id=1),p1 INTEGER,p2 INTEGER,s1 INTEGER,s2 INTEGER,venue TEXT,paused INTEGER)');
      });
  }
  Future<List<Map<String,Object?>>> players() => db.query('players', orderBy:'name COLLATE NOCASE');
  Future<List<Map<String,Object?>>> matches() => db.query('matches',orderBy:'playedAt DESC');
  Future<void> addPlayer(String n) async { if(n.trim().isNotEmpty) await db.insert('players',{'name':n.trim()},conflictAlgorithm:ConflictAlgorithm.ignore); }
  Future<void> active(int a,int b,int x,int y,String venue,bool paused) async {
    await db.insert('active',{'id':1,'p1':a,'p2':b,'s1':x,'s2':y,'venue':venue,'paused':paused?1:0},conflictAlgorithm:ConflictAlgorithm.replace);
  }
  Future<Map<String,Object?>?> getActive() async { final r=await db.query('active',where:'id=1'); return r.isEmpty?null:r.first; }
  Future<void> clearActive() async { await db.delete('active'); }
  Future<void> finish(int a,int b,int x,int y,String venue) async {
    await db.insert('matches',{'p1':a,'p2':b,'s1':x,'s2':y,'winner':x>y?a:b,'playedAt':DateTime.now().toIso8601String(),'venue':venue});
    await clearActive();
  }
}

class TennisApp extends StatelessWidget {
  const TennisApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'Tennis Voice Score',
    theme:ThemeData(brightness:Brightness.dark,scaffoldBackgroundColor:bg,
      colorScheme:ColorScheme.fromSeed(seedColor:lime,brightness:Brightness.dark),useMaterial3:true,
      cardTheme:CardThemeData(color:panel,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)))),
    home:const MainPage());
}

class MainPage extends StatefulWidget { const MainPage({super.key}); @override State<MainPage> createState()=>_MainPageState(); }
class _MainPageState extends State<MainPage>{
  int index=0;
  @override Widget build(BuildContext context){
    final pages=[Home(onNew:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>const NewMatch()));setState((){});}),const Players(),const Ranking(),const History(),const HeadToHead()];
    return Scaffold(appBar:AppBar(title:Text(['Tennis Voice Score','Players','Leaderboard','Match History','Head to Head'][index],style:const TextStyle(fontWeight:FontWeight.bold))),
      body:pages[index],bottomNavigationBar:NavigationBar(backgroundColor:panel,selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),
        destinations:const [NavigationDestination(icon:Icon(Icons.sports_tennis),label:'Home'),NavigationDestination(icon:Icon(Icons.people),label:'Players'),NavigationDestination(icon:Icon(Icons.emoji_events),label:'Ranking'),NavigationDestination(icon:Icon(Icons.history),label:'History'),NavigationDestination(icon:Icon(Icons.compare_arrows),label:'H2H')]));
  }
}

class Home extends StatelessWidget {
  final VoidCallback onNew; const Home({super.key,required this.onNew});
  @override Widget build(BuildContext context)=>FutureBuilder(future:Future.wait([DB.instance.players(),DB.instance.matches()]),builder:(c,s){
    final ps=s.data?[0]??[], ms=s.data?[1]??[];
    final winMap=<int,int>{}; for(final m in ms){final id=m['winner'] as int;winMap[id]=(winMap[id]??0)+1;}
    final sorted=winMap.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    final names={for(final p in ps)p['id'] as int:p['name'] as String};
    return ListView(padding:const EdgeInsets.all(18),children:[
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xFF354A27),Color(0xFF172219)])),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('YOUR COURT. YOUR RULES.',style:TextStyle(color:lime,letterSpacing:2,fontWeight:FontWeight.bold,fontSize:11)),
          const SizedBox(height:12),const Text('Let your voice\nkeep the score.',style:TextStyle(fontSize:32,fontWeight:FontWeight.w900,height:1.1)),
          const SizedBox(height:10),const Text('First to 10 points wins. No deuce. No distractions.',style:TextStyle(color:Colors.white70)),
          const SizedBox(height:20),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:onNew,icon:const Icon(Icons.mic),label:const Text('START NEW MATCH'),style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,padding:const EdgeInsets.all(16))))
        ])),
      const SizedBox(height:16),Row(children:[_stat('PLAYERS','${ps.length}'),const SizedBox(width:10),_stat('MATCHES','${ms.length}')]),
      const SizedBox(height:22),const Text('TOP OF THE CLUB',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:1)),
      if(sorted.isEmpty)const Empty('Play your first match to start the leaderboard.')
      else ...sorted.take(3).toList().asMap().entries.map((e)=>Card(child:ListTile(leading:CircleAvatar(backgroundColor:e.key==0?lime:Colors.white12,child:Text('${e.key+1}',style:TextStyle(color:e.key==0?Colors.black:Colors.white))),title:Text(names[e.value.key]??'Player'),trailing:Text('${e.value.value} W',style:const TextStyle(color:lime,fontWeight:FontWeight.bold))))),
      const SizedBox(height:20),const Text('VOICE COMMANDS',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:1)),
      const Card(child:ListTile(leading:Icon(Icons.graphic_eq,color:lime),title:Text('"Point for 1"'),subtitle:Text('Award a point to Player 1'))),
      const Card(child:ListTile(leading:Icon(Icons.graphic_eq,color:lime),title:Text('"Point for 2"'),subtitle:Text('Award a point to Player 2'))),
      const Card(child:ListTile(leading:Icon(Icons.undo,color:lime),title:Text('"Undo"  •  "Pause"  •  "Resume"'))),
    ]);
  });
}
Widget _stat(String label,String val)=>Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[Text(val,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),Text(label,style:const TextStyle(color:Colors.white60,fontSize:11))]))));
class Empty extends StatelessWidget{final String text;const Empty(this.text,{super.key});@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Text(text,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white60))));}

class Players extends StatefulWidget{const Players({super.key});@override State<Players> createState()=>_PlayersState();}
class _PlayersState extends State<Players>{
  Future<void> add()async{final c=TextEditingController();final n=await showDialog<String>(context:context,builder:(x)=>AlertDialog(title:const Text('Add player'),content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(hintText:'Player name')),actions:[TextButton(onPressed:()=>Navigator.pop(x),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,c.text),child:const Text('Save'))]));if(n!=null){await DB.instance.addPlayer(n);setState((){});}}
  @override Widget build(BuildContext context)=>Scaffold(floatingActionButton:FloatingActionButton.extended(onPressed:add,backgroundColor:lime,foregroundColor:Colors.black,icon:const Icon(Icons.add),label:const Text('Add player')),
    body:FutureBuilder(future:DB.instance.players(),builder:(c,s){final ps=s.data??[];if(ps.isEmpty)return const Empty('Add your first players to start.');return ListView(padding:const EdgeInsets.all(14),children:ps.map((p)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text('${p['name']}'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PlayerStats(id:p['id'] as int,name:p['name'] as String))))).toList());}));
}

class PlayerStats extends StatelessWidget{
  final int id;final String name;const PlayerStats({super.key,required this.id,required this.name});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(name)),body:FutureBuilder(future:Future.wait([DB.instance.matches(),DB.instance.players()]),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());final ms=s.data![0].where((m)=>m['p1']==id||m['p2']==id).toList();final w=ms.where((m)=>m['winner']==id).length;final pf=ms.fold<int>(0,(v,m)=>v+(m['p1']==id?m['s1'] as int:m['s2'] as int));final pa=ms.fold<int>(0,(v,m)=>v+(m['p1']==id?m['s2'] as int:m['s1'] as int));
    return ListView(padding:const EdgeInsets.all(16),children:[Text('Matches: ${ms.length}   Wins: $w   Losses: ${ms.length-w}'),Text('Win rate: ${ms.isEmpty?0:(w/ms.length*100).toStringAsFixed(1)}%'),Text('Points for: $pf   Against: $pa   Difference: ${pf-pa}'),const SizedBox(height:18),const Text('RECENT MATCHES',style:TextStyle(fontWeight:FontWeight.bold)),...ms.map((m)=>Card(child:ListTile(title:Text('${m['s1']} - ${m['s2']}'),subtitle:Text(m['playedAt'].toString().substring(0,16)))))]);
  }));
}

class Ranking extends StatelessWidget{const Ranking({super.key});@override Widget build(BuildContext context)=>FutureBuilder(future:Future.wait([DB.instance.players(),DB.instance.matches()]),builder:(c,s){
  if(!s.hasData)return const Center(child:CircularProgressIndicator());final ps=s.data![0],ms=s.data![1];final rows=<Map<String,dynamic>>[];
  for(final p0 in ps){final id=p0['id'] as int;final mine=ms.where((m)=>m['p1']==id||m['p2']==id).toList();final w=mine.where((m)=>m['winner']==id).length;final pf=mine.fold<int>(0,(v,m)=>v+(m['p1']==id?m['s1'] as int:m['s2'] as int));final pa=mine.fold<int>(0,(v,m)=>v+(m['p1']==id?m['s2'] as int:m['s1'] as int));rows.add({'name':p0['name'],'w':w,'l':mine.length-w,'rate':mine.isEmpty?0.0:w/mine.length,'diff':pf-pa});}
  rows.sort((a,b){final x=(b['w'] as int).compareTo(a['w'] as int);if(x!=0)return x;final y=(b['rate'] as double).compareTo(a['rate'] as double);return y!=0?y:(b['diff'] as int).compareTo(a['diff'] as int);});
  if(rows.isEmpty)return const Empty('Leaderboard will appear after your first match.');
  return ListView(padding:const EdgeInsets.all(14),children:rows.asMap().entries.map((e)=>Card(child:ListTile(leading:CircleAvatar(backgroundColor:e.key==0?lime:Colors.white12,child:Text('${e.key+1}',style:TextStyle(color:e.key==0?Colors.black:Colors.white))),title:Text('${e.value['name']}'),subtitle:Text('${e.value['w']} wins • ${e.value['l']} losses • ${((e.value['rate'] as double)*100).toStringAsFixed(0)}%'),trailing:Text('${e.value['diff']>=0?'+':''}${e.value['diff']} pts',style:const TextStyle(color:lime))))).toList());
});}

class History extends StatelessWidget{const History({super.key});@override Widget build(BuildContext context)=>FutureBuilder(future:Future.wait([DB.instance.matches(),DB.instance.players()]),builder:(c,s){
  if(!s.hasData)return const Center(child:CircularProgressIndicator());final ms=s.data![0],ps=s.data![1];final names={for(final p in ps)p['id'] as int:p['name'] as String};if(ms.isEmpty)return const Empty('Completed matches will appear here.');
  return ListView(padding:const EdgeInsets.all(14),children:ms.map<Widget>((m)=>Card(child:ListTile(title:Text('${names[m['p1']]??'Player'} vs ${names[m['p2']]??'Player'}'),subtitle:Text('${m['playedAt'].toString().substring(0,16)} • ${names[m['winner']]??'Winner'} won'),trailing:Text('${m['s1']} - ${m['s2']}',style:const TextStyle(color:lime,fontWeight:FontWeight.bold)))).toList());
});}


class HeadToHead extends StatefulWidget {
  const HeadToHead({super.key});
  @override State<HeadToHead> createState()=>_HeadToHeadState();
}
class _HeadToHeadState extends State<HeadToHead> {
  int? first, second;
  @override Widget build(BuildContext context)=>FutureBuilder(
    future:Future.wait([DB.instance.players(),DB.instance.matches()]),
    builder:(context,snapshot){
      if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
      final players=snapshot.data![0], all=snapshot.data![1];
      if(players.length<2)return const Empty('Add at least two players to compare their head-to-head record.');
      first ??= players[0]['id'] as int;
      second ??= (players.firstWhere((p)=>p['id']!=first))['id'] as int;
      final a=first!, b=second!;
      final nameA=players.firstWhere((p)=>p['id']==a)['name'] as String;
      final nameB=players.firstWhere((p)=>p['id']==b)['name'] as String;
      final games=all.where((m)=>(m['p1']==a&&m['p2']==b)||(m['p1']==b&&m['p2']==a)).toList();
      final winsA=games.where((m)=>m['winner']==a).length;
      final winsB=games.length-winsA;
      return ListView(padding:const EdgeInsets.all(16),children:[
        const Text('CHOOSE PLAYERS',style:TextStyle(color:lime,fontWeight:FontWeight.bold,letterSpacing:1)),
        const SizedBox(height:10),
        DropdownButtonFormField<int>(value:a,decoration:const InputDecoration(labelText:'Player 1',border:OutlineInputBorder()),
          items:players.map((p)=>DropdownMenuItem(value:p['id'] as int,child:Text('${p['name']}'))).toList(),
          onChanged:(v)=>setState(()=>first=v)),
        const SizedBox(height:10),
        DropdownButtonFormField<int>(value:b,decoration:const InputDecoration(labelText:'Player 2',border:OutlineInputBorder()),
          items:players.where((p)=>p['id']!=a).map((p)=>DropdownMenuItem(value:p['id'] as int,child:Text('${p['name']}'))).toList(),
          onChanged:(v)=>setState(()=>second=v)),
        const SizedBox(height:18),
        Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
          Text('$nameA  vs  $nameB',style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
          const SizedBox(height:16),
          Row(children:[
            Expanded(child:Column(children:[Text('$winsA',style:const TextStyle(fontSize:42,color:lime,fontWeight:FontWeight.w900)),Text(nameA,textAlign:TextAlign.center)])),
            const Text('WINS',style:TextStyle(color:Colors.white54,letterSpacing:2)),
            Expanded(child:Column(children:[Text('$winsB',style:const TextStyle(fontSize:42,fontWeight:FontWeight.w900)),Text(nameB,textAlign:TextAlign.center)])),
          ]),
          const Divider(height:28),
          Text('TOTAL MATCHES: ${games.length}',style:const TextStyle(color:Colors.white70)),
          if(games.isNotEmpty)Text('Win rate: ${nameA} ${(winsA/games.length*100).toStringAsFixed(1)}%  •  ${nameB} ${(winsB/games.length*100).toStringAsFixed(1)}%',textAlign:TextAlign.center),
        ]))),
        const SizedBox(height:12),const Text('MATCHUP HISTORY',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:1)),
        if(games.isEmpty)const Empty('No matches between these players yet.')
        else ...games.map((m)=>Card(child:ListTile(
          title:Text('${m['s1']}  –  ${m['s2']}'),
          subtitle:Text('${m['playedAt'].toString().substring(0,16)}${(m['venue'] as String).isNotEmpty?' • ${m['venue']}':''}'),
          trailing:Text(m['winner']==a?nameA:nameB,style:const TextStyle(color:lime,fontWeight:FontWeight.bold)),
        )))
      ]);
    });
}

class NewMatch extends StatefulWidget{const NewMatch({super.key});@override State<NewMatch> createState()=>_NewMatchState();}
class _NewMatchState extends State<NewMatch>{int? a,b;String venue='';@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('New match')),body:FutureBuilder(future:DB.instance.players(),builder:(c,s){
  final ps=s.data??[];return ListView(padding:const EdgeInsets.all(18),children:[
    const Text('SELECT PLAYERS',style:TextStyle(color:lime,fontWeight:FontWeight.bold)),
    const SizedBox(height:12),DropdownButtonFormField<int>(value:a,decoration:const InputDecoration(labelText:'Player 1',border:OutlineInputBorder()),items:ps.map((p)=>DropdownMenuItem(value:p['id'] as int,child:Text('${p['name']}'))).toList(),onChanged:(v)=>setState(()=>a=v)),
    const SizedBox(height:12),DropdownButtonFormField<int>(value:b,decoration:const InputDecoration(labelText:'Player 2',border:OutlineInputBorder()),items:ps.where((p)=>p['id']!=a).map((p)=>DropdownMenuItem(value:p['id'] as int,child:Text('${p['name']}'))).toList(),onChanged:(v)=>setState(()=>b=v)),
    const SizedBox(height:12),TextField(decoration:const InputDecoration(labelText:'Court / venue (optional)',border:OutlineInputBorder()),onChanged:(v)=>venue=v),
    const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('First to 10 points wins. No deuce. No two-point margin.'))),
    if(ps.length<2)const Empty('Add at least two players first.'),
    FilledButton(onPressed:a!=null&&b!=null?()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>LiveMatch(p1:a!,p2:b!,venue:venue)));if(context.mounted)Navigator.pop(context);}:null,style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black),child:const Text('START MATCH')),
  ]); } );}

class LiveMatch extends StatefulWidget{final int p1,p2;final String venue;const LiveMatch({super.key,required this.p1,required this.p2,required this.venue});@override State<LiveMatch> createState()=>_LiveMatchState();}
class _LiveMatchState extends State<LiveMatch> with WidgetsBindingObserver{
  final recognizer=stt.SpeechToText();final tts=FlutterTts();Timer? restart;int x=0,y=0;String n1='Player 1',n2='Player 2',message='Ready';bool listening=false,paused=false,done=false,available=false;String voiceLanguage='English';String speechLocale='en_US';final List<int> pointHistory=[];DateTime last=DateTime.fromMillisecondsSinceEpoch(0);
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();}
  Future<void> load()async{final ps=await DB.instance.players();for(final p in ps){if(p['id']==widget.p1)n1=p['name'] as String;if(p['id']==widget.p2)n2=p['name'] as String;}final old=await DB.instance.getActive();if(old!=null&&old['p1']==widget.p1&&old['p2']==widget.p2){x=old['s1'] as int;y=old['s2'] as int;paused=old['paused']==1;}available=await recognizer.initialize(onStatus:(s){if(s=='notListening'&&listening&&!paused&&!done){restart?.cancel();restart=Timer(const Duration(milliseconds:500),listen);}},onError:(e){if(mounted)setState(()=>message='Mic: ${e.errorMsg}');});
    if(available){
      try{
        final locales=await recognizer.locales();
        final arabic=locales.where((l)=>l.localeId.toLowerCase().startsWith('ar')).toList();
        if(arabic.isNotEmpty)speechLocale=arabic.first.localeId;
      }catch(_){}
    }
    if(mounted)setState(()=>message=available?'Ready to listen':'Speech recognition unavailable');await persist();}
  Future<void> listen()async{if(!available||paused||done||!listening)return;try{await recognizer.listen(localeId:speechLocale,listenFor:const Duration(minutes:1),pauseFor:const Duration(seconds:3),onResult:(r){if(r.finalResult)parse(r.recognizedWords);});}catch(_){}}
  void parse(String raw){
    var t=raw.toLowerCase().trim()
      .replaceAll('١','1').replaceAll('٢','2').replaceAll('۱','1').replaceAll('۲','2')
      .replaceAll(RegExp(r'[،,!.؟?]'),' ')
      .replaceAll(RegExp(r'\s+'),' ');
    if(DateTime.now().difference(last).inMilliseconds<1800)return;
    if(RegExp(r'\b(undo|revert|cancel last)\b').hasMatch(t)||t.contains('تراجع')||t.contains('الغاء اخر نقطة')){
      last=DateTime.now();undo();return;
    }
    if(RegExp(r'\b(pause|stop listening)\b').hasMatch(t)||t.contains('إيقاف')||t.contains('وقف الاستماع')){
      last=DateTime.now();pauseVoice();return;
    }
    if(RegExp(r'\b(resume|start listening)\b').hasMatch(t)||t.contains('استئناف')||t.contains('ابدأ الاستماع')){
      last=DateTime.now();resumeVoice();return;
    }
    final one=RegExp(r'\b(point for 1|point one|player one|point 1)\b').hasMatch(t)||
      t.contains('نقطة للاعب الأول')||t.contains('نقطة للاعب الاول')||t.contains('نقطة للاعب واحد')||t.contains('نقطة واحد');
    final two=RegExp(r'\b(point for 2|point two|player two|point 2)\b').hasMatch(t)||
      t.contains('نقطة للاعب الثاني')||t.contains('نقطة للاعب اثنين')||t.contains('نقطة اثنين');
    if(one==two)return;
    last=DateTime.now();award(one?1:2);
  }
  Future<void> persist()=>DB.instance.active(widget.p1,widget.p2,x,y,widget.venue,paused);
  Future<void> award(int who)async{if(done||paused)return;pointHistory.add(who);setState((){if(who==1){x++;}else{y++;}});HapticFeedback.selectionClick();await persist();if(x>=10||y>=10){await finish();}else{tts.speak(who==1?'Point $n1':'Point $n2');}}
  Future<void> undo()async{if(done||pointHistory.isEmpty)return;final who=pointHistory.removeLast();setState((){if(who==1&&x>0)x--;if(who==2&&y>0)y--;});await persist();}
  Future<void> finish()async{if(done)return;done=true;listening=false;await recognizer.stop();await DB.instance.finish(widget.p1,widget.p2,x,y,widget.venue);final winner=x>y?n1:n2;await tts.speak('Game! $winner wins!');if(mounted)setState(()=>message='$winner wins!');}
  Future<void> pauseVoice()async{paused=true;listening=false;await recognizer.stop();await persist();if(mounted)setState(()=>message='Paused');}
  Future<void> resumeVoice()async{if(done)return;paused=false;listening=true;await persist();setState(()=>message='Listening…');listen();}
  @override void didChangeAppLifecycleState(AppLifecycleState s){if(s==AppLifecycleState.paused&&listening)pauseVoice();}
  @override void dispose(){restart?.cancel();recognizer.stop();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  Widget score(String name,int value,int num,bool lead)=>Expanded(child:Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:lead?const Color(0xFF2C3B24):panel,borderRadius:BorderRadius.circular(22),border:Border.all(color:lead?lime:Colors.white10,width:lead?2:1)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text('PLAYER $num',style:const TextStyle(color:Colors.white54,letterSpacing:2)),Text(name,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),Text('$value',style:TextStyle(fontSize:100,fontWeight:FontWeight.w900,color:lead?lime:Colors.white)),if(lead)const Text('LEADING',style:TextStyle(color:lime,letterSpacing:2))])));
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('LIVE MATCH')),body:SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
    Card(child:Column(children:[
      ListTile(leading:Icon(listening?Icons.mic:Icons.mic_off,color:listening?lime:Colors.orange),title:Text(message),subtitle:Text(voiceLanguage=='English'?'Say “Point for 1” or “Point for 2”':'قل “نقطة للاعب الأول” أو “نقطة للاعب الثاني”')),
      Padding(padding:const EdgeInsets.fromLTRB(14,0,14,12),child:Row(children:[
        const Text('Voice language',style:TextStyle(color:Colors.white60)),
        const Spacer(),
        SegmentedButton<String>(segments:const [ButtonSegment(value:'English',label:Text('EN')),ButtonSegment(value:'Arabic',label:Text('AR'))],selected:{voiceLanguage},onSelectionChanged:(v)async{
          setState(()=>voiceLanguage=v.first);
          if(available){final locales=await recognizer.locales();final found=locales.where((l)=>v.first=='Arabic'?l.localeId.toLowerCase().startsWith('ar'):l.localeId.toLowerCase().startsWith('en')).toList();if(found.isNotEmpty)speechLocale=found.first.localeId;}
          if(listening){await recognizer.stop();listen();}
        })
      ]))
    ])),
    const Spacer(),score(n1,x,1,x>y),const Padding(padding:EdgeInsets.all(8),child:Text('VS',style:TextStyle(color:Colors.white38,letterSpacing:4))),score(n2,y,2,y>x),const Spacer(),
    if(done)Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:lime,borderRadius:BorderRadius.circular(14)),child:Text('${x>y?n1:n2} WINS!',textAlign:TextAlign.center,style:const TextStyle(color:Colors.black,fontSize:22,fontWeight:FontWeight.w900))),
    if(!done)Row(children:[Expanded(child:FilledButton.icon(onPressed:()=>listening?pauseVoice():resumeVoice(),icon:Icon(listening?Icons.pause:Icons.mic),label:Text(listening?'PAUSE':'START LISTENING'),style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,padding:const EdgeInsets.all(16)))),const SizedBox(width:8),OutlinedButton(onPressed:undo,child:const Icon(Icons.undo))]),
    if(done)FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('DONE')),
    if(!done)TextButton(onPressed:()async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('End match?'),content:const Text('Save current score as a completed match?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save'))]));if(ok==true){if(x==y){await DB.instance.clearActive();if(context.mounted)Navigator.pop(context);}else{await finish();setState((){});}}},child:const Text('END MATCH')),
    const Text('First to 10 points wins • No deuce',style:TextStyle(color:Colors.white38,fontSize:12)),const SizedBox(height:8)
  ]))));
}
