// lib/configuracion_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Importante: Librería para abrir el enlace
import 'models.dart';
import 'storage_service.dart';
import 'main.dart'; // Para colores del tema

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

  // Función para abrir el enlace de políticas
  Future<void> _abrirPoliticas() async {
    final Uri url = Uri.parse(
      'https://drive.google.com/file/d/1cf2wmjUVlTGlXAo1dQDbEc020FkU04gQ/view?usp=sharing',
    );

    // Intentamos abrir el enlace en una aplicación externa (navegador o Drive)
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el enlace de políticas'),
          ),
        );
      }
    }
  }

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
                                'Activación',
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
                                'Soporte técnico',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Reporte de errores de la aplicación por favor contactarnos:',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.disabledColor,
                                ),
                              ),
                              Text(
                                'fuentesjoel723@gmail.com',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.disabledColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'david.galvito2000@gmail.com',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.disabledColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- Card 4: Políticas de Privacidad (BOTÓN ACTUALIZADO) ---
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Políticas de privacidad',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                // CAMBIO AQUÍ: Usamos FilledButton con estilo específico
                                child: FilledButton(
                                  onPressed: _abrirPoliticas,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors
                                        .cyan, // El color azul brillante de la imagen
                                    foregroundColor:
                                        Colors.white, // Texto blanco
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ), // Un poco más alto
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        8.0,
                                      ), // Bordes redondeados similares
                                    ),
                                  ),
                                  child: const Text(
                                    'Ver políticas de privacidad',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
