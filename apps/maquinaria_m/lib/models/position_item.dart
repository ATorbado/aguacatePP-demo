class PositionItem {
  final int id;
  final String nombre;

  PositionItem({
    required this.id,
    required this.nombre,
  });

  factory PositionItem.fromJson(Map<String, dynamic> json) {
    return PositionItem(
      id: json['id'],
      nombre: json['nombre'] ?? '',
    );
  }
}