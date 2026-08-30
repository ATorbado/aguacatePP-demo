import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'meter.dart';
import 'revisar.dart';
import 'enviar_pdf.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');
  Intl.defaultLocale = 'es_ES';
  final gate = await _PolicyGate.evaluate();
  await _NotificationService.instance.init();
  runApp(App3Nieve(gate: gate));
}

class App3Nieve extends StatelessWidget {
  final GateStatus gate;
  const App3Nieve({super.key, required this.gate});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app3nieve',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primaryColor: const Color(0xFFFF7700),
        scaffoldBackgroundColor: const Color(0xFFF3EEE4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF222222),
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7700),
            foregroundColor: Colors.white,
            minimumSize: const Size(64, 48),
          ),
        ),
      ),
      home: switch (gate) {
        GateStatus.allowed => const HomeMenuPage(),
        GateStatus.blockedByRemote =>
        const _GateBlockPage(msg: 'La aplicacion ha sido deshabilitada por el administrador.'),
        GateStatus.blockedByVersion =>
        const _GateBlockPage(msg: 'Actualiza la aplicacion para continuar.'),
        GateStatus.blockedByOffline =>
        const _GateBlockPage(msg: 'Conectate a internet para reactivar la aplicacion.'),
        GateStatus.unknown =>
        const _GateBlockPage(msg: 'No se pudo validar la politica remota.'),
      },
    );
  }
}

// ---------------------------- Menu principal ----------------------------
class HomeMenuPage extends StatelessWidget {
  const HomeMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nieve - Menu')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SizedBox.expand(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_note, size: 60),
                  label: const Text(
                    'Meter',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeterEntryPage())),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SizedBox.expand(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 60),
                  label: const Text(
                    'Revisar',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RevisarHome(repo: LocalPartesRepo()))),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SizedBox.expand(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send, size: 60),
                  label: const Text(
                    'Enviar + PDFs',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnviarPdfPage())),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------- Control remoto discreto ----------------------------
const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
const policyUrl = String.fromEnvironment('POLICY_URL');

enum GateStatus { allowed, blockedByRemote, blockedByVersion, blockedByOffline, unknown }

class _PolicyGate {
  static const int _ttlDaysDefault = 15;
  static const String _kPolicyJson = 'policy_json';
  static const String _kPolicyLastOk = 'policy_last_ok';

  static Future<GateStatus> evaluate() async {
    if (demoMode) return GateStatus.allowed;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 1) Intento remoto (no lanza)
    Map<String, dynamic>? policy = await _fetchPolicy();

    // 2) Si remoto OK => cache + last_ok
    if (policy != null) {
      await prefs.setString(_kPolicyJson, jsonEncode(policy));
      await prefs.setString(_kPolicyLastOk, now.toIso8601String());
    } else {
      // 3) Remoto falla => cache
      final cached = prefs.getString(_kPolicyJson);
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is Map<String, dynamic>) policy = decoded;
        } catch (_) {}
      }
    }

    // 4) Si no hay policy ni remoto ni cache => primera vez sin cobertura => bloquear
    if (policy == null) return GateStatus.blockedByOffline;

    // 5) TTL: si pasaron >= 15 días desde el último OK => exigir check remoto
    final ttl = (policy['ttlDays'] is int) ? (policy['ttlDays'] as int) : _ttlDaysDefault;
    final lastStr = prefs.getString(_kPolicyLastOk);
    if (lastStr == null) return GateStatus.blockedByOffline;

    DateTime lastOk;
    try {
      lastOk = DateTime.parse(lastStr);
    } catch (_) {
      return GateStatus.blockedByOffline;
    }

    final expired = now.difference(lastOk).inDays >= ttl;

    // Si está expirado y hoy no pudimos validar remoto (policy vino de cache) => bloquear
    final policyFromCache = (await _fetchedRemotelyThisRun(prefs)) == false;
    if (expired && policyFromCache) return GateStatus.blockedByOffline;

    // 6) Bloqueo remoto por flag
    if (policy['enabled'] != true) return GateStatus.blockedByRemote;

    // 7) Bloqueo por versión mínima
    final info = await PackageInfo.fromPlatform();
    final minV = (policy['minVersion'] ?? '0.0.0') as String;
    if (_cmp(info.version, minV) < 0) return GateStatus.blockedByVersion;


    // 8) Comprobación validación
    //print("Policy OK guardada en: $now");
    //print("Última validación: $lastStr");
    //print("Diferencia días: ${now.difference(lastOk).inDays}");

    return GateStatus.allowed;
  }

  // Marca si este evaluate obtuvo policy remotamente en esta ejecución.
  // Implementación: se setea un flag temporal en prefs solo durante evaluate.
  static Future<bool?> _fetchedRemotelyThisRun(SharedPreferences prefs) async {
    // Si existe, lo leemos y lo borramos para que no persista.
    if (!prefs.containsKey('_policy_remote_ok_once')) return null;
    final v = prefs.getBool('_policy_remote_ok_once');
    await prefs.remove('_policy_remote_ok_once');
    return v;
  }

  static Future<Map<String, dynamic>?> _fetchPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final cb = DateTime.now().millisecondsSinceEpoch;
      final rJson = await http
          .get(Uri.parse('$policyUrl?cb=$cb'))
          .timeout(const Duration(seconds: 6));

      if (rJson.statusCode != 200) return null;

      final body = utf8.decode(rJson.bodyBytes);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;

      // flag: remoto OK en esta ejecución
      await prefs.setBool('_policy_remote_ok_once', true);

      return decoded;
    } catch (_) {
      // flag: remoto NO en esta ejecución
      await prefs.setBool('_policy_remote_ok_once', false);
      return null;
    }
  }

  static int _cmp(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va > vb ? 1 : -1;
    }
    return 0;
  }
}

class _GateBlockPage extends StatelessWidget {
  final String msg;
  const _GateBlockPage({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 72),
              const SizedBox(height: 16),
              Text(msg, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final gate = await _PolicyGate.evaluate();
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => App3Nieve(gate: gate)),
                  );
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------- Notificaciones ----------------------------
class _NotificationService {
  _NotificationService._();
  static final _NotificationService instance = _NotificationService._();
  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    final madrid = tz.getLocation('Europe/Madrid');
    tz.setLocalLocation(madrid);

    const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: android);
    await _fln.initialize(settings);

    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
}
