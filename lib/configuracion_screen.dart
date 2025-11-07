// lib/configuracion_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Necesario para la siembra temporal
import 'models.dart';
import 'storage_service.dart';
import 'main.dart'; // Para colores del tema
import 'package:firebase_core/firebase_core.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final StorageService _storage = StorageService();
  ActivationStatus _activationStatus = ActivationStatus.none;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivationStatus();
  }

  Future<void> _loadActivationStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final status = await _storage.getActivationStatus();
    if (!mounted) return;
    setState(() {
      _activationStatus = status;
      _isLoading = false;
    });
  }

  // <<<--- FUNCIÓN TEMPORAL DE SIEMBRA --- >>>
  Future<void> _sembrarDatosTemporal() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Iniciando siembra... espere...')),
    );

    // Tu lista de claves PRO
    final List<String> proKeys = [
      "W7X4-9N3K-R8F2-L6A1",
      "T5B3-E1H7-C4J2-G8V6",
      "X3Z8-M6P4-Q2R9-Y7S5",
      "F9G1-L7K3-H5B4-D2F8",
      "V6C2-T8J5-E4A9-M1P7",
      "K8R3-Y7S1-W4Z6-N2B9",
      "Q2H5-D9V8-G1C4-J7T3",
      "A1M7-P4E9-B2K6-R8L5",
      "N6S2-F8G5-T1W9-C3H4",
      "Y9K4-V6B8-D3K1-E7R2",
      "L5A9-R2P7-M3N1-G8F4",
      "H1D8-K4T2-W7S6-V3B9",
      "B4G7-E3Q9-K2R5-F1L0",
      "D8N2-T6W1-Y4S3-P9M5",
      "M3V6-C9H2-S7A4-R1K8",
      "Z5S1-G4J7-L9P3-W8N2",
      "E9Q4-K8R1-F2D7-T3V6",
      "R7B3-N6S9-A1M4-H5C2",
      "W2T5-V8B1-J4G7-Y9E3",
      "C6H9-L2K5-S8N1-P4M7",
      "G1J8-D4N3-V7C6-T2B5",
      "P4M2-A7R9-K1L6-S3H8",
      "S8N5-E1Q3-B6G2-W7S4",
      "Y3V7-T9W4-H2C1-R8K5",
      "J6G0-F5D8-M1P9-N4S7",
      "X1Z4-K7R2-T5B8-L9A3",
      "H9C5-W3T1-S6N8-G4J3",
      "R2L8-A4M1-P7E3-B9V7",
      "T7B1-Y9V4-E2Q6-K5R3",
      "N3S8-D6F2-C1H9-G7K4",
      "A6N9-P1U7-L4K2-R8B5",
      "F2D5-J8G1-W3T7-S9N4",
      "K4R7-V1B3-H6C9-Q2E5",
      "V8B2-S4N6-T1W5-M7P9",
      "C3H6-G9J1-L7K4-R2B8",
      "Q7E1-W5T9-Y2V3-A8M4",
      "S1N9-R4K2-P8M6-J7G3",
      "M5P3-B8V1-A6R9-H4C7",
      "D9N6-K2Q1-S7N4-T8W3",
      "G4J0-C7H1-B9V5-E3Q8",
      "W1T8-A3M6-R9K4-L2B7",
      "P7E9-S2N5-V4B1-J6G3",
      "R3K6-B9V2-L4A8-C1H7",
      "H8C4-G1J7-T5W3-N6S2",
      "E2Q5-V7B9-M3P1-Y4R8",
      "K9R1-D6F4-S2N8-A7M3",
      "L4A7-H3C2-V6B1-T9W5",
      "J8G3-T1W9-N5S4-F2D7",
      "B2V6-M7P1-R9K3-E4Q8",
      "Y2W9-E4Q1-P6M3-S8N7",
    ];

    final firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: '(default)', // Forzamos el nombre exacto
    );
    final batch = firestore.batch();

    for (String key in proKeys) {
      final docRef = firestore.collection('licenses').doc(key);
      // Usamos 'set' con 'SetOptions(merge: true)' para no sobrescribir si ya existe
      // y solo actualizar campos si fuera necesario, aunque aquí queremos crear.
      batch.set(docRef, {
        'key': key,
        'tier': 'PRO',
        'isActive': true,
        'deviceId': null, // Importante: null para que esté libre
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('✅ ¡SIEMBRA FINALIZADA! ${proKeys.length} claves.'),
          ),
        );
      }
    } catch (e) {
      print("Error semilla: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('❌ ERROR: $e')),
        );
      }
    }
  }
  // <<<--- FIN FUNCIÓN TEMPORAL --- >>>

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(title: const Text('Configuración')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // --- Card 1: Estado ---
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estado de la Aplicación',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Estado actual: ${_activationStatus.displayName}',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: _activationStatus.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _activationStatus.description,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- Card 2: Activación ---
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Activacion',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Para la activación de todas las funcionalidades por favor contactarse al: ',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.disabledColor,
                                ),
                              ),
                              Text(
                                '7727-8551',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.disabledColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- Card 3: Soporte Técnico ---
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Soporte tecnico',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Reporte de errores de la aplicaion por favor contactarse al correo:',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.disabledColor,
                                ),
                              ),
                              Text(
                                'soportetecnico@gmail.com',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.disabledColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // <<<--- BOTÓN TEMPORAL DE SIEMBRA --- >>>
                      const SizedBox(height: 40),
                      Center(
                        child: ElevatedButton(
                          onPressed: _sembrarDatosTemporal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                          ),
                          child: const Text(
                            "SEMBRAR CLAVES (USAR 1 VEZ)",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      // <<<--- FIN BOTÓN TEMPORAL --- >>>
                    ],
                  ),
                ),

                // --- Texto de Créditos (Footer) ---
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'Desarrollo por Joel Fuentes y David Gálvez',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}
