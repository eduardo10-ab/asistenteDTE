// lib/scan_passport_util.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'app_data.dart'; // Importamos para la lista de países

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
    final List<String> lines = fullText.split('\n');

    // --- ESTRATEGIA 1: LEER LA ZONA MRZ (LA MÁS FIABLE) ---
    // Esta zona está diseñada para ser leída por máquinas.
    String? mrzLine1, mrzLine2;

    for (String line in lines) {
      String cleanedLine = line.replaceAll(' ', ''); // Quitar espacios
      if (cleanedLine.startsWith('P<')) {
        mrzLine1 = cleanedLine;
      }
      // La segunda línea de MRZ de un pasaporte usualmente tiene 9
      // caracteres de pasaporte, 1 de chequeo, 3 de país, etc.
      else if (RegExp(r'^[A-Z0-9<]{9}\d').hasMatch(cleanedLine) &&
          cleanedLine.length > 40) {
        mrzLine2 = cleanedLine;
      }
    }

    if (mrzLine1 != null && mrzLine2 != null) {
      try {
        // Línea 1: P<PAIS<APELLIDOS<<NOMBRES<<<<<
        // P<SLVGALVEZ<URRUTIA<<WILLIAM<EDGARDO<<<<...
        String codigoPais = mrzLine1.substring(2, 5).replaceAll('<', '');
        String fullName = mrzLine1.substring(5);
        List<String> parts = fullName.split('<<');
        if (parts.length >= 2) {
          String apellidos = parts[0].replaceAll('<', ' ').trim();
          String nombres = parts[1].replaceAll('<', ' ').trim();
          data['nombre'] = '$nombres $apellidos';
        }
        data['pais'] = _mapCountryCode(codigoPais);

        // Línea 2: [PASAPORTE_NUM]<[...]<
        // B007962287SLV7501171M2510251D4096914<<<...
        data['pasaporte'] = mrzLine2.substring(0, 9).replaceAll('<', '');
      } catch (e) {
        // Error parseando MRZ
      }
    }

    // --- ESTRATEGIA 2: LEER ETIQUETAS (SÓLO PARA CAMPOS FALTANTES) ---
    // El "Lugar de Nacimiento" no está en la MRZ, así que lo buscamos por etiqueta.
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].toUpperCase();
      if (line.contains('LUGAR DE NACIMIENTO') ||
          line.contains('PLACE OF BIRTH')) {
        if (i + 1 < lines.length) {
          data['direccion'] = lines[i + 1]; // "SANTA ANA"
          break; // Lo encontramos, salimos del bucle
        }
      }
    }

    // --- Respaldo por si la MRZ falla (muy raro) ---
    if (data['pasaporte'] == null || data['pasaporte']!.isEmpty) {
      data['pasaporte'] = _findFieldByLabel(lines, [
        'PASAPORTE NO',
        'PASSPORT NO',
      ]);
    }
    if (data['nombre'] == null || data['nombre']!.isEmpty) {
      String? nombres = _findFieldByLabel(lines, ['NOMBRES', 'GIVEN NAMES']);
      String? apellidos = _findFieldByLabel(lines, ['APELLIDOS', 'SURNAME']);
      data['nombre'] = '${nombres ?? ''} ${apellidos ?? ''}'.trim();
    }
    if (data['pais'] == null || data['pais']!.isEmpty) {
      data['pais'] = _mapCountryCode(_findFieldByLabel(lines, ['CÓDIGO PAÍS']));
    }

    return data;
  }

  /// Helper para buscar un valor. Es menos fiable que la MRZ.
  static String _findFieldByLabel(List<String> lines, List<String> keywords) {
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].toUpperCase();
      bool allKeywordsFound = true;
      for (String key in keywords) {
        if (!line.contains(key)) {
          allKeywordsFound = false;
          break;
        }
      }

      if (allKeywordsFound) {
        // Intenta encontrar el valor en la misma línea
        var parts = line.split(RegExp(r':\s*'));
        if (parts.length > 1) {
          return parts.last.trim();
        }
        // Si no, tómalo de la línea siguiente
        if (i + 1 < lines.length) {
          return lines[i + 1].trim();
        }
      }
    }
    return ''; // No encontrado
  }

  /// Mapea códigos de 3 letras a nombres completos de la lista kPaises.
  static String _mapCountryCode(String code) {
    if (code.isEmpty) return '';

    // Lista corta de mapeo
    const Map<String, String> codeMap = {
      'SLV': 'EL SALVADOR',
      'USA': 'ESTADOS UNIDOS',
      'GTM': 'GUATEMALA',
      'HND': 'HONDURAS',
      'NIC': 'NICARAGUA',
      'CRI': 'COSTA RICA',
      'PAN': 'PANAMÁ',
      'MEX': 'MÉXICO',
      'CAN': 'CANADÁ',
      'ESP': 'ESPAÑA',
    };

    String mappedName = codeMap[code] ?? code;

    // Verifica si el nombre mapeado existe en la lista kPaises
    if (kPaises.any((p) => p.toUpperCase() == mappedName.toUpperCase())) {
      return mappedName; // Devuelve "EL SALVADOR"
    }

    // Fallback: si el OCR leyó mal "SLV" pero kPaises tiene "EL SALVADOR"
    if (codeMap.containsValue(code)) {
      return code;
    }

    return code;
  }
}
