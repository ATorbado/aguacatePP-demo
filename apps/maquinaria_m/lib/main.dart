import 'package:flutter/material.dart';

import 'pages/vehicles_page.dart';
import 'remote_security.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final securityResult = await RemoteSecurity.check();

  runApp(MaquinariaMApp(securityResult: securityResult));
}

class MaquinariaMApp extends StatelessWidget {
  final RemoteSecurityResult securityResult;

  const MaquinariaMApp({
    super.key,
    required this.securityResult,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaquinariaM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF3EEE4),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7700),
          primary: const Color(0xFFFF7700),
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: securityResult.isAllowed
          ? const VehiclesPage()
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
    const negroMedianoche = Color(0xFF222222);
    const grisPerlado = Color(0xFFF3EEE4);

    return Scaffold(
      backgroundColor: grisPerlado,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Card(
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
                        color: negroMedianoche,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: negroMedianoche,
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
