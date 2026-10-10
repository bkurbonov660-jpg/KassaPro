import 'dart:async';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_keep_alive/voice_keep_alive.dart';

// ==== Firebase Options ====
const FirebaseOptions firebaseConfig = FirebaseOptions(
  apiKey: 'AIzaSyCDQV_iv0rErrhV2zcYIyg-_zpjwZ9oRf0',
  appId: '1:257778582335:android:4eb4b0244a346c8b84c98a',
  messagingSenderId: '257778582335',
  projectId: 'master-a0086',
  storageBucket: 'master-a0086.firebasestorage.app',
);

const MethodChannel platform = MethodChannel('com.master/remote');
final FlutterLocalNotificationsPlugin notifPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  try {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifPlugin.initialize(const InitializationSettings(android: android));
    const channel = AndroidNotificationChannel(
      'master_cmds', 'Команды и безопасность',
      description: 'Уведомления команд и системы защиты',
      importance: Importance.high,
    );
    await notifPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  } catch (e) { debugPrint('notif init: $e'); }
}

Future<void> showNotif(String title, String body) async {
  try {
    const details = NotificationDetails(android: AndroidNotificationDetails(
      'master_cmds', 'Команды и безопасность',
      importance: Importance.high, priority: Priority.high,
    ));
    await notifPlugin.show(0, title, body, details);
  } catch (_) {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  ErrorWidget.builder = (d) => Scaffold(
    backgroundColor: const Color(0xFF121212),
    body: Center(child: Text('Ошибка: ${d.exceptionAsString()}',
      style: const TextStyle(color: Colors.redAccent))),
  );
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Master & Client',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: const ColorScheme.dark(surface: Color(0xFF1E1E1E), primary: Color(0xFF3B82F6)),
    ),
    home: const Splash(),
  );
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  String _msg = 'Инициализация...';
  double _p = 0.2;

  @override void initState() { super.initState(); _boot(); }

  Future<void> _boot() async {
    try {
      setState(() { _msg = 'Firebase...'; _p = 0.5; });
      try { await Firebase.initializeApp(options: firebaseConfig); }
      catch (_) { if (Firebase.apps.isEmpty) await Firebase.initializeApp(); }

      setState(() { _msg = 'Уведомления...'; _p = 0.8; });
      await initNotifications();

      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('app_role');
      if (!mounted) return;
      Widget next = const RoleGate();
      if (role == 'master') next = const MasterScreen();
      else if (role == 'client') next = const ClientScreen();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
    } catch (e) {
      if (mounted) Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const RoleGate()));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.shield_outlined, size: 72, color: Color(0xFF3B82F6)),
        const SizedBox(height: 24),
        const Text('Master & Client',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 48),
        LinearProgressIndicator(value: _p,
          backgroundColor: const Color(0xFF2A2A2A),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6))),
        const SizedBox(height: 16),
        Text(_msg, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    )),
  );
}

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  Future<void> _sel(BuildContext c, String r) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('app_role', r);
    if (!c.mounted) return;
    Navigator.pushReplacement(c, MaterialPageRoute(
      builder: (_) => r == 'master' ? const MasterScreen() : const ClientScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Выбор режима')),
    body: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _card(Icons.admin_panel_settings, 'РОДИТЕЛЬ (Пульт)',
          'Управление, мониторинг', const Color(0xFF3B82F6),
          () => _sel(context, 'master')),
        const SizedBox(height: 20),
        _card(Icons.family_restroom, 'РЕБЁНОК (Маяк)',
          'Прозрачный контроль с согласиями', const Color(0xFF10B981),
          () => _sel(context, 'client')),
      ]),
    )),
  );

  Widget _card(IconData i, String t, String s, Color c, VoidCallback onTap) => Card(
    color: const Color(0xFF1E1E1E),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        CircleAvatar(radius: 28, backgroundColor: c.withOpacity(0.15),
          child: Icon(i, color: c, size: 30)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(s, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ])),
        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ])),
    ),
  );
}

// ===================== MASTER SCREEN (родитель) =====================
class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});
  @override State<MasterScreen> createState() => _MasterState();
}

class _MasterState extends State<MasterScreen> {
  final _db = FirebaseFirestore.instance;
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  final RTCVideoRenderer _audioRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _remoteAudioStream;
  String? _sessionId;
  int _battery = 0;
  String _status = 'Нет сессии';
  String _connState = 'idle';
  String _currentApp = '—';
  bool _streaming = false;
  bool _micListening = false;
  bool _pcReady = false;
  Offset? _swipeStart;
  Size _videoSize = const Size(1, 1);
  StreamSubscription? _sessionSub;
  StreamSubscription? _iceSub;
  Timer? _appTimer;
  LatLng? _childLocation;
  DateTime? _lastGeoUpdate;
  int _tabIndex = 0; // 0=Видео, 1=Микрофон, 2=Карта, 3=Чат, 4=Управление

  Map<String, dynamic> _permissions = {
    'screen': true, 'camera': true, 'gestures': true,
    'battery': true, 'location': true, 'microphone': true,
  };
  bool _revokedByChild = false;

  @override void initState() {
    super.initState();
    _renderer.initialize();
    _audioRenderer.initialize();
  }

  @override void dispose() {
    _sessionSub?.cancel(); _iceSub?.cancel(); _appTimer?.cancel();
    _pc?.close(); _renderer.dispose(); _audioRenderer.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('app_role');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleGate()));
  }

  Future<void> _createSession() async {
    final id = (Random().nextInt(900000) + 100000).toString();
    await _db.collection('sessions').doc(id).set({
      'createdAt': FieldValue.serverTimestamp(),
      'active': true, 'battery': 0, 'online': false, 'revoked': false,
      'currentApp': '—',
      'latitude': null, 'longitude': null, 'locationTime': null,
      'permissions': _permissions,
      'offer': null, 'answer': null, 'command': null, 'messages': [],
    });
    setState(() { _sessionId = id; _status = 'Ожидание ребёнка...'; });
    _listenSession();
  }

  void _listenSession() {
    _sessionSub?.cancel();
    _sessionSub = _db.collection('sessions').doc(_sessionId).snapshots().listen((snap) async {
      final d = snap.data();
      if (d == null || !mounted) return;

      setState(() {
        _battery = (d['battery'] ?? 0) as int;
        _revokedByChild = d['revoked'] == true;
        _currentApp = (d['currentApp'] ?? '—').toString();
        if (d['latitude'] != null && d['longitude'] != null) {
          _childLocation = LatLng(
            (d['latitude'] as num).toDouble(),
            (d['longitude'] as num).toDouble(),
          );
          final ts = d['locationTime'];
          if (ts is Timestamp) _lastGeoUpdate = ts.toDate();
        }
        if (d['permissions'] != null) {
          _permissions = Map<String, dynamic>.from(d['permissions']);
        }
        if (d['online'] == true && _status == 'Ожидание ребёнка...') {
          _status = 'Ребёнок подключён';
        }
      });

      if (_revokedByChild) {
        _pc?.close(); _pcReady = false;
        _streaming = false; _micListening = false;
        showNotif('Внимание', 'Ребёнок отозвал доступ');
      }

      final answer = d['answer'];
      if (answer != null && _pc != null && _pcReady && _pc!.getRemoteDescription() == null) {
        try {
          await _pc!.setRemoteDescription(
            RTCSessionDescription(answer['sdp'], answer['type']));
          if (mounted) setState(() => _connState = 'answer получен');
        } catch (e) { debugPrint('setRemote err: $e'); }
      }
    });
  }

  Future<void> _startWebRTC({bool includeAudio = false}) async {
    if (_sessionId == null || _revokedByChild) return;
    if (_permissions['camera'] != true && _permissions['screen'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ребёнок ограничил доступ к видео')));
      return;
    }

    // Полная очистка предыдущего соединения
    await _pc?.close();
    _pc = null; _pcReady = false;
    _streaming = false;
    if (includeAudio) _micListening = false;

    setState(() { _connState = 'создание offer...'; });

    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ],
      'sdpSemantics': 'unified-plan',
    });

    // Видео — recvonly (родитель только принимает)
    await _pc!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    // Аудио — recvonly, если слушаем микрофон
    if (includeAudio) {
      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
    }

    _pcReady = true;

    _pc!.onTrack = (RTCTrackEvent e) {
      debugPrint('onTrack: ${e.track.kind}');
      if (e.streams.isNotEmpty) {
        if (e.track.kind == 'video') {
          _renderer.srcObject = e.streams[0];
          if (mounted) setState(() { _streaming = true; _connState = 'стрим идёт'; });
        } else if (e.track.kind == 'audio') {
          _remoteAudioStream = e.streams[0];
          _audioRenderer.srcObject = _remoteAudioStream;
          if (mounted) setState(() => _micListening = true);
        }
      }
    };

    _pc!.onIceConnectionState = (state) async {
      debugPrint('ICE: $state');
      if (mounted) setState(() => _connState = 'ICE: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateClosed ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        if (mounted) {
          setState(() { _streaming = false; _connState = 'соединение потеряно, переподключение...'; });
        }
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && _sessionId != null && !_revokedByChild) {
          _startWebRTC(includeAudio: includeAudio);
        }
      }
    };

    _pc!.onIceCandidate = (RTCIceCandidate c) async {
      if (_pc == null || !_pcReady) return;
      await _db.collection('sessions').doc(_sessionId)
        .collection('master_ice').add({
          'candidate': c.candidate, 'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        });
    };

    _iceSub?.cancel();
    _iceSub = _db.collection('sessions').doc(_sessionId)
      .collection('client_ice').snapshots().listen((snap) {
        for (final doc in snap.docs) {
          final d = doc.data();
          if (_pc != null && _pcReady) {
            try {
              _pc?.addCandidate(RTCIceCandidate(
                d['candidate'], d['sdpMid'], d['sdpMLineIndex']));
            } catch (_) {}
          }
          doc.reference.delete();
        }
      });

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await _db.collection('sessions').doc(_sessionId).update({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'answer': null,
      'withAudio': includeAudio,
    });
    if (mounted) setState(() => _connState = includeAudio ? 'offer (mic) отправлен' : 'offer отправлен');
  }

  Future<void> _toggleMic() async {
    if (_micListening) {
      await _pc?.close(); _pc = null; _pcReady = false;
      _micListening = false; _streaming = false;
      setState(() {});
      await _startWebRTC(includeAudio: false);
    } else {
      await _startWebRTC(includeAudio: true);
    }
  }

  void _sendTap(Offset localPos) {
    if (_sessionId == null || _permissions['gestures'] != true || _revokedByChild) return;
    final nx = (localPos.dx / _videoSize.width).clamp(0.0, 1.0);
    final ny = (localPos.dy / _videoSize.height).clamp(0.0, 1.0);
    _db.collection('sessions').doc(_sessionId).update({
      'command': 'tap', 'nx': nx, 'ny': ny,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  void _sendSwipe(Offset start, Offset end) {
    if (_sessionId == null || _permissions['gestures'] != true || _revokedByChild) return;
    _db.collection('sessions').doc(_sessionId).update({
      'command': 'swipe',
      'snx': (start.dx / _videoSize.width).clamp(0.0, 1.0),
      'sny': (start.dy / _videoSize.height).clamp(0.0, 1.0),
      'enx': (end.dx / _videoSize.width).clamp(0.0, 1.0),
      'eny': (end.dy / _videoSize.height).clamp(0.0, 1.0),
      'ts': FieldValue.serverTimestamp(),
    });
  }

  void _sendGlobalAction(String action) {
    if (_sessionId == null) return;
    _db.collection('sessions').doc(_sessionId).update({
      'command': 'globalAction', 'action': action,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  void _switchCamera() {
    if (_sessionId == null) return;
    _db.collection('sessions').doc(_sessionId).update({
      'command': 'switchCamera',
      'ts': FieldValue.serverTimestamp(),
    });
  }

  void _openChat() {
    if (_sessionId == null) return;
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Чат с ребёнком', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot>(
            stream: _db.collection('sessions').doc(_sessionId).snapshots(),
            builder: (c, snap) {
              if (!snap.hasData) return const SizedBox();
              final list = (snap.data?.get('messages') as List<dynamic>? ?? []);
              return SizedBox(height: 220, child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final m = list[i];
                  final me = m['sender'] == 'parent';
                  return Align(
                    alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: me ? const Color(0xFF3B82F6) : const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12)),
                      child: Text(m['text'] ?? '', style: const TextStyle(fontSize: 13))),
                  );
                },
              ));
            },
          ),
          Row(children: [
            Expanded(child: TextField(controller: ctrl,
              decoration: const InputDecoration(hintText: 'Сообщение...', border: InputBorder.none))),
            IconButton(icon: const Icon(Icons.send, color: Color(0xFF3B82F6)),
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                _db.collection('sessions').doc(_sessionId).update({
                  'messages': FieldValue.arrayUnion([
                    {'sender': 'parent', 'text': ctrl.text.trim(),
                     'time': DateTime.now().toIso8601String()}
                  ])
                });
                ctrl.clear();
              }),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _openMap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChildMapScreen(
      sessionId: _sessionId!,
      db: _db,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['Видео', 'Микрофон', 'Карта', 'Чат', 'Управление'][_tabIndex]),
        actions: [
          if (_sessionId != null)
            IconButton(icon: const Icon(Icons.map), onPressed: _openMap, tooltip: 'Карта'),
          if (_sessionId != null)
            IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: _openChat),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildVideoTab(),
          _buildMicTab(),
          _buildMapTab(),
          _buildChatTab(),
          _buildControlTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1E1E1E),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'Видео'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Микрофон'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Карта'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Чат'),
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Управление'),
        ],
      ),
    );
  }

  // === Вкладка 0: Видео ===
  Widget _buildVideoTab() {
    return Column(children: [
      if (_revokedByChild)
        Container(width: double.infinity, color: Colors.red[900],
          padding: const EdgeInsets.all(12),
          child: const Text('⚠️ Ребёнок отозвал доступ',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      // Статус-бар
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFF1A1A1A),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.battery_charging_full, size: 20, color: Colors.green),
            const SizedBox(width: 6),
            Text('$_battery%', style: const TextStyle(fontSize: 14)),
          ]),
          Text(_status, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (_sessionId != null)
            Text('Код: $_sessionId',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
        ]),
      ),
      // Бейджи разрешений
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF222222),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _badge('Экран', _permissions['screen'] == true),
          _badge('Камера', _permissions['camera'] == true),
          _badge('Управление', _permissions['gestures'] == true),
          _badge('Батарея', _permissions['battery'] == true),
          _badge('Гео', _permissions['location'] == true),
          _badge('Микрофон', _permissions['microphone'] == true),
        ]),
      ),
      // Текущее приложение
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: const Color(0xFF262626),
        child: Row(children: [
          const Icon(Icons.apps, size: 16, color: Colors.amberAccent),
          const SizedBox(width: 8),
          Expanded(child: Text('Активно: $_currentApp',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12))),
          Text(_connState, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
      // Видео
      Expanded(
        child: _sessionId == null
          ? Center(child: ElevatedButton.icon(
              icon: const Icon(Icons.add_link),
              label: const Text('Создать код сопряжения'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(240, 56)),
              onPressed: _createSession))
          : LayoutBuilder(builder: (context, constraints) {
              _videoSize = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onTapUp: (d) => _sendTap(d.localPosition),
                onPanStart: (d) => _swipeStart = d.localPosition,
                onPanEnd: (d) {
                  if (_swipeStart != null) {
                    _sendSwipe(_swipeStart!, d.localPosition);
                    _swipeStart = null;
                  }
                },
                child: Container(color: Colors.black,
                  child: _streaming
                    ? RTCVideoView(_renderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)
                    : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.videocam_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(_connState == 'idle'
                          ? 'Нажмите «Старт видео»'
                          : 'Состояние: $_connState',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey)),
                      ]))),
              );
            }),
      ),
      // Кнопки управления видео
      if (_sessionId != null && !_revokedByChild)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text('Старт видео'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50)),
              onPressed: () => _startWebRTC(includeAudio: false))),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.flip_camera_android),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C2C),
                minimumSize: const Size(50, 50)),
              onPressed: _switchCamera,
              tooltip: 'Переключить камеру'),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.chat),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C),
                minimumSize: const Size(50, 50)),
              onPressed: _openChat),
          ]),
        ),
      // Невидимый аудио-рендерер
      if (_micListening)
        SizedBox(width: 0, height: 0, child: RTCVideoView(_audioRenderer)),
    ]);
  }

  // === Вкладка 1: Микрофон ===
  Widget _buildMicTab() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_micListening ? Icons.mic : Icons.mic_none,
        size: 80, color: _micListening ? Colors.red : Colors.grey),
      const SizedBox(height: 24),
      Text(_micListening ? 'Прослушивание активно' : 'Микрофон выключен',
        style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 8),
      Text(_micListening ? 'Звук идёт с микрофона ребёнка' : 'Нажмите кнопку ниже',
        style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        icon: Icon(_micListening ? Icons.stop : Icons.play_arrow),
        label: Text(_micListening ? 'Остановить' : 'Начать прослушивание'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(240, 60),
          backgroundColor: _micListening ? Colors.red[800] : const Color(0xFF3B82F6),
          foregroundColor: Colors.white),
        onPressed: _sessionId == null ? null : _toggleMic,
      ),
    ]));
  }

  // === Вкладка 2: Карта ===
  Widget _buildMapTab() {
    return ChildMapScreen(sessionId: _sessionId ?? '', db: _db);
  }

  // === Вкладка 3: Чат ===
  Widget _buildChatTab() {
    if (_sessionId == null) {
      return const Center(child: Text('Создайте сессию для чата',
        style: TextStyle(color: Colors.grey)));
    }
    final ctrl = TextEditingController();
    return Column(children: [
      Expanded(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('sessions').doc(_sessionId).snapshots(),
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final list = (snap.data?.get('messages') as List<dynamic>? ?? []);
            if (list.isEmpty) {
              return const Center(child: Text('Сообщений пока нет',
                style: TextStyle(color: Colors.grey)));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final m = list[i];
                final me = m['sender'] == 'parent';
                return Align(
                  alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: me ? const Color(0xFF3B82F6) : const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(16)),
                    child: Text(m['text'] ?? '', style: const TextStyle(fontSize: 14))),
                );
              },
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF1E1E1E),
        child: Row(children: [
          Expanded(child: TextField(controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'Написать сообщение...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF3B82F6)),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              _db.collection('sessions').doc(_sessionId).update({
                'messages': FieldValue.arrayUnion([
                  {'sender': 'parent', 'text': ctrl.text.trim(),
                   'time': DateTime.now().toIso8601String()}
                ])
              });
              ctrl.clear();
            }),
        ]),
      ),
    ]);
  }

  // === Вкладка 4: Управление ===
  Widget _buildControlTab() {
    if (_sessionId == null) {
      return const Center(child: Text('Создайте сессию',
        style: TextStyle(color: Colors.grey)));
    }
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _controlBtn(Icons.home, 'Home', () => _sendGlobalAction('home')),
        _controlBtn(Icons.arrow_back, 'Back', () => _sendGlobalAction('back')),
        _controlBtn(Icons.apps, 'Recents', () => _sendGlobalAction('recents')),
        _controlBtn(Icons.lock, 'Блокировка', () => _sendGlobalAction('lock')),
        _controlBtn(Icons.notifications, 'Уведомления', () => _sendGlobalAction('notifications')),
        _controlBtn(Icons.flip_camera_android, 'Камера', _switchCamera),
      ],
    );
  }

  Widget _controlBtn(IconData icon, String label, VoidCallback onTap) {
    return Card(
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 36, color: const Color(0xFF3B82F6)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _badge(String t, bool g) => Row(children: [
    Icon(g ? Icons.check_circle : Icons.cancel, size: 12, color: g ? Colors.green : Colors.red),
    const SizedBox(width: 2),
    Text(t, style: TextStyle(fontSize: 10, color: g ? Colors.white : Colors.grey)),
  ]);
}

// ===================== MAP SCREEN =====================
class ChildMapScreen extends StatefulWidget {
  final String sessionId;
  final FirebaseFirestore db;
  const ChildMapScreen({super.key, required this.sessionId, required this.db});

  @override State<ChildMapScreen> createState() => _ChildMapScreenState();
}

class _ChildMapScreenState extends State<ChildMapScreen> {
  final MapController _mapCtrl = MapController();
  LatLng? _loc;
  DateTime? _lastUpdate;
  StreamSubscription? _sub;

  @override void initState() {
    super.initState();
    if (widget.sessionId.isNotEmpty) {
      _sub = widget.db.collection('sessions').doc(widget.sessionId)
        .snapshots().listen((snap) {
          final d = snap.data();
          if (d == null) return;
          if (d['latitude'] != null && d['longitude'] != null) {
            setState(() {
              _loc = LatLng(
                (d['latitude'] as num).toDouble(),
                (d['longitude'] as num).toDouble(),
              );
              final ts = d['locationTime'];
              if (ts is Timestamp) _lastUpdate = ts.toDate();
            });
          }
        });
    }
  }

  @override void dispose() { _sub?.cancel(); super.dispose(); }

  void _center() {
    if (_loc != null) _mapCtrl.move(_loc!, 16);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessionId.isEmpty) {
      return const Center(child: Text('Создайте сессию',
        style: TextStyle(color: Colors.grey)));
    }
    return _loc == null
      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Ожидание координат от ребёнка...'),
        ]))
      : Stack(children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _loc!,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.master.master_and_client',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _loc!,
                  width: 50, height: 50,
                  child: const Icon(Icons.location_on, size: 50, color: Colors.red),
                ),
              ]),
            ],
          ),
          Positioned(
            top: 16, right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _center,
              backgroundColor: const Color(0xFF1E1E1E),
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xDD1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Широта: ${_loc!.latitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 13)),
                Text('Долгота: ${_loc!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 13)),
                if (_lastUpdate != null)
                  Text('Обновлено: ${DateFormat('HH:mm:ss').format(_lastUpdate!)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ),
          ),
        ]);
  }
}

// ===================== CLIENT SCREEN (ребёнок) =====================
class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});
  @override State<ClientScreen> createState() => _ClientState();
}

class _ClientState extends State<ClientScreen> {
  final _db = FirebaseFirestore.instance;
  final _codeCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();
  final _battery = Battery();
  String? _sessionId;
  bool _accessibilityOn = false;
  Timer? _telemetryTimer, _appTimer, _geoTimer;
  StreamSubscription? _cmdSub, _offerSub, _iceSub;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _audioStream;
  Size _screenSize = const Size(1080, 1920);
  String _currentCamera = 'environment';

  bool _agreeScreen = true;
  bool _agreeCamera = true;
  bool _agreeGestures = true;
  bool _agreeBattery = true;
  bool _agreeLocation = true;
  bool _agreeMicrophone = true;
  bool _revoked = false;

  @override void initState() {
    super.initState();
    _loadScreenSize();
  }

  Future<void> _loadScreenSize() async {
    try {
      final r = await platform.invokeMethod<Map>('screenSize');
      if (r != null) {
        _screenSize = Size((r['w'] as num).toDouble(), (r['h'] as num).toDouble());
      }
    } catch (_) {}
  }

  @override void dispose() {
    _telemetryTimer?.cancel(); _appTimer?.cancel(); _geoTimer?.cancel();
    _cmdSub?.cancel(); _offerSub?.cancel(); _iceSub?.cancel();
    _pc?.close(); _localStream?.dispose(); _audioStream?.dispose();
    _codeCtrl.dispose(); _chatCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('app_role');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleGate()));
  }

  Future<void> _updatePerms() async {
    if (_sessionId == null) return;
    await _db.collection('sessions').doc(_sessionId).update({
      'permissions': {
        'screen': _agreeScreen, 'camera': _agreeCamera,
        'gestures': _agreeGestures, 'battery': _agreeBattery,
        'location': _agreeLocation, 'microphone': _agreeMicrophone,
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Согласия обновлены')));
  }

  Future<void> _revoke() async {
    if (_sessionId == null) return;
    await _db.collection('sessions').doc(_sessionId).update({
      'revoked': true, 'online': false,
    });
    try {
      await platform.invokeMethod('stopForegroundService');
      await VoiceKeepAlive.stopService(); // ИСПРАВЛЕНО: статический метод
    } catch (_) {}
    _telemetryTimer?.cancel(); _appTimer?.cancel(); _geoTimer?.cancel();
    _pc?.close();
    setState(() => _revoked = true);
    showNotif('Контроль отключен', 'Вы отозвали доступ');
  }

  Future<void> _connect() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите 6-значный код')));
      return;
    }
    final doc = await _db.collection('sessions').doc(code).get();
    if (!doc.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия не найдена')));
      return;
    }

    await _db.collection('sessions').doc(code).update({
      'online': true, 'revoked': false,
      'permissions': {
        'screen': _agreeScreen, 'camera': _agreeCamera,
        'gestures': _agreeGestures, 'battery': _agreeBattery,
        'location': _agreeLocation, 'microphone': _agreeMicrophone,
      }
    });

    setState(() => _sessionId = code);
    try {
      await platform.invokeMethod('startForegroundService');
      await VoiceKeepAlive.startService( // ИСПРАВЛЕНО: статический метод
        title: 'Master & Client',
        content: 'Служба контроля активна', // ИСПРАВЛЕНО: content
      );
    } catch (e) { debugPrint('service err: $e'); }

    _startTelemetry();
    _startAppReporter();
    _startGeoReporter();
    _listenCommands();
    _listenOffer();
  }

  void _startTelemetry() async {
    _telemetryTimer?.cancel();
    await _sendBattery();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 15), (_) => _sendBattery());
  }

  Future<void> _sendBattery() async {
    if (_sessionId == null || !_agreeBattery || _revoked) return;
    try {
      final lvl = await _battery.batteryLevel;
      await _db.collection('sessions').doc(_sessionId).update({
        'battery': lvl, 'online': true,
      });
    } catch (e) { debugPrint('battery err: $e'); }
  }

  void _startAppReporter() {
    _appTimer?.cancel();
    _appTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_sessionId == null || _revoked) return;
      try {
        final app = await platform.invokeMethod<String>('getCurrentApp');
        if (app != null && app.isNotEmpty) {
          await _db.collection('sessions').doc(_sessionId).update({'currentApp': app});
        }
      } catch (_) {}
    });
  }

  void _startGeoReporter() async {
    _geoTimer?.cancel();
    await _sendLocation();
    _geoTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendLocation());
  }

  Future<void> _sendLocation() async {
    if (_sessionId == null || !_agreeLocation || _revoked) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      await _db.collection('sessions').doc(_sessionId).update({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'locationTime': FieldValue.serverTimestamp(),
      });
    } catch (e) { debugPrint('geo err: $e'); }
  }

  void _listenCommands() {
    _cmdSub?.cancel();
    _cmdSub = _db.collection('sessions').doc(_sessionId).snapshots().listen((snap) async {
      final d = snap.data();
      if (d == null || _revoked) return;
      final cmd = d['command'];

      if (cmd == 'tap' && _agreeGestures) {
        final nx = (d['nx'] as num?)?.toDouble() ?? -1;
        final ny = (d['ny'] as num?)?.toDouble() ?? -1;
        if (nx < 0 || ny < 0) return;
        final x = (nx * _screenSize.width).toDouble();
        final y = (ny * _screenSize.height).toDouble();
        try {
          await platform.invokeMethod('performTap', {'x': x, 'y': y});
        } catch (e) { debugPrint('tap err: $e'); }
      } else if (cmd == 'swipe' && _agreeGestures) {
        final snx = (d['snx'] as num?)?.toDouble() ?? -1;
        final sny = (d['sny'] as num?)?.toDouble() ?? -1;
        final enx = (d['enx'] as num?)?.toDouble() ?? -1;
        final eny = (d['eny'] as num?)?.toDouble() ?? -1;
        if (snx < 0 || enx < 0) return;
        try {
          await platform.invokeMethod('performSwipe', {
            'startX': snx * _screenSize.width,
            'startY': sny * _screenSize.height,
            'endX': enx * _screenSize.width,
            'endY': eny * _screenSize.height,
          });
        } catch (e) { debugPrint('swipe err: $e'); }
      } else if (cmd == 'switchCamera') {
        final track = _localStream?.getVideoTracks().firstOrNull;
        if (track != null) {
          try {
            await Helper.switchCamera(track);
            _currentCamera = _currentCamera == 'environment' ? 'user' : 'environment';
            showNotif('Камера', 'Переключено на $_currentCamera');
          } catch (e) { debugPrint('switchCamera err: $e'); }
        }
      } else if (cmd == 'globalAction') {
        final action = d['action'] as String? ?? 'home';
        try { await platform.invokeMethod('globalAction', {'action': action}); } catch (_) {}
      }
    });
  }

  void _listenOffer() {
    _offerSub?.cancel();
    _offerSub = _db.collection('sessions').doc(_sessionId).snapshots().listen((snap) async {
      final d = snap.data();
      if (d == null || _revoked) return;
      final offer = d['offer'];
      if (offer == null) return;
      if (_pc != null) return;
      final withAudio = d['withAudio'] == true;

      debugPrint('Получен offer (audio=$withAudio)');
      _pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {
            'urls': 'turn:openrelay.metered.ca:80',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
          {
            'urls': 'turn:openrelay.metered.ca:443',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
        ],
        'sdpSemantics': 'unified-plan',
      });

      _pc!.onIceCandidate = (c) async {
        await _db.collection('sessions').doc(_sessionId)
          .collection('client_ice').add({
            'candidate': c.candidate, 'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          });
      };

      // Видео — если разрешено
      if (_agreeCamera || _agreeScreen) {
        try {
          final media = await navigator.mediaDevices.getUserMedia({
            'audio': false,
            'video': {
              'facingMode': _currentCamera,
              'width': {'ideal': 640}, 'height': {'ideal': 480},
            }
          });
          _localStream = media;
          for (final track in media.getTracks()) {
            await _pc!.addTrack(track, media);
          }
        } catch (e) {
          debugPrint('getUserMedia err: $e');
        }
      }

      // Аудио — отдельный трек (если родитель слушает)
      if (withAudio && _agreeMicrophone) {
        try {
          final audio = await navigator.mediaDevices.getUserMedia({
            'audio': true, 'video': false,
          });
          _audioStream = audio;
          for (final track in audio.getTracks()) {
            await _pc!.addTrack(track, audio);
          }
        } catch (e) { debugPrint('mic err: $e'); }
      }

      await _pc!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']));
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      await _db.collection('sessions').doc(_sessionId).update({
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });

      _iceSub?.cancel();
      _iceSub = _db.collection('sessions').doc(_sessionId)
        .collection('master_ice').snapshots().listen((iceSnap) {
          for (final doc in iceSnap.docs) {
            final ice = doc.data();
            try {
              _pc?.addCandidate(RTCIceCandidate(
                ice['candidate'], ice['sdpMid'], ice['sdpMLineIndex']));
            } catch (_) {}
            doc.reference.delete();
          }
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Режим: Ребёнок'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (_revoked)
          Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.red[900], borderRadius: BorderRadius.circular(16)),
            child: const Column(children: [
              Icon(Icons.shield, size: 48, color: Colors.white),
              SizedBox(height: 8),
              Text('Контроль отключен', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ])),
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF383838))),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.verified_user, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Text('Правила прозрачного контроля',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            SizedBox(height: 8),
            Text('Контроль работает только с твоего согласия. Ты сам решаешь, что разрешить. Можешь отключить в любой момент.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
        const SizedBox(height: 20),
        const Text('Мои согласия:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        _sw('Трансляция экрана', 'Показывать экран', _agreeScreen,
          (v) { setState(() => _agreeScreen = v); _updatePerms(); }),
        _sw('Доступ к камере', 'Разрешить камеру', _agreeCamera,
          (v) { setState(() => _agreeCamera = v); _updatePerms(); }),
        _sw('Удалённые клики', 'Разрешить нажатия родителя', _agreeGestures,
          (v) { setState(() => _agreeGestures = v); _updatePerms(); }),
        _sw('Батарея', 'Передавать заряд', _agreeBattery,
          (v) { setState(() => _agreeBattery = v); _updatePerms(); }),
        _sw('Геолокация', 'Передавать координаты', _agreeLocation,
          (v) { setState(() => _agreeLocation = v); _updatePerms(); }),
        _sw('Микрофон', 'Разрешить прослушивание микрофона', _agreeMicrophone,
          (v) { setState(() => _agreeMicrophone = v); _updatePerms(); }),
        const SizedBox(height: 24),
        if (_sessionId == null) ...[
          TextField(controller: _codeCtrl, keyboardType: TextInputType.number,
            maxLength: 6, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 6),
            decoration: const InputDecoration(hintText: '000000', counterText: '',
              border: OutlineInputBorder())),
          const SizedBox(height: 16),
          ElevatedButton.icon(icon: const Icon(Icons.link),
            label: const Text('Подключить родителя'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: _connect),
        ] else ...[
          Text('Подключено: $_sessionId',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Чат с родителем',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              StreamBuilder<DocumentSnapshot>(
                stream: _db.collection('sessions').doc(_sessionId).snapshots(),
                builder: (c, snap) {
                  if (!snap.hasData) return const SizedBox();
                  final list = (snap.data?.get('messages') as List<dynamic>? ?? []);
                  return SizedBox(height: 140, child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      final me = m['sender'] == 'child';
                      return Align(
                        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: me ? const Color(0xFF10B981) : const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(8)),
                          child: Text(m['text'] ?? '', style: const TextStyle(fontSize: 12))),
                      );
                    },
                  ));
                },
              ),
              Row(children: [
                Expanded(child: TextField(controller: _chatCtrl,
                  decoration: const InputDecoration(hintText: 'Сообщение...', border: InputBorder.none))),
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF10B981)),
                  onPressed: () {
                    if (_chatCtrl.text.trim().isEmpty) return;
                    _db.collection('sessions').doc(_sessionId).update({
                      'messages': FieldValue.arrayUnion([
                        {'sender': 'child', 'text': _chatCtrl.text.trim(),
                         'time': DateTime.now().toIso8601String()}
                      ])
                    });
                    _chatCtrl.clear();
                  }),
              ]),
            ])),
          const SizedBox(height: 20),
          ElevatedButton.icon(icon: const Icon(Icons.gavel),
            label: const Text('🚨 Отозвать согласие'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800], foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50)),
            onPressed: _revoke),
        ],
        const SizedBox(height: 20),
        ElevatedButton.icon(icon: const Icon(Icons.security),
          label: const Text('Выдать системные доступы'),
          onPressed: () async {
            await [
              Permission.camera, Permission.microphone, Permission.notification,
              Permission.ignoreBatteryOptimizations,
              Permission.location, Permission.locationAlways,
            ].request();
            final on = await platform.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
            setState(() => _accessibilityOn = on);
          }),
        const SizedBox(height: 8),
        OutlinedButton.icon(icon: const Icon(Icons.accessibility_new),
          label: const Text('Спец. возможности Android'),
          onPressed: () => platform.invokeMethod('openAccessibilitySettings')),
      ]),
    );
  }

  Widget _sw(String t, String s, bool v, ValueChanged<bool> on) => Card(
    color: const Color(0xFF1E1E1E),
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: SwitchListTile(
      title: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(s, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      value: v, activeColor: const Color(0xFF10B981),
      onChanged: _revoked ? null : on,
    ),
  );
}
