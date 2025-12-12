// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:provider/provider.dart'; // <--- IMPORTANTE: Provider

// --- Imports ---
import 'clientes_perfiles_screen.dart';
import 'productos_screen.dart';
import 'configuracion_screen.dart';
import 'menu_flotante_widget.dart';
import 'models.dart';
import 'storage_service.dart';
import 'js_injection.dart';
import 'correo_screen.dart';
import 'theme_provider.dart'; // <--- IMPORTANTE: Tu archivo de tema

// --- Colores Constantes (Modo Claro) ---
const Color colorBlanco = Colors.white;
const Color colorCelestePastel = Color(0xFF80D8FF);
const Color colorAzulActivo = Color(0xFF40C4FF);
const Color colorGrisClaro = Color(0xFFF5F5F5);
const Color colorTextoPrincipal = Color(0xFF424242);
const Color colorTextoSecundario = Color(0xFF9E9E9E);

// --- Colores Constantes (Modo Oscuro) ---
const Color colorFondoOscuro = Color(0xFF121212);
const Color colorCardOscuro = Color(0xFF1E1E1E);
const Color colorTextoOscuro = Color(0xFFE0E0E0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Envolvemos la app en el ChangeNotifierProvider para manejar el estado del tema
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

// --- MyApp ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios del tema
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Facturación App',
      debugShowCheckedModeBanner: false,

      // Le decimos a la app qué modo usar (Claro, Oscuro o Sistema)
      themeMode: themeProvider.themeMode,

      // --- TEMA CLARO (Tu diseño original) ---
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorCelestePastel,
          primary: colorCelestePastel,
          secondary: colorAzulActivo,
          surface: colorBlanco,
          onSurface: colorTextoPrincipal,
          surfaceContainerHighest: colorGrisClaro,
          onSurfaceVariant: colorTextoPrincipal,
          onPrimary: colorTextoPrincipal,
          onSecondary: Colors.white,
          error: Colors.red[700] ?? Colors.red,
        ),
        scaffoldBackgroundColor: colorBlanco,
        appBarTheme: const AppBarTheme(
          backgroundColor: colorBlanco,
          foregroundColor: colorTextoPrincipal,
          elevation: 1,
          iconTheme: IconThemeData(color: colorTextoPrincipal),
          titleTextStyle: TextStyle(
            color: colorTextoPrincipal,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: colorBlanco,
          elevation: 2,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: colorBlanco,
          elevation: 2,
          selectedItemColor: colorAzulActivo,
          unselectedItemColor: colorTextoSecundario,
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: colorAzulActivo,
          foregroundColor: colorBlanco,
        ),
        cardTheme: CardThemeData(
          color: colorGrisClaro,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorAzulActivo,
            foregroundColor: colorBlanco,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorAzulActivo,
            side: const BorderSide(color: colorAzulActivo),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorBlanco,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: colorAzulActivo, width: 1.5),
          ),
          hintStyle: const TextStyle(color: colorTextoSecundario),
          labelStyle: const TextStyle(color: colorTextoSecundario),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: colorBlanco,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: colorAzulActivo, width: 1.5),
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: colorTextoPrincipal, fontSize: 16),
          bodyMedium: TextStyle(color: colorTextoSecundario, fontSize: 14),
          titleLarge: TextStyle(
            color: colorTextoPrincipal,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          titleMedium: TextStyle(
            color: colorTextoPrincipal,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: colorGrisClaro,
          labelStyle: const TextStyle(color: colorTextoPrincipal),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // --- TEMA OSCURO (Nueva Configuración) ---
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: colorCelestePastel,
          primary: colorAzulActivo,
          secondary: colorCelestePastel,
          surface: colorFondoOscuro,
          onSurface: colorTextoOscuro,
          surfaceContainerHighest: colorCardOscuro,
          error: Colors.red[300] ?? Colors.red,
        ),
        scaffoldBackgroundColor: colorFondoOscuro,
        appBarTheme: const AppBarTheme(
          backgroundColor: colorFondoOscuro,
          foregroundColor: colorTextoOscuro,
          elevation: 0,
          iconTheme: IconThemeData(color: colorTextoOscuro),
          titleTextStyle: TextStyle(
            color: colorTextoOscuro,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: colorCardOscuro,
          elevation: 2,
          selectedItemColor: colorAzulActivo,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: colorAzulActivo,
          foregroundColor: colorBlanco,
        ),
        cardTheme: CardThemeData(
          color: colorCardOscuro,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorAzulActivo,
            foregroundColor: colorBlanco,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorAzulActivo,
            side: const BorderSide(color: colorAzulActivo),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        // Ajustamos los inputs para que se vean bien en oscuro
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorCardOscuro,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: colorAzulActivo, width: 1.5),
          ),
          hintStyle: const TextStyle(color: Colors.grey),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: colorCardOscuro,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: colorAzulActivo, width: 1.5),
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: colorTextoOscuro, fontSize: 16),
          bodyMedium: TextStyle(color: Colors.grey, fontSize: 14),
          titleLarge: TextStyle(
            color: colorTextoOscuro,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          titleMedium: TextStyle(
            color: colorTextoOscuro,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: colorCardOscuro,
          labelStyle: const TextStyle(color: colorTextoOscuro),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      home: const MainScreen(),
    );
  }
}

// --- MainScreen ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  // Variable para controlar si el menú está abierto
  bool _isMenuOpen = false;

  WebViewController? _webViewController;
  late List<Widget> _widgetOptions;
  final StorageService _storage = StorageService();
  ActivationStatus _activationStatus = ActivationStatus.none;
  bool _isLoadingStatus = true;

  final GlobalKey<_HomeScreenState> _homeScreenKey =
      GlobalKey<_HomeScreenState>();
  final GlobalKey<ProductosScreenState> _productosScreenKey =
      GlobalKey<ProductosScreenState>();
  final GlobalKey<CorreoScreenState> _correoScreenKey =
      GlobalKey<CorreoScreenState>();

  @override
  void initState() {
    super.initState();
    _loadInitialStatusAndBuildScreens();
  }

  Future<void> _loadInitialStatusAndBuildScreens() async {
    final status = await _storage.getActivationStatus();
    if (!mounted) return;
    setState(() {
      _activationStatus = status;
      _isLoadingStatus = false;
      _buildScreens();
    });
  }

  void _buildScreens() {
    _widgetOptions = <Widget>[
      HomeScreen(
        key: _homeScreenKey,
        initialStatus: _activationStatus,
        onWebViewRequested: (controller) {
          if (mounted) {
            setState(() {
              _webViewController = controller;
            });
          }
        },
        onStatusChangeNeeded: _reloadActivationStatus,
      ),
      CorreoScreen(key: _correoScreenKey, currentStatus: _activationStatus),
      ClientesPerfilesScreen(currentStatus: _activationStatus),
      ProductosScreen(
        key: _productosScreenKey,
        currentStatus: _activationStatus,
      ),
    ];
  }

  Future<void> _reloadActivationStatus() async {
    if (kDebugMode) {
      print("Recargando estado...");
    }
    final status = await _storage.getActivationStatus();
    if (!mounted) return;
    if (status != _activationStatus) {
      if (kDebugMode) {
        print("¡Estado cambió a $status!");
      }
      setState(() {
        _activationStatus = status;
        _buildScreens();
      });
    } else {
      if (kDebugMode) {
        print("Estado no cambió.");
      }
    }
  }

  void _onItemTapped(int index) {
    if (!mounted) return;

    if (index == 1 && _selectedIndex != 1) {
      _correoScreenKey.currentState?.loadData();
    }
    if (index == 3 && _selectedIndex != 3) {
      _productosScreenKey.currentState?.loadData(_activationStatus);
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex == 0) {
      final homeState = _homeScreenKey.currentState;
      if (homeState != null) {
        final bool handledByHome = await homeState.handlePop();
        if (handledByHome) {
          return false;
        }
      }
    }
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return false;
    }
    return true;
  }

  // Función para controlar el menú flotante y ocultar la pluma
  Future<void> _mostrarMenuFlotanteInterno() async {
    setState(() {
      _isMenuOpen = true; // 1. Ocultar el botón
    });

    // 2. Esperar a que el menú se cierre (await)
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) =>
          MenuFlotanteWidget(webViewController: _webViewController),
    );

    // 3. Cuando se cierra (por X o click fuera), volver a mostrar el botón
    if (mounted) {
      setState(() {
        _isMenuOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final bool shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
        // Verificamos también que el menú NO esté abierto (!__isMenuOpen)
        floatingActionButton: (_selectedIndex == 0 && !_isMenuOpen)
            ? FloatingActionButton(
                onPressed: () {
                  if (!context.mounted) return;
                  _mostrarMenuFlotanteInterno();
                },
                child: const Icon(Icons.mode_edit, color: colorBlanco),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Correo'),
            BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Clientes'),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_shopping_cart),
              label: 'Productos',
            ),
          ],
        ),
      ),
    );
  }
}

//--- HomeScreen ---
class HomeScreen extends StatefulWidget {
  final ActivationStatus initialStatus;
  final Function(WebViewController) onWebViewRequested;
  final VoidCallback onStatusChangeNeeded;
  const HomeScreen({
    super.key,
    required this.initialStatus,
    required this.onWebViewRequested,
    required this.onStatusChangeNeeded,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ActivationStatus _activationStatus;
  final TextEditingController _activationKeyController =
      TextEditingController();
  bool _isActivating = false;
  final StorageService _storage = StorageService();

  WebViewController? _controller;
  bool _showWebView = false;
  bool _estaCargando = true;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  DateTime? _lastPdfDownloadTime;
  final Duration _pdfCooldown = const Duration(seconds: 5);

  Future<bool> _requestStoragePermissions() async {
    if (kDebugMode) {
      print('Solicitando permisos de almacenamiento...');
    }

    if (Platform.isAndroid) {
      try {
        var storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) {
          return true;
        }
        final storageRequest = await Permission.storage.request();
        if (storageRequest.isGranted) {
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Warning: error comprobando Permission.storage: $e');
        }
      }
      return false;
    }
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

  Future<String> _saveFileToDownloadsPublic(
    Uint8List data,
    String filename,
  ) async {
    try {
      const platform = MethodChannel('com.facturacion.sv.app_factura/files');

      final String? savePath = await platform.invokeMethod('saveToDownloads', {
        'data': data,
        'filename': filename,
      });

      if (savePath == null || savePath.isEmpty) {
        throw Exception(
          'Error nativo: La ruta de guardado es nula o vacía. ¿Falta implementar Kotlin?',
        );
      }
      return savePath;
    } catch (e) {
      if (kDebugMode) {
        print('Error en _saveFileToDownloadsPublic: $e');
      }
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _activationStatus = widget.initialStatus;
    _maybeRequestStoragePermission();
  }

  Future<void> _maybeRequestStoragePermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final asked = prefs.getBool('storage_permission_asked') ?? false;
      if (!asked) {
        await _requestStoragePermissions();
        await prefs.setBool('storage_permission_asked', true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error comprobando SharedPreferences para permisos: $e');
      }
    }
  }

  @override
  void dispose() {
    _activationKeyController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStatus != oldWidget.initialStatus) {
      setState(() {
        _activationStatus = widget.initialStatus;
      });
    }
  }

  String _getFilenameFromJson(String jsonContent, String fallbackName) {
    try {
      final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
      if (decoded.containsKey('identificacion') &&
          decoded['identificacion'] is Map) {
        final String? codigo =
            (decoded['identificacion'] as Map)['codigoGeneracion']?.toString();
        if (codigo != null && codigo.isNotEmpty) {
          return '$codigo.json';
        }
      }
      final String? codigoRoot = decoded['codigoGeneracion']?.toString();
      if (codigoRoot != null && codigoRoot.isNotEmpty) {
        return '$codigoRoot.json';
      }
      String cleanFallback = fallbackName.replaceAll('.json', '');
      if (cleanFallback.length == 36 && cleanFallback.contains('-')) {
        return '$cleanFallback.json';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al parsear JSON para buscar nombre de archivo: $e');
      }
    }
    if (fallbackName.endsWith('.json')) {
      return fallbackName;
    }
    return '$fallbackName.json';
  }

  Future<void> _setupWebView() async {
    _controller = WebViewController();
    await _controller!.addJavaScriptChannel(
      'FlutterChannel',
      onMessageReceived: (JavaScriptMessage message) async {
        if (kDebugMode) {
          print('Mensaje recibido de JS: ${message.message}');
        }
        try {
          final data = jsonDecode(message.message) as Map<String, dynamic>;

          if (data['action'] == 'downloadDTE') {
            if (kDebugMode) {
              print('Acción downloadDTE (interceptor JS) recibida.');
            }
            if (data['processingStarted'] == true) {
              if (mounted) {
                setState(() {
                  _estaCargando = true;
                  _isDownloading = false;
                });
              }
            }
            if (data['data'] != null) {
              final jsonData = data['data'] as Map<String, dynamic>;
              final String jsonContent = jsonData['jsonContent'] ?? '';
              final String pdfUrl = jsonData['pdfUrl'] ?? '';
              if (jsonContent.isNotEmpty) {
                final String fallbackName = jsonData['filename'] ?? 'dte.json';
                final String finalFilename = _getFilenameFromJson(
                  jsonContent,
                  fallbackName,
                );
                await _handleJsonDataDownload(jsonContent, finalFilename);
              }
              if (pdfUrl.isNotEmpty) {
                await _launchPdfUrl(pdfUrl);
                if (mounted) {
                  setState(() => _estaCargando = false);
                }
              }
            }
          } else if (data['action'] == 'downloadFromBlob') {
            if (kDebugMode) {
              print('Acción downloadFromBlob (lector de blob) recibida.');
            }
            final String jsonContent = data['jsonContent'] ?? '';
            if (jsonContent.isNotEmpty) {
              final String fallbackName =
                  data['filename'] ?? 'dte_from_blob.json';
              final String finalFilename = _getFilenameFromJson(
                jsonContent,
                fallbackName,
              );
              _handleJsonDataDownload(jsonContent, finalFilename);
            } else {
              _showErrorSnackBar('Error: El blob JSON estaba vacío.');
            }
            _showMessage('JSON descargado. Se abrirá una ventana para el PDF.');
          } else if (data['action'] == 'openWindow') {
            try {
              final String url = (data['url'] ?? '').toString();
              if (url.isEmpty || url == 'about:blank') {
                if (kDebugMode) {
                  print('openWindow ignorado para URL vacía/about:blank');
                }
                return;
              }
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                _showErrorSnackBar('No se pudo abrir el enlace: $url');
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error abriendo ventana desde JS: $e');
              }
              _showErrorSnackBar('Error al abrir enlace desde la página.');
            }
          } else if (data['action'] == 'pdfBlob') {
            final now = DateTime.now();
            if (_lastPdfDownloadTime != null &&
                now.difference(_lastPdfDownloadTime!) < _pdfCooldown) {
              if (kDebugMode) {
                print('[pdfBlob] Cooldown: Ignorando descarga duplicada.');
              }
              return;
            }
            _lastPdfDownloadTime = now;
            try {
              final String base64Data = data['base64'] ?? '';
              final String originalFileName =
                  data['filename']?.replaceAll(
                    RegExp(r'[^a-zA-Z0-9_.-]'),
                    '',
                  ) ??
                  'dte_blob.pdf';
              final String timestamp = DateTime.now().millisecondsSinceEpoch
                  .toString();
              final String filename = '${timestamp}_$originalFileName';
              if (base64Data.isEmpty) {
                _showErrorSnackBar('PDF vacío o no válido.');
                return;
              }

              final bytes = base64Decode(base64Data);

              final String savePath = await _saveFileToDownloadsPublic(
                bytes,
                filename,
              );

              if (kDebugMode) {
                print('[pdfBlob] PDF guardado en: $savePath');
              }
              try {
                const platform = MethodChannel(
                  'com.facturacion.sv.app_factura/files',
                );
                await platform.invokeMethod('scanFile', {'path': savePath});
              } catch (e) {
                if (kDebugMode) {
                  print('Error solicitando scanFile: $e');
                }
              }
              _showMessage('Archivo PDF guardado en Descargas: $filename');
              try {
                final res = await OpenFilex.open(savePath);
                if (kDebugMode) {
                  print('OpenFilex result (pdfBlob): $res');
                }
                if (res.type != ResultType.done) {
                  throw Exception('No se pudo abrir el PDF');
                }
              } catch (e) {
                if (kDebugMode) {
                  print('Error abriendo PDF con OpenFilex: $e');
                }
                _showErrorSnackBar('Error al abrir el PDF: ${e.toString()}');
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error procesando pdfBlob desde JS: $e');
              }
              _showErrorSnackBar(
                'Error al procesar PDF recibido: ${e.toString()}',
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error procesando mensaje de JS: $e');
          }
          _showErrorSnackBar('Error procesando datos de la página.');
        }
      },
    );
    await _controller!.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller!.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {},
        onPageStarted: (String url) {
          if (mounted) {
            setState(() => _estaCargando = true);
          }
        },
        onPageFinished: (String url) {
          if (mounted) {
            setState(() => _estaCargando = false);
          }
          _controller!.runJavaScript(jsInjector);
          if (kDebugMode) {
            print("Interceptor JS y helpers inyectados en $url");
          }
        },
        onWebResourceError: (WebResourceError error) {
          if (mounted) {
            setState(() => _estaCargando = false);
          }
          if (kDebugMode) {
            print('Error al cargar recurso: ${error.description}');
          }
          _showErrorSnackBar(
            'Error: ${error.description} (Code: ${error.errorCode})',
          );
        },
        onNavigationRequest: (NavigationRequest request) async {
          final String url = request.url;
          if (kDebugMode) {
            print('NavReq: $url | Main frame: ${request.isMainFrame}');
          }
          if (url.endsWith('.pdf') ||
              url.endsWith('.zip') ||
              url.endsWith('.doc') ||
              url.endsWith('.docx') ||
              url.endsWith('.xls') ||
              url.endsWith('.xlsx')) {
            if (kDebugMode) {
              print('Detectada descarga de archivo directo (fallback): $url');
            }
            _handleFileDownload(url);
            return NavigationDecision.prevent;
          }
          if (url.startsWith('blob:') && request.isMainFrame) {
            if (kDebugMode) {
              print(
                'Navegación a JSON/Blob detectada. PREVINIENDO y LEYENDO...',
              );
            }
            final String blobReadScript =
                '''
        (async function() {
          try {
            const response = await fetch('$url');
            const contentType = (response.headers && response.headers.get) ? (response.headers.get('content-type') || '') : '';
            if (contentType.toLowerCase().includes('pdf')) {
              const blob = await response.blob();
              const reader = new FileReader();
              reader.onload = function() {
                const base64 = reader.result.split(',')[1];
                window.FlutterChannel.postMessage(JSON.stringify({
                  action: 'pdfBlob',
                  base64: base64,
                  filename: 'dte_${DateTime.now().millisecondsSinceEpoch}.pdf'
                }));
              };
              reader.readAsDataURL(blob);
            } else {
              const text = await response.text();
              window.FlutterChannel.postMessage(JSON.stringify({
                action: 'downloadFromBlob',
                jsonContent: text,
                filename: 'dte_blob_${DateTime.now().millisecondsSinceEpoch}.json'
              }));
            }
          } catch (e) {
            window.FlutterChannel.postMessage(JSON.stringify({ action: 'downloadError', error: e && e.message }));
          }
        })();
            ''';
            _controller?.runJavaScript(blobReadScript);
            _showMessage('Procesando JSON/PDF...');
            return NavigationDecision.prevent;
          }
          if (url == 'about:blank' || url.startsWith('javascript:')) {
            if (url == 'about:blank' && !request.isMainFrame) {
              if (kDebugMode) {
                print('Permitiendo navegación de pop-up a: $url');
              }
              return NavigationDecision.navigate;
            }
            if (url == 'about:blank' && request.isMainFrame) {
              if (kDebugMode) {
                print('Bloqueando navegación de frame principal a: $url');
              }
              return NavigationDecision.prevent;
            }
            if (url.startsWith('javascript:')) {
              if (kDebugMode) {
                print('Permitiendo navegación interna: $url');
              }
              return NavigationDecision.navigate;
            }
          }
          final uri = Uri.parse(url);
          final String currentUrl = await _controller!.currentUrl() ?? '';
          final String currentHost = currentUrl.isNotEmpty
              ? Uri.parse(currentUrl).host
              : '';
          if (!request.isMainFrame &&
              uri.host.isNotEmpty &&
              uri.host != currentHost) {
            if (kDebugMode) {
              print(
                'Detectado pop-up a host diferente ($url). Abriendo externamente.',
              );
            }
            _showMessage('Abriendo enlace externo...');

            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              _showErrorSnackBar('No se pudo abrir enlace externo.');
            }
            return NavigationDecision.prevent;
          }
          if (kDebugMode) {
            print(
              'Navegación normal permitida (isMainFrame: ${request.isMainFrame}, host: ${uri.host}).',
            );
          }
          return NavigationDecision.navigate;
        },
      ),
    );
    if (mounted) {
      widget.onWebViewRequested(_controller!);
    }
    try {
      await _controller!.loadRequest(
        Uri.parse('https://admin.factura.gob.sv/login'),
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error cargando URL inicial: $e");
      }
      _showErrorSnackBar("No se pudo cargar la página inicial.");
      if (mounted) {
        setState(() => _estaCargando = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleJsonDataDownload(
    String jsonContent,
    String filename,
  ) async {
    try {
      await _requestStoragePermissions();

      if (Platform.isAndroid) {
        final Uint8List dataBytes = utf8.encode(jsonContent);
        final String savePath = await _saveFileToDownloadsPublic(
          dataBytes,
          filename,
        );

        if (kDebugMode) {
          print('[_handleJsonDataDownload] JSON guardado en: $savePath');
        }
        try {
          const platform = MethodChannel(
            'com.facturacion.sv.app_factura/files',
          );
          await platform.invokeMethod('scanFile', {'path': savePath});
        } catch (e) {
          if (kDebugMode) {
            print('Error solicitando scanFile: $e');
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('JSON guardado en Descargas: $filename'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final String savePath = '${directory.path}/$filename';
        final File file = File(savePath);
        await file.writeAsString(jsonContent, flush: true);
        if (kDebugMode) {
          print('[_handleJsonDataDownload] JSON guardado en: $savePath');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('JSON guardado: $filename'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("[_handleJsonDataDownload] *** ERROR AL GUARDAR JSON: $e");
      }
      _showErrorSnackBar('Error al guardar archivo JSON: ${e.toString()}');
    }
  }

  Future<void> _launchPdfUrl(String pdfUrl) async {
    final now = DateTime.now();
    if (_lastPdfDownloadTime != null &&
        now.difference(_lastPdfDownloadTime!) < _pdfCooldown) {
      return;
    }
    _lastPdfDownloadTime = now;

    String cleanUrl = pdfUrl.trim();
    if (!cleanUrl.startsWith('http')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final uri = Uri.parse(cleanUrl);

    try {
      await _requestStoragePermissions();

      final String originalFileName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
                .split('?')
                .first
                .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '')
          : 'documento.pdf';
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = '${timestamp}_$originalFileName';

      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/$fileName';

      Dio dio = Dio();
      await dio.download(
        cleanUrl,
        tempPath,
        onReceiveProgress: (rec, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = rec / total;
              _isDownloading = true;
            });
          }
        },
      );

      final File tempFile = File(tempPath);
      final Uint8List fileBytes = await tempFile.readAsBytes();

      final String savePath = await _saveFileToDownloadsPublic(
        fileBytes,
        fileName,
      );

      await tempFile.delete();

      try {
        const platform = MethodChannel('com.facturacion.sv.app_factura/files');
        await platform.invokeMethod('scanFile', {'path': savePath});
      } catch (e) {
        if (kDebugMode) {
          print('Error solicitando scanFile: $e');
        }
      }

      _showMessage('Archivo PDF guardado en Descargas: $fileName');

      final result = await OpenFilex.open(savePath);
      if (kDebugMode) {
        print('OpenFilex result: $result');
      }
      if (result.type != ResultType.done) {
        throw Exception(
          'OpenFilex no pudo abrir el archivo: ${result.message}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('No fue posible descargar/abrir localmente el PDF: $e');
      }
      _showErrorSnackBar('No se pudo abrir el PDF localmente: ${e.toString()}');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      } catch (e2) {
        if (kDebugMode) {
          print('Error en fallback al abrir PDF: $e2');
        }
        _showErrorSnackBar('No se pudo abrir el PDF de ninguna forma');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _handleFileDownload(String url, {String? customFileName}) async {
    if (url.endsWith('.pdf') || (customFileName ?? '').endsWith('.pdf')) {
      final now = DateTime.now();
      if (_lastPdfDownloadTime != null &&
          now.difference(_lastPdfDownloadTime!) < _pdfCooldown) {
        return;
      }
      _lastPdfDownloadTime = now;
    }

    if (_isDownloading) {
      _showErrorSnackBar("Ya hay una descarga en curso.");
      return;
    }

    String originalFileName =
        customFileName ??
        url
            .split('/')
            .last
            .split('?')
            .first
            .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '');
    if (originalFileName.isEmpty || !originalFileName.contains('.')) {
      originalFileName = 'download.file';
    }
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String fileName = '${timestamp}_$originalFileName';

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      await _requestStoragePermissions();

      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/$fileName';

      Dio dio = Dio();
      await dio.download(
        url,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      final File tempFile = File(tempPath);
      final Uint8List fileBytes = await tempFile.readAsBytes();

      final String savePath = await _saveFileToDownloadsPublic(
        fileBytes,
        fileName,
      );

      await tempFile.delete();

      try {
        const platform = MethodChannel('com.facturacion.sv.app_factura/files');
        await platform.invokeMethod('scanFile', {'path': savePath});
      } catch (e) {
        if (kDebugMode) {
          print('Error solicitando scanFile: $e');
        }
      }

      if (mounted) {
        if (url.endsWith('.pdf')) {
          _showMessage('Archivo PDF guardado en Descargas: $fileName');
        } else {
          _showMessage('Archivo descargado: $fileName');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en la descarga: $e');
      }
      _showErrorSnackBar('Error al descargar el archivo: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green[700]),
      );
    }
  }

  Future<void> _activateApp() async {
    final key = _activationKeyController.text.trim();
    if (key.isEmpty) {
      _showError('Por favor, introduce una clave.');
      return;
    }
    setState(() => _isActivating = true);
    try {
      final newStatus = await _storage.activateLicense(key);
      _activationKeyController.clear();
      widget.onStatusChangeNeeded();
      if (mounted) {
        setState(() => _activationStatus = newStatus);
      }
      if (newStatus == ActivationStatus.pro) {
        _showMessage('¡Aplicación activada a PRO!');
      } else if (newStatus == ActivationStatus.demo) {
        _showMessage('Versión DEMO activada.');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  Future<bool> handlePop() async {
    if (!_showWebView) {
      return false;
    }
    final canGoBack = await _controller?.canGoBack() ?? false;
    if (canGoBack) {
      _controller!.goBack();
      return true;
    } else {
      if (!mounted) return true;
      final bool? shouldClose = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cerrar Portal'),
          content: const Text(
            '¿Estás seguro de que quieres cerrar el portal web? Volverás a la pantalla de inicio.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, cerrar'),
            ),
          ],
        ),
      );
      if (shouldClose == true && mounted) {
        setState(() => _showWebView = false);
      }
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool overlayEnabled =
        _activationStatus == ActivationStatus.demo ||
        _activationStatus == ActivationStatus.pro;

    // Obtenemos el tema actual (Claro u Oscuro)
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_showWebView ? 'Portal de Facturación' : 'Inicio'),
        actions: _showWebView
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _controller?.reload(),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar portal',
                  onPressed: () => setState(() => _showWebView = false),
                ),
              ]
            : [
                Padding(
                  padding: const EdgeInsets.only(
                    right: 8.0,
                    top: 8.0,
                    bottom: 8.0,
                  ),
                  child: Chip(
                    label: Text(
                      _activationStatus.chipLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusChipTextColor(_activationStatus),
                      ),
                    ),
                    backgroundColor: _getStatusChipColor(_activationStatus),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Configuración',
                  onPressed: () async {
                    if (!mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConfiguracionScreen(),
                      ),
                    );
                    widget.onStatusChangeNeeded();
                    final newStatus = await _storage.getActivationStatus();
                    if (mounted && newStatus != _activationStatus) {
                      setState(() => _activationStatus = newStatus);
                    }
                  },
                ),
              ],
      ),
      body: Stack(
        children: [
          Offstage(
            offstage: _showWebView,
            child: _buildGreetingUI(context, theme, overlayEnabled),
          ),
          Offstage(offstage: !_showWebView, child: _buildWebViewUI()),
        ],
      ),
    );
  }

  Widget _buildGreetingUI(
    BuildContext context,
    ThemeData theme,
    bool overlayEnabled,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const SizedBox(height: 16.0),
        _buildGreeting(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Divider(color: Colors.grey[300], height: 1),
        ),
        if (_activationStatus != ActivationStatus.pro) ...[
          _buildActivationSection(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Divider(color: Colors.grey[300], height: 1),
          ),
        ],
        _buildOverlaySection(context, overlayEnabled ? _toggleWebView : null),
        const SizedBox(height: 24),
        if (_activationStatus != ActivationStatus.pro) _buildProSection(),
      ],
    );
  }

  Widget _buildWebViewUI() {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_estaCargando) const Center(child: CircularProgressIndicator()),
        if (_isDownloading)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 10,
            ),
          ),
      ],
    );
  }

  void _toggleWebView() {
    if (_controller == null) {
      setState(() {
        _estaCargando = true;
      });
      _setupWebView();
    }
    setState(() {
      _showWebView = true;
    });
  }

  Color _getStatusChipColor(ActivationStatus status) {
    switch (status) {
      case ActivationStatus.pro:
        return Colors.green.shade50;
      case ActivationStatus.demo:
        return Colors.orange.shade50;
      case ActivationStatus.none:
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getStatusChipTextColor(ActivationStatus status) {
    switch (status) {
      case ActivationStatus.pro:
        return Colors.green.shade800;
      case ActivationStatus.demo:
        return Colors.orange.shade800;
      case ActivationStatus.none:
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildGreeting() {
    return const Text(
      'Bienvenido a tu asistente de facturación DTE',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildActivationSection() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activación de la aplicación',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Estado actual: ${_activationStatus.chipLabel}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: _activationStatus.color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Para la activación de todas las funcionalidades por favor contactarnos al: ',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '7727-8551 o 7722-0472',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.disabledColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Introduce tu clave de licencia:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _activationKeyController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'XXXX-XXXX-XXXX-XXXX',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isActivating ? null : _activateApp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
              child: _isActivating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Activar'),
            ),
            const SizedBox(height: 16),
            Text('Clave DEMO: DEMO-2025', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlaySection(
    BuildContext context,
    VoidCallback? onWebViewNavigated,
  ) {
    final bool isEnabled = onWebViewNavigated != null;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Iniciar Asistente DTE', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: InkWell(
            onTap: onWebViewNavigated,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/cardPrincipal.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      if (kDebugMode) {
                        print("Error cargando imagen: $error");
                      }
                      return Container(
                        height: 150,
                        color: Colors.grey[200],
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 40,
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: Colors.grey[300]),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(
                      'Ir al sitio web',
                      style: TextStyle(
                        color: isEnabled
                            ? theme.colorScheme.secondary
                            : Colors.grey,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Activa la aplicación (DEMO o PRO) para usar esta función.',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildProSection() {
    return Card(
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Text(
          'Actualiza a la version PRO para acceder a todas las caracteristicas de la app',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
