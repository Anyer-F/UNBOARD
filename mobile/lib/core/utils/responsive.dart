import 'package:flutter/material.dart';

/// Utilidades responsive para adaptar la interfaz a
/// diferentes tamaños de pantalla (teléfonos y tablets).
class Responsive {
  Responsive._();

  /// Ancho de la pantalla.
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Alto de la pantalla.
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// `true` en pantallas pequeñas (< 360 dp).
  static bool isSmall(BuildContext context) => width(context) < 360;

  /// `true` en tablets o pantallas grandes (>= 600 dp).
  static bool isLarge(BuildContext context) => width(context) >= 600;

  /// Ancho máximo del contenido principal.
  /// En tablets se centra el contenido para evitar líneas excesivamente largas.
  static double maxContentWidth(BuildContext context) =>
      isLarge(context) ? 640 : double.infinity;

  /// Padding lateral de pantalla: 16 en teléfono, 24 en pantallas grandes.
  static EdgeInsets screenPadding(BuildContext context) => EdgeInsets.symmetric(
        horizontal: isLarge(context) ? 24 : 16,
      );

  /// Número de columnas para grids adaptativos.
  static int gridColumns(BuildContext context, {int phoneColumns = 1, int tabletColumns = 2}) {
    return isLarge(context) ? tabletColumns : phoneColumns;
  }
}

/// Contenedor que centra y limita el ancho del contenido
/// en pantallas grandes, manteniendo el margen lateral.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final limit = maxWidth ?? Responsive.maxContentWidth(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limit),
        child: Padding(
          padding: padding ?? Responsive.screenPadding(context),
          child: child,
        ),
      ),
    );
  }
}

/// Layout de pantallas de inicio (dashboards).
///
/// - Centra el contenido y limita su ancho en pantallas grandes.
/// - En teléfonos muestra [principal] y luego [secundario] en una
///   sola columna; desde [anchoDosColumnas] los muestra lado a lado.
/// - Usa el ancho real disponible (LayoutBuilder), no el de la
///   pantalla, para funcionar igual dentro de shells y diálogos.
class DashboardLayout extends StatelessWidget {
  final List<Widget> principal;
  final List<Widget> secundario;
  final Future<void> Function() onRefresh;
  final double maxWidth;
  final double anchoDosColumnas;

  const DashboardLayout({
    super.key,
    required this.principal,
    this.secundario = const [],
    required this.onRefresh,
    this.maxWidth = 1100,
    this.anchoDosColumnas = 840,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 600 ? 24.0 : 16.0;
        final ancho = (constraints.maxWidth - horizontal * 2).clamp(0.0, maxWidth);
        final dosColumnas = secundario.isNotEmpty && ancho >= anchoDosColumnas;

        Widget columna(List<Widget> hijos) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: hijos,
            );

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: ancho,
                child: dosColumnas
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: columna(principal)),
                          const SizedBox(width: 24),
                          Expanded(flex: 4, child: columna(secundario)),
                        ],
                      )
                    : columna([...principal, ...secundario]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fila de métricas que reparte el ancho disponible en partes iguales
/// y pasa a una cuadrícula cuando no caben en una sola fila.
class MetricRow extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  const MetricRow({
    super.key,
    required this.children,
    this.minItemWidth = 96,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var columnas = children.length;
        while (columnas > 1 &&
            (constraints.maxWidth - spacing * (columnas - 1)) / columnas < minItemWidth) {
          columnas--;
        }
        // floor: evita que el redondeo mande el último elemento a otra fila
        final ancho =
            ((constraints.maxWidth - spacing * (columnas - 1)) / columnas).floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: ancho, child: child),
          ],
        );
      },
    );
  }
}

/// Grid adaptable que cambia el número de columnas según el ancho.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int phoneColumns;
  final int tabletColumns;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.phoneColumns = 1,
    this.tabletColumns = 2,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.childAspectRatio = 2.2,
  });

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.gridColumns(
      context,
      phoneColumns: phoneColumns,
      tabletColumns: tabletColumns,
    );

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (_, index) => children[index],
    );
  }
}
