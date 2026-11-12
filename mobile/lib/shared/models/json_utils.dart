/// Conversión tolerante de valores JSON (el backend puede enviar
/// números como int, double o String).
int toInt(dynamic v, [int defecto = 0]) {
  if (v == null) return defecto;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? defecto;
}

int? toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool toBool(dynamic v) => v == true || v?.toString() == 'true';

List<T> toList<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) {
  if (v is! List) return <T>[];
  return v
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// Fecha (yyyy-MM-dd) o fecha-hora ISO del backend → DateTime local.
DateTime? toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
