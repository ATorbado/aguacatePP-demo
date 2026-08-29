class MaintenanceType {
  final int id;
  final String nombre;
  final String categoria;
  final bool requierePosicion;

  MaintenanceType({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.requierePosicion,
  });

  factory MaintenanceType.fromJson(Map<String, dynamic> json) {
    return MaintenanceType(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      categoria: json['categoria'] ?? '',
      requierePosicion: json['requiere_posicion'] == true,
    );
  }
}