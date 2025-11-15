// lib/scan_dui_util.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // <-- ESTA ES LA LÍNEA CORREGIDA
import 'app_data.dart'; // Para la lista de departamentos
import 'dart:async'; // Para Future.wait

class DuiParser {
  // Esta función ahora acepta dos rutas de imagen
  static Future<Map<String, String>> parseDUI(
    String frontPath,
    String backPath,
  ) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    // Crear las imágenes de entrada
    final frontInput = InputImage.fromFilePath(frontPath);
    final backInput = InputImage.fromFilePath(backPath);

    // Procesar ambas imágenes en paralelo (más rápido)
    final results = await Future.wait([
      textRecognizer.processImage(frontInput),
      textRecognizer.processImage(backInput),
    ]);

    final RecognizedText frontText = results[0];
    final RecognizedText backText = results[1];

    await textRecognizer.close();

    final Map<String, String> data = {};

    // --- 1. PROCESAR PARTE FRONTAL (para DUI y Nombres/Apellidos) ---
    _parseFront(frontText.text.toUpperCase(), data);

    // --- 2. PROCESAR PARTE TRASERA (para Dirección y MRZ) ---
    _parseBack(backText.text.toUpperCase(), data);

    // --- 3. LIMPIEZA FINAL ---
    // Si obtuvimos el nombre del MRZ (más fiable), lo usamos.
    if (data.containsKey('mrz_nombre')) {
      data['nombre'] = data['mrz_nombre']!;
    }

    // Limpieza final del nombre (en caso de que venga del frontal)
    if (data['nombre'] != null) {
      data['nombre'] = data['nombre']!
          .replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÑ\s]'), '') // Quitar caracteres raros
          .replaceAll(RegExp(r'\s+'), ' ') // Quitar espacios dobles
          .trim();
    }

    // --- 4. ADIVINAR DEPARTAMENTO (basado en la dirección trasera) ---
    if (data['direccion'] != null) {
      final String dirUpper = data['direccion']!;
      // Intentamos también con el municipio de la parte trasera
      final String muniUpper = data['municipio_trasero']?.toUpperCase() ?? '';

      for (String deptoKey in kDepartamentos) {
        String deptoNombre = deptoKey.split(' - ').last.toUpperCase();
        // Comprueba si la dirección O el municipio leído contienen el nombre del depto
        if (dirUpper.contains(deptoNombre) || muniUpper.contains(deptoNombre)) {
          data['departamento'] = deptoKey;
          break;
        }
      }
    }

    data['pais'] = 'EL SALVADOR';
    data['municipio'] = ''; // Sigue siendo imposible de adivinar con fiabilidad

    // Remover claves auxiliares
    data.remove('mrz_nombre');
    data.remove('municipio_trasero');

    return data;
  }

  static void _parseFront(String fullText, Map<String, String> data) {
    // Extraer DUI
    final RegExp duiRegEx = RegExp(r'\b(\d{8}-\d)\b');
    final duiMatch = duiRegEx.firstMatch(fullText);
    if (duiMatch != null) {
      data['dui'] = duiMatch.group(1)!;
    }

    // Extraer Nombre/Apellido (Método 1: por líneas)
    final List<String> lines = fullText.split('\n');
    String? apellidos, nombres;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      // Usamos .contains() porque la línea puede tener más texto (ej. "Apellidos / Surname")
      if (line.contains('APELLIDOS') || line.contains('SURNAME')) {
        if (i + 1 < lines.length) {
          apellidos = lines[i + 1];
        }
      }
      if (line.contains('NOMBRES') || line.contains('GIVEN NAMES')) {
        if (i + 1 < lines.length) {
          nombres = lines[i + 1];
        }
      }
    }
    if (nombres != null || apellidos != null) {
      data['nombre'] = '${nombres ?? ''} ${apellidos ?? ''}';
    }
  }

  static void _parseBack(String fullText, Map<String, String> data) {
    final List<String> lines = fullText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      // Extraer Dirección (Residencia)
      if (line.contains('RESIDENCIA') || line.contains('ADDRESS')) {
        if (i + 1 < lines.length) {
          data['direccion'] = lines[i + 1];
          // (Opcional) Aferrarse a más líneas si parecen parte de la dirección
          if (i + 2 < lines.length && !lines[i + 2].contains('MUNICIPIO')) {
            data['direccion'] = data['direccion']! + ' ' + lines[i + 2];
          }
        }
      }

      // Extraer Municipio (para ayudar a adivinar el depto)
      if (line.contains('MUNICIPIO') || line.contains('CITY')) {
        if (i + 1 < lines.length) {
          data['municipio_trasero'] = lines[i + 1];
        }
      }
    }

    // Extraer Nombre de la Zona MRZ (la más fiable)
    // Busca una línea que se parezca a: "GALVEZ<VALENCIA<<DAVID<ANTONIO"
    final RegExp mrzNameRegex = RegExp(r'^([A-Z<]+)<<([A-Z<]+)$');
    for (String line in lines) {
      // Evita las primeras 2 líneas del MRZ (IDSLV... y 0004237M...)
      if (line.contains('<<') &&
          !line.startsWith('IDSLV') &&
          !line.startsWith('000')) {
        // Limpia la línea de posibles espacios
        final mrzMatch = mrzNameRegex.firstMatch(
          line.trim().replaceAll(' ', ''),
        );
        if (mrzMatch != null) {
          String apellidos = mrzMatch.group(1)!.replaceAll('<', ' ').trim();
          String nombres = mrzMatch.group(2)!.replaceAll('<', ' ').trim();
          data['mrz_nombre'] = '$nombres $apellidos';
          break; // Encontramos el nombre MRZ
        }
      }
    }
  }
}
