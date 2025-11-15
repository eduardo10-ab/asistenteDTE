// lib/scan_passport_util.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PassportParser {
  static Future<Map<String, String>> parsePassport(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );
    await textRecognizer.close();

    final String fullText = recognizedText.text;
    final Map<String, String> data = {};

    // La Zona de Lectura Mecánica (MRZ) del pasaporte son 2 líneas de 44 caracteres
    // Buscamos esas líneas en todo el texto
    final List<String> lines = fullText.split('\n');

    String? line1, line2;

    for (String line in lines) {
      String cleanedLine = line.replaceAll(' ', ''); // Quitar espacios
      if (cleanedLine.startsWith('P<') && cleanedLine.length >= 44) {
        line1 = cleanedLine.substring(0, 44);
      } else if (RegExp(r'^[A-Z0-9<]{9}<\d').hasMatch(cleanedLine) &&
          cleanedLine.length >= 44) {
        line2 = cleanedLine.substring(0, 44);
      }
    }

    if (line1 != null) {
      _parseMRZLine1(line1, data);
    }
    if (line2 != null) {
      _parseMRZLine2(line2, data);
    }

    return data;
  }

  /// Parsea la Línea 1 de la MRZ (Contiene Nombre y Apellido)
  /// Formato: P<[PAIS][APELLIDOS]<<[NOMBRES]<<<<<<<<<<
  static void _parseMRZLine1(String line, Map<String, String> data) {
    try {
      data['pais'] = line.substring(2, 5).replaceAll('<', '');

      String fullName = line.substring(5); // Resto de la línea
      List<String> parts = fullName.split('<<');

      if (parts.isNotEmpty) {
        String apellidos = parts[0].replaceAll('<', ' ').trim();
        String nombres = (parts.length > 1)
            ? parts[1].replaceAll('<', ' ').trim()
            : '';
        data['nombre'] = '$nombres $apellidos'.trim();
      }
    } catch (e) {
      // Error parseando la línea 1
    }
  }

  /// Parsea la Línea 2 de la MRZ (Contiene Número de Pasaporte)
  /// Formato: [PASAPORTE_NUM]<[...][DOB][SEX][EXPIRY_DATE][...]
  static void _parseMRZLine2(String line, Map<String, String> data) {
    try {
      // El número de pasaporte son los primeros 9 caracteres
      data['pasaporte'] = line.substring(0, 9).replaceAll('<', '');
    } catch (e) {
      // Error parseando la línea 2
    }
  }
}
