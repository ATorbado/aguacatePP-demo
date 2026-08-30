import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../services/maquinaria_api.dart';
import 'vehicle_detail_page.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  late Future<List<Vehicle>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = MaquinariaApi.getVehicles();
  }

  void _reload() {
    setState(() {
      _future = MaquinariaApi.getVehicles();
    });
  }

  IconData _iconForVehicle(String nombre) {
    final n = nombre.toLowerCase();

    // maquinaria
    if (n.contains('jcb') ||
        n.contains('kubota') ||
        n.contains('claas') ||
        n.contains('massey') ||
        n.contains('new holland')) {
      return Icons.agriculture;
    }

    // camiones
    if (n.contains('man') ||
        n.contains('iveco') ||
        n.contains('stralis') ||
        n.contains('trakker') ||
        n.contains('kerax') ||
        n.contains('tgs') ||
        n.contains('tgm') ||
        n.contains('k380') ||
        n.contains('k460')) {
      return Icons.local_shipping;
    }

    // pickups
    if (n.contains('hilux') ||
        n.contains('ranger')) {
      return Icons.fire_truck;
    }

    // furgonetas
    if (n.contains('transit') ||
        n.contains('jumper') ||
        n.contains('interstar') ||
        n.contains('sprinter') ||
        n.contains('kangoo') ||
        n.contains('berlingo') ||
        n.contains('combo') ||
        n.contains('caddy')) {
      return Icons.airport_shuttle;
    }

    // coches
    return Icons.directions_car;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EEE4),
      appBar: AppBar(
        title: const Text('MaquinariaM'),
        backgroundColor: const Color(0xFF222222),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Vehicle>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
              ),
            );
          }

          final vehicles = snapshot.data ?? [];

          final filtered = vehicles.where((v) {
            final q = _search.toLowerCase();
            return v.matricula.toLowerCase().contains(q) ||
                v.nombre.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar matrícula o vehículo',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final v = filtered[index];
                    final ultimo = v.ultimoMantenimiento;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VehicleDetailPage(vehicle: v),
                            ),
                          );
                          _reload();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF7700,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  _iconForVehicle(v.nombre),
                                  color: Color(0xFFFF7700),
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.matricula,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      v.nombre,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      ultimo == null
                                          ? 'Sin mantenimientos registrados'
                                          : 'Último: ${ultimo['tipo']} - ${ultimo['fecha']}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
