class Vehicle {
  final int id;
  final String matricula;
  final String nombre;
  final Map<String, dynamic>? ultimoMantenimiento;

  Vehicle({
    required this.id,
    required this.matricula,
    required this.nombre,
    this.ultimoMantenimiento,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      matricula: json['matricula'] ?? '',
      nombre: json['nombre'] ?? '',
      ultimoMantenimiento: json['ultimo_mantenimiento'],
    );
  }
}