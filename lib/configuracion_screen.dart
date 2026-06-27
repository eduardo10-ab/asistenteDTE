// lib/configuracion_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart'; // <--- IMPORTANTE
import 'package:open_filex/open_filex.dart';
import 'theme_provider.dart'; // <--- IMPORTANTE
import 'storage_service.dart';
import 'services/excel_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  late final StorageService _storageService;
  late final ExcelService _excelService;
  bool _generandoExcel = false;

  @override
  void initState() {
    super.initState();
    // CRÍTICO: inicializar en initState, NO en build()
    // Si se inicializan en build(), el late final falla al reconstruir (ej. cambio de tema)
    _storageService = Provider.of<StorageService>(context, listen: false);
    _excelService = Provider.of<ExcelService>(context, listen: false);
    _storageService.addListener(_onStorageChanged);
  }

  @override
  void dispose() {
    _storageService.removeListener(_onStorageChanged);
    super.dispose();
  }

  void _onStorageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _abrirPoliticas() async {
    final Uri url = Uri.parse(
      'https://drive.google.com/file/d/1cf2wmjUVlTGlXAo1dQDbEc020FkU04gQ/view?usp=sharing',
    );
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

  Future<void> _generarReporteExcel() async {
    if (_generandoExcel) return;

    setState(() => _generandoExcel = true);
    try {
      final perfil = await _storageService.getCurrentProfileData();
      final nombrePerfil = await _storageService.getCurrentProfileName();
      final file = await _excelService.generarReporteVentasExcel(
        nombrePerfil: nombrePerfil,
        ventas: perfil.ventas,
      );

      await OpenFilex.open(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reporte generado: ${file.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al generar reporte: $e')));
    } finally {
      if (mounted) {
        setState(() => _generandoExcel = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Obtenemos el provider para saber qué tema está seleccionado
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Configuración')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // --- NUEVA SECCIÓN: VISUALIZACIÓN ---
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            top: 10,
                            bottom: 5,
                          ),
                          child: Text(
                            'Visualización',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.system,
                                label: Text('Sistema'),
                                icon: Icon(Icons.phone_android),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.light,
                                label: Text('Claro'),
                                icon: Icon(Icons.light_mode),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.dark,
                                label: Text('Oscuro'),
                                icon: Icon(Icons.dark_mode),
                              ),
                            ],
                            selected: {themeProvider.themeMode},
                            onSelectionChanged: (selection) {
                              themeProvider.setThemeMode(selection.first);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- Card 2: Activación ---
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Activación', style: theme.textTheme.titleMedium),
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
                          child: FilledButton(
                            onPressed: _abrirPoliticas,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: const Text(
                              'Ver políticas de privacidad',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reportes', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Genera un archivo Excel con el historial de facturación del perfil actual.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _generandoExcel
                                ? null
                                : _generarReporteExcel,
                            icon: _generandoExcel
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.grid_on),
                            label: Text(
                              _generandoExcel
                                  ? 'Generando reporte...'
                                  : 'Reporte de Ventas',
                            ),
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

                // --- Card 4: Políticas de Privacidad ---
              ],
            ),
          ),

          // --- Footer ---
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
