// lib/configuracion_screen.dart
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // Usamos el color de fondo de la app (Blanco)
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
      // <<< --- INICIO: CAMBIOS --- >>>
      // Convertimos el body en una Columna para poder fijar el texto abajo
          : Column(
        children: [
          // 1. La lista ahora ocupa todo el espacio disponible
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [

                // --- Card 1: Estado (MODIFICADA) ---
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
                          'Estado actual: ${_activationStatus.displayName}', // <<< CAMBIO AQUÍ
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: _activationStatus.color, // <<< CAMBIO AQUÍ
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _activationStatus.description, // <<< CAMBIO AQUÍ
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Card 2: Activación (NUEVO) ---
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
                              color: theme.disabledColor)
                        ),

                        Text(
                          '7727-8551',
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.disabledColor, // <<< CAMBIO AQUÍ
                              fontWeight: FontWeight.bold),
                        )
                      ],
                    ),
                  ),
                ),

                // --- Card 3: Soporte Técnico (NUEVO) ---
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
                          'Reporte de errores de la aplicaion por favor contactarse al correo:' ,
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color:theme.disabledColor)
                        ),
                        Text(
                          'soportetecnico@gmail.com',
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.disabledColor, // <<< CAMBIO AQUÍ
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- 2. Texto de Créditos (Footer) ---
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
      // <<< --- FIN: CAMBIOS --- >>>
    );
  }
}