class MaintenanceLog {
  final int id;
  final String fecha;
  final String? tipoMantenimiento;
  final String? tituloLibre;
  final String? posicion;
  final int? kilometros;
  final String? descripcion;
  final String? marcaModelo;

  MaintenanceLog({
    required this.id,
    required this.fecha,
    this.tipoMantenimiento,
    this.tituloLibre,
    this.posicion,
    this.kilometros,
    this.descripcion,
    this.marcaModelo,
  });

  String get titulo => tipoMantenimiento ?? tituloLibre ?? 'Mantenimiento';

  factory MaintenanceLog.fromJson(Map<String, dynamic> json) {
    return MaintenanceLog(
      id: json['id'],
      fecha: json['fecha'] ?? '',
      tipoMantenimiento: json['tipo_mantenimiento'],
      tituloLibre: json['titulo_libre'],
      posicion: json['posicion'],
      kilometros: json['kilometros'],
      descripcion: json['descripcion'],
      marcaModelo: json['marca_modelo'],
    );
  }
}