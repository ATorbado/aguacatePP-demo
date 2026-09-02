// main.dart
import 'package:flutter/material.dart';
import 'package:animalesapp/silvestres_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animales App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFF7700),
        scaffoldBackgroundColor: const Color(0xFFF3EEE4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF222222),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7700),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const MainMenu(),
    );
  }
}

class BlockedPage extends StatelessWidget {
  final String message;

  const BlockedPage({super.key, required this.message});

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

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final TextEditingController _otrosController = TextEditingController();
  String? _nombreComun;

  final List<String> nombres = [
    'Operario de ejemplo 1',
    'Operario de ejemplo 2',
    'Añadir otro Operario',
  ];

  bool get _showOtros => _nombreComun == 'Añadir otro Operario';

  @override
  void dispose() {
    _otrosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menú principal')),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/walpaper.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _nombreComun,
                hint: const Text('Operario'),
                items:
                    nombres
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (val) {
                  setState(() {
                    _nombreComun = val;
                    if (val != 'Añadir otro Operario') {
                      _otrosController.clear();
                    }
                  });
                },
              ),
              if (_showOtros)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextFormField(
                    controller: _otrosController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de otro Operario',
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final nombre =
                      (_nombreComun == 'Añadir otro Operario'
                              ? _otrosController.text
                              : _nombreComun ?? '')
                          .trim();

                  if (nombre.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Debes introducir el nombre de un Operario',
                        ),
                      ),
                    );
                    return;
                  }

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SilvestresPage(operario: nombre),
                    ),
                  );
                },
                child: const Text('Animales Atropellados'),
              ),
              const Spacer(),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Proyecto de demostración',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
