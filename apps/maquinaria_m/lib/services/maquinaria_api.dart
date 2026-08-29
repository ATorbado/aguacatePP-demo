import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/vehicle.dart';
import '../models/maintenance_type.dart';
import '../models/position_item.dart';
import '../models/maintenance_log.dart';

class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() => message;
}

class MaquinariaApi {
  static const bool demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: true,
  );
  static const String baseUrl = String.fromEnvironment(
    'MAQUINARIA_BACKEND_URL',
  );

  static final Map<int, List<MaintenanceLog>> _demoLogs = {
    1: [
      MaintenanceLog(
        id: 1,
        fecha: '2026-01-15',
        tipoMantenimiento: 'Cambio de aceite',
        kilometros: 45200,
        descripcion: 'Registro ficticio para probar la interfaz.',
      ),
    ],
    2: <MaintenanceLog>[],
  };

  static void _requireConfiguration() {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      throw AppException(
        'Configura MAQUINARIA_BACKEND_URL con tu propio servidor HTTPS.',
      );
    }
  }

  static String _safeError(String accion) {
    return 'No se ha podido $accion. Revisa la conexión e inténtalo de nuevo.';
  }

  static Future<List<Vehicle>> getVehicles() async {
    if (demoMode) {
      return [
        Vehicle(id: 1, matricula: 'DEMO-001', nombre: 'Vehículo de ejemplo'),
        Vehicle(id: 2, matricula: 'DEMO-002', nombre: 'Máquina de ejemplo'),
      ];
    }
    _requireConfiguration();
    try {
      final res = await http.get(Uri.parse('$baseUrl/vehicles'));

      if (res.statusCode != 200) {
        throw AppException(_safeError('cargar los vehículos'));
      }

      final List data = jsonDecode(res.body);
      return data.map((e) => Vehicle.fromJson(e)).toList();
    } catch (_) {
      throw AppException(_safeError('cargar los vehículos'));
    }
  }

  static Future<List<MaintenanceType>> getTypes() async {
    if (demoMode) {
      return [
        MaintenanceType(
          id: 1,
          nombre: 'Cambio de aceite',
          categoria: 'Motor',
          requierePosicion: false,
        ),
        MaintenanceType(
          id: 2,
          nombre: 'Revisión de neumático',
          categoria: 'Ruedas',
          requierePosicion: true,
        ),
      ];
    }
    _requireConfiguration();
    try {
      final res = await http.get(Uri.parse('$baseUrl/types'));

      if (res.statusCode != 200) {
        throw AppException(_safeError('cargar los tipos de mantenimiento'));
      }

      final List data = jsonDecode(res.body);
      return data.map((e) => MaintenanceType.fromJson(e)).toList();
    } catch (_) {
      throw AppException(_safeError('cargar los tipos de mantenimiento'));
    }
  }

  static Future<List<PositionItem>> getPositions() async {
    if (demoMode) {
      return [
        PositionItem(id: 1, nombre: 'Delantera izquierda'),
        PositionItem(id: 2, nombre: 'Delantera derecha'),
      ];
    }
    _requireConfiguration();
    try {
      final res = await http.get(Uri.parse('$baseUrl/positions'));

      if (res.statusCode != 200) {
        throw AppException(_safeError('cargar las posiciones'));
      }

      final List data = jsonDecode(res.body);
      return data.map((e) => PositionItem.fromJson(e)).toList();
    } catch (_) {
      throw AppException(_safeError('cargar las posiciones'));
    }
  }

  static Future<List<MaintenanceLog>> getLogs(int vehicleId) async {
    if (demoMode) {
      return List<MaintenanceLog>.unmodifiable(
        _demoLogs[vehicleId] ?? const <MaintenanceLog>[],
      );
    }
    _requireConfiguration();
    try {
      final res = await http.get(Uri.parse('$baseUrl/vehicles/$vehicleId/logs'));

      if (res.statusCode != 200) {
        throw AppException(_safeError('cargar el historial'));
      }

      final List data = jsonDecode(res.body);
      return data.map((e) => MaintenanceLog.fromJson(e)).toList();
    } catch (_) {
      throw AppException(_safeError('cargar el historial'));
    }
  }

  static Future<Map<String, dynamic>?> getLast({
    required int vehicleId,
    required int typeId,
    int? positionId,
  }) async {
    if (demoMode) {
      final logs = _demoLogs[vehicleId] ?? const <MaintenanceLog>[];
      if (logs.isEmpty) return null;
      final last = logs.last;
      return {
        'fecha': last.fecha,
        'kilometros': last.kilometros,
        'descripcion': last.descripcion,
      };
    }
    _requireConfiguration();
    try {
      final uri = Uri.parse('$baseUrl/vehicles/$vehicleId/last').replace(
        queryParameters: {
          'typeId': typeId.toString(),
          if (positionId != null) 'positionId': positionId.toString(),
        },
      );

      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw AppException(_safeError('cargar el último mantenimiento'));
      }

      if (res.body == 'null') return null;
      return jsonDecode(res.body);
    } catch (_) {
      throw AppException(_safeError('cargar el último mantenimiento'));
    }
  }

  static Future<void> createLog({
    required int vehicleId,
    int? maintenanceTypeId,
    int? positionId,
    required String fechaIso,
    int? kilometros,
    String? tituloLibre,
    String? descripcion,
    String? marcaModelo,
  }) async {
    if (demoMode) {
      final logs = _demoLogs.putIfAbsent(vehicleId, () => []);
      logs.add(
        MaintenanceLog(
          id: logs.length + 1,
          fecha: fechaIso,
          tipoMantenimiento:
              maintenanceTypeId == null ? null : 'Mantenimiento de ejemplo',
          tituloLibre: tituloLibre,
          posicion: positionId == null ? null : 'Posición $positionId',
          kilometros: kilometros,
          descripcion: descripcion,
          marcaModelo: marcaModelo,
        ),
      );
      return;
    }
    _requireConfiguration();
    try {
      final body = {
        'fecha': fechaIso,
        if (maintenanceTypeId != null) 'maintenance_type_id': maintenanceTypeId,
        if (positionId != null) 'position_id': positionId,
        if (kilometros != null) 'kilometros': kilometros,
        if (tituloLibre != null && tituloLibre.trim().isNotEmpty)
          'titulo_libre': tituloLibre.trim(),
        if (descripcion != null && descripcion.trim().isNotEmpty)
          'descripcion': descripcion.trim(),
        if (marcaModelo != null && marcaModelo.trim().isNotEmpty)
          'marca_modelo': marcaModelo.trim(),
      };

      final res = await http.post(
        Uri.parse('$baseUrl/vehicles/$vehicleId/logs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode != 201) {
        throw AppException(_safeError('guardar el mantenimiento'));
      }
    } catch (_) {
      throw AppException(_safeError('guardar el mantenimiento'));
    }
  }
}
