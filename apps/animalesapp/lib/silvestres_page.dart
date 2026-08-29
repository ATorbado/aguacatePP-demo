import 'package:flutter/material.dart';

/// Formulario demostrativo sin contactos, ubicaciones ni infraestructura real.
class SilvestresPage extends StatefulWidget {
  final String operario;

  const SilvestresPage({super.key, required this.operario});

  @override
  State<SilvestresPage> createState() => _SilvestresPageState();
}

class _SilvestresPageState extends State<SilvestresPage> {
  final _formKey = GlobalKey<FormState>();
  final _viaController = TextEditingController(text: 'VÍA-DEMO');
  final _puntoController = TextEditingController(text: '1+000');
  final _notasController = TextEditingController();

  String _animal = 'Animal silvestre';
  bool _sending = false;

  @override
  void dispose() {
    _viaController.dispose();
    _puntoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _simulateSubmission() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Envío simulado. No se ha contactado con ningún servidor ni correo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incidencia de ejemplo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modo demostración',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Operario: ${widget.operario}'),
                    const Text(
                      'Los datos son ficticios y permanecen en este dispositivo.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _animal,
              decoration: const InputDecoration(labelText: 'Tipo de animal'),
              items: const [
                DropdownMenuItem(
                  value: 'Animal silvestre',
                  child: Text('Animal silvestre'),
                ),
                DropdownMenuItem(
                  value: 'Animal doméstico',
                  child: Text('Animal doméstico'),
                ),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
              ],
              onChanged: (value) => setState(() => _animal = value ?? _animal),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _viaController,
              decoration: const InputDecoration(labelText: 'Vía ficticia'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Introduce una vía de ejemplo.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _puntoController,
              decoration: const InputDecoration(labelText: 'Punto ficticio'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Introduce un punto de ejemplo.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observaciones ficticias',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _sending ? null : _simulateSubmission,
              icon: const Icon(Icons.science_outlined),
              label: Text(_sending ? 'Simulando…' : 'Simular envío'),
            ),
          ],
        ),
      ),
    );
  }
}
