import 'package:flutter/material.dart';

/// Validadores reutilizables para formularios.
class Validators {
  Validators._();

  static String? required(String? value, {String field = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field es obligatorio';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es obligatorio';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Ingresa un correo electrónico válido';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  static String? minLength(String? value, int min, {String field = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field es obligatorio';
    }
    if (value.trim().length < min) {
      return '$field debe tener al menos $min caracteres';
    }
    return null;
  }

  static String? maxLength(String? value, int max, {String field = 'Este campo'}) {
    if (value != null && value.length > max) {
      return '$field no debe superar $max caracteres';
    }
    return null;
  }

  /// Valida un código de comunidad (ej. UNB-X7K92).
  static String? communityCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El código es obligatorio';
    }
    if (value.trim().length < 4) {
      return 'El código es demasiado corto';
    }
    return null;
  }
}

/// Extensión para validar un formulario completo.
extension FormValidator on GlobalKey<FormState> {
  bool validateForm() => currentState?.validate() ?? false;
}
