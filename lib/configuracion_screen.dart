// lib/configuracion_screen.dart
import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // <--- ELIMINADO
import 'models.dart';
import 'storage_service.dart';
import 'main.dart'; // Para colores del tema
// import 'package:firebase_core/firebase_core.dart'; // <--- ELIMINADO

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

  // <<<--- FUNCIÓN TEMPORAL DE SIEMBRA (ELIMINADA) --- >>>
  // ... La función _sembrarDatosTemporal() se ha borrado ...

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

                      // <<<--- BOTÓN TEMPORAL DE SIEMBRA (ELIMINADO) --- >>>
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
