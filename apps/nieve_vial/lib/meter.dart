import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// ============================= CONFIG (igual que tu main) =============================
const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
const serverValidateUrl = String.fromEnvironment('NIEVE_VALIDATION_URL');

const List<Map<String, String>> matriculas = [
  {'id': '1', 'label': 'DEMO-001'},
  {'id': '2', 'label': 'DEMO-002'},
  {'id': '3', 'label': 'DEMO-003'},
  {'id': '4', 'label': 'DEMO-004'},
  {'id': '5', 'label': 'DEMO-005'},
  {'id': '6', 'label': 'DEMO-006'},
  {'id': '7', 'label': 'DEMO-007'},
  {'id': '8', 'label': 'DEMO-008'},
  {'id': '9', 'label': 'DEMO-009'},
  {'id': '10', 'label': 'DEMO-010'},
  {'id': '11', 'label': 'DEMO-011'},
  {'id': '12', 'label': 'DEMO-012'},
  {'id': '13', 'label': '-- reserva --'},
];

bool isSalAllowedForMatricula(String? matriculaId) {
  if (matriculaId == null) return false;
  final n = int.tryParse(matriculaId) ?? 99;
  return n >= 1 && n <= 11;
}

bool isSpecialVehicle(String? matriculaId) => matriculaId == '12';

const List<String> actividades = [
  'DEMO-01',
  'DEMO-02',
  'DEMO-03',
  'DEMO-04',
  'DEMO-05',
];

List<String> actividadesDisponibles(String? matriculaId) {
  final base = <String>['DEMO-01', 'DEMO-02', 'DEMO-04', 'DEMO-05'];
  if (isSpecialVehicle(matriculaId)) {
    base.insert(2, 'DEMO-03');
  }
  return base;
}

const Map<String, String> actividadTitulos = {
  'DEMO-01': 'Tratamiento preventivo',
  'DEMO-02': 'Tratamiento curativo',
  'DEMO-03': 'Retirada de nieve con fresadora',
  'DEMO-04': 'Mantenimiento de cuchillas',
  'DEMO-05': 'Carga de material',
};

const Map<int, Map<String, dynamic>> tramosDefaults = {
  1: {'ctra': 'V-001', 'pkIni': 0, 'mIni': 0, 'pkFin': 10, 'mFin': 0},
  2: {'ctra': 'V-002', 'pkIni': 10, 'mIni': 0, 'pkFin': 20, 'mFin': 0},
  3: {'ctra': 'V-003', 'pkIni': 20, 'mIni': 0, 'pkFin': 30, 'mFin': 0},
  4: {'ctra': 'V-004', 'pkIni': 30, 'mIni': 0, 'pkFin': 40, 'mFin': 0},
  5: {'ctra': 'V-005', 'pkIni': 40, 'mIni': 0, 'pkFin': 50, 'mFin': 0},
  6: {'ctra': 'V-006', 'pkIni': 50, 'mIni': 0, 'pkFin': 60, 'mFin': 0},
  7: {'ctra': 'V-007', 'pkIni': 60, 'mIni': 0, 'pkFin': 70, 'mFin': 0},
};

const List<String> materiales = [
  'Sal de mina',
  'Sal marina',
  'Sal de silo',
  'Salmuera',
];

const List<Map<String, dynamic>> silos = [
  {'id': 1, 'label': 'Almacén de ejemplo 1'},
  {'id': 2, 'label': 'Almacén de ejemplo 2'},
  {'id': 3, 'label': 'Almacén de ejemplo 3'},
];

// Identidades ficticias para la demostración pública.
const List<String> operariosDummy = [
  'Persona de ejemplo 1',
  'Persona de ejemplo 2',
  'Persona de ejemplo 3',
];

// DEMO-04
const List<String> cuchillaAccionesDemo = [
  'Cambio de cuchillas',
  'Mantenimiento',
  'En espera',
];

const List<Map<String, String>> cuchillasTiposDemo = [
  {'id': 'C.Cunna+salero', 'label': 'C.Cuña+Salero'},
  {'id': 'C.Teja+Salero', 'label': 'C.Teja+Salero'},
  {'id': 'C.Teja+salmuera', 'label': 'C.Teja+Salmuera'},
  {'id': 'C.Teja+Combi', 'label': 'C.Teja+Combi'},
];

// ============================= PK LIMITS =============================

class _PkBounds {
  final String ctra;
  final int minKm;
  final int minM;
  final int maxKm;
  final int maxM;

  const _PkBounds({
    required this.ctra,
    required this.minKm,
    required this.minM,
    required this.maxKm,
    required this.maxM,
  });

  int get minAbs => minKm * 1000 + minM;
  int get maxAbs => maxKm * 1000 + maxM;
}

const int _pkSnapThresholdMeters = 21 * 1000; // 21 km

String _normCtra(String? s) => (s ?? '').trim().toUpperCase();

const Map<String, _PkBounds> _pkBoundsPorCtra = {
  'V-001': _PkBounds(ctra: 'V-001', minKm: 0, minM: 0, maxKm: 10, maxM: 0),
  'V-002': _PkBounds(ctra: 'V-002', minKm: 10, minM: 0, maxKm: 20, maxM: 0),
  'V-003': _PkBounds(ctra: 'V-003', minKm: 20, minM: 0, maxKm: 30, maxM: 0),
  'V-004': _PkBounds(ctra: 'V-004', minKm: 30, minM: 0, maxKm: 40, maxM: 0),
  'V-005': _PkBounds(ctra: 'V-005', minKm: 40, minM: 0, maxKm: 50, maxM: 0),
  'V-006': _PkBounds(ctra: 'V-006', minKm: 50, minM: 0, maxKm: 60, maxM: 0),
  'V-007': _PkBounds(ctra: 'V-007', minKm: 60, minM: 0, maxKm: 70, maxM: 0),
};

String adaptarNumerosMas(String input) {
  // 1) Reemplaza '+' por ','
  // 2) Borra espacios
  // Ej: "131 +740" -> "131,740"
  // Ej: "131,740" -> "131,740"
  var s = input.replaceAll(' ', '');
  s = s.replaceAll('+', ',');
  return s;
}

class _PkParsed {
  final int km;
  final int m;
  const _PkParsed(this.km, this.m);

  int get abs => km * 1000 + m;
}

_PkParsed? _parsePkFlexible(String raw, {int? fallbackKm, int? fallbackM}) {
  final s = adaptarNumerosMas(raw.trim());
  if (s.isEmpty) return null;

  if (s.contains(',')) {
    final parts = s.split(',');
    if (parts.length != 2) return null;
    final km = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (km == null || m == null) return null;
    if (m < 0 || m > 999) return null;
    return _PkParsed(km, m);
  }

  final km = int.tryParse(s);
  if (km == null) return null;
  final m = (fallbackM ?? 0).clamp(0, 999);
  return _PkParsed(km, m);
}

_PkParsed _applyBoundsSnap({
  required String ctra,
  required _PkParsed value,
}) {
  final b = _pkBoundsPorCtra[_normCtra(ctra)];
  if (b == null) return value;

  final v = value.abs;

  if (v < b.minAbs) {
    final diff = b.minAbs - v;
    if (diff <= _pkSnapThresholdMeters) {
      return _PkParsed(b.minKm, b.minM);
    }
    return value; // demasiado lejos, se rechazará por validación
  }

  if (v > b.maxAbs) {
    final diff = v - b.maxAbs;
    if (diff <= _pkSnapThresholdMeters) {
      return _PkParsed(b.maxKm, b.maxM);
    }
    return value; // demasiado lejos, se rechazará por validación
  }

  return value;
}

String? _validatePkBoundsForTramo({
  required String? ctra,
  required int pkIni,
  required int mIni,
  required int pkFin,
  required int mFin,
}) {
  final b = _pkBoundsPorCtra[_normCtra(ctra)];
  if (b == null) return null;

  final iniAbs = pkIni * 1000 + mIni;
  final finAbs = pkFin * 1000 + mFin;

  bool inRange(int x) => x >= b.minAbs && x <= b.maxAbs;

  if (!inRange(iniAbs)) {
    return 'PK inicio fuera de rango para ${b.ctra}: ${b.minKm},${b.minM.toString().padLeft(3, '0')} .. ${b.maxKm},${b.maxM.toString().padLeft(3, '0')} (max desvío 21 km).';
  }
  if (!inRange(finAbs)) {
    return 'PK fin fuera de rango para ${b.ctra}: ${b.minKm},${b.minM.toString().padLeft(3, '0')} .. ${b.maxKm},${b.maxM.toString().padLeft(3, '0')} (max desvío 21 km).';
  }
  return null;
}

// ============================= VALIDACION (solo minimos, como tu main) =============================
class ValidationService {
  static Future<Map<String, dynamic>> fetchMinimos({required String matricula}) async {
    if (demoMode || serverValidateUrl.isEmpty) {
      return {'kmMin': 0, 'horaMinMillis': 0};
    }
    try {
      final resp = await http.get(Uri.parse('$serverValidateUrl?matricula=$matricula'));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'kmMin': 0, 'horaMinMillis': 0};
  }
}

// ============================= SQLITE =============================
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    final path = p.join(base, 'nieve_vial.db');

    _db = await openDatabase(
      path,
      version: 10,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE partes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            fecha_iso TEXT NOT NULL,
            operario TEXT,
            matricula_id INTEGER,
            km_inicio INTEGER,
            km_fin INTEGER,
            horas_inicio INTEGER,
            horas_fin INTEGER,
            gasolina_l REAL,
            adblue_l REAL,
            fecha_inicio_parte TEXT,
            hora_inicio_parte TEXT,
            fecha_fin_parte TEXT,
            hora_fin_parte TEXT,
            horas_trabajador TEXT,
            horas_extra_trabajador TEXT,
            observaciones TEXT,
            status TEXT
          );
        ''');

        await d.execute('''
          CREATE TABLE tramos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            parte_id INTEGER NOT NULL,
            numero INTEGER,
            actividad TEXT,
            ctra TEXT,
            pk_ini INTEGER,
            m_ini INTEGER,
            pk_fin INTEGER,
            m_fin INTEGER,
            hora TEXT,
            hora_fin TEXT,
            material TEXT,
            silo_id INTEGER,
            consumo REAL,
            clca REAL,
            material_solido TEXT,
            consumo_sal_t REAL,
            consumo_salmuera_l REAL,
            clca_kg REAL,
            cuchilla_modo TEXT,
            cuchilla TEXT,
            horas_normal REAL,
            horas_extra REAL,
            orden INTEGER,
            FOREIGN KEY(parte_id) REFERENCES partes(id) ON DELETE CASCADE
          );
        ''');

        await d.execute('''
          CREATE TABLE IF NOT EXISTS operarios_parte(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            parte_id INTEGER NOT NULL,
            nombre TEXT NOT NULL,
            horas_normal REAL,
            horas_extra REAL,
            FOREIGN KEY(parte_id) REFERENCES partes(id) ON DELETE CASCADE
          );
        ''');
        await d.execute('CREATE INDEX IF NOT EXISTS idx_operarios_parte ON operarios_parte(parte_id);');
      },
      onUpgrade: (d, oldV, newV) async {
        Future<bool> hasCol(String table, String col) async {
          final rows = await d.rawQuery('PRAGMA table_info($table)');
          return rows.any((r) => (r['name'] as String?) == col);
        }

        await d.execute('''
          CREATE TABLE IF NOT EXISTS operarios_parte(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            parte_id INTEGER NOT NULL,
            nombre TEXT NOT NULL,
            horas_normal REAL,
            horas_extra REAL,
            FOREIGN KEY(parte_id) REFERENCES partes(id) ON DELETE CASCADE
          );
        ''');
        await d.execute('CREATE INDEX IF NOT EXISTS idx_operarios_parte ON operarios_parte(parte_id);');

        if (!await hasCol('partes', 'observaciones')) {
          await d.execute('ALTER TABLE partes ADD COLUMN observaciones TEXT;');
        }

        if (!await hasCol('tramos', 'cuchilla_modo')) {
          await d.execute('ALTER TABLE tramos ADD COLUMN cuchilla_modo TEXT;');
        }

        if (!await hasCol('tramos', 'horas_normal')) {
          await d.execute('ALTER TABLE tramos ADD COLUMN horas_normal REAL;');
        }

        if (!await hasCol('tramos', 'horas_extra')) {
          await d.execute('ALTER TABLE tramos ADD COLUMN horas_extra REAL;');
        }

        if (!await hasCol('tramos', 'orden')) {
          await d.execute('ALTER TABLE tramos ADD COLUMN orden INTEGER;');
        }

        if (oldV < 8) {
          if (!await hasCol('tramos', 'cuchilla')) {
            await d.execute('ALTER TABLE tramos ADD COLUMN cuchilla TEXT;');
          }
          if (!await hasCol('tramos', 'material_solido')) {
            await d.execute('ALTER TABLE tramos ADD COLUMN material_solido TEXT;');
          }
          if (!await hasCol('tramos', 'consumo_sal_t')) {
            await d.execute('ALTER TABLE tramos ADD COLUMN consumo_sal_t REAL;');
          }
          if (!await hasCol('tramos', 'consumo_salmuera_l')) {
            await d.execute('ALTER TABLE tramos ADD COLUMN consumo_salmuera_l REAL;');
          }
          if (!await hasCol('tramos', 'clca_kg')) {
            await d.execute('ALTER TABLE tramos ADD COLUMN clca_kg REAL;');
          }
          if (!await hasCol('partes', 'horas_trabajador')) {
            await d.execute('ALTER TABLE partes ADD COLUMN horas_trabajador TEXT;');
          }
          if (!await hasCol('partes', 'horas_extra_trabajador')) {
            await d.execute('ALTER TABLE partes ADD COLUMN horas_extra_trabajador TEXT;');
          }
        }
      },
    );

    return _db!;
  }

  Future<int> insertParteWithTramos({
    required ParteLocal parte,
    required List<TramoLocal> tramos,
    required List<Map<String, Object?>> operarios,
  }) async {
    final d = await db;

    return d.transaction<int>((tx) async {
      final parteId = await tx.insert('partes', parte.toMap());

      for (final t in tramos) {
        await tx.insert('tramos', t.toMap(parteId: parteId));
      }

      for (final o in operarios) {
        final nombre = (o['nombre'] as String?)?.trim() ?? '';
        if (nombre.isEmpty) continue;

        await tx.insert('operarios_parte', {
          'parte_id': parteId,
          'nombre': nombre,
          'horas_normal': o['horas_normal'],
          'horas_extra': o['horas_extra'],
        });
      }

      return parteId;
    });
  }
}

// ============================= MODELOS =============================
class OperarioInput {
  OperarioInput({this.nombre});
  String? nombre;

  double? horasNormal;
  double? horasExtra;
}

class DatosPrevios {
  // legacy
  String? operario;

  // 1..3
  List<OperarioInput> operarios = [OperarioInput()];

  String? matriculaId;
  int? kmInicio;
  String? horasInicio; // minutos acumulados
}

class TramoItem {
  TramoItem(this.numero, this.uid) {
    final d = tramosDefaults[numero];
    if (d != null) {
      ctra = d['ctra'] as String;
      pkIni = d['pkIni'] as int;
      mIni = d['mIni'] as int;
      pkFin = d['pkFin'] as int;
      mFin = d['mFin'] as int;
    }
  }

  int numero;
  final int uid;

  String actividad = 'DEMO-01';

  String ctra = '';
  int pkIni = 0;
  int mIni = 0;
  int pkFin = 0;
  int mFin = 0;

  TimeOfDay? hora; // OBLIGATORIA en validacion
  TimeOfDay? horaFin; // OBLIGATORIA en validacion

  String? material;
  int? siloId;
  double? consumo;
  double? clca;

  double? consumoSalT;
  double? consumoSalmueraL;
  double? clcaKg;

  // DEMO-04
  String? cuchillaModo; // Cambio de cuchillas | Mantenimiento | En espera
  String? cuchilla; // solo si modo = Cambio de cuchillas
}

class ParteLocal {
  final String createdAtIso;
  final String diaParteIso;

  final String? operario;

  final int? matriculaId;
  final int kmInicio;
  final int kmFin;
  final int horasInicio;
  final int horasFin;

  final double? gasolinaL;
  final double? adblueL;

  final String fechaInicioParte;
  final String horaInicioParte;
  final String fechaFinParte;
  final String horaFinParte;

  final String? horasTrabajador;
  final String? horasExtraTrabajador;

  final String? observaciones;

  ParteLocal({
    required this.createdAtIso,
    required this.diaParteIso,
    required this.operario,
    required this.matriculaId,
    required this.kmInicio,
    required this.kmFin,
    required this.horasInicio,
    required this.horasFin,
    required this.gasolinaL,
    required this.adblueL,
    required this.fechaInicioParte,
    required this.horaInicioParte,
    required this.fechaFinParte,
    required this.horaFinParte,
    this.horasTrabajador,
    this.horasExtraTrabajador,
    this.observaciones,
  });

  Map<String, Object?> toMap() => {
    'created_at': createdAtIso,
    'fecha_iso': diaParteIso,
    'operario': operario,
    'matricula_id': matriculaId,
    'km_inicio': kmInicio,
    'km_fin': kmFin,
    'horas_inicio': horasInicio,
    'horas_fin': horasFin,
    'gasolina_l': gasolinaL,
    'adblue_l': adblueL,
    'fecha_inicio_parte': fechaInicioParte,
    'hora_inicio_parte': horaInicioParte,
    'fecha_fin_parte': fechaFinParte,
    'hora_fin_parte': horaFinParte,
    'horas_trabajador': horasTrabajador,
    'horas_extra_trabajador': horasExtraTrabajador,
    'observaciones': observaciones,
    'status': 'pending',
  };
}

class TramoLocal {
  final int numero;
  final String actividad;
  final String? ctra;
  final int? pkIni;
  final int? mIni;
  final int? pkFin;
  final int? mFin;

  final String? hora;
  final String? horaFin;

  final String? material;
  final int? siloId;
  final double? consumo;
  final double? clca;

  final String? materialSolido;
  final double? consumoSalT;
  final double? consumoSalmueraL;
  final double? clcaKg;

  final String? cuchillaModo;
  final String? cuchilla;

  TramoLocal({
    required this.numero,
    required this.actividad,
    required this.ctra,
    required this.pkIni,
    required this.mIni,
    required this.pkFin,
    required this.mFin,
    required this.hora,
    required this.horaFin,
    required this.material,
    required this.siloId,
    required this.consumo,
    required this.clca,
    required this.materialSolido,
    required this.consumoSalT,
    required this.consumoSalmueraL,
    required this.clcaKg,
    required this.cuchillaModo,
    required this.cuchilla,
  });

  Map<String, Object?> toMap({required int parteId}) => {
    'parte_id': parteId,
    'numero': numero,
    'actividad': actividad,
    'ctra': ctra,
    'pk_ini': pkIni,
    'm_ini': mIni,
    'pk_fin': pkFin,
    'm_fin': mFin,
    'hora': hora,
    'hora_fin': horaFin,
    'material': material,
    'silo_id': siloId,
    'consumo': consumo,
    'clca': clca,
    'material_solido': materialSolido,
    'consumo_sal_t': consumoSalT,
    'consumo_salmuera_l': consumoSalmueraL,
    'clca_kg': clcaKg,
    'cuchilla_modo': cuchillaModo,
    'cuchilla': cuchilla,
  };
}

// ============================= ENTRY WIDGET =============================
class MeterEntryPage extends StatelessWidget {
  const MeterEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DatosPreviosPage();
  }
}

// ============================= UI: DATOS PREVIOS =============================
class DatosPreviosPage extends StatefulWidget {
  const DatosPreviosPage({super.key});

  @override
  State<DatosPreviosPage> createState() => _DatosPreviosPageState();
}

class _DatosPreviosPageState extends State<DatosPreviosPage> {
  final _formKey = GlobalKey<FormState>();
  final DatosPrevios _datos = DatosPrevios();

  Map<String, dynamic>? _minimos;

  final TextEditingController _ctrlKmInicio = TextEditingController();
  final TextEditingController _ctrlHorasInicio = TextEditingController();

  Future<void> _validarContraServidor() async {
    if (_datos.matriculaId == null) return;
    final min = await ValidationService.fetchMinimos(matricula: _datos.matriculaId!);
    setState(() => _minimos = min);
  }

  @override
  void dispose() {
    _ctrlKmInicio.dispose();
    _ctrlHorasInicio.dispose();
    super.dispose();
  }

  int _horaMinMinutes() {
    final raw = _minimos?['horaMinMillis'];
    final ms = raw is num ? raw.toInt() : 0;
    if (ms <= 0) return 0;
    return (ms / 60000).ceil();
  }

  void _syncOperarios() {
    final ops = _datos.operarios;
    _datos.operario = (ops.isNotEmpty && (ops.first.nombre ?? '').trim().isNotEmpty) ? ops.first.nombre!.trim() : null;
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final horaMin = _horaMinMinutes();
    final kmMin = (_minimos?['kmMin'] is num) ? (_minimos!['kmMin'] as num).toInt() : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Datos del parte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Operarios (maximo 3)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...List.generate(_datos.operarios.length, (i) {
                final op = _datos.operarios[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: (op.nombre != null && op.nombre!.isNotEmpty) ? op.nombre : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Operario ${i + 1}',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: operariosDummy
                              .map((n) => DropdownMenuItem<String>(
                            value: n,
                            child: Text(n),
                          ))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              op.nombre = v;
                              _syncOperarios();
                            });
                          },
                          validator: (v) {
                            if (i == 0) {
                              if (v == null || v.trim().isEmpty) return 'Requerido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_datos.operarios.length > 1)
                        IconButton(
                          tooltip: 'Quitar operario',
                          onPressed: () {
                            setState(() {
                              _datos.operarios.removeAt(i);
                              _syncOperarios();
                            });
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                );
              }),
              if (_datos.operarios.length < 3)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Anadir operario'),
                    onPressed: () {
                      setState(() {
                        _datos.operarios.add(OperarioInput());
                        _syncOperarios();
                      });
                    },
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _datos.matriculaId,
                hint: const Text('Matricula'),
                items: matriculas.map((m) => DropdownMenuItem(value: m['id'], child: Text(m['label']!))).toList(),
                onChanged: (val) async {
                  setState(() => _datos.matriculaId = val);
                  await _validarContraServidor();
                },
                validator: (v) => (v == null) ? 'Selecciona matricula' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlKmInicio,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: 'KM inicio (min >= $kmMin)'),
                onChanged: (v) => _datos.kmInicio = int.tryParse(v),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null) return 'Requerido';
                  if (n < kmMin) return 'Debe ser >= $kmMin';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlHorasInicio,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: horaMin > 0
                      ? 'Hora inicio contador (opcional; min >= $horaMin)'
                      : 'Hora inicio contador (opcional)',
                ),
                onChanged: (v) {
                  _datos.horasInicio = v.isEmpty ? null : v;
                },
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = int.tryParse(v);
                  if (n == null) return 'Número inválido';
                  if (n < horaMin) return 'Debe ser >= $horaMin';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _datos.operarios = _datos.operarios.where((o) => (o.nombre ?? '').trim().isNotEmpty).toList();
                      if (_datos.operarios.isEmpty) {
                        _showMsg('Debe indicar al menos 1 operario.');
                        return;
                      }
                      if (_datos.operarios.length > 3) {
                        _datos.operarios = _datos.operarios.take(3).toList();
                      }
                      _datos.operario = _datos.operarios.first.nombre?.trim();

                      Navigator.push(context, MaterialPageRoute(builder: (_) => PartesPage(datos: _datos)));
                    }
                  },
                  child: const Text('Meter los partes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================= UI: TRATAMIENTOS =============================
class PartesPage extends StatefulWidget {
  final DatosPrevios datos;
  const PartesPage({super.key, required this.datos});

  @override
  State<PartesPage> createState() => _PartesPageState();
}

class _PartesPageState extends State<PartesPage> {
  final List<TramoItem> _tramos = [];
  final _formKey = GlobalKey<FormState>();
  int _seq = 0;

  int _currentIdx = -1;

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  DateTime _diaParteBase() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _mapHoraToDate(TimeOfDay tod, DateTime diaParte) {
    const int nightStart = 20 * 60 + 30;
    const int morningEnd = 8 * 60 + 30;

    final mins = _toMinutes(tod);
    final dia = DateTime(diaParte.year, diaParte.month, diaParte.day);
    final diaAnterior = dia.subtract(const Duration(days: 1));

    if (mins >= nightStart) {
      return DateTime(diaAnterior.year, diaAnterior.month, diaAnterior.day, tod.hour, tod.minute);
    } else if (mins <= morningEnd) {
      return DateTime(dia.year, dia.month, dia.day, tod.hour, tod.minute);
    } else {
      return DateTime(dia.year, dia.month, dia.day, tod.hour, tod.minute);
    }
  }

  Future<({String actividad, int? tramo})?> _pickActividadYTramo() async {
    String actividad = isSpecialVehicle(widget.datos.matriculaId) ? 'DEMO-03' : 'DEMO-01';
    int tramo = 1;
    final acts = actividadesDisponibles(widget.datos.matriculaId);

    return showDialog<({String actividad, int? tramo})>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Nuevo tratamiento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: actividad,
                items: acts.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (v) => setStateDialog(() => actividad = v ?? actividad),
              ),
              const SizedBox(height: 8),
              if (actividad == 'DEMO-01' || actividad == 'DEMO-02' || actividad == 'DEMO-03')
                DropdownButton<int>(
                  isExpanded: true,
                  value: tramo,
                  items: List.generate(7, (i) => i + 1).map((n) => DropdownMenuItem(value: n, child: Text('Tramo $n'))).toList(),
                  onChanged: (v) => setStateDialog(() => tramo = v ?? 1),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                (actividad == 'DEMO-05' || actividad == 'DEMO-04') ? (actividad: actividad, tramo: null) : (actividad: actividad, tramo: tramo),
              ),
              child: const Text('Anadir'),
            ),
          ],
        ),
      ),
    );
  }

  void _addTramo() async {
    final sel = await _pickActividadYTramo();
    if (sel == null) return;

    final numero = sel.tramo ?? 1;
    final t = TramoItem(numero, _seq++);
    t.actividad = sel.actividad;

    if (_tramos.isNotEmpty) {
      final last = _tramos.last;
      if (last.horaFin != null) t.hora = last.horaFin;
    }

    if (t.actividad == 'DEMO-01' || t.actividad == 'DEMO-02' || t.actividad == 'DEMO-03') {
      TramoItem? lastSame;
      for (var i = _tramos.length - 1; i >= 0; i--) {
        final x = _tramos[i];
        final esTramo = x.actividad == 'DEMO-01' || x.actividad == 'DEMO-02' || x.actividad == 'DEMO-03';
        if (esTramo && x.numero == t.numero) {
          lastSame = x;
          break;
        }
      }
      if (lastSame != null) {
        t.ctra = lastSame.ctra;
        t.pkIni = lastSame.pkFin;
        t.mIni = lastSame.mFin;
        t.pkFin = lastSame.pkIni;
        t.mFin = lastSame.mIni;
      }
    }

    if (t.actividad == 'DEMO-04') {
      t.cuchillaModo = 'Cambio de cuchillas';
      t.cuchilla = null;
    }

    setState(() {
      _tramos.add(t);
      _currentIdx = _tramos.length - 1;
    });
  }

  String? _validarMaterial(TramoItem t) {
    if (t.actividad == 'DEMO-01' || t.actividad == 'DEMO-02') {
      final salAllowed = isSalAllowedForMatricula(widget.datos.matriculaId);

      final sal = (t.consumoSalT ?? 0);
      final smu = (t.consumoSalmueraL ?? 0);
      final clca = (t.clcaKg ?? 0);

      if (!salAllowed && sal > 0) {
        return 'La matricula no permite usar sal solida en este tratamiento.';
      }

      if (smu > 0) {
        if (smu < 100 || smu > 12000) return 'La salmuera debe estar entre 100 y 12000 litros.';
      }

      if (sal > 0) {
        if (sal < 0.5 || sal > 15) return 'La sal solida debe estar entre 0,5 y 15 toneladas.';
      }

      if (clca > 0) {
        if (clca < 50 || clca > 250) return 'El CLCA debe estar entre 50 y 250 kg.';
      }

      if (sal <= 0 && smu <= 0 && clca <= 0) return null;

      if (t.material == 'Sal de silo' && sal > 0 && t.siloId == null) {
        return 'Selecciona un silo para la sal solida.';
      }

      return null;
    }

    if (t.actividad == 'DEMO-05') {
      if (t.material == null) return 'Selecciona el tipo de material en la carga.';
      if (!isSalAllowedForMatricula(widget.datos.matriculaId)) {
        if (t.material == 'Sal de mina' || t.material == 'Sal marina' || t.material == 'Sal de silo') {
          return 'Esta matricula no puede cargar sal solida (solo salmuera).';
        }
      }
      if (t.material == 'Salmuera') {
        final v = t.consumo ?? -1;
        if (v < 100 || v > 12000) return 'La cantidad de salmuera debe estar entre 100 y 12000 litros.';
      } else {
        final v = t.consumo ?? -1;
        if (v < 0.5 || v > 15) return 'La cantidad de sal solida debe estar entre 0,5 y 15 toneladas.';
        if (t.clca != null) {
          final c = t.clca!;
          if (c < 50 || c > 250) return 'El CLCA de la carga debe estar entre 50 y 250 kg.';
        }
        if (t.material == 'Sal de silo' && t.siloId == null) return 'Selecciona un silo para la carga de sal solida.';
      }
      return null;
    }

    return null;
  }

  // (1) Validaciones: volver a exigir hora/horaFin + PK bounds
  String? _validarTramoComun(TramoItem t) {
    if (t.mIni < 0 || t.mIni > 999) return 'Los metros de inicio deben estar entre 0 y 999.';
    if (t.mFin < 0 || t.mFin > 999) return 'Los metros de fin deben estar entre 0 y 999.';
    if (t.pkIni < 0 || t.pkFin < 0) return 'Los PK de inicio y fin deben ser mayores o iguales que 0.';

    final boundsErr = _validatePkBoundsForTramo(
      ctra: t.ctra,
      pkIni: t.pkIni,
      mIni: t.mIni,
      pkFin: t.pkFin,
      mFin: t.mFin,
    );
    if (boundsErr != null) return boundsErr;

    if (t.hora == null) return 'Indica la hora de inicio del tramo.';
    if (t.horaFin == null) return 'Indica la hora de fin del tramo.';

    if (_toMinutes(t.horaFin!) < _toMinutes(t.hora!)) {
      return 'La hora fin no puede ser anterior a la hora inicio.';
    }

    return null;
  }

  String? _validarHorasSolo(TramoItem t) {
    if (t.hora == null) return 'Indica la hora de inicio.';
    if (t.horaFin == null) return 'Indica la hora de fin.';

    if (_toMinutes(t.horaFin!) < _toMinutes(t.hora!)) {
      return 'La hora fin no puede ser anterior a la hora inicio.';
    }

    return null;
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tramos.isEmpty) {
      _showMsg('Anade al menos 1 tratamiento.');
      return;
    }

    for (final t in _tramos) {
      String? err;
      if (t.actividad == 'DEMO-01' || t.actividad == 'DEMO-02') {
        err = _validarTramoComun(t) ?? _validarMaterial(t);
      } else if (t.actividad == 'DEMO-03') {
        err = _validarTramoComun(t);
      } else if (t.actividad == 'DEMO-05') {
        err = _validarHorasSolo(t) ?? _validarMaterial(t);
      } else if (t.actividad == 'DEMO-04') {
        err = _validarHorasSolo(t);
        if ((t.cuchillaModo ?? '').isEmpty) err = 'Selecciona una accion de cuchillas.';
        if (t.cuchillaModo == 'Cambio de cuchillas' && (t.cuchilla == null || t.cuchilla!.isEmpty)) {
          err = 'Selecciona el tipo de cuchilla.';
        }
      }
      if (err != null) {
        _showMsg('Tratamiento ${t.numero}: $err');
        return;
      }
    }

    if (widget.datos.kmInicio == null) {
      _showMsg('Indica km inicio.');
      return;
    }

    final diaParte = _diaParteBase();

    DateTime? inicioParte;
    DateTime? finParte;

    for (final t in _tramos) {
      if (t.hora != null) {
        final ini = _mapHoraToDate(t.hora!, diaParte);
        inicioParte = (inicioParte == null || ini.isBefore(inicioParte)) ? ini : inicioParte;
      }
      if (t.horaFin != null) {
        final fin = _mapHoraToDate(t.horaFin!, diaParte);
        finParte = (finParte == null || fin.isAfter(finParte)) ? fin : finParte;
      }
    }

    // (2) No fallback: exigir horas para calcular inicio/fin
    if (inicioParte == null || finParte == null) {
      _showMsg('Debe indicar hora inicio y hora fin en los tratamientos.');
      return;
    }

    final fechaInicioParte = DateFormat('yyyy-MM-dd').format(inicioParte);
    final horaInicioParte = DateFormat('HH:mm').format(inicioParte);
    final fechaFinParte = DateFormat('yyyy-MM-dd').format(finParte);
    final horaFinParte = DateFormat('HH:mm').format(finParte);

    for (final t in _tramos) {
      if (t.actividad == 'DEMO-01' || t.actividad == 'DEMO-02') {
        t.consumo = null;
        t.clca = null;

        final sal = t.consumoSalT ?? 0;
        final smu = t.consumoSalmueraL ?? 0;

        if (sal > 0 && (t.material == 'Sal de mina' || t.material == 'Sal marina' || t.material == 'Sal de silo')) {
          t.consumo = t.consumoSalT;
        } else if (smu > 0) {
          t.material = 'Salmuera';
          t.consumo = t.consumoSalmueraL;
        }
        if ((t.clcaKg ?? 0) > 0) t.clca = t.clcaKg;
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinalizarPartePage(
          datos: widget.datos,
          tramos: _tramos,
          diaParte: diaParte,
          fechaInicioParte: fechaInicioParte,
          horaInicioParte: horaInicioParte,
          fechaFinParte: fechaFinParte,
          horaFinParte: horaFinParte,
        ),
      ),
    );
  }

  void _goPrev() {
    if (_tramos.isEmpty) return;
    setState(() {
      if (_currentIdx <= 0) return;
      _currentIdx--;
    });
  }

  void _goNext() {
    if (_tramos.isEmpty) return;
    setState(() {
      if (_currentIdx >= _tramos.length - 1) return;
      _currentIdx++;
    });
  }

  void _ensureCurrent() {
    if (_tramos.isEmpty) {
      _currentIdx = -1;
      return;
    }
    if (_currentIdx < 0) _currentIdx = _tramos.length - 1;
    if (_currentIdx > _tramos.length - 1) _currentIdx = _tramos.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    _ensureCurrent();

    final hasAny = _tramos.isNotEmpty;
    final current = hasAny ? _tramos[_currentIdx] : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Tratamientos del parte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Finalizar partes'),
                ),
              ),
              const SizedBox(height: 12),
              if (hasAny)
                Row(
                  children: [
                    IconButton(
                      onPressed: _currentIdx > 0 ? _goPrev : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Tratamiento ${_currentIdx + 1} de ${_tramos.length}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _currentIdx < _tramos.length - 1 ? _goNext : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No hay tratamientos. Anade uno abajo.'),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: hasAny
                    ? ListView(
                  children: [
                    _TramoCard(
                      key: ValueKey('tramo_${current!.uid}'),
                      tramo: current,
                      matriculaId: widget.datos.matriculaId,
                      onDelete: () {
                        setState(() {
                          _tramos.removeAt(_currentIdx);
                          if (_tramos.isEmpty) {
                            _currentIdx = -1;
                          } else if (_currentIdx > _tramos.length - 1) {
                            _currentIdx = _tramos.length - 1;
                          }
                        });
                      },
                    ),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addTramo,
                  icon: const Icon(Icons.add),
                  label: const Text('+ Anadir tratamiento'),
                  style: ElevatedButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ============================= UI: FINALIZAR (GUARDA EN SQLITE) =============================
class FinalizarPartePage extends StatefulWidget {
  final DatosPrevios datos;
  final List<TramoItem> tramos;

  final DateTime diaParte;
  final String fechaInicioParte;
  final String horaInicioParte;
  final String fechaFinParte;
  final String horaFinParte;

  const FinalizarPartePage({
    super.key,
    required this.datos,
    required this.tramos,
    required this.diaParte,
    required this.fechaInicioParte,
    required this.horaInicioParte,
    required this.fechaFinParte,
    required this.horaFinParte,
  });

  @override
  State<FinalizarPartePage> createState() => _FinalizarPartePageState();
}

class _FinalizarPartePageState extends State<FinalizarPartePage> {
  final _formKey = GlobalKey<FormState>();
  final _kmFinCtrl = TextEditingController();
  final _horasFinCtrl = TextEditingController();

  late final List<TextEditingController> _horasNormCtrl;
  late final List<TextEditingController> _horasExtraCtrl;

  bool _repostajeGasolina = false;
  bool _repostajeAdBlue = false;
  final _litrosGasolinaCtrl = TextEditingController();
  final _litrosAdBlueCtrl = TextEditingController();

  final _obsCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final count = widget.datos.operarios.length.clamp(1, 3);
    _horasNormCtrl = List.generate(count, (_) => TextEditingController());
    _horasExtraCtrl = List.generate(count, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _kmFinCtrl.dispose();
    _horasFinCtrl.dispose();
    for (final c in _horasNormCtrl) {
      c.dispose();
    }
    for (final c in _horasExtraCtrl) {
      c.dispose();
    }
    _litrosGasolinaCtrl.dispose();
    _litrosAdBlueCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  int _calcHorasDeltaHours(int iniMin, int finMin) {
    final delta = finMin >= iniMin ? (finMin - iniMin) : 0;
    return (delta / 60).floor();
  }

  String? _fmtHora(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  double? _parseDouble(String s) {
    final v = s.trim();
    if (v.isEmpty) return null;
    return double.tryParse(v.replaceAll(',', '.'));
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _guardarLocal() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final kmFin = int.parse(_kmFinCtrl.text);
    final horasFin = int.tryParse(_horasFinCtrl.text);

    final kmInicio = widget.datos.kmInicio ?? 0;
    final horasInicio = int.tryParse(widget.datos.horasInicio ?? '');

    final totalKm = kmFin - kmInicio;
    final totalHoras = (horasInicio != null && horasFin != null) ? _calcHorasDeltaHours(horasInicio, horasFin) : 0;

    if (totalKm > 2000) {
      _showMsg('Maximo 2000 km por parte.');
      return;
    }
    if (totalHoras > 24) {
      _showMsg('Maximo 24 horas por parte.');
      return;
    }

    final ops = widget.datos.operarios.where((o) => (o.nombre ?? '').trim().isNotEmpty).toList();
    if (ops.isEmpty) {
      _showMsg('Debe indicar al menos 1 operario.');
      return;
    }
    if (ops.length > 3) {
      _showMsg('Maximo 3 operarios.');
      return;
    }

    final horasNorm = <double?>[];
    final horasExtra = <double?>[];

    for (int i = 0; i < ops.length; i++) {
      horasNorm.add(_parseDouble(_horasNormCtrl[i].text));
      horasExtra.add(_parseDouble(_horasExtraCtrl[i].text));
    }

    final litrosGasolina = _repostajeGasolina ? _parseDouble(_litrosGasolinaCtrl.text) : null;
    final litrosAdBlue = _repostajeAdBlue ? _parseDouble(_litrosAdBlueCtrl.text) : null;

    if (_repostajeGasolina && (litrosGasolina == null || litrosGasolina <= 0)) {
      _showMsg('Indica litros de gasolina (>0).');
      return;
    }
    if (_repostajeAdBlue && (litrosAdBlue == null || litrosAdBlue <= 0)) {
      _showMsg('Indica litros de AdBlue (>0).');
      return;
    }

    final obs = _obsCtrl.text.trim();
    if (obs.length > 616) {
      _showMsg('Observaciones: maximo 616 caracteres.');
      return;
    }

    setState(() => _saving = true);

    try {
      final diaIso = DateFormat('yyyy-MM-dd').format(widget.diaParte);

      final parte = ParteLocal(
        createdAtIso: DateTime.now().toIso8601String(),
        diaParteIso: diaIso,
        operario: ops.first.nombre?.trim(),
        matriculaId: int.tryParse(widget.datos.matriculaId ?? ''),
        kmInicio: kmInicio,
        kmFin: kmFin,
        horasInicio: horasInicio ?? 0,
        horasFin: horasFin ?? 0,
        gasolinaL: litrosGasolina,
        adblueL: litrosAdBlue,
        fechaInicioParte: widget.fechaInicioParte,
        horaInicioParte: widget.horaInicioParte,
        fechaFinParte: widget.fechaFinParte,
        horaFinParte: widget.horaFinParte,
        horasTrabajador: null,
        horasExtraTrabajador: null,
        observaciones: obs.isEmpty ? null : obs,
      );

      final tramos = widget.tramos.map((t) {
        final esTrat = t.actividad == 'DEMO-01' || t.actividad == 'DEMO-02';
        final materialSolido = esTrat && (t.material == 'Sal de mina' || t.material == 'Sal marina' || t.material == 'Sal de silo') ? t.material : null;

        return TramoLocal(
          numero: t.numero,
          actividad: t.actividad,
          ctra: t.ctra,
          pkIni: t.pkIni,
          mIni: t.mIni,
          pkFin: t.pkFin,
          mFin: t.mFin,
          hora: _fmtHora(t.hora),
          horaFin: _fmtHora(t.horaFin),
          material: t.material,
          siloId: t.siloId,
          consumo: t.consumo,
          clca: t.clca,
          materialSolido: materialSolido,
          consumoSalT: esTrat ? t.consumoSalT : null,
          consumoSalmueraL: esTrat ? t.consumoSalmueraL : null,
          clcaKg: esTrat ? t.clcaKg : null,
          cuchillaModo: t.actividad == 'DEMO-04' ? t.cuchillaModo : null,
          cuchilla: (t.actividad == 'DEMO-04' && t.cuchillaModo == 'Cambio de cuchillas') ? t.cuchilla : null,
        );
      }).toList();

      final operariosDb = <Map<String, Object?>>[];
      for (int i = 0; i < ops.length; i++) {
        final nombre = (ops[i].nombre ?? '').trim();
        if (nombre.isEmpty) continue;
        operariosDb.add({
          'nombre': nombre,
          'horas_normal': horasNorm[i],
          'horas_extra': horasExtra[i],
        });
      }

      final id = await LocalDb.instance.insertParteWithTramos(
        parte: parte,
        tramos: tramos,
        operarios: operariosDb,
      );

      _showMsg('Parte guardado en local (#$id)');
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _showMsg('Error guardando en local: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kmInicio = widget.datos.kmInicio ?? 0;
    final horasInicio = int.tryParse(widget.datos.horasInicio ?? '') ?? 0;

    final ops = widget.datos.operarios.where((o) => (o.nombre ?? '').trim().isNotEmpty).toList();
    final opCount = ops.length.clamp(1, 3);

    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar parte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Operarios: ${ops.map((e) => e.nombre).join(', ')}'),
                      Text('Matricula: ${widget.datos.matriculaId ?? ''}'),
                      Text('KM inicio: $kmInicio'),
                      Text('Horas inicio: $horasInicio'),
                      const SizedBox(height: 8),
                      Text('Inicio parte: ${widget.fechaInicioParte} ${widget.horaInicioParte}'),
                      Text('Fin parte: ${widget.fechaFinParte} ${widget.horaFinParte}'),
                      const SizedBox(height: 8),
                      Text('Tratamientos: ${widget.tramos.length}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _kmFinCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'KM fin'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null) return 'Requerido';
                  if (n < kmInicio) return 'Fin >= inicio';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _horasFinCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Hora fin contador (opcional)'),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = int.tryParse(v);
                  if (n == null) return 'Número inválido';
                  if (widget.datos.horasInicio != null) {
                    final ini = int.tryParse(widget.datos.horasInicio!);
                    if (ini != null && n < ini) return 'Fin >= inicio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Horas por operario', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...List.generate(opCount, (i) {
                final nombre = (ops[i].nombre ?? '').trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre.isEmpty ? 'Operario ${i + 1}' : nombre),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _horasNormCtrl[i],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              decoration: const InputDecoration(
                                labelText: 'Horas normales',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _horasExtraCtrl[i],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              decoration: const InputDecoration(
                                labelText: 'Horas extra',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              const Text('Repostajes', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('He echado gasolina'),
                value: _repostajeGasolina,
                onChanged: (v) => setState(() => _repostajeGasolina = v),
              ),
              if (_repostajeGasolina)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _litrosGasolinaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(
                      labelText: 'Litros gasolina',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              SwitchListTile(
                title: const Text('He echado AdBlue'),
                value: _repostajeAdBlue,
                onChanged: (v) => setState(() => _repostajeAdBlue = v),
              ),
              if (_repostajeAdBlue)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _litrosAdBlueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(
                      labelText: 'Litros AdBlue',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text('Observaciones del operario', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _obsCtrl,
                maxLength: 616,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Volver a tratamientos'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _guardarLocal,
                      child: Text(_saving ? 'Guardando...' : 'Guardar en local'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================= UI: TRAMO CARD =============================
class _TramoCard extends StatefulWidget {
  final TramoItem tramo;
  final String? matriculaId;
  final VoidCallback onDelete;
  const _TramoCard({super.key, required this.tramo, required this.matriculaId, required this.onDelete});

  @override
  State<_TramoCard> createState() => _TramoCardState();
}

class _TramoCardState extends State<_TramoCard> {
  late final TextEditingController _ctraCtrl;

  // PK: ahora admite "131 +740" / "131,740" en el campo PK (y sincroniza metros)
  late final TextEditingController _pkIniCtrl;
  late final TextEditingController _mIniCtrl;
  late final TextEditingController _pkFinCtrl;
  late final TextEditingController _mFinCtrl;

  late final TextEditingController _consumoCtrl;
  late final TextEditingController _clcaCtrl;
  late final TextEditingController _horaCtrl;
  late final TextEditingController _horaFinCtrl;

  late final TextEditingController _salSolidaCtrl;
  late final TextEditingController _salmueraCtrl;
  late final TextEditingController _clcaKgCtrl;

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool _syncingPk = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tramo;

    _ctraCtrl = TextEditingController(text: t.ctra);

    _pkIniCtrl = TextEditingController(text: t.pkIni.toString());
    _mIniCtrl = TextEditingController(text: t.mIni.toString());
    _pkFinCtrl = TextEditingController(text: t.pkFin.toString());
    _mFinCtrl = TextEditingController(text: t.mFin.toString());

    _consumoCtrl = TextEditingController(text: t.consumo?.toString() ?? '');
    _clcaCtrl = TextEditingController(text: t.clca?.toString() ?? '');
    _horaCtrl = TextEditingController(text: _horaToStr(t.hora));
    _horaFinCtrl = TextEditingController(text: _horaToStr(t.horaFin));

    _salSolidaCtrl = TextEditingController(text: t.consumoSalT?.toString() ?? '');
    _salmueraCtrl = TextEditingController(text: t.consumoSalmueraL?.toString() ?? '');
    _clcaKgCtrl = TextEditingController(text: t.clcaKg?.toString() ?? '');

    _ctraCtrl.addListener(() {
      t.ctra = _ctraCtrl.text;
      // al cambiar carretera, re-aplica snap por bounds (si procede)
      _applyPkFromController(isInicio: true, force: true);
      _applyPkFromController(isInicio: false, force: true);
    });

    // PK listeners (con adaptarNumerosMas + snap bounds)
    _pkIniCtrl.addListener(() => _applyPkFromController(isInicio: true));
    _pkFinCtrl.addListener(() => _applyPkFromController(isInicio: false));

    // metros: siguen siendo numéricos, pero si el PK llevaba coma ya los sincronizamos igualmente
    _mIniCtrl.addListener(() {
      if (_syncingPk) return;
      t.mIni = int.tryParse(_mIniCtrl.text) ?? t.mIni;
      _applyPkFromController(isInicio: true, force: true);
    });
    _mFinCtrl.addListener(() {
      if (_syncingPk) return;
      t.mFin = int.tryParse(_mFinCtrl.text) ?? t.mFin;
      _applyPkFromController(isInicio: false, force: true);
    });

    _consumoCtrl.addListener(() => t.consumo = double.tryParse(_consumoCtrl.text.replaceAll(',', '.')));
    _clcaCtrl.addListener(() => t.clca = double.tryParse(_clcaCtrl.text.replaceAll(',', '.')));

    _salSolidaCtrl.addListener(() {
      final v = double.tryParse(_salSolidaCtrl.text.replaceAll(',', '.'));
      t.consumoSalT = v;

      final n = v ?? 0;

      if (n > 0) {
        if (t.material == 'Salmuera') {
          t.material = null;
          t.consumoSalmueraL = null;
          _salmueraCtrl.text = '';
        }
      } else {
        if (t.material == 'Sal de mina' || t.material == 'Sal marina' || t.material == 'Sal de silo') {
          t.material = null;
        }
        if (t.material != 'Sal de silo') t.siloId = null;
      }

      if (mounted) setState(() {});
    });

    _salmueraCtrl.addListener(() {
      final v = double.tryParse(_salmueraCtrl.text.replaceAll(',', '.'));
      t.consumoSalmueraL = v;

      final n = v ?? 0;

      if (n > 0) {
        if ((t.consumoSalT ?? 0) > 0) {
          t.consumoSalT = null;
          _salSolidaCtrl.text = '';
        }
        if (t.material == 'Sal de mina' || t.material == 'Sal marina' || t.material == 'Sal de silo') {
          t.material = null;
        }

        if (t.material != 'Salmuera') {
          t.material = 'Salmuera';
          t.siloId = null;
        }
      } else {
        if (t.material == 'Salmuera') {
          t.material = null;
        }
      }

      if (mounted) setState(() {});
    });

    _clcaKgCtrl.addListener(() {
      t.clcaKg = double.tryParse(_clcaKgCtrl.text.replaceAll(',', '.'));
      if (mounted) setState(() {});
    });

    if (t.actividad == 'DEMO-04') {
      t.cuchillaModo ??= 'Cambio de cuchillas';
      if (t.cuchillaModo != 'Cambio de cuchillas') {
        t.cuchilla = null;
      }
    }
  }

  void _applyPkFromController({required bool isInicio, bool force = false}) {
    if (_syncingPk) return;

    final t = widget.tramo;
    final pkCtrl = isInicio ? _pkIniCtrl : _pkFinCtrl;
    final mCtrl = isInicio ? _mIniCtrl : _mFinCtrl;

    // Solo intentamos parsear formato flexible si hay indicios (',' '+' espacios) o si force=true
    final raw = pkCtrl.text;
    final shouldParseFlexible = force || raw.contains(',') || raw.contains('+') || raw.contains(' ');

    if (!shouldParseFlexible) {
      // modo clásico: PK en pkCtrl, metros en mCtrl
      final km = int.tryParse(raw);
      final m = int.tryParse(mCtrl.text);
      if (km != null) {
        if (isInicio) {
          t.pkIni = km;
        } else {
          t.pkFin = km;
        }
      }
      if (m != null) {
        if (isInicio) {
          t.mIni = m;
        } else {
          t.mFin = m;
        }
      }

      // aplica snap igualmente
      final current = _PkParsed(isInicio ? t.pkIni : t.pkFin, isInicio ? t.mIni : t.mFin);
      final snapped = _applyBoundsSnap(ctra: t.ctra, value: current);
      if (snapped.abs != current.abs) {
        _syncingPk = true;
        try {
          if (isInicio) {
            t.pkIni = snapped.km;
            t.mIni = snapped.m;
            pkCtrl.text = snapped.km.toString();
            mCtrl.text = snapped.m.toString();
          } else {
            t.pkFin = snapped.km;
            t.mFin = snapped.m;
            pkCtrl.text = snapped.km.toString();
            mCtrl.text = snapped.m.toString();
          }
        } finally {
          _syncingPk = false;
        }
        if (mounted) setState(() {});
      }
      return;
    }

    // modo flexible: "131 +740" / "131,740"
    final parsed = _parsePkFlexible(
      raw,
      fallbackKm: isInicio ? t.pkIni : t.pkFin,
      fallbackM: isInicio ? t.mIni : t.mFin,
    );
    if (parsed == null) return; // todavía escribiendo / inválido parcial

    // snap bounds (DESPUÉS de adaptarNumerosMas, porque parsePkFlexible ya lo usa)
    final snapped = _applyBoundsSnap(ctra: t.ctra, value: parsed);

    _syncingPk = true;
    try {
      if (isInicio) {
        t.pkIni = snapped.km;
        t.mIni = snapped.m;
        pkCtrl.text = snapped.km.toString();
        mCtrl.text = snapped.m.toString();
      } else {
        t.pkFin = snapped.km;
        t.mFin = snapped.m;
        pkCtrl.text = snapped.km.toString();
        mCtrl.text = snapped.m.toString();
      }
    } finally {
      _syncingPk = false;
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctraCtrl.dispose();
    _pkIniCtrl.dispose();
    _mIniCtrl.dispose();
    _pkFinCtrl.dispose();
    _mFinCtrl.dispose();
    _consumoCtrl.dispose();
    _clcaCtrl.dispose();
    _horaCtrl.dispose();
    _horaFinCtrl.dispose();
    _salSolidaCtrl.dispose();
    _salmueraCtrl.dispose();
    _clcaKgCtrl.dispose();
    super.dispose();
  }

  String _horaToStr(TimeOfDay? t) => t == null ? '' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTimeInicio() async {
    final now = TimeOfDay.now();
    final t = await showTimePicker(context: context, initialTime: widget.tramo.hora ?? now);
    if (t != null) {
      setState(() {
        widget.tramo.hora = t;
        _horaCtrl.text = _horaToStr(t);
      });
    }
  }

  Future<void> _pickTimeFin() async {
    final now = TimeOfDay.now();
    final t = await showTimePicker(context: context, initialTime: widget.tramo.horaFin ?? widget.tramo.hora ?? now);
    if (t != null) {
      setState(() {
        widget.tramo.horaFin = t;
        _horaFinCtrl.text = _horaToStr(t);
      });
    }
  }

  void _clearHoraInicio() {
    setState(() {
      widget.tramo.hora = null;
      _horaCtrl.text = '';
    });
  }

  void _clearHoraFin() {
    setState(() {
      widget.tramo.horaFin = null;
      _horaFinCtrl.text = '';
    });
  }

  bool get _salPermitida => isSalAllowedForMatricula(widget.matriculaId);

  double get _salSolidaVal => double.tryParse(_salSolidaCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _salmueraVal => double.tryParse(_salmueraCtrl.text.replaceAll(',', '.')) ?? 0;

  bool get _mostrarTipoSal => _salSolidaVal > 0 && _salmueraVal <= 0;

  void _applyTramoDefaults(int v) {
    final d = tramosDefaults[v]!;
    widget.tramo.ctra = d['ctra'];
    widget.tramo.pkIni = d['pkIni'];
    widget.tramo.mIni = d['mIni'];
    widget.tramo.pkFin = d['pkFin'];
    widget.tramo.mFin = d['mFin'];
    _ctraCtrl.text = widget.tramo.ctra;
    _pkIniCtrl.text = widget.tramo.pkIni.toString();
    _mIniCtrl.text = widget.tramo.mIni.toString();
    _pkFinCtrl.text = widget.tramo.pkFin.toString();
    _mFinCtrl.text = widget.tramo.mFin.toString();

    // snap inmediato por bounds
    _applyPkFromController(isInicio: true, force: true);
    _applyPkFromController(isInicio: false, force: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tramo;

    final opcionesTipoSal = _salPermitida ? const ['Sin Sal', 'Sal de mina', 'Sal marina', 'Sal de silo'] : const ['Sin Sal'];

    final titulo = actividadTitulos[t.actividad] ?? 'Tratamiento';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_forever)),
          ]),
          const SizedBox(height: 8),
          if (t.actividad == 'DEMO-01' || t.actividad == 'DEMO-02' || t.actividad == 'DEMO-03')
            DropdownButtonFormField<int>(
              value: t.numero,
              decoration: const InputDecoration(labelText: 'Tramo'),
              items: List.generate(7, (i) => i + 1).map((n) => DropdownMenuItem(value: n, child: Text('Tramo $n'))).toList(),
              onChanged: (v) => setState(() {
                if (v == null) return;
                t.numero = v;
                _applyTramoDefaults(v);
              }),
            ),
          if (t.actividad == 'DEMO-01' || t.actividad == 'DEMO-02' || t.actividad == 'DEMO-03') ...[
            const SizedBox(height: 8),
            TextFormField(controller: _ctraCtrl, decoration: const InputDecoration(labelText: 'Ctra (por tramo)')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _pkIniCtrl,
                  keyboardType: TextInputType.text,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,+\s]'))],
                  decoration: const InputDecoration(labelText: 'PK inicio (admite 131+740 / 131,740)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _mIniCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Metros inicio (0..999)'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _pkFinCtrl,
                  keyboardType: TextInputType.text,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,+\s]'))],
                  decoration: const InputDecoration(labelText: 'PK fin (admite 131+740 / 131,740)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _mFinCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Metros fin (0..999)'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Intercambiar PK inicio/fin',
                onPressed: () => setState(() {
                  final pkI = t.pkIni;
                  final mI = t.mIni;
                  t.pkIni = t.pkFin;
                  t.mIni = t.mFin;
                  t.pkFin = pkI;
                  t.mFin = mI;
                  _pkIniCtrl.text = t.pkIni.toString();
                  _mIniCtrl.text = t.mIni.toString();
                  _pkFinCtrl.text = t.pkFin.toString();
                  _mFinCtrl.text = t.mFin.toString();

                  _applyPkFromController(isInicio: true, force: true);
                  _applyPkFromController(isInicio: false, force: true);
                }),
                icon: const Icon(Icons.swap_horiz),
              )
            ]),
          ],
          const SizedBox(height: 8),

          // (3) Validadores en campos hora
          TextFormField(
            readOnly: true,
            controller: _horaCtrl,
            decoration: InputDecoration(
              labelText: 'Hora inicio del tramo',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.clear), onPressed: _horaCtrl.text.isEmpty ? null : _clearHoraInicio),
                  IconButton(icon: const Icon(Icons.schedule), onPressed: _pickTimeInicio),
                ],
              ),
            ),
            validator: (_) {
              if (widget.tramo.hora == null) return 'Requerido';
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            readOnly: true,
            controller: _horaFinCtrl,
            decoration: InputDecoration(
              labelText: 'Hora fin del tramo',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.clear), onPressed: _horaFinCtrl.text.isEmpty ? null : _clearHoraFin),
                  IconButton(icon: const Icon(Icons.schedule), onPressed: _pickTimeFin),
                ],
              ),
            ),
            validator: (_) {
              if (widget.tramo.horaFin == null) return 'Requerido';
              if (widget.tramo.hora != null && _toMinutes(widget.tramo.horaFin!) < _toMinutes(widget.tramo.hora!)) {
                return 'Fin < inicio';
              }
              return null;
            },
          ),

          if (t.actividad == 'DEMO-01' || t.actividad == 'DEMO-02') ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _salSolidaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Sal solida (t)', helperText: '0,5..15 t'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _salmueraCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Salmuera (L)', helperText: '100..12000 L'),
                ),
              ),
            ]),
            if (_mostrarTipoSal) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: opcionesTipoSal.contains(t.material) ? t.material : null,
                decoration: const InputDecoration(labelText: 'Tipo de Sal'),
                items: opcionesTipoSal.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() {
                  t.material = v;
                  if (v == 'Sin Sal') {
                    t.consumoSalT = null;
                    _salSolidaCtrl.text = '';
                    t.siloId = null;
                  }
                  if (v != 'Sal de silo') t.siloId = null;
                }),
                validator: (v) {
                  if (_mostrarTipoSal && (v == null || v.isEmpty)) return 'Seleccione tipo de Sal';
                  return null;
                },
              ),
              if (t.material == 'Sal de silo') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: t.siloId,
                  decoration: const InputDecoration(labelText: 'Silo'),
                  items: silos
                      .map((s) => DropdownMenuItem<int>(
                    value: s['id'] as int,
                    child: Text(s['label'] as String),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => t.siloId = v),
                ),
              ],
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _clcaKgCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'CLCA (kg, opcional)', helperText: '50..250 kg'),
            ),
          ],

          if (t.actividad == 'DEMO-05') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: t.material,
              decoration: InputDecoration(
                labelText: _salPermitida ? 'Tipo de material (carga)' : 'Tipo de material (sal deshabilitada)',
              ),
              items: materiales.where((m) => _salPermitida ? true : m == 'Salmuera').map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() {
                t.material = v;
                if (v != 'Sal de silo') t.siloId = null;
              }),
            ),
            if (t.material == 'Sal de silo')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: DropdownButtonFormField<int>(
                  value: t.siloId,
                  decoration: const InputDecoration(labelText: 'Silo'),
                  items: silos
                      .map((s) => DropdownMenuItem<int>(
                    value: s['id'] as int,
                    child: Text(s['label'] as String),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => t.siloId = v),
                ),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _consumoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                labelText: (t.material == 'Salmuera') ? 'Cantidad carga (100..12000 L)' : 'Cantidad carga (0,5..15)',
              ),
            ),
            if (t.material == 'Sal de mina' || t.material == 'Sal marina' || t.material == 'Sal de silo')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextFormField(
                  controller: _clcaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'CLCA (50..250 kg, opcional)'),
                ),
              ),
          ],

          if (t.actividad == 'DEMO-04') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: (t.cuchillaModo != null && cuchillaAccionesDemo.contains(t.cuchillaModo)) ? t.cuchillaModo : null,
              decoration: const InputDecoration(labelText: 'Accion'),
              items: cuchillaAccionesDemo.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() {
                t.cuchillaModo = v;
                if (t.cuchillaModo != 'Cambio de cuchillas') {
                  t.cuchilla = null;
                }
              }),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Seleccione accion';
                return null;
              },
            ),
            if (t.cuchillaModo == 'Cambio de cuchillas') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: t.cuchilla,
                decoration: const InputDecoration(labelText: 'Tipo de cuchilla'),
                items: cuchillasTiposDemo
                    .map((x) => DropdownMenuItem<String>(
                  value: x['id'],
                  child: Text(x['label']!),
                ))
                    .toList(),
                onChanged: (v) => setState(() => t.cuchilla = v),
                validator: (v) {
                  if (t.cuchillaModo == 'Cambio de cuchillas' && (v == null || v.isEmpty)) return 'Seleccione cuchilla';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 8),
            Text(
              (t.cuchillaModo == 'Mantenimiento')
                  ? 'Mantenimiento'
                  : (t.cuchillaModo == 'En espera')
                  ? 'En espera'
                  : 'Cambio de cuchillas',
            ),
          ],
        ]),
      ),
    );
  }
}
