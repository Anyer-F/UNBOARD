import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:unbound_mobile/core/theme/app_theme.dart';
import 'package:unbound_mobile/features/dashboard/apadrinado_home_screen.dart';
import 'package:unbound_mobile/features/dashboard/coordinador_dashboard_screen.dart';
import 'package:unbound_mobile/shared/models/actividad.dart';
import 'package:unbound_mobile/shared/models/apadrinado.dart';
import 'package:unbound_mobile/shared/models/notificacion.dart';

/// Anchos de prueba: teléfono pequeño, teléfono, tablet, escritorio/web.
const _anchos = <double>[320, 360, 412, 800, 1280];

final _actividades = [
  for (var i = 0; i < 4; i++)
    Actividad(
      id: i,
      titulo: 'Actividad con un título bastante largo para probar el ajuste $i',
      fechaCreacion: '2026-10-01',
      fechaLimite: '2026-10-${20 + i}',
      estado: ['PENDIENTE', 'ENTREGADA', 'APROBADA', 'CORRECCION_SOLICITADA'][i],
      apadrinadoNombre: 'María Fernanda López García',
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

final _notificaciones = [
  for (var i = 0; i < 3; i++)
    Notificacion(
      id: i,
      titulo: 'Nueva actividad asignada $i',
      mensaje: 'Tienes una nueva actividad pendiente de entregar antes de la fecha límite.',
      tipo: 'ACTIVIDAD',
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

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  for (final ancho in _anchos) {
    testWidgets('Inicio del coordinador sin desbordes a ${ancho.toInt()}px', (tester) async {
      await _pump(
        tester,
        ancho,
        CoordinadorHomeView(
          nombre: 'Carlos Alberto Méndez Rodríguez',
          apadrinados: _apadrinados,
          actividades: _actividades,
          onRefresh: () async {},
          onNuevaActividad: () {},
          onAbrirComunidades: () {},
          onExpedientesActividad: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Expedientes por actividad'), findsOneWidget);
      await _recorrer(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Inicio del apadrinado sin desbordes a ${ancho.toInt()}px', (tester) async {
      await _pump(
        tester,
        ancho,
        ApadrinadoHomeView(
          nombre: 'María Fernanda López García',
          comunidad: 'Comunidad San Juan Ixcoy, Huehuetenango',
          actividades: _actividades,
          notificaciones: _notificaciones,
          onRefresh: () async {},
        ),
      );
      expect(tester.takeException(), isNull);
      await _recorrer(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('En pantallas anchas el inicio usa dos columnas', (tester) async {
    await _pump(
      tester,
      1280,
      ApadrinadoHomeView(
        nombre: 'Ana',
        comunidad: 'Comunidad',
        actividades: _actividades,
        notificaciones: _notificaciones,
        onRefresh: () async {},
      ),
    );
    final resumen = tester.getTopLeft(find.text('Mi resumen'));
    final expediente = tester.getTopLeft(find.text('Mi expediente digital'));
    expect(expediente.dx, greaterThan(resumen.dx));
  });

  testWidgets('En teléfono el inicio usa una columna', (tester) async {
    await _pump(
      tester,
      360,
      CoordinadorHomeView(
        nombre: 'Carlos',
        apadrinados: _apadrinados,
        actividades: _actividades,
        onRefresh: () async {},
      ),
    );
    final resumen = tester.getTopLeft(find.text('Mi resumen'));
    final apadrinados = tester.getTopLeft(find.text('Apadrinados').last);
    expect(apadrinados.dx, resumen.dx);
  });
}
