// lib/input_formatters.dart
import 'package:flutter/services.dart';

// Formatter for ####-#### (Teléfono)
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
    if (text.length > 8) {
      return oldValue; // Prevent typing more than 8 digits
    }

    String newText = '';
    for (int i = 0; i < text.length; i++) {
      newText += text[i];
      if (i == 3 && text.length > 4) {
        newText += '-';
      }
    }

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// Formatter for ########-# (DUI)
class DuiInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
    if (text.length > 9) {
      return oldValue; // Prevent typing more than 9 digits
    }

    String newText = '';
    for (int i = 0; i < text.length; i++) {
      newText += text[i];
      if (i == 7 && text.length > 8) {
        newText += '-';
      }
    }

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// Formatter for ####-######-###-# (NIT) - VERSIÓN CORREGIDA DE 14 DÍGITOS
class NitInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
    // 4 + 6 + 3 + 1 = 14 digits
    if (text.length > 14) {
      return oldValue; // Prevent typing more than 14 digits
    }

    String newText = '';
    for (int i = 0; i < text.length; i++) {
      newText += text[i];
      if (i == 3 && text.length > 4) { // First hyphen
        newText += '-';
      } else if (i == 9 && text.length > 10) { // Second hyphen (4 + 6 = 10 digits before)
        newText += '-';
      } else if (i == 12 && text.length > 13) { // Third hyphen (4 + 6 + 3 = 13 digits before)
        newText += '-';
      }
    }

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// <<< --- INICIO: NUEVO FORMATEADOR PARA NRC --- >>>
// Formateador flexible para NRC (ej. 123456-7 o 161-9)
// Añade un guion antes del último dígito.
class NrcInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {

    // Permite al usuario borrar el campo
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Solo dígitos y un guion
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Máximo 8 dígitos (ej. 1234567-8)
    if (text.length > 8) {
      return oldValue;
    }

    // No formatear si solo hay 1 dígito
    if (text.length < 2) {
      return newValue;
    }

    final lastDigit = text.substring(text.length - 1);
    final firstPart = text.substring(0, text.length - 1);

    String newText = '$firstPart-$lastDigit';

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
// <<< --- FIN: NUEVO FORMATEADOR PARA NRC --- >>>


// Formatter to allow only letters and spaces
class LettersOnlyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Permite letras, espacios, y vocales acentuadas comunes + ñ/Ñ
    final String filtered = newValue.text.replaceAll(RegExp(r'[^a-zA-Z\sáéíóúÁÉÍÓÚñÑ]'), '');

    int offset = newValue.selection.baseOffset;
    if (newValue.text.length != filtered.length && offset > filtered.length) {
      offset = filtered.length;
    }

    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}