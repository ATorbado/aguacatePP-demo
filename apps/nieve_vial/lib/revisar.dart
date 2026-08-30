import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// ========================= LIMITES PK POR CARRETERA =========================
// Unidades: metros totales (pk*1000 + m)
const int _pkSnapUmbralMetros = 21000; // 21 km

const Map<String, ({int minM, int maxM})> _pkBounds = {
  'V-001': (minM: 0, maxM: 10000),
  'V-002': (minM: 10000, maxM: 20000),
  'V-003': (minM: 20000, maxM: 30000),
  'V-004': (minM: 30000, maxM: 40000),
  'V-005': (minM: 40000, maxM: 50000),
  'V-006': (minM: 50000, maxM: 60000),
  'V-007': (minM: 60000, maxM: 70000),
};

// ========================= ADAPTADOR NUMEROS =========================
// - Reemplaza + por ,
// - Borra espacios
// - Ejemplos:
//   131 +740 -> 131,740
//   131,740 -> 131,740
String adaptarNumerosMas(String s) {
  return s.replaceAll(' ', '').replaceAll('+', ',');
}

// ========================= CONFIG / DATOS =========================

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

String matriculaFromId(int? id) {
  if (id == null) return '-';
  final sId = id.toString();
  for (final m in matriculas) {
    if (m['id'] == sId) return m['label'] ?? sId;
  }
  return sId;
}

// ========================= MODELOS =========================

class Parte {
  int id; // autoincrement local
  DateTime createdAt;
  String? status; // pending | sent | archived
  String fechaIso; // yyyy-MM-dd (dia del parte)
  String? operario;
  int? matriculaId;

  int? kmInicio;
  int? kmFin;
  int? horasInicio; // minutos acumulados reales
  int? horasFin;

  double? gasolinaL;
  double? adblueL;

  // Para mostrar en revisar (si los guardas en local)
  String? fechaInicioParte; // yyyy-MM-dd
  String? horaInicioParte; // HH:mm
  String? fechaFinParte; // yyyy-MM-dd
  String? horaFinParte; // HH:mm

  // Campos extra (compat con meter/enviar)
  String? horasTrabajador;
  String? horasExtraTrabajador;
  String? observaciones;

  List<Tramo> tramos;

  Parte({
    required this.id,
    required this.createdAt,
    required this.fechaIso,
    this.status,
    this.operario,
    this.matriculaId,
    this.kmInicio,
    this.kmFin,
    this.horasInicio,
    this.horasFin,
    this.gasolinaL,
    this.adblueL,
    this.fechaInicioParte,
    this.horaInicioParte,
    this.fechaFinParte,
    this.horaFinParte,
    this.horasTrabajador,
    this.horasExtraTrabajador,
    this.observaciones,
    List<Tramo>? tramos,
  }) : tramos = tramos ?? [];
}

class Tramo {
  int id; // autoincrement local
  int parteId;
  int? numero;
  String? actividad;
  String? ctra;
  int? pkIni;
  int? mIni;
  int? pkFin;
  int? mFin;
  String? hora; // HH:mm
  String? horaFin; // HH:mm

  String? material;
  double? consumo;
  double? clca;

  String? materialSolido;
  int? siloId;
  double? consumoSalT;
  double? consumoSalmueraL;
  double? clcaKg;

  // Campos extra (compat con meter/enviar)
  String? cuchillaModo;
  String? cuchilla;
  double? horasNormal;
  double? horasExtra;
  int? orden;

  Tramo({
    required this.id,
    required this.parteId,
    this.numero,
    this.actividad,
    this.ctra,
    this.pkIni,
    this.mIni,
    this.pkFin,
    this.mFin,
    this.hora,
    this.horaFin,
    this.material,
    this.consumo,
    this.clca,
    this.materialSolido,
    this.siloId,
    this.consumoSalT,
    this.consumoSalmueraL,
    this.clcaKg,
    this.cuchillaModo,
    this.cuchilla,
    this.horasNormal,
    this.horasExtra,
    this.orden,
  });

  int? get inicioEnMetros =>
      (pkIni != null && mIni != null) ? pkIni! * 1000 + mIni! : null;

  int? get finEnMetros =>
      (pkFin != null && mFin != null) ? pkFin! * 1000 + mFin! : null;

  double get salSolidaT {
    if (consumoSalT != null) return consumoSalT!;
    if (material == 'Sal de mina' ||
        material == 'Sal marina' ||
        material == 'Sal de silo') {
      return consumo ?? 0;
    }
    return 0;
  }

  double get salmueraL {
    if (consumoSalmueraL != null) return consumoSalmueraL!;
    if (material == 'Salmuera') return consumo ?? 0;
    return 0;
  }

  double get clcaTotalKg => clcaKg ?? clca ?? 0;
}

// ========================= SQLITE (DB + REPO) =========================

class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    final path = p.join(base, 'nieve_vial.db');

    return openDatabase(
      path,
      // IMPORTANTE: alinear con meter.dart (v10)
      version: 10,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        Future<bool> hasCol(String table, String col) async {
          final rows = await db.rawQuery('PRAGMA table_info($table)');
          return rows.any((r) => (r['name'] as String?) == col);
        }

        // ---- PARTES ----
        if (!await hasCol('partes', 'fecha_iso')) {
          await db.execute('ALTER TABLE partes ADD COLUMN fecha_iso TEXT');
        }
        if (!await hasCol('partes', 'fecha_inicio_parte')) {
          await db.execute('ALTER TABLE partes ADD COLUMN fecha_inicio_parte TEXT');
        }
        if (!await hasCol('partes', 'hora_inicio_parte')) {
          await db.execute('ALTER TABLE partes ADD COLUMN hora_inicio_parte TEXT');
        }
        if (!await hasCol('partes', 'fecha_fin_parte')) {
          await db.execute('ALTER TABLE partes ADD COLUMN fecha_fin_parte TEXT');
        }
        if (!await hasCol('partes', 'hora_fin_parte')) {
          await db.execute('ALTER TABLE partes ADD COLUMN hora_fin_parte TEXT');
        }
        if (!await hasCol('partes', 'horas_trabajador')) {
          await db.execute('ALTER TABLE partes ADD COLUMN horas_trabajador TEXT');
        }
        if (!await hasCol('partes', 'horas_extra_trabajador')) {
          await db.execute('ALTER TABLE partes ADD COLUMN horas_extra_trabajador TEXT');
        }
        if (!await hasCol('partes', 'observaciones')) {
          await db.execute('ALTER TABLE partes ADD COLUMN observaciones TEXT');
        }

        // ---- TRAMOS ----
        if (!await hasCol('tramos', 'hora')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN hora TEXT');
        }
        if (!await hasCol('tramos', 'hora_fin')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN hora_fin TEXT');
        }

        if (!await hasCol('tramos', 'material_solido')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN material_solido TEXT');
        }
        if (!await hasCol('tramos', 'silo_id')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN silo_id INTEGER');
        }
        if (!await hasCol('tramos', 'consumo_sal_t')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN consumo_sal_t REAL');
        }
        if (!await hasCol('tramos', 'consumo_salmuera_l')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN consumo_salmuera_l REAL');
        }
        if (!await hasCol('tramos', 'clca_kg')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN clca_kg REAL');
        }

        // Compat con meter/enviar
        if (!await hasCol('tramos', 'cuchilla_modo')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN cuchilla_modo TEXT');
        }
        if (!await hasCol('tramos', 'cuchilla')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN cuchilla TEXT');
        }
        if (!await hasCol('tramos', 'horas_normal')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN horas_normal REAL');
        }
        if (!await hasCol('tramos', 'horas_extra')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN horas_extra REAL');
        }
        if (!await hasCol('tramos', 'orden')) {
          await db.execute('ALTER TABLE tramos ADD COLUMN orden INTEGER');
        }
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE partes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            status TEXT,
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
            observaciones TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE tramos (
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
            consumo REAL,
            clca REAL,

            material_solido TEXT,
            silo_id INTEGER,
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

        await db.execute('CREATE INDEX idx_partes_fecha ON partes(fecha_iso);');
        await db.execute('CREATE INDEX idx_tramos_parte ON tramos(parte_id);');
      },
    );
  }
}

class LocalPartesRepo {
  Future<List<Parte>> listPartesByFecha(String fechaIso) async {
    final db = await LocalDb.instance.db;
    final rows = await db.query(
      'partes',
      where: 'fecha_iso = ? AND (status IS NULL OR status != ?)',
      whereArgs: [fechaIso, 'archived'],
      orderBy: 'created_at DESC',
      limit: 200,
    );

    final res = <Parte>[];
    for (final r in rows) {
      res.add(_parteFromRow(r));
    }
    return res;
  }

  Future<Parte> getParte(int id) async {
    final db = await LocalDb.instance.db;
    final rows = await db.query(
      'partes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Parte no encontrado en local (#$id)');

    final p = _parteFromRow(rows.first);

    final trRows = await db.query(
      'tramos',
      where: 'parte_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );

    p.tramos = trRows.map(_tramoFromRow).toList();
    return p;
  }

  Future<void> saveTramos({
    required int parteId,
    required List<Tramo> tramos,
  }) async {
    final db = await LocalDb.instance.db;

    await db.transaction((txn) async {
      for (final t in tramos) {
        await txn.update(
          'tramos',
          _tramoToRow(t),
          where: 'id = ? AND parte_id = ?',
          whereArgs: [t.id, parteId],
        );
      }
    });
  }

  Future<void> setParteStatus({
    required int parteId,
    required String status,
  }) async {
    final db = await LocalDb.instance.db;
    await db.update(
      'partes',
      {'status': status},
      where: 'id = ?',
      whereArgs: [parteId],
    );
  }

  Future<void> deleteParte(int parteId) async {
    final db = await LocalDb.instance.db;

    await db.transaction((txn) async {
      await txn.delete('tramos', where: 'parte_id = ?', whereArgs: [parteId]);
      await txn.delete('partes', where: 'id = ?', whereArgs: [parteId]);
    });
  }

  Parte _parteFromRow(Map<String, Object?> r) {
    DateTime parseDt(String? s) =>
        DateTime.tryParse(s ?? '')?.toLocal() ?? DateTime.now();
    int? _i(Object? v) =>
        v == null ? null : (v is int ? v : int.tryParse('$v'));
    double? _d(Object? v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

    return Parte(
      id: _i(r['id']) ?? 0,
      createdAt: parseDt(r['created_at']?.toString()),
      status: r['status']?.toString(),
      fechaIso: r['fecha_iso']?.toString() ?? '1970-01-01',
      operario: r['operario']?.toString(),
      matriculaId: _i(r['matricula_id']),
      kmInicio: _i(r['km_inicio']),
      kmFin: _i(r['km_fin']),
      horasInicio: _i(r['horas_inicio']),
      horasFin: _i(r['horas_fin']),
      gasolinaL: _d(r['gasolina_l']),
      adblueL: _d(r['adblue_l']),
      fechaInicioParte: r['fecha_inicio_parte']?.toString(),
      horaInicioParte: r['hora_inicio_parte']?.toString(),
      fechaFinParte: r['fecha_fin_parte']?.toString(),
      horaFinParte: r['hora_fin_parte']?.toString(),
      horasTrabajador: r['horas_trabajador']?.toString(),
      horasExtraTrabajador: r['horas_extra_trabajador']?.toString(),
      observaciones: r['observaciones']?.toString(),
    );
  }

  Tramo _tramoFromRow(Map<String, Object?> r) {
    int? _i(Object? v) =>
        v == null ? null : (v is int ? v : int.tryParse('$v'));
    double? _d(Object? v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

    return Tramo(
      id: _i(r['id']) ?? 0,
      parteId: _i(r['parte_id']) ?? 0,
      numero: _i(r['numero']),
      actividad: r['actividad']?.toString(),
      ctra: r['ctra']?.toString(),
      pkIni: _i(r['pk_ini']),
      mIni: _i(r['m_ini']),
      pkFin: _i(r['pk_fin']),
      mFin: _i(r['m_fin']),
      hora: r['hora']?.toString(),
      horaFin: r['hora_fin']?.toString(),
      material: r['material']?.toString(),
      consumo: _d(r['consumo']),
      clca: _d(r['clca']),
      materialSolido: r['material_solido']?.toString(),
      siloId: _i(r['silo_id']),
      consumoSalT: _d(r['consumo_sal_t']),
      consumoSalmueraL: _d(r['consumo_salmuera_l']),
      clcaKg: _d(r['clca_kg']),
      cuchillaModo: r['cuchilla_modo']?.toString(),
      cuchilla: r['cuchilla']?.toString(),
      horasNormal: _d(r['horas_normal']),
      horasExtra: _d(r['horas_extra']),
      orden: _i(r['orden']),
    );
  }

  Map<String, Object?> _tramoToRow(Tramo t) {
    return {
      'parte_id': t.parteId,
      'numero': t.numero,
      'actividad': t.actividad,
      'ctra': t.ctra,
      'pk_ini': t.pkIni,
      'm_ini': t.mIni,
      'pk_fin': t.pkFin,
      'm_fin': t.mFin,
      'hora': t.hora,
      'hora_fin': t.horaFin,
      'material': t.material,
      'consumo': t.consumo,
      'clca': t.clca,
      'material_solido': t.materialSolido,
      'silo_id': t.siloId,
      'consumo_sal_t': t.consumoSalT,
      'consumo_salmuera_l': t.consumoSalmueraL,
      'clca_kg': t.clcaKg,
      'cuchilla_modo': t.cuchillaModo,
      'cuchilla': t.cuchilla,
      'horas_normal': t.horasNormal,
      'horas_extra': t.horasExtra,
      'orden': t.orden,
    };
  }
}

// ========================= AGRUPADO =========================

bool _isHoraValida(String s) {
  final v = s.trim();
  if (v.isEmpty) return false;
  final parts = v.split(':');
  if (parts.length < 2) return false;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return false;
  if (h < 0 || h > 23) return false;
  if (m < 0 || m > 59) return false;
  return true;
}

int? _horaToMinutes(String s) {
  if (!_isHoraValida(s)) return null;
  final parts = s.trim().split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  return h * 60 + m;
}

DateTime? _parseHoraToDate(String? s) {
  if (s == null) return null;
  final parts = s.trim().split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final total = h * 60 + m;

  const nightStart = 20 * 60 + 30; // 20:30

  final baseDay = DateTime(2000, 1, 2);
  final previousDay = baseDay.subtract(const Duration(days: 1));

  final day = (total >= nightStart) ? previousDay : baseDay;
  return DateTime(day.year, day.month, day.day, h, m);
}

String _formatHora(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm:00';
}

class TramoAgrupado {
  final String? actividad;
  final int? tramo;
  final String? ctra;
  int? pkIni;
  int? mIni;
  int? pkFin;
  int? mFin;
  String? horaIni;
  String? horaFin;
  double totalSalT;
  double totalSalmueraL;
  double totalClcaKg;
  final List<Tramo> origen;

  TramoAgrupado({
    required this.actividad,
    required this.tramo,
    this.ctra,
    this.pkIni,
    this.mIni,
    this.pkFin,
    this.mFin,
    this.horaIni,
    this.horaFin,
    this.totalSalT = 0,
    this.totalSalmueraL = 0,
    this.totalClcaKg = 0,
    List<Tramo>? origen,
  }) : origen = origen ?? [];
}

List<TramoAgrupado> agruparTramosConsecutivos(List<Tramo> tramos) {
  if (tramos.isEmpty) return [];

  final list = [...tramos];
  list.sort((a, b) {
    final na = a.numero ?? 0;
    final nb = b.numero ?? 0;
    if (na != nb) return na.compareTo(nb);
    final ia = a.inicioEnMetros ?? 0;
    final ib = b.inicioEnMetros ?? 0;
    return ia.compareTo(ib);
  });

  final res = <TramoAgrupado>[];
  TramoAgrupado? current;

  void flush() {
    if (current != null) {
      DateTime? minIni;
      DateTime? maxFin;

      for (final t in current!.origen) {
        final ini = _parseHoraToDate(t.hora);
        final fin = _parseHoraToDate(t.horaFin ?? t.hora);
        if (ini == null || fin == null) continue;

        if (minIni == null || ini.isBefore(minIni)) minIni = ini;
        if (maxFin == null || fin.isAfter(maxFin)) maxFin = fin;
      }

      if (minIni != null && maxFin != null) {
        current!
          ..horaIni = _formatHora(minIni)
          ..horaFin = _formatHora(maxFin);
      }

      res.add(current!);
    }
    current = null;
  }

  for (final t in list) {
    if (t.actividad == 'DEMO-05') {
      flush();
      res.add(
        TramoAgrupado(
          actividad: t.actividad,
          tramo: t.numero,
          ctra: t.ctra,
          pkIni: t.pkIni,
          mIni: t.mIni,
          pkFin: t.pkFin,
          mFin: t.mFin,
          horaIni: t.hora,
          horaFin: t.horaFin ?? t.hora,
          totalSalT: t.salSolidaT,
          totalSalmueraL: t.salmueraL,
          totalClcaKg: t.clcaTotalKg,
          origen: [t],
        ),
      );
      continue;
    }

    if (current == null) {
      current = TramoAgrupado(
        actividad: t.actividad,
        tramo: t.numero,
        ctra: t.ctra,
        pkIni: t.pkIni,
        mIni: t.mIni,
        pkFin: t.pkFin,
        mFin: t.mFin,
        horaIni: t.hora,
        horaFin: t.horaFin ?? t.hora,
        totalSalT: t.salSolidaT,
        totalSalmueraL: t.salmueraL,
        totalClcaKg: t.clcaTotalKg,
        origen: [t],
      );
      continue;
    }

    final mismoBloque =
        current!.actividad == t.actividad && current!.tramo == t.numero;
    if (!mismoBloque) {
      flush();
      current = TramoAgrupado(
        actividad: t.actividad,
        tramo: t.numero,
        ctra: t.ctra,
        pkIni: t.pkIni,
        mIni: t.mIni,
        pkFin: t.pkFin,
        mFin: t.mFin,
        horaIni: t.hora,
        horaFin: t.horaFin ?? t.hora,
        totalSalT: t.salSolidaT,
        totalSalmueraL: t.salmueraL,
        totalClcaKg: t.clcaTotalKg,
        origen: [t],
      );
      continue;
    }

    current!.origen.add(t);

    final iniActualM = (current!.pkIni != null && current!.mIni != null)
        ? current!.pkIni! * 1000 + current!.mIni!
        : null;
    final iniNuevoM = t.inicioEnMetros;
    if (iniActualM == null || (iniNuevoM != null && iniNuevoM < iniActualM)) {
      current!
        ..pkIni = t.pkIni
        ..mIni = t.mIni;
    }

    final finActualM = (current!.pkFin != null && current!.mFin != null)
        ? current!.pkFin! * 1000 + current!.mFin!
        : null;
    final finNuevoM = t.finEnMetros;
    if (finActualM == null || (finNuevoM != null && finNuevoM > finActualM)) {
      current!
        ..pkFin = t.pkFin
        ..mFin = t.mFin;
    }

    current!
      ..totalSalT += t.salSolidaT
      ..totalSalmueraL += t.salmueraL
      ..totalClcaKg += t.clcaTotalKg;
  }

  flush();
  return res;
}

// ========================= UI PRINCIPAL =========================

class RevisarHome extends StatefulWidget {
  final LocalPartesRepo repo;

  const RevisarHome({super.key, required this.repo});

  @override
  State<RevisarHome> createState() => _RevisarHomeState();
}

class _RevisarHomeState extends State<RevisarHome> {
  bool _hoy = true;

  String _fechaIsoSelected() {
    final now = DateTime.now();
    final d = _hoy ? now : now.subtract(const Duration(days: 1));
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  void _abrirLista() {
    final fechaIso = _fechaIsoSelected();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RevisarListPage(repo: widget.repo, fechaIso: fechaIso),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaIso = _fechaIsoSelected();

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar partes (local)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Hoy')),
                ButtonSegment(value: false, label: Text('Ayer')),
              ],
              selected: {_hoy},
              onSelectionChanged: (s) => setState(() => _hoy = s.first),
            ),
            const SizedBox(height: 16),
            Text('Fecha seleccionada: $fechaIso'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _abrirLista,
                child: const Text('Abrir partes'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nota: esta pantalla solo lee/guarda en SQLite. No se envía nada al servidor.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ========================= LISTA DE PARTES =========================

class RevisarListPage extends StatefulWidget {
  final LocalPartesRepo repo;
  final String fechaIso;

  const RevisarListPage({
    super.key,
    required this.repo,
    required this.fechaIso,
  });

  @override
  State<RevisarListPage> createState() => _RevisarListPageState();
}

class _RevisarListPageState extends State<RevisarListPage> {
  late Future<List<Parte>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.listPartesByFecha(widget.fechaIso);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.repo.listPartesByFecha(widget.fechaIso);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Partes locales (${widget.fechaIso})'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Parte>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final partes = (snap.data ?? [])
              .where((p) => (p.status ?? '').toLowerCase() != 'archived')
              .toList();

          if (partes.isEmpty) {
            return const Center(
              child: Text('No hay partes locales para esa fecha'),
            );
          }

          return ListView.separated(
            itemCount: partes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = partes[i];
              return ListTile(
                title: Text(
                  'Parte local #${p.id} • Mat ${matriculaFromId(p.matriculaId)}',
                ),
                subtitle: Text(
                  'Operario: ${p.operario ?? '-'} • Estado: ${p.status ?? 'pending'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          RevisarDetailPage(repo: widget.repo, parteId: p.id),
                    ),
                  );
                  if (changed == true) {
                    await _reload();
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ========================= DETALLE + EDICION =========================

class RevisarDetailPage extends StatefulWidget {
  final LocalPartesRepo repo;
  final int parteId;

  const RevisarDetailPage({
    super.key,
    required this.repo,
    required this.parteId,
  });

  @override
  State<RevisarDetailPage> createState() => _RevisarDetailPageState();
}

class _RevisarDetailPageState extends State<RevisarDetailPage> {
  Parte? _parte;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await widget.repo.getParte(widget.parteId);
      setState(() {
        _parte = p;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String? _validaHorasTramos(Parte p) {
    for (final t in p.tramos) {
      final hIni = (t.hora ?? '').trim();
      final hFin = (t.horaFin ?? '').trim();

      if (!_isHoraValida(hIni) || !_isHoraValida(hFin)) {
        return 'Todos los tramos deben tener hora inicio y hora fin (HH:mm)';
      }

      final iniM = _horaToMinutes(hIni);
      final finM = _horaToMinutes(hFin);
      if (iniM != null && finM != null && finM < iniM) {
        return 'Hay tramos con hora fin anterior a hora inicio';
      }
    }
    return null;
  }

  Future<void> _guardarTramos() async {
    final p = _parte;
    if (p == null) return;

    final err = _validaHorasTramos(p);
    if (err != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repo.saveTramos(parteId: p.id, tramos: p.tramos);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tramos guardados en local')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _borrar() async {
    final p = _parte;
    if (p == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar parte'),
        content: const Text(
          'Se borrará el parte y todos sus tramos. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await widget.repo.deleteParte(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Parte borrado')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _parte;

    return Scaffold(
      appBar: AppBar(
        title: Text('Parte local #${widget.parteId}'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _buildBody(p),
      bottomNavigationBar: p == null
          ? null
          : Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _borrar,
                child: const Text('Borrar parte'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _guardarTramos,
                child: Text(_saving ? 'Guardando...' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Parte? p) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    if (p == null) return const Center(child: Text('Parte no encontrado'));

    final agrupados = agruparTramosConsecutivos(
      p.tramos
          .where((t) => t.actividad == 'DEMO-01' || t.actividad == 'DEMO-02')
          .toList(),
    );

    String fechaParteStr = p.fechaIso;
    if ((p.fechaInicioParte != null && p.horaInicioParte != null) ||
        (p.fechaFinParte != null && p.horaFinParte != null)) {
      final a = '${p.fechaInicioParte ?? '-'} ${p.horaInicioParte ?? '-'}';
      final b = '${p.fechaFinParte ?? '-'} ${p.horaFinParte ?? '-'}';
      fechaParteStr = '$a → $b';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Camión', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Fecha parte: $fechaParteStr'),
          Text('Operario: ${p.operario ?? '-'}'),
          Text('Matrícula: ${matriculaFromId(p.matriculaId)}'),
          Text('KM: ${p.kmInicio ?? '-'} → ${p.kmFin ?? '-'}'),
          Text('Horas contador (min): ${p.horasInicio ?? '-'} → ${p.horasFin ?? '-'}'),
          const SizedBox(height: 16),

          Text('Tramos agrupados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (agrupados.isEmpty) const Text('Sin tramos DEMO-01/DEMO-02 para agrupar.'),
          if (agrupados.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: agrupados.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = agrupados[index];
                final pkIniStr = t.pkIni == null ? '-' : '${t.pkIni},${t.mIni ?? 0}';
                final pkFinStr = t.pkFin == null ? '-' : '${t.pkFin},${t.mFin ?? 0}';
                final horasStr = '${t.horaIni ?? '-'} → ${t.horaFin ?? '-'}';

                return ListTile(
                  title: Text('${t.actividad ?? '-'} - tramo ${t.tramo ?? '-'} - ${t.ctra ?? ''}'),
                  subtitle: Text(
                    'PK $pkIniStr → $pkFinStr\n'
                        'Horas tramo: $horasStr\n'
                        'Sal sólida: ${t.totalSalT.toStringAsFixed(2)} t\n'
                        'Salmuera: ${t.totalSalmueraL.toStringAsFixed(0)} L\n'
                        'CLCA: ${t.totalClcaKg.toStringAsFixed(0)} kg\n'
                        'Tramos originales: ${t.origen.length}',
                  ),
                );
              },
            ),

          const SizedBox(height: 24),
          Text('Tramos editables', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: p.tramos.length,
            itemBuilder: (context, index) {
              final t = p.tramos[index];
              return _TramoEditCard(tramo: t);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ========================= TARJETA EDICION TRAMO =========================

class _TramoEditCard extends StatefulWidget {
  final Tramo tramo;

  const _TramoEditCard({required this.tramo});

  @override
  State<_TramoEditCard> createState() => _TramoEditCardState();
}

class _TramoEditCardState extends State<_TramoEditCard> {
  late final TextEditingController _actCtrl;
  late final TextEditingController _numCtrl;

  late final TextEditingController _ctraCtrl;
  late final TextEditingController _pkIniCtrl;
  late final TextEditingController _mIniCtrl;
  late final TextEditingController _pkFinCtrl;
  late final TextEditingController _mFinCtrl;

  late final TextEditingController _horaIniCtrl;
  late final TextEditingController _horaFinCtrl;

  late final TextEditingController _salTCtrl;
  late final TextEditingController _salmueraCtrl;
  late final TextEditingController _clcaCtrl;

  String? _horaErr;
  String? _horaFinErr;

  bool _updating = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tramo;

    _actCtrl = TextEditingController(text: t.actividad ?? '');
    _numCtrl = TextEditingController(text: t.numero?.toString() ?? '');

    _ctraCtrl = TextEditingController(text: t.ctra ?? '');
    _pkIniCtrl = TextEditingController(text: t.pkIni?.toString() ?? '');
    _mIniCtrl = TextEditingController(text: t.mIni?.toString() ?? '');
    _pkFinCtrl = TextEditingController(text: t.pkFin?.toString() ?? '');
    _mFinCtrl = TextEditingController(text: t.mFin?.toString() ?? '');

    _horaIniCtrl = TextEditingController(text: t.hora ?? '');
    _horaFinCtrl = TextEditingController(text: t.horaFin ?? '');

    _salTCtrl = TextEditingController(text: t.consumoSalT?.toString() ?? '');
    _salmueraCtrl =
        TextEditingController(text: t.consumoSalmueraL?.toString() ?? '');
    _clcaCtrl = TextEditingController(text: t.clcaKg?.toString() ?? '');

    _actCtrl.addListener(() => t.actividad = _actCtrl.text.trim());
    _numCtrl.addListener(() => t.numero = int.tryParse(_numCtrl.text.trim()));

    _ctraCtrl.addListener(() {
      t.ctra = _ctraCtrl.text.trim();
      _clampPkIfNearBounds();
    });

    _pkIniCtrl.addListener(() {
      if (_updating) return;
      _applyPkPlusFormato(isIni: true);
      t.pkIni = int.tryParse(_pkIniCtrl.text.trim());
      _clampPkIfNearBounds();
    });
    _mIniCtrl.addListener(() {
      if (_updating) return;
      t.mIni = int.tryParse(_mIniCtrl.text.trim());
      _clampPkIfNearBounds();
    });

    _pkFinCtrl.addListener(() {
      if (_updating) return;
      _applyPkPlusFormato(isIni: false);
      t.pkFin = int.tryParse(_pkFinCtrl.text.trim());
      _clampPkIfNearBounds();
    });
    _mFinCtrl.addListener(() {
      if (_updating) return;
      t.mFin = int.tryParse(_mFinCtrl.text.trim());
      _clampPkIfNearBounds();
    });

    _horaIniCtrl.addListener(() {
      final s = _horaIniCtrl.text.trim();
      t.hora = s.isEmpty ? null : s;
      _revalHoras();
    });
    _horaFinCtrl.addListener(() {
      final s = _horaFinCtrl.text.trim();
      t.horaFin = s.isEmpty ? null : s;
      _revalHoras();
    });

    _salTCtrl.addListener(() => t.consumoSalT = _parseDouble(_salTCtrl.text));
    _salmueraCtrl.addListener(
            () => t.consumoSalmueraL = _parseDouble(_salmueraCtrl.text));
    _clcaCtrl.addListener(() => t.clcaKg = _parseDouble(_clcaCtrl.text));

    _revalHoras();
  }

  void _applyPkPlusFormato({required bool isIni}) {
    // Permite que el usuario pegue "131+740" o "131 +740" en el campo PK.
    // Se adapta y se reparte en PK y m.
    final pkCtrl = isIni ? _pkIniCtrl : _pkFinCtrl;
    final mCtrl = isIni ? _mIniCtrl : _mFinCtrl;

    final raw = pkCtrl.text;
    if (raw.isEmpty) return;

    final norm = adaptarNumerosMas(raw);
    if (!norm.contains(',')) return;

    final parts = norm.split(',');
    if (parts.length < 2) return;

    final pk = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (pk == null || m == null) return;

    _updating = true;
    try {
      pkCtrl.text = pk.toString();
      mCtrl.text = m.toString();
      widget.tramo
        ..pkIni = isIni ? pk : widget.tramo.pkIni
        ..mIni = isIni ? m : widget.tramo.mIni
        ..pkFin = !isIni ? pk : widget.tramo.pkFin
        ..mFin = !isIni ? m : widget.tramo.mFin;
    } finally {
      _updating = false;
    }
  }

  ({int pk, int m})? _snapPkMetros(String? ctraRaw, int? pk, int? m) {
    if (pk == null || m == null) return null;
    final ctra = (ctraRaw ?? '').trim().toUpperCase();
    final b = _pkBounds[ctra];
    if (b == null) return null;

    final val = pk * 1000 + m;
    int snapped = val;

    if (val < b.minM) {
      final diff = b.minM - val;
      if (diff <= _pkSnapUmbralMetros) snapped = b.minM;
    } else if (val > b.maxM) {
      final diff = val - b.maxM;
      if (diff <= _pkSnapUmbralMetros) snapped = b.maxM;
    } else {
      return null;
    }

    final newPk = snapped ~/ 1000;
    final newM = snapped % 1000;
    return (pk: newPk, m: newM);
  }

  void _clampPkIfNearBounds() {
    if (_updating) return;

    final t = widget.tramo;
    final ctra = t.ctra;

    final snapIni = _snapPkMetros(ctra, t.pkIni, t.mIni);
    final snapFin = _snapPkMetros(ctra, t.pkFin, t.mFin);

    if (snapIni == null && snapFin == null) return;

    _updating = true;
    try {
      if (snapIni != null) {
        t.pkIni = snapIni.pk;
        t.mIni = snapIni.m;
        _pkIniCtrl.text = snapIni.pk.toString();
        _mIniCtrl.text = snapIni.m.toString();
      }
      if (snapFin != null) {
        t.pkFin = snapFin.pk;
        t.mFin = snapFin.m;
        _pkFinCtrl.text = snapFin.pk.toString();
        _mFinCtrl.text = snapFin.m.toString();
      }
    } finally {
      _updating = false;
    }
  }

  void _revalHoras() {
    final ini = (_horaIniCtrl.text).trim();
    final fin = (_horaFinCtrl.text).trim();

    String? eIni;
    String? eFin;

    if (!_isHoraValida(ini)) eIni = 'Requerido (HH:mm)';
    if (!_isHoraValida(fin)) eFin = 'Requerido (HH:mm)';

    final iniM = _horaToMinutes(ini);
    final finM = _horaToMinutes(fin);
    if (eIni == null &&
        eFin == null &&
        iniM != null &&
        finM != null &&
        finM < iniM) {
      eFin = 'Fin < inicio';
    }

    if (mounted) {
      setState(() {
        _horaErr = eIni;
        _horaFinErr = eFin;
      });
    }
  }

  double? _parseDouble(String s) {
    if (s.trim().isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  @override
  void dispose() {
    _actCtrl.dispose();
    _numCtrl.dispose();
    _ctraCtrl.dispose();
    _pkIniCtrl.dispose();
    _mIniCtrl.dispose();
    _pkFinCtrl.dispose();
    _mFinCtrl.dispose();
    _horaIniCtrl.dispose();
    _horaFinCtrl.dispose();
    _salTCtrl.dispose();
    _salmueraCtrl.dispose();
    _clcaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tramo;
    final titulo = 'Tramo id ${t.id} • parte ${t.parteId}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _actCtrl,
                    decoration: const InputDecoration(labelText: 'Actividad'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _numCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Nº tramo'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            TextField(
              controller: _ctraCtrl,
              decoration: const InputDecoration(labelText: 'Carretera (ctra)'),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pkIniCtrl,
                    keyboardType: TextInputType.number,
                    // Permite pegar "131+740" o "131,740" (se reparte automáticamente).
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+,\s]')),
                    ],
                    decoration: const InputDecoration(labelText: 'PK inicio'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _mIniCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'm inicio'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pkFinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+,\s]')),
                    ],
                    decoration: const InputDecoration(labelText: 'PK fin'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _mFinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'm fin'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _horaIniCtrl,
                    decoration: InputDecoration(
                      labelText: 'Hora inicio (HH:mm)',
                      errorText: _horaErr,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _horaFinCtrl,
                    decoration: InputDecoration(
                      labelText: 'Hora fin (HH:mm)',
                      errorText: _horaFinErr,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _salTCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Sal sólida (t)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _salmueraCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Salmuera (L)'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            TextField(
              controller: _clcaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(labelText: 'CLCA (kg)'),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================= USO DESDE main.dart =========================
//
// Navigator.push(
//   context,
//   MaterialPageRoute(
//     builder: (_) => RevisarHome(repo: LocalPartesRepo()),
//   ),
// );
