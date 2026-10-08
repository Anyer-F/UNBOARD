import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_shadows.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';

/// Tarjeta base reutilizable (superficie blanca, borde suave,
/// esquinas redondeadas, sombra sutil).
///
/// Componente base para [ActivityCard], [DocumentCard],
/// [CommunityCard], [PersonCard] y [NotificationCard].
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double? elevation;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.onTap,
    this.elevation = 0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.xl);

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBg,
        borderRadius: radius,
        boxShadow: elevation! > 0 ? AppShadows.md : null,
        border: Border.all(
          color: AppColors.borderLight.withAlpha(102),
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );

    if (onTap != null) {
      return Padding(
        padding: margin ??
            const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.lg,
            ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: cardContent,
          ),
        ),
      );
    }

    return Padding(
      padding: margin ??
            const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.lg,
            ),
      child: cardContent,
    );
  }
}
