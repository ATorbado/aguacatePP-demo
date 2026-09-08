import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'meter.dart';
import 'revisar.dart';
import 'enviar_pdf.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');
  Intl.defaultLocale = 'es_ES';
  await _NotificationService.instance.init();
  runApp(const App3Nieve());
}

class App3Nieve extends StatelessWidget {
  const App3Nieve({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app3nieve',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
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
      home: const HomeMenuPage(),
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
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MeterEntryPage()),
                  ),
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
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RevisarHome(repo: LocalPartesRepo()),
                    ),
                  ),
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
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EnviarPdfPage()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------- Notificaciones ----------------------------
class _NotificationService {
  _NotificationService._();
  static final _NotificationService instance = _NotificationService._();
  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    final madrid = tz.getLocation('Europe/Madrid');
    tz.setLocalLocation(madrid);

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
    );
    await _fln.initialize(settings);

    await _fln
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }
}
