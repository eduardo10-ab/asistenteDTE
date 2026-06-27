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
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:provider/provider.dart'; // <--- IMPORTANTE: Provider

// --- Imports ---
import 'clientes_perfiles_screen.dart';
import 'productos_screen.dart';
import 'menu_flotante_widget.dart';
import 'models.dart';
import 'storage_service.dart';
import 'js_injection.dart';
import 'correo_screen.dart';
import 'admin_panel_screen.dart';
import 'historial_facturas_screen.dart';
import 'theme_provider.dart'; // <--- IMPORTANTE: Tu archivo de tema
import 'core/ui/app_colors.dart';
import 'services/excel_service.dart';
import 'profile_avatar_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configurar Firestore para reducir warnings de conectividad
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, // Habilita caché offline
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Caché sin límite
  );

  // Envolvemos la app en MultiProvider para manejar múltiples estados
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => StorageService()),
        Provider(create: (_) => ExcelService()),
      ],
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isMenuOpen = false;
  bool _keyboardVisible = false;

  // PageController para el cambio lazy de pantallas (fix del lag del teclado)
  late final PageController _pageController;

  WebViewController? _webViewController;
  late List<Widget> _widgetOptions;
  late final StorageService _storage;
  ActivationStatus _activationStatus = ActivationStatus.none;

  final GlobalKey<_HomeScreenState> _homeScreenKey =
      GlobalKey<_HomeScreenState>();
  final GlobalKey<ProductosScreenState> _productosScreenKey =
      GlobalKey<ProductosScreenState>();
  final GlobalKey<CorreoScreenState> _correoScreenKey =
      GlobalKey<CorreoScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
    _pageController = PageController(initialPage: 0);
    _storage = Provider.of<StorageService>(context, listen: false);
    _buildScreens();
    _loadInitialStatusAndBuildScreens();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool visible = bottomInset > 0;
    if (visible != _keyboardVisible) {
      _keyboardVisible = visible;
      _logPerformance(
        'Keyboard',
        visible
            ? 'opened bottomInset=${bottomInset.toStringAsFixed(1)}'
            : 'closed',
      );
    }
  }

  void _onFocusChanged() {
    final focus = FocusManager.instance.primaryFocus;
    final focusType = focus?.context?.widget.runtimeType.toString() ?? 'none';
    _logPerformance('FocusChange', 'primaryFocus=$focusType');
  }

  void _logPerformance(String event, [String details = '']) {
    if (!kDebugMode) return;
  }

  Future<void> _loadInitialStatusAndBuildScreens() async {
    try {
      final status = await _storage.getActivationStatus();
      if (!mounted) return;
      setState(() {
        _activationStatus = status;
        _buildScreens();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activationStatus = ActivationStatus.none;
        _buildScreens();
      });
    }
  }

  void _buildScreens() {
    _widgetOptions = <Widget>[
      HomeScreen(
        // index 0 - Inicio
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
      CorreoScreen(
        key: _correoScreenKey,
        currentStatus: _activationStatus,
      ), // index 1 - Correo
      ClientesPerfilesScreen(
        currentStatus: _activationStatus,
      ), // index 2 - Clientes
      ProductosScreen(
        // index 3 - Productos
        key: _productosScreenKey,
        currentStatus: _activationStatus,
      ),
      const HistorialFacturasScreen(), // index 4 - Facturas
      const AdminPanelScreen(),
    ];
  }

  Future<void> _reloadActivationStatus() async {
    final status = await _storage.getActivationStatus();
    if (!mounted) return;
    if (status != _activationStatus) {
      setState(() {
        _activationStatus = status;
        _buildScreens();
      });
    } else {}
  }

  void _onItemTapped(int index) {
    if (!mounted) return;

    _logPerformance('PageTap', 'from=$_selectedIndex to=$index');

    // Cerrar teclado al cambiar de pantalla — fix del lag
    FocusManager.instance.primaryFocus?.unfocus();

    if (index == 1 && _selectedIndex != 1) {
      _correoScreenKey.currentState?.loadData();
    }
    if (index == 3 && _selectedIndex != 3) {
      _productosScreenKey.currentState?.loadData(_activationStatus);
    }

    setState(() {
      _selectedIndex = index;
    });
    // Saltar a la página sin animación para evitar lag visual
    _pageController.jumpToPage(index);
    _logPerformance('PageSwitch', 'jumped to page $index');
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
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _selectedIndex = 0;
      });
      _pageController.jumpToPage(0);
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
        // PageView con física bloqueada — solo se navega programáticamente.
        // Construye páginas bajo demanda para evitar instanciar todas las vistas al mismo tiempo.
        body: PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _widgetOptions.length,
          itemBuilder: (context, index) => _widgetOptions[index],
          allowImplicitScrolling: false,
        ),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt),
              label: 'Facturas',
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

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late ActivationStatus _activationStatus;
  final TextEditingController _activationKeyController =
      TextEditingController();
  bool _isActivating = false;
  late final StorageService _storage;
  WebViewController? _controller;
  bool _showWebView = false;
  bool _estaCargando = true;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  bool _demoMode = false;
  Future<bool>? _storagePermissionRequestFuture;

  // Cache del Future para evitar relanzarlo en cada rebuild
  Future<Perfil?>? _perfilFuture;
  Future<List<Producto>>? _productosFuture;

  // Para el menú de perfil
  String _perfilActivo = '';
  List<String> _perfiles = [];

  DateTime? _lastPdfDownloadTime;
  final Duration _pdfCooldown = const Duration(seconds: 5);
  final Uuid _uuid = const Uuid();

  Future<bool> _requestStoragePermissions() async {
    if (_storagePermissionRequestFuture != null) {
      return _storagePermissionRequestFuture!;
    }

    _storagePermissionRequestFuture = _requestStoragePermissionsInternal();
    final result = await _storagePermissionRequestFuture!;
    _storagePermissionRequestFuture = null;
    return result;
  }

  Future<bool> _requestStoragePermissionsInternal() async {
    if (Platform.isAndroid) {
      try {
        final manageStatus = await Permission.manageExternalStorage.status;
        if (manageStatus.isGranted) {
          return true;
        }

        if (manageStatus.isDenied ||
            manageStatus.isLimited ||
            manageStatus.isRestricted) {
          final manageRequest = await Permission.manageExternalStorage
              .request();
          if (manageRequest.isGranted) {
            return true;
          }
        }

        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) {
          return true;
        }

        if (storageStatus.isDenied ||
            storageStatus.isLimited ||
            storageStatus.isRestricted) {
          final storageRequest = await Permission.storage.request();
          if (storageRequest.isGranted) {
            return true;
          }
        }

        return true;
      } catch (e) {
        return true;
      }
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
    _storage = Provider.of<StorageService>(context, listen: false);
    _perfilFuture = _storage.getCurrentProfileData();
    _productosFuture = _storage.getProductos();
    _demoMode = widget.initialStatus == ActivationStatus.demo;
    _storage.addListener(_onStorageUpdated);
    _loadPerfilInfo();
    // Solicitar permisos inmediatamente al iniciar la app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRequestStoragePermission();
    });
  }

  Future<void> _loadPerfilInfo() async {
    final nombre = await _storage.getCurrentProfileName();
    final lista = await _storage.getProfileNames();
    if (mounted) {
      setState(() {
        _perfilActivo = nombre;
        _perfiles = lista;
      });
    }
  }

  void _refreshPerfilFutures() {
    if (!mounted) return;
    setState(() {
      _perfilFuture = _storage.getCurrentProfileData();
      _productosFuture = _storage.getProductos();
    });
    _loadPerfilInfo();
  }

  void _onStorageUpdated() {
    // addPostFrameCallback evita el assertion 'debugFrameWasSentToEngine'
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _perfilFuture = _storage.getCurrentProfileData();
          _productosFuture = _storage.getProductos();
        });
        _loadPerfilInfo();
      }
    });
  }

  Future<void> _maybeRequestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        // Verificar primero el estado actual del permiso
        final manageStatus = await Permission.manageExternalStorage.status;
        final storageStatus = await Permission.storage.status;

        // Si ya tenemos alguno de los permisos, no hacer nada
        if (manageStatus.isGranted || storageStatus.isGranted) {
          return;
        }

        // Si ningún permiso está otorgado, verificar si ya preguntamos antes
        final prefs = await SharedPreferences.getInstance();
        final asked = prefs.getBool('storage_permission_asked') ?? false;

        if (!asked) {
          await _requestStoragePermissions();
          await prefs.setBool('storage_permission_asked', true);
        }
      }
    } catch (e) {
      final _ = e;
    }
  }

  @override
  void dispose() {
    _storage.removeListener(_onStorageUpdated);
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
      final _ = e;
    }
    if (fallbackName.endsWith('.json')) {
      return fallbackName;
    }
    return '$fallbackName.json';
  }

  /// Escanea el archivo en el MediaStore de Android para que sea visible en Descargas
  Future<void> _scanFile(String path) async {
    if (!Platform.isAndroid) return;
    try {
      const platform = MethodChannel('com.facturacion.sv.app_factura/files');
      await platform.invokeMethod('scanFile', {'path': path});
    } catch (e) {
      final _ = e;
    }
  }

  /// Extrae los datos de factura del JSON descargado y los registra en el historial.
  Future<void> _registrarVentaDesdeJson(String jsonContent) async {
    try {
      final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
      await _registrarVentaDesdeMap(decoded);
    } catch (e) {
      final _ = e;
    }
  }

  // Almacena metadata de la última factura procesada para nombrar archivos
  String? _lastInvoiceClientName;
  DateTime? _lastInvoiceDate;

  /// Crea un objeto Venta desde un Map y lo guarda via StorageService.
  /// Esto sincroniza la factura al historial de la app Y a Firestore (webapp).
  Future<void> _registrarVentaDesdeMap(Map<String, dynamic> data) async {
    try {
      final now = DateTime.now();

      // Extraer campos del DTE — compatible con el formato del MH de El Salvador
      final identificacion =
          data['identificacion'] as Map<String, dynamic>? ?? {};
      final receptor = data['receptor'] as Map<String, dynamic>? ?? {};
      final resumen = data['resumen'] as Map<String, dynamic>? ?? {};
      final cuerpo = data['cuerpoDocumento'] as List<dynamic>? ?? [];

      final codigo =
          identificacion['codigoGeneracion']?.toString() ??
          data['codigoGeneracion']?.toString() ??
          data['codigo']?.toString() ??
          '';

      final numeroControl =
          identificacion['numeroControl']?.toString() ??
          data['numeroControl']?.toString() ??
          '';

      final fecha =
          identificacion['fecEmi']?.toString() ??
          data['fecha']?.toString() ??
          '${now.day}/${now.month}/${now.year}';

      final hora =
          identificacion['horEmi']?.toString() ??
          data['hora']?.toString() ??
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final totalPagar =
          resumen['totalPagar']?.toString() ??
          data['totalPagar']?.toString() ??
          data['total']?.toString() ??
          '0.00';

      final nombreCliente =
          receptor['nombre']?.toString() ??
          data['nombreCliente']?.toString() ??
          data['cliente']?.toString() ??
          'Cliente General';

      final tipoDte =
          identificacion['tipoDte']?.toString() ??
          data['tipoDte']?.toString() ??
          data['tipo']?.toString() ??
          '01';

      final estado = data['estado']?.toString() ?? 'PROCESADO';
      final sello =
          data['selloRecibido']?.toString() ?? data['sello']?.toString();

      // Guardar metadata para nombrar archivos
      _lastInvoiceClientName = nombreCliente;
      _lastInvoiceDate = now;

      final venta = Venta(
        id: codigo.isNotEmpty ? codigo : _uuid.v4(),
        fecha: fecha,
        hora: hora,
        timestamp: now.millisecondsSinceEpoch,
        codigo: codigo.isNotEmpty ? codigo : null,
        numeroControl: numeroControl.isNotEmpty ? numeroControl : null,
        sello: sello,
        total: totalPagar,
        cliente: nombreCliente,
        tipo: tipoDte,
        estado: estado,
        items: cuerpo,
      );

      await _storage.addVenta(venta);
    } catch (e) {
      final _ = e;
    }
  }

  Future<void> _setupWebView() async {
    _controller = WebViewController();
    await _controller!.addJavaScriptChannel(
      'FlutterChannel',
      onMessageReceived: (JavaScriptMessage message) async {
        try {
          final data = jsonDecode(message.message) as Map<String, dynamic>;

          if (data['action'] == 'downloadDTE') {
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
                // Registrar la venta en el historial al mismo tiempo
                await _registrarVentaDesdeJson(jsonContent);
              }
              if (pdfUrl.isNotEmpty) {
                await _launchPdfUrl(pdfUrl);
                if (mounted) {
                  setState(() => _estaCargando = false);
                }
              }
            }
          } else if (data['action'] == 'downloadFromBlob') {
            final String jsonContent = data['jsonContent'] ?? '';
            if (jsonContent.isNotEmpty) {
              final String fallbackName =
                  data['filename'] ?? 'dte_from_blob.json';
              final String finalFilename = _getFilenameFromJson(
                jsonContent,
                fallbackName,
              );
              await _handleJsonDataDownload(jsonContent, finalFilename);
              await _registrarVentaDesdeJson(jsonContent);
            } else {
              _showErrorSnackBar('Error: El blob JSON estaba vacío.');
            }
            _showMessage('JSON descargado. Se abrirá una ventana para el PDF.');
          } else if (data['action'] == 'invoiceGenerated') {
            // El WebView notifica que se generó una factura (sin descargar aún)
            // La webapp debe llamar: FlutterChannel.postMessage(JSON.stringify({action:'invoiceGenerated', invoice:{...}}))
            try {
              final invoiceMap = data['invoice'] as Map<String, dynamic>?;
              if (invoiceMap != null) {
                await _registrarVentaDesdeMap(invoiceMap);
              }
            } catch (e) {
              final _ = e;
            }
          } else if (data['action'] == 'openWindow') {
            try {
              final String url = (data['url'] ?? '').toString();
              if (url.isEmpty || url == 'about:blank') {
                return;
              }
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                _showErrorSnackBar('No se pudo abrir el enlace: $url');
              }
            } catch (e) {
              _showErrorSnackBar('Error al abrir enlace desde la página.');
            }
          } else if (data['action'] == 'pdfBlob') {
            final now = DateTime.now();
            if (_lastPdfDownloadTime != null &&
                now.difference(_lastPdfDownloadTime!) < _pdfCooldown) {
              return;
            }
            _lastPdfDownloadTime = now;
            try {
              final String base64Data = data['base64'] ?? '';
              final String originalFileName =
                  data['filename']?.toString().replaceAll(
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
              try {
                await _requestStoragePermissions();

                // Guarda en Descargas/asistente de facturacion DTE/facturas emitidas/<perfil>/<año>/<mes>/
                final savedFile = await _storage.saveFacturaPdf(
                  filename,
                  bytes,
                  clientName: _lastInvoiceClientName,
                  fecha: _lastInvoiceDate,
                );
                await _scanFile(savedFile.path);

                _showMessage('PDF guardado: ${savedFile.path}');

                try {
                  await OpenFilex.open(savedFile.path);
                } catch (e) {
                  // Ignorar error al abrir el archivo
                }
              } catch (e) {
                _showErrorSnackBar('Error al guardar PDF: ${e.toString()}');
              }
            } catch (e) {
              _showErrorSnackBar('Error al procesar PDF: ${e.toString()}');
            }
          }
        } catch (e) {
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
        },
        onWebResourceError: (WebResourceError error) {
          if (mounted) {
            setState(() => _estaCargando = false);
          }
          _showErrorSnackBar(
            'Error: ${error.description} (Code: ${error.errorCode})',
          );
        },
        onNavigationRequest: (NavigationRequest request) async {
          final String url = request.url;
          if (url.endsWith('.pdf') ||
              url.endsWith('.zip') ||
              url.endsWith('.doc') ||
              url.endsWith('.docx') ||
              url.endsWith('.xls') ||
              url.endsWith('.xlsx')) {
            _handleFileDownload(url);
            return NavigationDecision.prevent;
          }
          if (url.startsWith('blob:') && request.isMainFrame) {
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
              return NavigationDecision.navigate;
            }
            if (url == 'about:blank' && request.isMainFrame) {
              return NavigationDecision.prevent;
            }
            if (url.startsWith('javascript:')) {
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
            _showMessage('Abriendo enlace externo...');

            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              _showErrorSnackBar('No se pudo abrir enlace externo.');
            }
            return NavigationDecision.prevent;
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
      // Solicita permisos pero no bloquea si fallan (funciona con carpeta app-specific)
      await _requestStoragePermissions();

      // Primero registrar la venta para obtener el nombre del cliente
      await _registrarVentaDesdeJson(jsonContent);

      final savedFile = await _storage.saveFacturaJson(filename, jsonContent);

      if (Platform.isAndroid) {
        try {
          const platform = MethodChannel(
            'com.facturacion.sv.app_factura/files',
          );
          await platform.invokeMethod('scanFile', {'path': savedFile.path});
        } catch (e) {
          final _ = e;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('JSON guardado: $filename\n${savedFile.path}'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar(' Error al guardar JSON: ${e.toString()}');
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
      // Intenta solicitar permisos (pero no bloquea si fallan)
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
      final List<int> fileBytes = await tempFile.readAsBytes();

      // Guarda en Descargas/asistente de facturacion DTE/facturas emitidas/<perfil>/<año>/<mes>/
      final savedFile = await _storage.saveFacturaPdf(
        fileName,
        fileBytes,
        clientName: _lastInvoiceClientName,
        fecha: _lastInvoiceDate,
      );
      await _scanFile(savedFile.path);
      await tempFile.delete();

      _showMessage('PDF guardado: ${savedFile.path}');

      await OpenFilex.open(savedFile.path);
    } catch (e) {
      _showErrorSnackBar(' Error: ${e.toString()}');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      } catch (e2) {
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
      File savedFile;

      if (url.endsWith('.pdf') || fileName.endsWith('.pdf')) {
        final bytes = await tempFile.readAsBytes();
        savedFile = await _storage.saveFacturaPdf(
          fileName,
          bytes,
          clientName: _lastInvoiceClientName,
          fecha: _lastInvoiceDate,
        );
      } else if (url.endsWith('.json') || fileName.endsWith('.json')) {
        final content = await tempFile.readAsString();
        // Primero registrar la venta para obtener el nombre del cliente
        await _registrarVentaDesdeJson(content);
        // Guardar JSON con nombre original
        savedFile = await _storage.saveFacturaJson(fileName, content);
      } else {
        final bytes = await tempFile.readAsBytes();
        savedFile = await _storage.saveFacturaPdf(
          fileName,
          bytes,
          clientName: _lastInvoiceClientName,
          fecha: _lastInvoiceDate,
        );
      }

      await tempFile.delete();
      await _scanFile(savedFile.path);

      if (mounted) {
        _showMessage('Archivo guardado: $fileName');
      }
    } catch (e) {
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

  Future<void> _openWhatsAppSupport() async {
    final uri = Uri.parse('https://wa.me/50377278551');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('No se pudo abrir WhatsApp.');
      }
    } catch (e) {
      _showError('No se pudo abrir WhatsApp.');
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
    super.build(context); // required for AutomaticKeepAliveClientMixin
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
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ProfileAvatarMenu(
                    perfilActivo: _perfilActivo,
                    perfiles: _perfiles,
                    activationStatus: _activationStatus,
                    onCambiarPerfil: (p) async {
                      if (p != null && p != _perfilActivo) {
                        await _storage.switchProfile(p);
                        widget.onStatusChangeNeeded();
                        final newStatus = await _storage.getActivationStatus();
                        if (mounted) {
                          setState(() => _activationStatus = newStatus);
                        }
                        _refreshPerfilFutures();
                      }
                    },
                    onAfterConfiguracion: () async {
                      widget.onStatusChangeNeeded();
                      final newStatus = await _storage.getActivationStatus();
                      if (mounted && newStatus != _activationStatus) {
                        setState(() {
                          _activationStatus = newStatus;
                        });
                      }
                    },
                    onCerrarSesion: () async {
                      await _storage.signOutUser();
                      widget.onStatusChangeNeeded();
                      final newStatus = await _storage.getActivationStatus();
                      if (mounted) {
                        setState(() {
                          _activationStatus = newStatus;
                          _demoMode = false;
                        });
                      }
                    },
                  ),
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
        return Colors.grey.shade700;
    }
  }

  Widget _buildGreeting() {
    return const Text(
      'Bienvenido a tu asistente de facturación DTE',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  double _getTotalAcumulado(Perfil? perfil) {
    final ventas = perfil?.ventas ?? const [];
    return ventas.fold<double>(0, (acc, venta) {
      final raw = (venta.total ?? '0').replaceAll(RegExp(r'[^0-9.,-]'), '');
      final normalized = raw.replaceAll(',', '');
      return acc + (double.tryParse(normalized) ?? 0);
    });
  }

  void _showDashboardDetails(
    BuildContext context,
    Perfil? perfil,
    int productos,
  ) {
    final clientes = perfil?.clients.length ?? 0;
    final facturas = perfil?.ventas.length ?? 0;
    final total = _getTotalAcumulado(perfil);
    final promedio = facturas > 0 ? total / facturas : 0.0;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final sheetTheme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen del perfil activo',
                  style: sheetTheme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  perfil != null
                      ? 'Datos en tiempo real'
                      : 'Sin perfil cargado',
                  style: sheetTheme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _detailStatRow(
                  sheetTheme,
                  Icons.group_outlined,
                  Colors.teal,
                  'Clientes registrados',
                  clientes.toString(),
                ),
                const Divider(height: 24),
                _detailStatRow(
                  sheetTheme,
                  Icons.payments_outlined,
                  Colors.green,
                  'Total acumulado',
                  '\$${total.toStringAsFixed(2)}',
                ),
                const Divider(height: 24),
                _detailStatRow(
                  sheetTheme,
                  Icons.calculate_outlined,
                  Colors.orange,
                  'Promedio por factura',
                  '\$${promedio.toStringAsFixed(2)}',
                ),
                const Divider(height: 24),
                _detailStatRow(
                  sheetTheme,
                  Icons.inventory_2_outlined,
                  Colors.deepPurple,
                  'Productos registrados',
                  productos.toString(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Toca una sección para ver más detalles en su pantalla.',
                  style: sheetTheme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailStatRow(
    ThemeData theme,
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCard(BuildContext context, Perfil? perfil) {
    final clientes = perfil?.clients.length ?? 0;
    final total = _getTotalAcumulado(perfil);
    final theme = Theme.of(context);

    Widget metric(String title, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<List<Producto>>(
      future: _productosFuture,
      builder: (ctx, snap) {
        final productos = snap.data?.length ?? 0;
        return InkWell(
          onTap: () => _showDashboardDetails(context, perfil, productos),
          borderRadius: BorderRadius.circular(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Resumen de facturación',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ver detalle',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Total de ingresos - Full Width
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total de ingresos',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Clientes y Productos - Compartir ancho
                  Row(
                    children: [
                      metric(
                        'Clientes',
                        '$clientes',
                        Icons.group_outlined,
                        Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      metric(
                        'Productos',
                        '$productos',
                        Icons.inventory_2_outlined,
                        Colors.deepPurple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivationSection() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Para activar todas las funcionalidades, escríbenos por WhatsApp o usa tu clave de licencia.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color.fromARGB(255, 59, 59, 59),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openWhatsAppSupport,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp +503 7727-8551'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 16),
          Text(
            'Introduce tu clave de licencia:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color.fromARGB(255, 59, 59, 59),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _activationKeyController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'XXXX-XXXX-XXXX-XXXX'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isActivating ? null : _activateApp,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: const Color(
                0xFF0891B2,
              ), // Celeste oscuro (cyan-600)
              foregroundColor: Colors.white,
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
                : const Text(
                    'ACTIVAR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),
        ],
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

  Widget _buildGreetingUI(
    BuildContext context,
    ThemeData theme,
    bool overlayEnabled,
  ) {
    return FutureBuilder<Perfil?>(
      future: _perfilFuture,
      builder: (context, snapshot) {
        final perfil = snapshot.data;

        final List<Widget> children = [
          const SizedBox(height: 16.0),
          _buildGreeting(),
          const SizedBox(height: 16),
        ];

        if (_activationStatus == ActivationStatus.none) {
          // Primera vez: 1) modo Demo, 2) modo Premium colapsable, 3) iniciar asistente
          children.add(_buildModeSelector());
          children.add(const SizedBox(height: 16));
          children.add(
            _buildOverlaySection(
              context,
              overlayEnabled ? _toggleWebView : null,
            ),
          );
        } else if (_activationStatus == ActivationStatus.pro) {
          // PRO: 1) iniciar asistente, 2) resumen de facturación
          children.add(_buildOverlaySection(context, _toggleWebView));
          children.add(const SizedBox(height: 16));
          children.add(_buildDashboardCard(context, perfil));
        } else if (_activationStatus == ActivationStatus.demo) {
          // DEMO: mantener selector/card premium visible + asistente
          children.add(_buildModeSelector());
          children.add(const SizedBox(height: 16));
          children.add(_buildOverlaySection(context, _toggleWebView));
        }

        children.add(const SizedBox(height: 8));

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: children,
        );
      },
    );
  }

  Widget _buildModeSelector() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modo de inicio',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Activa el modo DEMO para probar la app sin clave.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _demoMode,
                      onChanged: (v) async {
                        setState(() => _demoMode = v);
                        try {
                          await _storage.setDemoMode(v);
                        } catch (e) {
                          final _ = e;
                        }
                        widget.onStatusChangeNeeded();
                        final newStatus = await _storage.getActivationStatus();
                        if (mounted) {
                          setState(() => _activationStatus = newStatus);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 231, 248, 255),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromARGB(255, 192, 235, 255),
              width: 3,
            ),
          ),
          child: ExpansionTile(
            title: Text(
              'ACTIVA LA VERSION PREMIUM',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color.fromARGB(255, 27, 27, 27),
                fontWeight: FontWeight.bold,
              ),
            ),
            iconColor: Colors.black,
            collapsedIconColor: Colors.black,
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [_buildActivationSection()],
          ),
        ),
      ],
    );
  }
}
