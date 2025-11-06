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
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.length > 8) {
      return oldValue;
    }
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

// <<<--- INICIO: NUEVO FORMATEADOR PARA NOMBRES --- >>>
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
    // Ajustar el cursor si se eliminaron caracteres
    if (newValue.text.length != filtered.length) {
      // Si la longitud cambió, intentamos mantener el cursor en una posición lógica,
      // pero lo más seguro es ponerlo al final del texto filtrado si estaba más allá.
      if (offset > filtered.length) {
        offset = filtered.length;
      }
      // Una mejor aproximación si se borró algo en medio es reducir el offset
      // por la cantidad de caracteres borrados antes del cursor.
      // Por simplicidad, y porque suele funcionar bien para este caso:
      offset = filtered.length;
    }

    return newValue.copyWith(
      text: filtered,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
// <<<--- FIN: NUEVO FORMATEADOR PARA NOMBRES --- >>>