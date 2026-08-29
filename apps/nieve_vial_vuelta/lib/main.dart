import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'recpart.dart';
import 'modifc.dart';
import 'remote_security.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final securityResult = await RemoteSecurity.check();

  runApp(
    App2ConfirmacionNieve(
      api: ApiClient(baseUrl: baseUrl, apiToken: apiToken),
      securityResult: securityResult,
    ),
  );
}

// ========================= CONFIG =========================

const String baseUrl = String.fromEnvironment('NIEVE_VUELTA_BASE_URL');
const String apiToken = String.fromEnvironment('NIEVE_VUELTA_API_TOKEN');
const bool demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

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
    if (m['id'] == sId) {
      return m['label'] ?? sId;
    }
  }
  return sId;
}

// ========================= CLIENTE API =========================

class ApiClient {
  final String baseUrl;
  final String? apiToken;
  final http.Client _c = http.Client();
  bool _demoModulacionActiva = false;
  Map<String, dynamic> _demoObjetivos = {
    'objetivo_mina': 20.0,
    'objetivo_marina': 10.0,
    'objetivo_salmuera': 5000.0,
    'objetivos_silo': <String, double>{'1': 8.0, '2': 8.0},
  };
  final List<Parte> _demoPartes = [
    Parte(
      id: 1,
      createdAt: DateTime(2026, 1, 15, 8, 30),
      status: 'pending',
      fecha: '2026-01-15',
      operario: 'Persona de ejemplo',
      matriculaId: 1,
      kmInicio: 1000,
      kmFin: 1025,
      observaciones: 'Registro ficticio para probar la interfaz.',
    ),
  ];

  ApiClient({required this.baseUrl, this.apiToken});

  void _requireConfiguration() {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      throw StateError(
        'Configura NIEVE_VUELTA_BASE_URL con tu propio servidor HTTPS.',
      );
    }
  }

  Map<String, String> _headers() {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (apiToken != null && apiToken!.isNotEmpty) {
      h['x-api-token'] = apiToken!;
    }

    return h;
  }

  Future<List<Parte>> listPartes({DateTime? from, DateTime? to}) async {
    if (demoMode) return List<Parte>.unmodifiable(_demoPartes);
    _requireConfiguration();
    final qs = <String>[];

    if (from != null) {
      qs.add('from=${from.toUtc().toIso8601String()}');
    }

    if (to != null) {
      qs.add('to=${to.toUtc().toIso8601String()}');
    }

    qs.add('limit=100');

    final uri = Uri.parse(
      '$baseUrl/api/nieve/partes${qs.isEmpty ? '' : '?${qs.join('&')}'}',
    );

    final res = await _c.get(uri, headers: _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error al listar partes: ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List?) ?? [];

    return items.map((e) => Parte.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<bool> getModulacionActiva() async {
    if (demoMode) return _demoModulacionActiva;
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/modulacion/estado');

    final res = await _c.get(uri, headers: _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Error obteniendo estado de modulación: ${res.statusCode}',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['activa'] == true;
  }

  Future<void> setModulacionActiva(bool activa) async {
    if (demoMode) {
      _demoModulacionActiva = activa;
      return;
    }
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/modulacion/estado');

    final res = await _c.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'activa': activa}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Error cambiando estado de modulación: ${res.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> getModulacionObjetivos() async {
    if (demoMode) return Map<String, dynamic>.from(_demoObjetivos);
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/modulacion/objetivos');

    final res = await _c.get(uri, headers: _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Error obteniendo objetivos de modulación: ${res.statusCode}',
      );
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> setModulacionObjetivos({
    required double objetivoMina,
    required double objetivoMarina,
    required double objetivoSalmuera,
    required Map<String, dynamic> objetivosSilo,
    required String updatedBy,
  }) async {
    if (demoMode) {
      _demoObjetivos = {
        'objetivo_mina': objetivoMina,
        'objetivo_marina': objetivoMarina,
        'objetivo_salmuera': objetivoSalmuera,
        'objetivos_silo': Map<String, dynamic>.from(objetivosSilo),
      };
      return;
    }
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/modulacion/objetivos');

    final body = {
      'objetivo_mina': objetivoMina,
      'objetivo_marina': objetivoMarina,
      'objetivo_salmuera': objetivoSalmuera,
      'objetivos_silo': objetivosSilo,
      'updated_by': updatedBy,
    };

    final res = await _c.post(uri, headers: _headers(), body: jsonEncode(body));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Error guardando objetivos de modulación: ${res.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> recalcularModulacion() async {
    if (demoMode) {
      return {
        'result': {'cambios': 0},
      };
    }
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/modulacion/recalcular');

    final res = await _c.post(uri, headers: _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error recalculando modulación: ${res.statusCode}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStockBase() async {
    if (demoMode) {
      return {
        'mina_t': 12.0,
        'marina_t': 8.0,
        'salmuera_l': 3200.0,
        'silos': <String, double>{'1': 4.0, '2': 5.0},
      };
    }
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/modulacion/stock-base');

    final res = await _c.get(uri, headers: _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error obteniendo stock base: ${res.statusCode}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> fijarStockActual({
    required String material,
    int? siloId,
    required double stockActualT,
    required double stockObjetivoT,
    required double stockActualL,
    required double stockObjetivoL,
    required String updatedBy,
  }) async {
    if (demoMode) return;
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/modulacion/fijar-stock');

    final body = {
      'material': material,
      'silo_id': siloId,
      'stock_actual_t': stockActualT,
      'stock_objetivo_t': stockObjetivoT,
      'stock_actual_l': stockActualL,
      'stock_objetivo_l': stockObjetivoL,
      'updated_by': updatedBy,
    };

    final res = await _c.post(uri, headers: _headers(), body: jsonEncode(body));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error fijando stock actual: ${res.statusCode}');
    }
  }

  Future<Parte> getParte(int id) async {
    if (demoMode) {
      return _demoPartes.firstWhere(
        (parte) => parte.id == id,
        orElse: () => throw StateError('Parte de ejemplo no encontrado.'),
      );
    }
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/partes/$id');

    final res = await _c.get(uri, headers: _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error al obtener parte: ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Parte.fromJson(body);
  }

  Future<void> patchTramos({
    required int parteId,
    required List<Tramo> tramos,
    required String updatedBy,
  }) async {
    if (demoMode) {
      final parte = await getParte(parteId);
      parte.tramos = List<Tramo>.from(tramos);
      parte.updatedBy = updatedBy;
      return;
    }
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/partes/$parteId');

    final body = {
      'tramos': tramos.map((t) => t.toJson()).toList(),
      'updated_by': updatedBy,
    };

    final res = await _c.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error al guardar tramos: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> confirmarParte({
    required int parteId,
    required String updatedBy,
  }) async {
    if (demoMode) {
      final parte = await getParte(parteId);
      parte.status = 'confirmed';
      parte.updatedBy = updatedBy;
      return;
    }
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/partes/$parteId/confirm');

    final body = {'source': 'nieve_vial2', 'updated_by': updatedBy};

    final res = await _c.post(uri, headers: _headers(), body: jsonEncode(body));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Error al confirmar parte: ${res.statusCode} ${res.body}',
      );
    }
  }

  Future<Map<String, dynamic>> exportPdfConfirmado({
    required int parteId,
    required String updatedBy,
  }) async {
    if (demoMode) {
      return {'saved_path': 'modo-demostracion/sin-archivo-real.pdf'};
    }
    _requireConfiguration();
    final uri = Uri.parse('$baseUrl/api/nieve/partes/$parteId/export-pdf');

    final res = await _c.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'updated_by': updatedBy}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error al exportar PDF: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

// ========================= MODELOS =========================

class Parte {
  final int id;
  final DateTime createdAt;
  String? status;
  String? fecha;
  String? operario;
  int? matriculaId;
  int? kmInicio;
  int? kmFin;
  int? horasInicio;
  int? horasFin;
  double? gasolinaL;
  double? adblueL;
  String? updatedBy;
  String? horasTrabajador;
  String? horasExtraTrabajador;
  String? observaciones;
  List<Tramo> tramos;

  DateTime? fechaHoraInicioParte;
  DateTime? fechaHoraFinParte;

  Parte({
    required this.id,
    required this.createdAt,
    this.status,
    this.fecha,
    this.operario,
    this.matriculaId,
    this.kmInicio,
    this.kmFin,
    this.horasInicio,
    this.horasFin,
    this.gasolinaL,
    this.adblueL,
    this.updatedBy,
    this.horasTrabajador,
    this.horasExtraTrabajador,
    this.observaciones,
    List<Tramo>? tramos,
    this.fechaHoraInicioParte,
    this.fechaHoraFinParte,
  }) : tramos = tramos ?? [];

  factory Parte.fromJson(Map<String, dynamic> j) {
    DateTime parseDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();

    int? parseInt(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

    double? parseDouble(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

    final tr = <Tramo>[];
    final rawTr = j['tramos'];

    if (rawTr is List) {
      for (final e in rawTr) {
        if (e is Map<String, dynamic>) {
          tr.add(Tramo.fromJson(e));
        }
      }
    }

    DateTime? parseFechaHora(String? fecha, String? hora) {
      if (fecha == null || hora == null) return null;
      final h = hora.length == 5 ? '$hora:00' : hora;
      return DateTime.tryParse('${fecha}T$h')?.toLocal();
    }

    return Parte(
      id: parseInt(j['id']) ?? 0,
      createdAt: parseDt(j['created_at']),
      status: j['status']?.toString(),
      fecha: j['fecha']?.toString(),
      operario: j['operario']?.toString(),
      matriculaId: parseInt(j['matricula_id']),
      kmInicio: parseInt(j['km_inicio']),
      kmFin: parseInt(j['km_fin']),
      horasInicio: parseInt(j['horas_inicio']),
      horasFin: parseInt(j['horas_fin']),
      gasolinaL: parseDouble(j['gasolina_l']),
      adblueL: parseDouble(j['adblue_l']),
      updatedBy: j['updated_by']?.toString(),
      horasTrabajador: j['horas_trabajador']?.toString(),
      horasExtraTrabajador: j['horas_extra_trabajador']?.toString(),
      observaciones: j['observaciones']?.toString(),
      tramos: tr,
      fechaHoraInicioParte: parseFechaHora(
        j['fecha_inicio_parte']?.toString(),
        j['hora_inicio_parte']?.toString(),
      ),
      fechaHoraFinParte: parseFechaHora(
        j['fecha_fin_parte']?.toString(),
        j['hora_fin_parte']?.toString(),
      ),
    );
  }
}

class Tramo {
  int? id;
  int? numero;
  String? actividad;
  String? ctra;
  int? pkIni;
  int? mIni;
  int? pkFin;
  int? mFin;
  String? hora;
  String? horaFin;

  String? material;
  double? consumo;
  double? clca;

  String? materialSolido;
  int? siloId;
  double? consumoSalT;
  double? consumoSalmueraL;
  double? clcaKg;

  String? materialRobot;
  int? siloIdRobot;
  double? consumoSalTRobot;
  double? consumoSalmueraLRobot;

  String? cuchillaModo;
  String? cuchilla;
  double? horasNormal;
  double? horasExtra;
  int? orden;

  Tramo({
    this.id,
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
    this.materialRobot,
    this.siloIdRobot,
    this.consumoSalTRobot,
    this.consumoSalmueraLRobot,
    this.cuchillaModo,
    this.cuchilla,
    this.horasNormal,
    this.horasExtra,
    this.orden,
  });

  factory Tramo.fromJson(Map<String, dynamic> j) {
    double? parseDouble(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

    int? parseInt(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

    return Tramo(
      id: parseInt(j['id']),
      numero: parseInt(j['numero']),
      actividad: j['actividad']?.toString(),
      ctra: j['ctra']?.toString(),
      pkIni: parseInt(j['pk_ini']),
      mIni: parseInt(j['m_ini']),
      pkFin: parseInt(j['pk_fin']),
      mFin: parseInt(j['m_fin']),
      hora: j['hora']?.toString(),
      horaFin: j['hora_fin']?.toString() ?? j['horaFin']?.toString(),
      material: j['material']?.toString(),
      consumo: parseDouble(j['consumo']),
      clca: parseDouble(j['clca']),
      materialSolido: j['material_solido']?.toString(),
      siloId: parseInt(j['silo_id']),
      consumoSalT: parseDouble(j['consumo_sal_t']),
      consumoSalmueraL: parseDouble(j['consumo_salmuera_l']),
      clcaKg: parseDouble(j['clca_kg']),
      materialRobot: j['material_robot']?.toString(),
      siloIdRobot: parseInt(j['silo_id_robot']),
      consumoSalTRobot: parseDouble(j['consumo_sal_t_robot']),
      consumoSalmueraLRobot: parseDouble(j['consumo_salmuera_l_robot']),
      cuchillaModo: j['cuchilla_modo']?.toString(),
      cuchilla: j['cuchilla']?.toString(),
      horasNormal: parseDouble(j['horas_normal']),
      horasExtra: parseDouble(j['horas_extra']),
      orden: parseInt(j['orden']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'consumo': consumo,
      'clca': clca,
      'material_solido': materialSolido,
      'silo_id': siloId,
      'consumo_sal_t': consumoSalT,
      'consumo_salmuera_l': consumoSalmueraL,
      'clca_kg': clcaKg,
      'material_robot': materialRobot,
      'silo_id_robot': siloIdRobot,
      'consumo_sal_t_robot': consumoSalTRobot,
      'consumo_salmuera_l_robot': consumoSalmueraLRobot,
      'cuchilla_modo': cuchillaModo,
      'cuchilla': cuchilla,
      'horas_normal': horasNormal,
      'horas_extra': horasExtra,
      'orden': orden,
    };
  }

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

    if (material == 'Salmuera') {
      return consumo ?? 0;
    }

    return 0;
  }

  double get clcaTotalKg {
    if (clcaKg != null) return clcaKg!;
    return clca ?? 0;
  }

  int? get inicioEnMetros =>
      (pkIni != null && mIni != null) ? pkIni! * 1000 + mIni! : null;

  int? get finEnMetros =>
      (pkFin != null && mFin != null) ? pkFin! * 1000 + mFin! : null;
}

// ========================= AGRUPADO =========================

DateTime? parseHoraToDate(String? s) {
  if (s == null) return null;

  final parts = s.split(':');
  if (parts.length < 2) return null;

  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final total = h * 60 + m;

  const nightStart = 20 * 60 + 30;
  final baseDay = DateTime(2000, 1, 2);
  final previousDay = baseDay.subtract(const Duration(days: 1));

  final day = total >= nightStart ? previousDay : baseDay;

  return DateTime(day.year, day.month, day.day, h, m);
}

String formatHora(DateTime dt) {
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
      res.add(current!);
    }
    current = null;
  }

  for (final t in list) {
    if (current == null ||
        current!.actividad != t.actividad ||
        current!.tramo != t.numero) {
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
    } else {
      current!.origen.add(t);
      current!.totalSalT += t.salSolidaT;
      current!.totalSalmueraL += t.salmueraL;
      current!.totalClcaKg += t.clcaTotalKg;

      final currentIni = current!.pkIni != null && current!.mIni != null
          ? current!.pkIni! * 1000 + current!.mIni!
          : null;
      final newIni = t.inicioEnMetros;

      if (currentIni == null || (newIni != null && newIni < currentIni)) {
        current!
          ..pkIni = t.pkIni
          ..mIni = t.mIni;
      }

      final currentFin = current!.pkFin != null && current!.mFin != null
          ? current!.pkFin! * 1000 + current!.mFin!
          : null;
      final newFin = t.finEnMetros;

      if (currentFin == null || (newFin != null && newFin > currentFin)) {
        current!
          ..pkFin = t.pkFin
          ..mFin = t.mFin;
      }
    }
  }

  flush();
  return res;
}

// ========================= UI =========================

DateTimeRange calcRangoTurno(DateTime now) {
  final today0830 = DateTime(now.year, now.month, now.day, 8, 30);
  final today2030 = DateTime(now.year, now.month, now.day, 20, 30);

  if (now.isAtSameMomentAs(today0830) ||
      (now.isAfter(today0830) && now.isBefore(today2030))) {
    return DateTimeRange(start: today0830, end: today2030);
  }

  if (now.isAtSameMomentAs(today2030) || now.isAfter(today2030)) {
    return DateTimeRange(
      start: today2030,
      end: today0830.add(const Duration(days: 1)),
    );
  }

  return DateTimeRange(
    start: today2030.subtract(const Duration(days: 1)),
    end: today0830,
  );
}

class App2ConfirmacionNieve extends StatelessWidget {
  final ApiClient api;
  final RemoteSecurityResult securityResult;

  const App2ConfirmacionNieve({
    super.key,
    required this.api,
    required this.securityResult,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App2 Nieve Supervisor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
      home: securityResult.isAllowed
          ? MainMenuPage(api: api)
          : GateBlockPage(msg: securityResult.message),
    );
  }
}

class MainMenuPage extends StatelessWidget {
  final ApiClient api;

  const MainMenuPage({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nieve Vial Vuelta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: _BigMenuButton(
                icon: Icons.assignment,
                text: 'Recoger partes',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PartesHome(api: api)),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _BigMenuButton(
                icon: Icons.tune,
                text: 'Cupos de modulación',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ModifcPage(api: api)),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _BigMenuButton(
                icon: Icons.warehouse,
                text: 'Fijar stock actual',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockActualPage(api: api),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigMenuButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _BigMenuButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FilledButton(
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class GateBlockPage extends StatelessWidget {
  final String msg;

  const GateBlockPage({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 72),
              const SizedBox(height: 16),
              Text(msg, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final securityResult = await RemoteSecurity.check();

                  if (!context.mounted) return;

                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => App2ConfirmacionNieve(
                        api: ApiClient(baseUrl: baseUrl, apiToken: apiToken),
                        securityResult: securityResult,
                      ),
                    ),
                  );
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
