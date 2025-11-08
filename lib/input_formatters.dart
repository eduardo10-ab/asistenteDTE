// lib/input_formatters.dart
import 'package:flutter/services.dart';

// Formatter for ####-#### (Teléfono)
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(
      RegExp(r'\D'),
      '',
    ); // Remove non-digits
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
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(
      RegExp(r'\D'),
      '',
    ); // Remove non-digits
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

// Formatter for ####-######-###-# (NIT)
class NitInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(
      RegExp(r'\D'),
      '',
    ); // Remove non-digits
    if (text.length > 14) {
      return oldValue; // Prevent typing more than 14 digits
    }

    String newText = '';
    for (int i = 0; i < text.length; i++) {
      newText += text[i];
      if (i == 3 && text.length > 4) {
        // First hyphen
        newText += '-';
      } else if (i == 9 && text.length > 10) {
        // Second hyphen
        newText += '-';
      } else if (i == 12 && text.length > 13) {
        // Third hyphen
        newText += '-';
      }
    }

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// Formateador flexible para NRC (ej. 123456-7 o 161-9)
class NrcInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // <<< FIX: Aseguramos que solo haya dígitos ANTES de aplicar el formato >>>
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (text.length > 8) {
      return oldValue;
    }
    if (text.length < 2) {
      // Devolvemos el valor crudo, que ya sabemos que solo tiene dígitos
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
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

// Permite letras, números, espacios y signos de puntuación comunes en nombres comerciales
class NameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Permite:
    // - Letras (a-z, A-Z) y vocales acentuadas/ñ
    // - Números (0-9)
    // - Espacios (\s)
    // - Signos de puntuación comunes: . , - _ & ( ) / " '
    final String filtered = newValue.text.replaceAll(
      RegExp(r'[^a-zA-Z0-9\sáéíóúÁÉÍÓÚñÑ.,\-_&()/"' + "']"),
      '',
    );

    int offset = newValue.selection.baseOffset;
    if (newValue.text.length != filtered.length) {
      if (offset > filtered.length) {
        offset = filtered.length;
      }
      offset = filtered.length;
    }

    return newValue.copyWith(
      text: filtered,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
