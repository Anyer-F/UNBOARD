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
