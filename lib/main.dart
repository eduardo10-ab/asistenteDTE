// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importación para SystemNavigator
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io'; // Para Platform
import 'package:dio/dio.dart'; // Para descargas
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert'; // Para jsonDecode

// <<< --- CAMBIO 1 (CONT): YA NO NECESITAMOS 'device_info_plus' --- >>>
// import 'package:device_info_plus/device_info_plus.dart';

// --- Imports ---
import 'clientes_perfiles_screen.dart';
import 'productos_screen.dart';
import 'configuracion_screen.dart';
import 'menu_flotante_widget.dart';
import 'models.dart';
import 'storage_service.dart';
import 'js_injection.dart';

// --- Colores ---
const Color colorBlanco = Colors.white;
const Color colorCelestePastel = Color(0xFF80D8FF);
const Color colorAzulActivo = Color(0xFF40C4FF);
const Color colorGrisClaro = Color(0xFFF5F5F5);
const Color colorTextoPrincipal = Color(0xFF424242);
const Color colorTextoSecundario = Color(0xFF9E9E9E);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// --- MyApp (Sin cambios) ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Facturación App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ... (Tu ThemeData sin cambios) ...
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorCelestePastel,
          primary: colorCelestePastel,
          secondary: colorAzulActivo,
          surface: colorBlanco,
          onSurface: colorTextoPrincipal,
          surfaceVariant: colorGrisClaro,
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: colorBlanco,
          elevation: 2,
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
  WebViewController? _webViewController;
  late List<Widget> _widgetOptions;
  final StorageService _storage = StorageService();
  ActivationStatus _activationStatus = ActivationStatus.none;
  bool _isLoadingStatus = true;

  // Clave para acceder al estado de HomeScreen
  final GlobalKey<_HomeScreenState> _homeScreenKey =
      GlobalKey<_HomeScreenState>();

  // Clave para acceder al estado de ProductosScreen
  final GlobalKey<ProductosScreenState> _productosScreenKey =
      GlobalKey<ProductosScreenState>();

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
        key: _homeScreenKey, // Asignación de la clave
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
      const Center(
        child: Text(
          'Pantalla de Correo',
          style: TextStyle(color: colorTextoPrincipal),
        ),
      ),
      ClientesPerfilesScreen(currentStatus: _activationStatus),

      ProductosScreen(
        key: _productosScreenKey, // Asigna la key aquí
        currentStatus: _activationStatus,
      ),
    ];
  }

  Future<void> _reloadActivationStatus() async {
    print("Recargando estado...");
    final status = await _storage.getActivationStatus();
    if (!mounted) return;
    if (status != _activationStatus) {
      print("¡Estado cambió a $status!");
      setState(() {
        _activationStatus = status;
        _buildScreens();
      });
    } else {
      print("Estado no cambió.");
    }
  }

  void _onItemTapped(int index) {
    if (!mounted) return;

    // Si el usuario TOCA la pestaña de Productos (índice 3)
    // Y NO estaba ya en esa pestaña...
    if (index == 3 && _selectedIndex != 3) {
      // Llama manualmente al método loadData() de ProductosScreen
      // Esto fuerza la recarga con el perfil más reciente
      _productosScreenKey.currentState?.loadData(_activationStatus);
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    // 1. Revisa si la pantalla de "Inicio" (HomeScreen) está activa
    if (_selectedIndex == 0) {
      // 2. Comprueba si la HomeScreen PUEDE manejar el pop
      final homeState = _homeScreenKey.currentState;
      if (homeState != null) {
        // 3. Llama a la lógica de pop de HomeScreen PRIMERO
        final bool handledByHome = await homeState.handlePop();
        // Si HomeScreen lo manejó (ej. retrocedió en la web o mostró un diálogo),
        // entonces MainScreen NO debe hacer nada (retorna false).
        if (handledByHome) {
          return false; // Pop manejado por HomeScreen
        }
      }
    }

    // 4. Si estamos en otra pestaña (Clientes, etc.), cambia a Inicio
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return false; // Previene que la app se cierre
    }

    // 5. Si estamos en Inicio Y el WebView NO lo manejó, permite salir.
    return true; // Permite que el PopScope llame a SystemNavigator.pop()
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
          // Cierra la app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _mostrarMenuFlotante(
              context,
              _webViewController,
              _reloadActivationStatus,
            );
          },
          child: const Icon(Icons.edit),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavItem(0, Icons.home, 'Inicio'),
              _buildNavItem(1, Icons.mail, 'Correo'),
              _buildNavItem(2, Icons.group, 'Clientes'),
              _buildNavItem(3, Icons.add_shopping_cart, 'Productos'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.secondary
        : colorTextoSecundario;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
} // Fin _MainScreenState

//--- HomeScreen (AHORA CONTIENE EL WEBVIEW) ---
class HomeScreen extends StatefulWidget {
  final ActivationStatus initialStatus;
  final Function(WebViewController) onWebViewRequested;
  final VoidCallback onStatusChangeNeeded;
  const HomeScreen({
    super.key, // Pasamos la clave
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

  // --- LÓGICA DEL WEBVIEW MOVIDA AQUÍ ---
  WebViewController? _controller;
  bool _showWebView = false;
  bool _estaCargando = true;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  DateTime? _lastPdfDownloadTime;
  final Duration _pdfCooldown = const Duration(seconds: 5);

  Future<bool> _requestStoragePermissions() async {
    print('Solicitando permisos de almacenamiento...');

    if (Platform.isAndroid) {
      try {
        var storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) return true;
        final storageRequest = await Permission.storage.request();
        if (storageRequest.isGranted) return true;
      } catch (e) {
        print('Warning: error comprobando Permission.storage: $e');
      }
      try {
        var manageStatus = await Permission.manageExternalStorage.status;
        if (manageStatus.isGranted) return true;
        final manageRequest = await Permission.manageExternalStorage.request();
        if (manageRequest.isGranted) return true;
      } catch (e) {
        print('Notice: manageExternalStorage no disponible o fallo: $e');
      }
      if (mounted) {
        final bool? openSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permiso necesario'),
            content: const Text(
              'La aplicación necesita permiso para guardar archivos (JSON/PDF) en tu dispositivo. '
              'Si no permites el acceso, se guardará una copia en la carpeta interna de la app, '
              'pero no estará en la carpeta Descargas. ¿Deseas abrir la configuración ahora?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abrir configuración'),
              ),
            ],
          ),
        );

        if (openSettings == true) {
          await openAppSettings();
          try {
            if (await Permission.storage.status.isGranted) return true;
            if (await Permission.manageExternalStorage.status.isGranted)
              return true;
          } catch (e) {
            print('Error re-check permisos después de configuración: $e');
          }
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
      print('Error comprobando SharedPreferences para permisos: $e');
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

  // <<<--- INICIO: NUEVA FUNCIÓN AUXILIAR --- >>>
  /// Parsea el JSON para encontrar el 'codigoGeneracion' y usarlo como nombre de archivo.
  String _getFilenameFromJson(String jsonContent, String fallbackName) {
    try {
      final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;

      // Intento 1: Llave "codigoGeneracion" anidada (más común en DTE)
      if (decoded.containsKey('identificacion') &&
          decoded['identificacion'] is Map) {
        final String? codigo =
            (decoded['identificacion'] as Map)['codigoGeneracion']?.toString();
        if (codigo != null && codigo.isNotEmpty) {
          return '$codigo.json';
        }
      }

      // Intento 2: Llave "codigoGeneracion" en la raíz
      final String? codigoRoot = decoded['codigoGeneracion']?.toString();
      if (codigoRoot != null && codigoRoot.isNotEmpty) {
        return '$codigoRoot.json';
      }

      // Intento 3: Usar el fallback si es un nombre de archivo DTE válido (UUID)
      // Quita la extensión .json si la tiene
      String cleanFallback = fallbackName.replaceAll('.json', '');
      // Comprueba si parece un UUID de DTE
      if (cleanFallback.length == 36 && cleanFallback.contains('-')) {
        return '$cleanFallback.json';
      }
    } catch (e) {
      print('Error al parsear JSON para buscar nombre de archivo: $e');
    }

    // Si todo falla, usa el fallback (asegurándose de que termine en .json)
    if (fallbackName.endsWith('.json')) {
      return fallbackName;
    }
    return '$fallbackName.json';
  }
  // <<<--- FIN: NUEVA FUNCIÓN AUXILIAR --- >>>

  Future<void> _setupWebView() async {
    _controller = WebViewController();
    await _controller!.addJavaScriptChannel(
      'FlutterChannel',
      onMessageReceived: (JavaScriptMessage message) async {
        print('Mensaje recibido de JS: ${message.message}');
        try {
          final data = jsonDecode(message.message) as Map<String, dynamic>;

          // Caso 1: El interceptor mejorado (js_injection.dart)
          if (data['action'] == 'downloadDTE') {
            print('Acción downloadDTE (interceptor JS) recibida.');
            if (data['processingStarted'] == true) {
              setState(() {
                _estaCargando = true;
                _isDownloading = false;
              });
            }

            if (data['data'] != null) {
              final jsonData = data['data'] as Map<String, dynamic>;
              final String jsonContent = jsonData['jsonContent'] ?? '';
              final String pdfUrl = jsonData['pdfUrl'] ?? '';

              if (jsonContent.isNotEmpty) {
                // <<< INICIO: CAMBIO --- Nueva Lógica de Nombre --- >>>
                // Usa el nombre del sitio si existe, si no, uno genérico
                final String fallbackName = jsonData['filename'] ?? 'dte.json';
                // Extrae el nombre real del contenido del JSON
                final String finalFilename = _getFilenameFromJson(
                  jsonContent,
                  fallbackName,
                );
                await _handleJsonDataDownload(jsonContent, finalFilename);
                // <<< FIN: CAMBIO --- Nueva Lógica de Nombre --- >>>
              }
              if (pdfUrl.isNotEmpty) {
                await _launchPdfUrl(pdfUrl);
                setState(() => _estaCargando = false);
              }
            }
          }
          // Caso 2: Nuestra nueva acción desde el lector de blob
          else if (data['action'] == 'downloadFromBlob') {
            print('Acción downloadFromBlob (lector de blob) recibida.');
            final String jsonContent = data['jsonContent'] ?? '';

            if (jsonContent.isNotEmpty) {
              // <<< INICIO: CAMBIO --- Nueva Lógica de Nombre --- >>>
              final String fallbackName =
                  data['filename'] ?? 'dte_from_blob.json';
              // Extrae el nombre real del contenido del JSON
              final String finalFilename = _getFilenameFromJson(
                jsonContent,
                fallbackName,
              );
              _handleJsonDataDownload(jsonContent, finalFilename);
              // <<< FIN: CAMBIO --- Nueva Lógica de Nombre --- >>>
            } else {
              _showErrorSnackBar('Error: El blob JSON estaba vacío.');
            }
            _showMessage('JSON descargado. Se abrirá una ventana para el PDF.');
          }
          // Caso 3: Abrir ventana/enlace desde JS (window.open / target="_blank")
          else if (data['action'] == 'openWindow') {
            try {
              final String url = (data['url'] ?? '').toString();
              if (url.isEmpty || url == 'about:blank') {
                print('openWindow ignorado para URL vacía/about:blank');
                return;
              }

              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                _showErrorSnackBar('No se pudo abrir el enlace: $url');
              }
            } catch (e) {
              print('Error abriendo ventana desde JS: $e');
              _showErrorSnackBar('Error al abrir enlace desde la página.');
            }
          }
          // Caso 4: PDF enviado como blob/base64 desde el injector JS
          else if (data['action'] == 'pdfBlob') {
            final now = DateTime.now();
            if (_lastPdfDownloadTime != null &&
                now.difference(_lastPdfDownloadTime!) < _pdfCooldown) {
              print('[pdfBlob] Cooldown: Ignorando descarga duplicada.');
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
              final bool hasPerm = await _requestStoragePermissions();
              if (!hasPerm) {
                _showErrorSnackBar(
                  'Permiso de almacenamiento necesario para guardar el PDF.',
                );
                return;
              }

              Directory downloadsDir = Directory(
                '/storage/emulated/0/Download',
              );
              if (!await downloadsDir.exists())
                await downloadsDir.create(recursive: true);
              final String savePath = '${downloadsDir.path}/$filename';

              final bytes = base64Decode(base64Data);
              final file = File(savePath);
              await file.writeAsBytes(bytes, flush: true);
              print('[pdfBlob] PDF guardado en: $savePath');

              try {
                const platform = MethodChannel(
                  'com.facturacion.sv.app_factura/files',
                );
                await platform.invokeMethod('scanFile', {'path': savePath});
              } catch (e) {
                print('Error solicitando scanFile al nativo (pdfBlob): $e');
              }
              _showMessage('Archivo PDF guardado en Descargas: $filename');
              try {
                final res = await OpenFilex.open(savePath);
                print('OpenFilex result (pdfBlob): $res');
                if (res.type != ResultType.done) {
                  throw Exception('No se pudo abrir el PDF');
                }
              } catch (e) {
                print('Error abriendo PDF con OpenFilex: $e');
                _showErrorSnackBar('Error al abrir el PDF: ${e.toString()}');
              }
            } catch (e) {
              print('Error procesando pdfBlob desde JS: $e');
              _showErrorSnackBar('Error al procesar PDF recibido.');
            }
          }
        } catch (e) {
          print('Error procesando mensaje de JS: $e');
          _showErrorSnackBar('Error procesando datos de la página.');
        }
      },
    );
    await _controller!.setJavaScriptMode(JavaScriptMode.unrestricted);

    await _controller!.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {},
        onPageStarted: (String url) {
          if (mounted) setState(() => _estaCargando = true);
        },
        onPageFinished: (String url) {
          if (mounted) setState(() => _estaCargando = false);
          _controller!.runJavaScript(jsInjector);
          print("Interceptor JS y helpers inyectados en $url");
        },
        onWebResourceError: (WebResourceError error) {
          if (mounted) setState(() => _estaCargando = false);
          print('Error al cargar recurso: ${error.description}');
          _showErrorSnackBar(
            'Error: ${error.description} (Code: ${error.errorCode})',
          );
        },
        onNavigationRequest: (NavigationRequest request) async {
          final String url = request.url;
          print('NavReq: $url | Main frame: ${request.isMainFrame}');

          // REGLA 1: Capturar descargas de archivos (PDF, etc.)
          if (url.endsWith('.pdf') ||
              url.endsWith('.zip') ||
              url.endsWith('.doc') ||
              url.endsWith('.docx') ||
              url.endsWith('.xls') ||
              url.endsWith('.xlsx')) {
            print('Detectada descarga de archivo directo (fallback): $url');
            _handleFileDownload(url);
            return NavigationDecision.prevent;
          }

          // REGLA 2: (Interceptar y leer BLOB - JSON)
          if (url.startsWith('blob:') && request.isMainFrame) {
            print('Navegación a JSON/Blob detectada. PREVINIENDO y LEYENDO...');

            final String blobReadScript =
                '''
        (async function() {
          try {
            const response = await fetch('$url');
            const contentType = (response.headers && response.headers.get) ? (response.headers.get('content-type') || '') : '';
            // Si es PDF, leer como blob y enviar base64
            if (contentType.toLowerCase().includes('pdf')) {
              const blob = await response.blob();
              const reader = new FileReader();
              reader.onload = function() {
                const dataUrl = reader.result; // data:application/pdf;base64,...
                const base64 = (dataUrl && dataUrl.split(',')[1]) ? dataUrl.split(',')[1] : '';
                window.FlutterChannel.postMessage(JSON.stringify({
                  action: 'pdfBlob',
                  base64: base64,
                  filename: 'dte_${DateTime.now().millisecondsSinceEpoch}.pdf'
                }));
              };
              reader.onerror = function(e) {
                console.error('Error leyendo blob como DataURL:', e);
                window.FlutterChannel.postMessage(JSON.stringify({ action: 'downloadError', error: e && e.message }));
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
            console.error('Error al leer el blob:', e);
            window.FlutterChannel.postMessage(JSON.stringify({
              action: 'downloadError',
              error: e && e.message
            }));
          }
        })();
            ''';

            _controller?.runJavaScript(blobReadScript);
            _showMessage('Procesando JSON/PDF...');
            return NavigationDecision.prevent;
          }

          // REGLA 3: (Lógica de about:blank y javascript:)
          if (url == 'about:blank' || url.startsWith('javascript:')) {
            if (url == 'about:blank' && !request.isMainFrame) {
              print('Permitiendo navegación de pop-up a: $url');
              return NavigationDecision.navigate;
            }
            if (url == 'about:blank' && request.isMainFrame) {
              print('Bloqueando navegación de frame principal a: $url');
              return NavigationDecision.prevent;
            }
            if (url.startsWith('javascript:')) {
              print('Permitiendo navegación interna: $url');
              return NavigationDecision.navigate;
            }
          }

          final uri = Uri.parse(url);
          final String currentUrl = await _controller!.currentUrl() ?? '';
          final String currentHost = currentUrl.isNotEmpty
              ? Uri.parse(currentUrl).host
              : '';
          final String requestHost = uri.host;

          // REGLA 4: (Lógica de Pop-up a host externo)
          if (!request.isMainFrame) {
            bool isDifferentHost =
                (uri.scheme == 'http' || uri.scheme == 'https') &&
                currentHost.isNotEmpty &&
                requestHost.isNotEmpty &&
                requestHost != currentHost;

            if (isDifferentHost) {
              print(
                'Detectado pop-up a host diferente ($url). Abriendo externamente.',
              );
              _showMessage('Abriendo enlace externo...');

              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                _showErrorSnackBar('No se pudo abrir enlace externo.');
              }
              return NavigationDecision.prevent;
            }
          }

          // REGLA 5: (Permitir el resto)
          print(
            'Navegación normal permitida (isMainFrame: ${request.isMainFrame}, host: $requestHost).',
          );
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
      print("Error cargando URL inicial: $e");
      _showErrorSnackBar("No se pudo cargar la página inicial.");
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // Función para guardar el contenido del JSON
  Future<void> _handleJsonDataDownload(
    String jsonContent,
    String filename, // <-- AHORA RECIBE EL NOMBRE CORRECTO
  ) async {
    print('[_handleJsonDataDownload] Iniciando guardado de JSON: $filename');
    try {
      bool hasPermission = await _requestStoragePermissions();
      if (!hasPermission) {
        throw Exception('Permiso de almacenamiento denegado');
      }

      if (Platform.isAndroid) {
        try {
          Directory? downloadsDir;
          if (Platform.isAndroid) {
            downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              print('Intentando crear directorio de descargas');
              await downloadsDir.create(recursive: true);
            }
          }

          if (downloadsDir != null) {
            // <<< CAMBIO: 'filename' ya tiene la extensión .json
            final String savePath = '${downloadsDir.path}/$filename';
            final File file = File(savePath);
            await file.writeAsString(jsonContent, flush: true);
            print('[_handleJsonDataDownload] JSON guardado en: $savePath');

            try {
              const platform = MethodChannel(
                'com.facturacion.sv.app_factura/files',
              );
              await platform.invokeMethod('scanFile', {'path': savePath});
            } catch (e) {
              print('Error solicitando scanFile al nativo: $e');
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'JSON guardado: $filename',
                  ), // Muestra el nuevo nombre
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            throw Exception('No se pudo acceder al directorio de descargas');
          }
        } catch (e) {
          print("Error guardando archivo: $e");
          throw Exception('No se pudo guardar el archivo: $e');
        }
      } else {
        // Lógica para otros OS (iOS)
        final directory = await getApplicationDocumentsDirectory();
        final String savePath = '${directory.path}/$filename';
        final File file = File(savePath);
        await file.writeAsString(jsonContent, flush: true);
        print('[_handleJsonDataDownload] JSON guardado en: $savePath');

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
      print("[_handleJsonDataDownload] *** ERROR AL GUARDAR JSON: $e");
      _showErrorSnackBar('Error al guardar archivo JSON: ${e.toString()}');
    }
  }

  // Función para abrir PDF: (Sin cambios en esta sección)
  Future<void> _launchPdfUrl(String pdfUrl) async {
    final now = DateTime.now();
    if (_lastPdfDownloadTime != null &&
        now.difference(_lastPdfDownloadTime!) < _pdfCooldown) {
      print('[_launchPdfUrl] Cooldown: Ignorando descarga duplicada.');
      return;
    }
    _lastPdfDownloadTime = now;

    print("Intentando procesar PDF: $pdfUrl");

    String cleanUrl = pdfUrl.trim();
    if (!cleanUrl.startsWith('http')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final uri = Uri.parse(cleanUrl);

    try {
      final bool hasPerm = await _requestStoragePermissions();
      if (!hasPerm) {
        throw Exception('Permiso de almacenamiento denegado');
      }

      Directory downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final String originalFileName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
                .split('?')
                .first
                .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '')
          : 'documento.pdf';
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = '${timestamp}_$originalFileName';

      final String savePath = '${downloadsDir.path}/$fileName';

      Dio dio = Dio();
      await dio.download(
        cleanUrl,
        savePath,
        onReceiveProgress: (rec, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = rec / total;
              _isDownloading = true;
            });
          }
        },
      );

      try {
        const platform = MethodChannel('com.facturacion.sv.app_factura/files');
        await platform.invokeMethod('scanFile', {'path': savePath});
      } catch (e) {
        print('Error solicitando scanFile al nativo (pdf): $e');
      }

      _showMessage('Archivo PDF guardado en Descargas: $fileName');

      final result = await OpenFilex.open(savePath);
      print('OpenFilex result: $result');
      if (result.type != ResultType.done) {
        throw Exception(
          'OpenFilex no pudo abrir el archivo: ${result.message}',
        );
      }
    } catch (e) {
      print('No fue posible descargar/abrir localmente el PDF: $e');
      _showErrorSnackBar('No se pudo abrir el PDF localmente: ${e.toString()}');

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      } catch (e2) {
        print('Error en fallback al abrir PDF: $e2');
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

  // Función para manejar la descarga de archivos genéricos (Sin cambios en esta sección)
  Future<void> _handleFileDownload(String url, {String? customFileName}) async {
    if (url.endsWith('.pdf') || (customFileName ?? '').endsWith('.pdf')) {
      final now = DateTime.now();
      if (_lastPdfDownloadTime != null &&
          now.difference(_lastPdfDownloadTime!) < _pdfCooldown) {
        print(
          '[_handleFileDownload] Cooldown: Ignorando descarga duplicada de PDF.',
        );
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
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Permiso de almacenamiento denegado');
        }
      }

      Directory downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final String savePath = '${downloadsDir.path}/$fileName';

      Dio dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      try {
        const platform = MethodChannel('com.facturacion.sv.app_factura/files');
        await platform.invokeMethod('scanFile', {'path': savePath});
      } catch (e) {
        print('Error solicitando scanFile al nativo (download): $e');
      }

      if (mounted) {
        if (url.endsWith('.pdf')) {
          _showMessage('Archivo PDF guardado en Descargas: $fileName');
        } else {
          _showMessage('Archivo descargado: $fileName');
        }
      }
    } catch (e) {
      print('Error en la descarga: $e');
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

  // --- Lógica de UI (sin cambios) ---
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green[700]),
    );
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
        setState(() {
          _activationStatus = newStatus;
        });
      }
      if (newStatus == ActivationStatus.pro) {
        _showMessage('¡Aplicación activada a PRO!');
      } else if (newStatus == ActivationStatus.demo) {
        _showMessage('Versión DEMO activada.');
      } else {
        _showError('Clave de activación incorrecta.');
      }
    } catch (e) {
      _showError('Error al activar: ${e.toString()}');
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
        setState(() {
          _showWebView = false;
        });
      }
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool overlayEnabled =
        _activationStatus == ActivationStatus.demo ||
        _activationStatus == ActivationStatus.pro;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _showWebView ? 'Portal de Facturación' : 'Facturación electrónica',
        ),
        actions: _showWebView
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _controller?.reload(),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar portal',
                  onPressed: () => setState(() {
                    _showWebView = false;
                  }),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Configuración',
                  onPressed: () async {
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

  // --- Widgets Refactorizados (sin cambios) ---

  Widget _buildGreetingUI(
    BuildContext context,
    ThemeData theme,
    bool overlayEnabled,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildGreeting(),
        const SizedBox(height: 12),
        Center(
          child: Chip(
            label: Text(
              'Estado: ${_activationStatus.name.toUpperCase()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getStatusChipTextColor(_activationStatus),
              ),
            ),
            backgroundColor: _getStatusChipColor(_activationStatus),
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
        ),
        const SizedBox(height: 20),
        _buildButtons(context),
        const SizedBox(height: 24),
        if (_activationStatus != ActivationStatus.pro) ...[
          _buildActivationSection(),
          const SizedBox(height: 24),
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
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildGreeting() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Hola, Joel',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        Icon(Icons.account_circle, size: 48, color: Colors.grey),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BlankPageWithNav()),
            ),
            child: const Text('Manual'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BlankPageWithNav()),
            ),
            child: const Text('Tutorial'),
          ),
        ),
      ],
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
              'Estado actual: ${_activationStatus.name.toUpperCase()}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: _activationStatus == ActivationStatus.demo
                    ? Colors.orange[800]
                    : theme.textTheme.bodyMedium?.color,
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
              keyboardType: TextInputType.visiblePassword,
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
        Text('Iniciar superposición', style: theme.textTheme.titleMedium),
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
                      print("Error cargando imagen: $error");
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
} // Fin _HomeScreenState

//--- BlankPageWithNav (Sin cambios) ---
class BlankPageWithNav extends StatelessWidget {
  const BlankPageWithNav({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: const Center(child: Text('Página en blanco')),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Correo'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_shopping_cart),
            label: 'Productos',
          ),
        ],
        currentIndex: 0,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) => Navigator.pop(context),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mostrarMenuFlotante(context, null, () {});
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}

// --- FUNCIÓN GLOBAL _mostrarMenuFlotante (Sin cambios) ---
void _mostrarMenuFlotante(
  BuildContext context,
  WebViewController? controller,
  VoidCallback onStatusChangeNeeded,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) {
      return MenuFlotanteWidget(webViewController: controller);
    },
  );
}
