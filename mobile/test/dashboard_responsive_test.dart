import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:unbound_mobile/core/theme/app_theme.dart';
import 'package:unbound_mobile/features/dashboard/apadrinado_home_screen.dart';
import 'package:unbound_mobile/features/dashboard/coordinador_dashboard_screen.dart';
import 'package:unbound_mobile/shared/models/actividad.dart';
import 'package:unbound_mobile/shared/models/apadrinado.dart';
import 'package:unbound_mobile/shared/models/asignacion.dart';
import 'package:unbound_mobile/shared/models/modulo.dart';
import 'package:unbound_mobile/shared/models/notificacion.dart';

/// Anchos de prueba: teléfono pequeño, teléfono, tablet, escritorio/web.
const _anchos = <double>[320, 360, 412, 800, 1280];

final _actividades = [
  for (var i = 0; i < 4; i++)
    Actividad(
      id: i,
      tipo: [TipoActividad.tarea, TipoActividad.tarea, TipoActividad.anuncio, TipoActividad.material][i],
      titulo: 'Actividad con un título bastante largo para probar el ajuste $i',
      fechaCreacion: '2026-10-01T10:00:00',
      fechaLimite: i < 2 ? '2026-10-${20 + i}' : null,
      comunidadNombre: 'Comunidad San Juan Ixcoy, Huehuetenango',
      moduloNombre: 'Módulo 1: Bienvenida',
      resumen: ResumenAvance(asignados: 5, pendientes: 1, enviados: i, aprobados: 2, correcciones: 1),
    ),
];

final _apadrinados = [
  for (var i = 0; i < 4; i++)
    Apadrinado(
      id: i,
      nombre: 'Apadrinado con nombre completo muy largo número $i',
      correo: 'apadrinado.con.correo.largo$i@unbound.org',
      comunidadNombre: 'Comunidad San Juan Ixcoy, Huehuetenango',
    ),
];

final _tablero = TableroApadrinado(
  pendientes: [
    for (var i = 0; i < 4; i++)
      Asignacion(
        id: i,
        actividadId: i,
        estado: [
          EstadoAsignacion.pendiente,
          EstadoAsignacion.enProgreso,
          EstadoAsignacion.correccion,
          EstadoAsignacion.pendiente,
        ][i],
        proximaAVencer: i == 1,
        ultimaSugerencia: i == 2 ? 'La fotografía no se ve bien, envía una más clara por favor.' : null,
        actividad: _actividades[0],
      ),
  ],
  correcciones: 1,
  proximasAVencer: 1,
  realizadas: 3,
  anunciosNuevos: 2,
);

final _notificaciones = [
  for (var i = 0; i < 3; i++)
    Notificacion(
      id: i,
      titulo: 'Nueva actividad asignada $i',
      mensaje: 'Tienes una nueva actividad pendiente de entregar antes de la fecha límite.',
      tipo: 'NUEVA_ACTIVIDAD',
      fechaCreacion: '2026-10-0${i + 1}T10:00:00',
    ),
];

Future<void> _pump(WidgetTester tester, double ancho, Widget body) async {
  tester.view.physicalSize = Size(ancho, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: body),
  ));
  await tester.pumpAndSettle();
}

/// Recorre todo el scroll para que se construya y pinte el contenido.
Future<void> _recorrer(WidgetTester tester) async {
  final scroll = find.byType(Scrollable).first;
  for (var i = 0; i < 6; i++) {
    await tester.drag(scroll, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

CoordinadorHomeView _coordinador() => CoordinadorHomeView(
      nombre: 'Carlos Alberto Méndez Rodríguez',
      comunidades: 3,
      solicitudesPendientes: 2,
      apadrinados: _apadrinados,
      actividades: _actividades,
      onRefresh: () async {},
      onNuevaActividad: () {},
      onAbrirComunidades: () {},
      onAbrirActividades: () {},
      onSolicitudes: () {},
      onExpedientesActividad: () {},
      onHistorial: () {},
    );

ApadrinadoHomeView _apadrinado() => ApadrinadoHomeView(
      nombre: 'María Fernanda López García',
      comunidad: 'Comunidad San Juan Ixcoy, Huehuetenango',
      tablero: _tablero,
      notificaciones: _notificaciones,
      onRefresh: () async {},
      onAbrirAsignacion: (_) {},
      onVerComunidad: () {},
    );

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  for (final ancho in _anchos) {
    testWidgets('Inicio del coordinador sin desbordes a ${ancho.toInt()}px', (tester) async {
      await _pump(tester, ancho, _coordinador());
      expect(tester.takeException(), isNull);
      expect(find.text('Expedientes por actividad'), findsOneWidget);
      await _recorrer(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Inicio del apadrinado sin desbordes a ${ancho.toInt()}px', (tester) async {
      await _pump(tester, ancho, _apadrinado());
      expect(tester.takeException(), isNull);
      expect(find.text('Mis pendientes'), findsOneWidget);
      await _recorrer(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('En pantallas anchas el inicio usa dos columnas', (tester) async {
    await _pump(tester, 1280, _apadrinado());
    final pendientes = tester.getTopLeft(find.text('Mis pendientes'));
    final resumen = tester.getTopLeft(find.text('Mi resumen'));
    expect(resumen.dx, greaterThan(pendientes.dx));
  });

  testWidgets('En teléfono el inicio usa una columna', (tester) async {
    await _pump(tester, 360, _coordinador());
    final resumen = tester.getTopLeft(find.text('Mi resumen'));
    await tester.scrollUntilVisible(find.text('Entregas por revisar'), 300);
    final entregas = tester.getTopLeft(find.text('Entregas por revisar'));
    expect(entregas.dx, resumen.dx);
  });
}
