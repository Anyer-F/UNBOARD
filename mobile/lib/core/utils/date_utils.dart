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

  /// `true` si la fecha límite ya pasó.
  static bool isOverdue(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    final dt = _parse(iso);
    if (dt == null) return false;
    return dt.toLocal().isBefore(DateTime.now());
  }

  /// Días restantes hasta la fecha (negativos si ya venció).
  static int daysUntil(String? iso) {
    if (iso == null || iso.isEmpty) return 0;
    final dt = _parse(iso);
    if (dt == null) return 0;
    return dt.toLocal().difference(DateTime.now()).inDays;
  }

  static DateTime? _parse(String iso) {
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }
}
