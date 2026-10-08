import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Sombras para diferentes niveles de elevación.
/// Se usan sombras suaves (sin exceso de sombras, según la especificación).
class AppShadows {
  static List<BoxShadow> get sm => [
        BoxShadow(
          color: AppColors.shadowLight,
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: AppColors.shadowLight,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: AppColors.shadowMedium,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: AppColors.shadowLight,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.shadowMedium,
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  AppShadows._();
}
