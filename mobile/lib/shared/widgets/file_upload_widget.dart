import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import 'app_button.dart';

/// Widget de carga de archivos (documentos, fotografías,
/// material de apoyo).
///
/// Muestra el área de selección, el archivo seleccionado con
/// nombre, tamaño, progreso, estado y opción de eliminar.
class FileUploadWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? fileName;
  final int? fileSizeBytes;
  final double? progress;
  final bool isUploading;
  final String? error;
  final bool enabled;
  final bool allowCamera;
  final List<String> acceptedExtensions;
  final VoidCallback? onPickFile;
  final VoidCallback? onTakePhoto;
  final VoidCallback? onRemove;

  const FileUploadWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.fileName,
    this.fileSizeBytes,
    this.progress,
    this.isUploading = false,
    this.error,
    this.enabled = true,
    this.allowCamera = false,
    this.acceptedExtensions = const ['.pdf', '.jpg', '.jpeg', '.png', '.webp'],
    this.onPickFile,
    this.onTakePhoto,
    this.onRemove,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool _isExtensionAllowed(String name) {
    final lower = name.toLowerCase();
    return acceptedExtensions.any((ext) => lower.endsWith(ext));
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null && fileName!.isNotEmpty;
    final extensionError =
        hasFile && !_isExtensionAllowed(fileName!) ? 'Tipo de archivo no permitido' : null;
    final displayError = error ?? extensionError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Área de selección
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: displayError != null
                  ? AppColors.coralRed
                  : AppColors.borderLight,
              width: displayError != null ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                hasFile ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                size: 40,
                color: hasFile ? AppColors.sageGreen : AppColors.darkNavy,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'Formatos: ${acceptedExtensions.join(', ')}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              if (enabled && !isUploading) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SecondaryButton(
                      label: 'Seleccionar archivo',
                      icon: Icons.folder_open_outlined,
                      expanded: false,
                      onPressed: onPickFile,
                    ),
                    if (allowCamera) ...[
                      const SizedBox(width: AppSpacing.md),
                      SecondaryButton(
                        label: 'Tomar foto',
                        icon: Icons.camera_alt_outlined,
                        expanded: false,
                        onPressed: onTakePhoto,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        // Archivo seleccionado
        if (hasFile) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.darkNavy.withAlpha(13),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    fileName!.toLowerCase().endsWith('.pdf')
                        ? Icons.picture_as_pdf
                        : Icons.image_outlined,
                    size: 20,
                    color: AppColors.darkNavy,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (fileSizeBytes != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatSize(fileSizeBytes!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (isUploading) ...[
                        const SizedBox(height: AppSpacing.sm),
                        LinearProgressIndicator(
                          value: progress ?? 0,
                          minHeight: 4,
                          backgroundColor: AppColors.borderLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Subiendo... ${((progress ?? 0) * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isUploading && onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar archivo',
                    color: AppColors.coralRed,
                    onPressed: onRemove,
                  ),
              ],
            ),
          ),
        ],
        if (displayError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            displayError,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.coralRed,
            ),
          ),
        ],
      ],
    );
  }
}

/// Resultado de la selección de un archivo.
class PickedFileResult {
  final File file;
  final String name;
  final int sizeBytes;

  const PickedFileResult({
    required this.file,
    required this.name,
    required this.sizeBytes,
  });
}

/// Valida un archivo antes de subirlo. Retorna `null` si es válido
/// o un mensaje de error descriptivo.
String? validatePickupFile({
  required String fileName,
  required int sizeBytes,
  List<String> allowedExtensions = const ['.pdf', '.jpg', '.jpeg', '.png', '.webp'],
  int maxSizeBytes = 10 * 1024 * 1024,
}) {
  final lower = fileName.toLowerCase();
  if (!allowedExtensions.any((e) => lower.endsWith(e))) {
    return 'Formato no permitido. Usa: ${allowedExtensions.join(', ')}';
  }
  if (sizeBytes > maxSizeBytes) {
    return 'El archivo supera el tamaño máximo de ${(maxSizeBytes / (1024 * 1024)).round()} MB';
  }
  return null;
}
