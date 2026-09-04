import 'package:flutter/material.dart';

import 'preguntas_insp.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inspecciones — Demostración',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const FormPage(),
    );
  }
}

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  static const _responsables = ['Responsable 1', 'Responsable 2'];
  static final _recentDates = [
    DateTime(2026, 3, 10),
    DateTime(2026, 2, 24),
    DateTime(2026, 2, 5),
  ];

  final _formKey = GlobalKey<FormState>();
  final _lugarTrabajoController = TextEditingController();
  final _actividadController = TextEditingController();

  String _responsableSeleccionado = _responsables.first;
  DateTime? _fechaInspeccion;

  @override
  void dispose() {
    _lugarTrabajoController.dispose();
    _actividadController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final now = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInspeccion ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (fecha != null && mounted) {
      setState(() => _fechaInspeccion = fecha);
    }
  }

  String _formatearFechaVisible(DateTime fecha) {
    final day = fecha.day.toString().padLeft(2, '0');
    final month = fecha.month.toString().padLeft(2, '0');
    return '$day/$month/${fecha.year}';
  }

  String _formatearFecha(DateTime fecha) {
    final day = fecha.day.toString().padLeft(2, '0');
    final month = fecha.month.toString().padLeft(2, '0');
    return '$day$month${fecha.year}';
  }

  Future<void> _guardarYContinuar() async {
    if (!_formKey.currentState!.validate()) return;
    final fecha = _fechaInspeccion;
    if (fecha == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una fecha')));
      return;
    }

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => InspeccionSeguridadPage(
              lugarTrabajo: _lugarTrabajoController.text.trim(),
              nombreObra: _actividadController.text.trim(),
              responsable: _responsableSeleccionado,
              fechaInspeccion: _formatearFecha(fecha),
            ),
      ),
    );

    if (ok == true && mounted) {
      _formKey.currentState!.reset();
      _lugarTrabajoController.clear();
      _actividadController.clear();
      setState(() {
        _responsableSeleccionado = _responsables.first;
        _fechaInspeccion = null;
      });
    }
  }

  Widget _buildRecentInspections(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surface.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Últimas inspecciones',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ..._recentDates.map(
              (date) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatearFechaVisible(date),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'Fechas de ejemplo; no se conecta a datos privados.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspecciones — Demostración')),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/fondoINS.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Modo demostración: el envío se simula y no contacta con ningún servidor.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildRecentInspections(context),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _lugarTrabajoController,
                  decoration: const InputDecoration(
                    labelText: 'Lugar de trabajo',
                  ),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Obligatorio'
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _actividadController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción de actividad',
                  ),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Obligatorio'
                              : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _responsableSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Responsable de Inspección',
                  ),
                  items:
                      _responsables
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _responsableSeleccionado = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Fecha de inspección',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _fechaInspeccion == null
                            ? 'Selecciona una fecha'
                            : _formatearFechaVisible(_fechaInspeccion!),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _seleccionarFecha,
                      child: const Text('Seleccionar'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _guardarYContinuar,
                  child: const Text('Guardar y continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
