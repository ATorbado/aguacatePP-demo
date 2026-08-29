import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workmanager/workmanager.dart';

import 'pages/home_page.dart';
import 'remote_security.dart';
import 'services/auth_service.dart';
import 'services/backup_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/weekly_backup_worker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('es_ES');

  final securityResult = await RemoteSecurity.check();

  if (securityResult.isAllowed) {
    await DatabaseService.instance.init();
    await NotificationService.instance.init();
    await NotificationService.instance.scheduleDailyReminders();

    await BackupService.instance.createBackupIfDue();

    await Workmanager().initialize(weeklyBackupCallbackDispatcher);

    await WeeklyBackupWorker.scheduleWeeklyBackup();
  }

  runApp(MiDiarioApp(securityResult: securityResult));
}

class MiDiarioApp extends StatelessWidget {
  final RemoteSecurityResult securityResult;

  const MiDiarioApp({
    super.key,
    required this.securityResult,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Diario',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7700),
          brightness: Brightness.dark,
          primary: const Color(0xFFFF7700),
          secondary: const Color(0xFF1976D2),
          tertiary: const Color(0xFF2E7D32),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        useMaterial3: true,
      ),
      home: securityResult.isAllowed
          ? const LockGate()
          : BlockedPage(message: securityResult.message),
    );
  }
}

class BlockedPage extends StatelessWidget {
  final String message;

  const BlockedPage({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    const naranjaPrincipal = Color(0xFFFF7700);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Card(
              color: const Color(0xFF1E1E1E),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 72,
                      color: naranjaPrincipal,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Aplicación bloqueada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LockGate extends StatefulWidget {
  const LockGate({super.key});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  bool _checking = false;
  bool _unlocked = false;
  String? _error;

  Future<void> _unlock() async {
    if (_checking) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    final ok = await AuthService.instance.unlockIfEnabled();

    if (!mounted) return;

    setState(() {
      _checking = false;
      _unlocked = ok;
      _error = ok ? null : 'No se pudo desbloquear la aplicación.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return const HomePage();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock,
                  size: 80,
                  color: Color(0xFFFF7700),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mi Diario',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Diario protegido',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_checking)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text(
                        'DESBLOQUEAR',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7700),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
