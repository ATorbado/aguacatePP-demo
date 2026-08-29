import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/vehicle.dart';
import '../models/maintenance_type.dart';
import '../models/position_item.dart';
import '../models/maintenance_log.dart';
import '../services/maquinaria_api.dart';

class VehicleDetailPage extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailPage({
    super.key,
    required this.vehicle,
  });

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  late Future<List<MaintenanceType>> _typesFuture;
  late Future<List<PositionItem>> _positionsFuture;
  late Future<List<MaintenanceLog>> _logsFuture;

  @override
  void initState() {
    super.initState();

    _typesFuture = MaquinariaApi.getTypes();
    _positionsFuture = MaquinariaApi.getPositions();
    _logsFuture = MaquinariaApi.getLogs(widget.vehicle.id);
  }

  void _reloadLogs() {
    setState(() {
      _logsFuture = MaquinariaApi.getLogs(widget.vehicle.id);
    });
  }

  IconData _iconForType(String nombre) {
    final lower = nombre.toLowerCase();

    if (lower.contains('aceite')) return Icons.oil_barrel;
    if (lower.contains('filtro')) return Icons.air;
    if (lower.contains('neum')) return Icons.tire_repair;
    if (lower.contains('pastilla')) return Icons.car_repair;
    if (lower.contains('disco')) return Icons.album;
    if (lower.contains('bater')) return Icons.battery_full;

    return Icons.build;
  }

  Future<void> _showAddDialog(
      MaintenanceType type,
      List<PositionItem> positions,
      ) async {
    final fechaController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    final kmController = TextEditingController();
    final descripcionController = TextEditingController();
    final marcaController = TextEditingController();

    PositionItem? selectedPosition;
    Map<String, dynamic>? ultimo;

    Future<void> cargarUltimo() async {
      ultimo = await MaquinariaApi.getLast(
        vehicleId: widget.vehicle.id,
        typeId: type.id,
        positionId: selectedPosition?.id,
      );

      if (mounted) {
        setState(() {});
      }
    }

    await cargarUltimo();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> reloadLast() async {
              ultimo = await MaquinariaApi.getLast(
                vehicleId: widget.vehicle.id,
                typeId: type.id,
                positionId: selectedPosition?.id,
              );

              setModalState(() {});
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF3EEE4),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.nombre,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: fechaController,
                      decoration: InputDecoration(
                        labelText: 'Fecha',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    if (type.requierePosicion)
                      Column(
                        children: [
                          DropdownButtonFormField<PositionItem>(
                            value: selectedPosition,
                            items: positions.map((p) {
                              return DropdownMenuItem(
                                value: p,
                                child: Text(p.nombre),
                              );
                            }).toList(),
                            onChanged: (v) async {
                              selectedPosition = v;
                              await reloadLast();
                            },
                            decoration: InputDecoration(
                              labelText: 'Posición',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),

                    TextField(
                      controller: kmController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Kilómetros',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: marcaController,
                      decoration: InputDecoration(
                        labelText: 'Marca / Modelo',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: descripcionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Observaciones',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (ultimo != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Último mantenimiento',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Fecha: ${ultimo!['fecha']}'),
                            if (ultimo!['kilometros'] != null)
                              Text(
                                'KM: ${ultimo!['kilometros']}',
                              ),
                            if (ultimo!['descripcion'] != null)
                              Text(
                                ultimo!['descripcion'],
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7700),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await MaquinariaApi.createLog(
                              vehicleId: widget.vehicle.id,
                              maintenanceTypeId: type.id,
                              positionId: selectedPosition?.id,
                              fechaIso: fechaController.text,
                              kilometros: int.tryParse(kmController.text),
                              descripcion: descripcionController.text,
                              marcaModelo: marcaController.text,
                            );

                            if (!mounted) return;

                            Navigator.pop(context);

                            _reloadLogs();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Mantenimiento guardado',
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$e'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'Guardar mantenimiento',
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _typesFuture,
        _positionsFuture,
        _logsFuture,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
  snapshot.error.toString(),
  textAlign: TextAlign.center,
),
            ),
          );
        }

        final types = snapshot.data![0] as List<MaintenanceType>;
        final positions = snapshot.data![1] as List<PositionItem>;
        final logs = snapshot.data![2] as List<MaintenanceLog>;

        return Scaffold(
          backgroundColor: const Color(0xFFF3EEE4),
          appBar: AppBar(
            backgroundColor: const Color(0xFF222222),
            foregroundColor: Colors.white,
            title: Text(widget.vehicle.matricula),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                color: const Color(0xFF222222),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vehicle.matricula,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.vehicle.nombre,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Mantenimientos',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: types.length,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.1,
                      ),
                      itemBuilder: (context, index) {
                        final t = types[index];

                        final last = logs
                            .where(
                              (e) => e.tipoMantenimiento == t.nombre,
                        )
                            .toList();

                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _showAddDialog(t, positions),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _iconForType(t.nombre),
                                    size: 34,
                                    color: const Color(0xFFFF7700),
                                  ),
                                  const Spacer(),
                                  Text(
                                    t.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    last.isEmpty
                                        ? 'Sin registros'
                                        : 'Último: ${last.first.fecha}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'Historial',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    ...logs.map(
                          (log) => Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _iconForType(log.titulo),
                                    color: const Color(0xFFFF7700),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      log.titulo,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    log.fecha,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),

                              if (log.posicion != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Posición: ${log.posicion}',
                                ),
                              ],

                              if (log.kilometros != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'KM: ${log.kilometros}',
                                ),
                              ],

                              if (log.marcaModelo != null &&
                                  log.marcaModelo!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(log.marcaModelo!),
                              ],

                              if (log.descripcion != null &&
                                  log.descripcion!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  log.descripcion!,
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}