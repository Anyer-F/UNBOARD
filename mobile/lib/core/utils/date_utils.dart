import 'package:intl/intl.dart';

/// Utilidades de fechas para toda la aplicación.
///
/// Se llama `AppDateUtils` para no colisionar con
/// `DateUtils` del paquete Material.
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _date = DateFormat('dd MMM yyyy', 'es');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy · HH:mm', 'es');
  static final DateFormat _shortDate = DateFormat('dd/MM/yyyy', 'es');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'es');
  static final DateFormat _dayMonth = DateFormat('dd MMM', 'es');

  /// `15 oct 2026`
  static String formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Sin fecha';
    final dt = _parse(iso);
    return dt == null ? iso : _date.format(dt.toLocal());
  }

  /// `05 oct 2026 · 14:22`
  static String formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Sin fecha';
    final dt = _parse(iso);
    return dt == null ? iso : _dateTime.format(dt.toLocal());
  }

  /// `15/10/2026`
  static String formatShort(String? iso) {
    if (iso == null || iso.isEmpty) return 'Sin fecha';
    final dt = _parse(iso);
    return dt == null ? iso : _shortDate.format(dt.toLocal());
  }

  /// `octubre 2026`
  static String formatMonthYear(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = _parse(iso);
    return dt == null ? iso : _monthYear.format(dt.toLocal());
  }

  /// `15 oct`
  static String formatDayMonth(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = _parse(iso);
    return dt == null ? iso : _dayMonth.format(dt.toLocal());
  }

  /// `true` si la fecha límite ya pasó. Una fecha sin hora (yyyy-MM-dd)
  /// vence al terminar ese día.
  static bool isOverdue(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    final dt = _parse(iso);
    if (dt == null) return false;
    if (iso.length <= 10) return daysUntil(iso) < 0;
    return dt.toLocal().isBefore(DateTime.now());
  }

  /// Días de calendario restantes hasta la fecha (0 = hoy, negativos si
  /// ya venció).
  static int daysUntil(String? iso) {
    if (iso == null || iso.isEmpty) return 0;
    final dt = _parse(iso);
    if (dt == null) return 0;
    final local = dt.toLocal();
    final ahora = DateTime.now();
    return DateTime(local.year, local.month, local.day)
        .difference(DateTime(ahora.year, ahora.month, ahora.day))
        .inDays;
  }

  /// Fecha para enviar al backend: `2026-10-15`.
  static String toApiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parse(String iso) {
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }
}
