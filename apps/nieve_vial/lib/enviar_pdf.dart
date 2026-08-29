import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// ========================= CONFIG =========================

const bool demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
const String apiBase = String.fromEnvironment('NIEVE_BACKEND_URL');
String get sendUrl => '$apiBase/api/nieve/partes';

// si no usas token, pon null
const String xApiToken = String.fromEnvironment('NIEVE_API_TOKEN');

const int retentionDays = 7;

const String payloadSource = 'nieve_vial1';
const bool payloadConfirmado = false;
const String payloadStatus = 'pending';

const Duration httpTimeout = Duration(seconds: 25);
const Duration healthTimeout = Duration(seconds: 8);

const int maxOperarios = 3;

// ========================= MODELOS =========================

class OperarioParte {
  final int? id; // id local (tabla operarios_parte)
  final int parteId;
  String nombre;
  double? horasNormal;
  double? horasExtra;

  OperarioParte({
    this.id,
    required this.parteId,
    required this.nombre,
    this.horasNormal,
    this.horasExtra,
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre.trim(),
    'horas_normal': horasNormal,
    'horas_extra': horasExtra,
  };

  static OperarioParte fromMap(Map<String, Object?> m) {
    return OperarioParte(
      id: (m['id'] as int?),
      parteId: (m['parte_id'] as int),
      nombre: (m['nombre'] as String?) ?? '',
      horasNormal: _toDouble(m['horas_normal']),
      horasExtra: _toDouble(m['horas_extra']),
    );
  }
}

class Parte {
  final int id;
  final String createdAt;
  final String fechaIso;
  final String? status;

  // legado (si existe en su DB antigua)
  final String? operario;

  final int? matriculaId;
  final int? kmInicio;
  final int? kmFin;
  final int? horasInicio;
  final int? horasFin;

  final double? gasolinaL;
  final double? adblueL;

  final String? fechaInicioParte;
  final String? horaInicioParte;
  final String? fechaFinParte;
  final String? horaFinParte;

  List<Tramo> tramos;
  List<OperarioParte> operariosParte;

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
    this.tramos = const [],
    this.operariosParte = const [],
  });

  String get operarioDisplay {
    if (operariosParte.isNotEmpty) {
      return operariosParte
          .map((o) => o.nombre.trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
    }
    return operario ?? '';
  }

  static Parte fromMap(Map<String, Object?> m) {
    return Parte(
      id: (m['id'] as int),
      createdAt: (m['created_at'] as String?) ?? '',
      fechaIso: (m['fecha_iso'] as String?) ?? '',
      status: (m['status'] as String?),
      operario: (m['operario'] as String?),
      matriculaId: (m['matricula_id'] as int?),
      kmInicio: (m['km_inicio'] as int?),
      kmFin: (m['km_fin'] as int?),
      horasInicio: (m['horas_inicio'] as int?),
      horasFin: (m['horas_fin'] as int?),
      gasolinaL: _toDouble(m['gasolina_l']),
      adblueL: _toDouble(m['adblue_l']),
      fechaInicioParte: (m['fecha_inicio_parte'] as String?),
      horaInicioParte: (m['hora_inicio_parte'] as String?),
      fechaFinParte: (m['fecha_fin_parte'] as String?),
      horaFinParte: (m['hora_fin_parte'] as String?),
    );
  }
}

class Tramo {
  final int id;
  final int parteId;

  final int? numero;
  final String? actividad;
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

  final double? horasNormal;
  final double? horasExtra;

  final int? orden;

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
    this.siloId,
    this.consumo,
    this.clca,
    this.materialSolido,
    this.consumoSalT,
    this.consumoSalmueraL,
    this.clcaKg,
    this.cuchillaModo,
    this.cuchilla,
    this.horasNormal,
    this.horasExtra,
    this.orden,
  });

  static Tramo fromMap(Map<String, Object?> m) {
    return Tramo(
      id: (m['id'] as int),
      parteId: (m['parte_id'] as int),
      numero: (m['numero'] as int?),
      actividad: (m['actividad'] as String?),
      ctra: (m['ctra'] as String?),
      pkIni: (m['pk_ini'] as int?),
      mIni: (m['m_ini'] as int?),
      pkFin: (m['pk_fin'] as int?),
      mFin: (m['m_fin'] as int?),
      hora: (m['hora'] as String?),
      horaFin: (m['hora_fin'] as String?),
      material: (m['material'] as String?),
      siloId: (m['silo_id'] as int?),
      consumo: _toDouble(m['consumo']),
      clca: _toDouble(m['clca']),
      materialSolido: (m['material_solido'] as String?),
      consumoSalT: _toDouble(m['consumo_sal_t']),
      consumoSalmueraL: _toDouble(m['consumo_salmuera_l']),
      clcaKg: _toDouble(m['clca_kg']),
      cuchillaModo: (m['cuchilla_modo'] as String?),
      cuchilla: (m['cuchilla'] as String?),
      horasNormal: _toDouble(m['horas_normal']),
      horasExtra: _toDouble(m['horas_extra']),
      orden: (m['orden'] as int?),
    );
  }
}

double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}

String _dateOnlyIso(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

// ========================= DB LOCAL (SQLITE) =========================

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get db async {
    final cached = _db;
    if (cached != null) return cached;

    final base = await getDatabasesPath();
    final path = p.join(base, 'nieve_vial.db');

    final opened = await openDatabase(
      path,
      // IMPORTANTE: no bajar versión. Debe ser >= a la de meter.dart / revisar.dart
      version: 9,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrateDefensive(db);
      },
      onOpen: (db) async {
        // FIX CLAVE: aunque no suba la versión, asegurar tablas/columnas mínimas
        await _migrateDefensive(db);
      },
    );

    _db = opened;
    return opened;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS partes(
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tramos(
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS operarios_parte(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parte_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        horas_normal REAL,
        horas_extra REAL,
        FOREIGN KEY(parte_id) REFERENCES partes(id) ON DELETE CASCADE
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_partes_fecha ON partes(fecha_iso);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tramos_parte ON tramos(parte_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_operarios_parte ON operarios_parte(parte_id);',
    );
  }

  Future<void> _migrateDefensive(Database db) async {
    Future<bool> hasTable(String table) async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table],
      );
      return rows.isNotEmpty;
    }

    Future<bool> hasCol(String table, String col) async {
      if (!await hasTable(table)) return false;
      final rows = await db.rawQuery('PRAGMA table_info($table)');
      return rows.any((r) => (r['name'] as String?) == col);
    }

    // Si no existen tablas base, créalas completas
    if (!await hasTable('partes') || !await hasTable('tramos')) {
      await _createSchema(db);
      return;
    }

    // Asegurar tabla operarios_parte
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operarios_parte(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parte_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        horas_normal REAL,
        horas_extra REAL,
        FOREIGN KEY(parte_id) REFERENCES partes(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_operarios_parte ON operarios_parte(parte_id);',
    );

    // Columnas de partes (compat)
    if (!await hasCol('partes', 'fecha_iso')) {
      await db.execute('ALTER TABLE partes ADD COLUMN fecha_iso TEXT;');
    }
    if (!await hasCol('partes', 'status')) {
      await db.execute('ALTER TABLE partes ADD COLUMN status TEXT;');
    }
    if (!await hasCol('partes', 'fecha_inicio_parte')) {
      await db.execute(
        'ALTER TABLE partes ADD COLUMN fecha_inicio_parte TEXT;',
      );
    }
    if (!await hasCol('partes', 'hora_inicio_parte')) {
      await db.execute('ALTER TABLE partes ADD COLUMN hora_inicio_parte TEXT;');
    }
    if (!await hasCol('partes', 'fecha_fin_parte')) {
      await db.execute('ALTER TABLE partes ADD COLUMN fecha_fin_parte TEXT;');
    }
    if (!await hasCol('partes', 'hora_fin_parte')) {
      await db.execute('ALTER TABLE partes ADD COLUMN hora_fin_parte TEXT;');
    }

    // Columnas de tramos (compat)
    if (!await hasCol('tramos', 'hora')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN hora TEXT;');
    }
    if (!await hasCol('tramos', 'hora_fin')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN hora_fin TEXT;');
    }
    if (!await hasCol('tramos', 'material')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN material TEXT;');
    }
    if (!await hasCol('tramos', 'silo_id')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN silo_id INTEGER;');
    }
    if (!await hasCol('tramos', 'consumo')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN consumo REAL;');
    }
    if (!await hasCol('tramos', 'clca')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN clca REAL;');
    }
    if (!await hasCol('tramos', 'consumo_sal_t')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN consumo_sal_t REAL;');
    }
    if (!await hasCol('tramos', 'consumo_salmuera_l')) {
      await db.execute(
        'ALTER TABLE tramos ADD COLUMN consumo_salmuera_l REAL;',
      );
    }
    if (!await hasCol('tramos', 'clca_kg')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN clca_kg REAL;');
    }
    if (!await hasCol('tramos', 'cuchilla')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN cuchilla TEXT;');
    }
    if (!await hasCol('tramos', 'horas_normal')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN horas_normal REAL;');
    }
    if (!await hasCol('tramos', 'horas_extra')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN horas_extra REAL;');
    }
    if (!await hasCol('tramos', 'orden')) {
      await db.execute('ALTER TABLE tramos ADD COLUMN orden INTEGER;');
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_partes_fecha ON partes(fecha_iso);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tramos_parte ON tramos(parte_id);',
    );
  }
}

class LocalRepo {
  Future<void> _ensureOperariosTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operarios_parte(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parte_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        horas_normal REAL,
        horas_extra REAL,
        FOREIGN KEY(parte_id) REFERENCES partes(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_operarios_parte ON operarios_parte(parte_id);',
    );
  }

  Future<List<Parte>> listPendientes({String? fechaIso}) async {
    final db = await LocalDb.instance.db;

    final where = <String>['(status IS NULL OR status = ?)'];
    final args = <Object?>['pending'];

    if (fechaIso != null && fechaIso.isNotEmpty) {
      where.add('fecha_iso = ?');
      args.add(fechaIso);
    }

    final rows = await db.query(
      'partes',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'fecha_iso DESC, id DESC',
    );

    final partes = rows.map(Parte.fromMap).toList();

    for (final p in partes) {
      p.operariosParte = await listOperariosParte(p.id);
    }

    return partes;
  }

  Future<List<OperarioParte>> listOperariosParte(int parteId) async {
    final db = await LocalDb.instance.db;
    try {
      await _ensureOperariosTable(db);
      final rows = await db.query(
        'operarios_parte',
        where: 'parte_id = ?',
        whereArgs: [parteId],
        orderBy: 'id ASC',
      );
      return rows.map(OperarioParte.fromMap).toList();
    } catch (_) {
      return <OperarioParte>[];
    }
  }

  Future<void> saveOperariosParte(int parteId, List<OperarioParte> ops) async {
    final db = await LocalDb.instance.db;
    await _ensureOperariosTable(db);

    await db.transaction((txn) async {
      await txn.delete(
        'operarios_parte',
        where: 'parte_id = ?',
        whereArgs: [parteId],
      );
      for (final o in ops) {
        final nombre = o.nombre.trim();
        if (nombre.isEmpty) continue;
        await txn.insert('operarios_parte', {
          'parte_id': parteId,
          'nombre': nombre,
          'horas_normal': o.horasNormal,
          'horas_extra': o.horasExtra,
        });
      }
    });
  }

  Future<Parte> getParteConTramos(int parteId) async {
    final db = await LocalDb.instance.db;

    final pRows = await db.query(
      'partes',
      where: 'id = ?',
      whereArgs: [parteId],
      limit: 1,
    );
    if (pRows.isEmpty) throw Exception('Parte no encontrado');
    final parte = Parte.fromMap(pRows.first);

    final tRows = await db.query(
      'tramos',
      where: 'parte_id = ?',
      whereArgs: [parteId],
      orderBy: 'id ASC',
    );

    parte.tramos = tRows.map(Tramo.fromMap).toList();
    parte.operariosParte = await listOperariosParte(parteId);

    // Compatibilidad: si no hay operarios nuevos pero existe campo legado
    if (parte.operariosParte.isEmpty &&
        (parte.operario ?? '').trim().isNotEmpty) {
      parte.operariosParte = [
        OperarioParte(
          parteId: parteId,
          nombre: parte.operario!.trim(),
          horasNormal: null,
          horasExtra: null,
        ),
      ];
    }

    return parte;
  }

  Future<void> markEnviado(int parteId) async {
    final db = await LocalDb.instance.db;
    await db.update(
      'partes',
      {'status': 'sent'},
      where: 'id = ?',
      whereArgs: [parteId],
    );
  }

  Future<void> deleteParte(int parteId) async {
    final db = await LocalDb.instance.db;
    await db.transaction((txn) async {
      try {
        await txn.delete(
          'operarios_parte',
          where: 'parte_id = ?',
          whereArgs: [parteId],
        );
      } catch (_) {}
      await txn.delete('tramos', where: 'parte_id = ?', whereArgs: [parteId]);
      await txn.delete('partes', where: 'id = ?', whereArgs: [parteId]);
    });
  }

  Future<void> cleanupOld() async {
    final db = await LocalDb.instance.db;
    final cutoff = DateTime.now().subtract(const Duration(days: retentionDays));
    final cutoffIso = _dateOnlyIso(cutoff);

    final old = await db.query(
      'partes',
      columns: ['id'],
      where: 'fecha_iso < ?',
      whereArgs: [cutoffIso],
    );
    if (old.isEmpty) return;

    await db.transaction((txn) async {
      for (final r in old) {
        final id = r['id'] as int;
        try {
          await txn.delete(
            'operarios_parte',
            where: 'parte_id = ?',
            whereArgs: [id],
          );
        } catch (_) {}
        await txn.delete('tramos', where: 'parte_id = ?', whereArgs: [id]);
        await txn.delete('partes', where: 'id = ?', whereArgs: [id]);
      }
    });
  }
}

// ========================= HTTP HELPERS =========================

String _maskToken(String? t) {
  if (t == null || t.isEmpty) return '(vacío)';
  if (t.length <= 6) return '***';
  return '${t.substring(0, 3)}***${t.substring(t.length - 3)}';
}

// ========================= HTTP EXPORT (JSON) =========================

Future<void> _pingHealth(
  http.Client client,
  Map<String, String> headers,
) async {
  final uri = Uri.parse('$apiBase/api/nieve/health');
  debugPrint('PING -> GET $uri headers=${headers.keys.toList()}');
  try {
    final r = await client.get(uri, headers: headers).timeout(healthTimeout);
    debugPrint('PING <- ${r.statusCode} body=${r.body}');
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Health NOK ${r.statusCode}: ${r.body}');
    }
  } catch (e, st) {
    debugPrint('PING !! ERROR: $e');
    debugPrint('$st');
    rethrow;
  }
}

Future<void> sendParteToServer(Parte parte) async {
  if (demoMode) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return;
  }
  final configuredUri = Uri.tryParse(apiBase);
  if (configuredUri == null ||
      configuredUri.scheme != 'https' ||
      !configuredUri.hasAuthority) {
    throw StateError(
      'Configura NIEVE_BACKEND_URL con tu propio servidor HTTPS.',
    );
  }

  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  headers['x-api-token'] = xApiToken;

  final uri = Uri.parse(sendUrl);

  final body = <String, dynamic>{
    'source': payloadSource,
    'confirmado': payloadConfirmado,
    'status': payloadStatus,

    // CAMPOS PLANOS (NO dentro de "parte")
    'id_local': parte.id,
    'created_at': parte.createdAt,
    'fecha_iso': parte.fechaIso,
    'operario': parte.operario,
    'matricula_id': parte.matriculaId,
    'km_inicio': parte.kmInicio,
    'km_fin': parte.kmFin,
    'horas_inicio': parte.horasInicio,
    'horas_fin': parte.horasFin,
    'gasolina_l': parte.gasolinaL,
    'adblue_l': parte.adblueL,
    'fecha_inicio_parte': parte.fechaInicioParte,
    'hora_inicio_parte': parte.horaInicioParte,
    'fecha_fin_parte': parte.fechaFinParte,
    'hora_fin_parte': parte.horaFinParte,

    'operarios': parte.operariosParte.map((o) => o.toJson()).toList(),

    'tramos': parte.tramos
        .map(
          (t) => {
            'id_local': t.id,
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
            'silo_id': t.siloId,
            'consumo': t.consumo,
            'clca': t.clca,
            'material_solido': t.materialSolido,
            'consumo_sal_t': t.consumoSalT,
            'consumo_salmuera_l': t.consumoSalmueraL,
            'clca_kg': t.clcaKg,
            'cuchilla': t.cuchilla,
            'orden': t.orden,
          },
        )
        .toList(),
  };

  final jsonBody = jsonEncode(body);

  debugPrint('SEND -> POST $uri');
  debugPrint(
    'SEND -> len=${utf8.encode(jsonBody).length} token=${_maskToken(xApiToken)}',
  );

  final client = http.Client();
  try {
    // await _pingHealth(client, headers); // opcional

    final resp = await client
        .post(uri, headers: headers, body: jsonBody)
        .timeout(httpTimeout);

    debugPrint(
      'SEND <- ${resp.statusCode} headers=${resp.headers} body=${resp.body}',
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Send NOK (${resp.statusCode}): ${resp.body}');
    }
  } catch (e, st) {
    debugPrint('SEND !! ERROR: $e');
    debugPrint('$st');
    rethrow;
  } finally {
    client.close();
  }
}

// ========================= UI =========================

class EnviarPdfPage extends StatefulWidget {
  const EnviarPdfPage({super.key});
  @override
  State<EnviarPdfPage> createState() => _EnviarPdfPageState();
}

class _EnviarPdfPageState extends State<EnviarPdfPage> {
  final _repo = LocalRepo();

  Future<List<Parte>> _future = Future.value(<Parte>[]);
  String? _fechaFiltro;

  bool _sendingAll = false;
  int _sentOk = 0;
  int _sentTotal = 0;
  String _sentMsg = '';

  String get _hoy => _dateOnlyIso(DateTime.now());
  String get _ayer =>
      _dateOnlyIso(DateTime.now().subtract(const Duration(days: 1)));

  @override
  void initState() {
    super.initState();
    _future = _repo.listPendientes();
    _init();
  }

  Future<void> _init() async {
    await _repo.cleanupOld();
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.listPendientes(fechaIso: _fechaFiltro);
    });
  }

  Future<void> _editOperarios(Parte p) async {
    final full = await _repo.getParteConTramos(p.id);

    final ops = List<OperarioParte>.from(
      full.operariosParte.map(
        (o) => OperarioParte(
          id: o.id,
          parteId: p.id,
          nombre: o.nombre,
          horasNormal: o.horasNormal,
          horasExtra: o.horasExtra,
        ),
      ),
    );

    if (ops.isEmpty) {
      ops.add(
        OperarioParte(
          parteId: p.id,
          nombre: '',
          horasNormal: null,
          horasExtra: null,
        ),
      );
    }

    double? parseD(String s) {
      final t = s.trim().replaceAll(',', '.');
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Operarios (máx 3)'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (int i = 0; i < ops.length; i++) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                initialValue: ops[i].nombre,
                                decoration: InputDecoration(
                                  labelText: 'Operario ${i + 1}',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (v) => ops[i].nombre = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue:
                                    ops[i].horasNormal?.toString() ?? '',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Normales',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (v) =>
                                    ops[i].horasNormal = parseD(v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue:
                                    ops[i].horasExtra?.toString() ?? '',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Extra',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (v) => ops[i].horasExtra = parseD(v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: ops.length <= 1
                                  ? null
                                  : () {
                                      setStateDialog(() => ops.removeAt(i));
                                    },
                              icon: const Icon(Icons.delete),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: ops.length >= maxOperarios
                                ? null
                                : () {
                                    setStateDialog(() {
                                      ops.add(
                                        OperarioParte(
                                          parteId: p.id,
                                          nombre: '',
                                          horasNormal: null,
                                          horasExtra: null,
                                        ),
                                      );
                                    });
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir operario'),
                          ),
                          const SizedBox(width: 12),
                          Text('(${ops.length}/$maxOperarios)'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Se enviarán solo operarios con nombre rellenado.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      final cleaned = ops
          .map(
            (o) => OperarioParte(
              parteId: p.id,
              nombre: o.nombre.trim(),
              horasNormal: o.horasNormal,
              horasExtra: o.horasExtra,
            ),
          )
          .where((o) => o.nombre.isNotEmpty)
          .take(maxOperarios)
          .toList();

      await _repo.saveOperariosParte(p.id, cleaned);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Operarios guardados')));
      await _reload();
    }
  }

  Future<void> _sendOne(Parte p) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Enviando...')));
      final full = await _repo.getParteConTramos(p.id);
      await sendParteToServer(full);
      await _repo.markEnviado(full.id);
      messenger.showSnackBar(const SnackBar(content: Text('Enviado OK')));
      await _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
    }
  }

  Future<void> _delete(Parte p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar parte'),
        content: const Text(
          'Se borrará el parte y todos sus tramos/operarios.',
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

    await _repo.deleteParte(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Borrado')));
    await _reload();
  }

  Future<void> _sendAll(List<Parte> list) async {
    if (_sendingAll || list.isEmpty) return;

    setState(() {
      _sendingAll = true;
      _sentOk = 0;
      _sentTotal = list.length;
      _sentMsg = 'Enviando partes...';
    });

    BuildContext? dialogCtx;
    StateSetter? setDialog;
    bool dialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogCtx = ctx;
        return StatefulBuilder(
          builder: (ctx, sd) {
            setDialog = sd;
            return AlertDialog(
              title: const Text('Enviando partes'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _sentMsg,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$_sentOk/$_sentTotal OK',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('Espere por favor...'),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    void updateDialog(VoidCallback fn) {
      final sd = setDialog;
      if (sd != null && dialogOpen) sd(fn);
    }

    int ok = 0;

    for (final p in list) {
      if (!mounted) break;

      updateDialog(() {
        _sentMsg = 'Enviando parte #${p.id}...';
        _sentOk = ok;
      });

      try {
        final full = await _repo.getParteConTramos(p.id);
        await sendParteToServer(full);
        await _repo.markEnviado(full.id);
        ok++;

        updateDialog(() {
          _sentOk = ok;
          _sentMsg = 'Parte #${p.id} enviado OK';
        });
      } catch (e) {
        updateDialog(() {
          _sentOk = ok;
          _sentMsg = 'Error en parte #${p.id}: $e';
        });
      }
    }

    if (dialogCtx != null && dialogOpen) {
      dialogOpen = false;
      Navigator.of(dialogCtx!).pop();
    }

    if (!mounted) return;

    setState(() => _sendingAll = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Envío masivo terminado: $ok/${list.length} OK')),
    );

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final filtros = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('Todas')),
      DropdownMenuItem(value: _hoy, child: const Text('Hoy')),
      DropdownMenuItem(value: _ayer, child: const Text('Ayer')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviar (pendientes)'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                const Text('Fecha'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _fechaFiltro,
                    items: filtros,
                    onChanged: (v) {
                      setState(() => _fechaFiltro = v);
                      _reload();
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Parte>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError)
                  return Center(child: Text('Error: ${snap.error}'));

                final list = snap.data ?? [];
                if (list.isEmpty)
                  return const Center(child: Text('No hay partes pendientes'));

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final pte = list[i];

                          final opsTxt = (pte.operariosParte.isEmpty)
                              ? (pte.operario ?? '-')
                              : pte.operariosParte
                                    .map((o) => o.nombre)
                                    .join(', ');

                          final sub =
                              'Fecha: ${pte.fechaIso} • Operarios: ${opsTxt.isEmpty ? '-' : opsTxt} • Matricula ID: ${pte.matriculaId ?? '-'}';

                          return ListTile(
                            title: Text('Parte #${pte.id}'),
                            subtitle: Text(sub),
                            trailing: PopupMenuButton<String>(
                              onSelected: (k) {
                                if (k == 'ops') _editOperarios(pte);
                                if (k == 'send') _sendOne(pte);
                                if (k == 'delete') _delete(pte);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'ops',
                                  child: Text('Operarios (máx 3)'),
                                ),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'send',
                                  child: Text('Enviar al servidor'),
                                ),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Borrar'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: (_sendingAll || list.isEmpty)
                              ? null
                              : () => _sendAll(list),
                          icon: const Icon(Icons.cloud_upload),
                          label: Text(
                            _sendingAll
                                ? 'Enviando...'
                                : 'ENVIAR TODOS (${list.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
