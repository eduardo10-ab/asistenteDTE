// lib/main_new.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart'; // <<< FIX: Agregado para kDebugMode

// --- Imports locales ---
import 'clientes_perfiles_screen.dart';
import 'productos_screen.dart';
import 'menu_flotante_widget.dart';
import 'models.dart';
import 'storage_service.dart';
import 'home_screen.dart';
// Asegúrate de que HomeScreenState esté exportado desde home_screen.dart

// --- Colores ---
const Color colorBlanco = Colors.white;
const Color colorCelestePastel = Color(0xFF80D8FF);
const Color colorAzulActivo = Color(0xFF40C4FF);
const Color colorGrisClaro = Color(0xFFF5F5F5);
const Color colorTextoPrincipal = Color(0xFF424242);
const Color colorTextoSecundario = Color(0xFF9E9E9E);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Solicitar permisos de almacenamiento al inicio
  if (Platform.isAndroid) {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Facturación App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorCelestePastel,
          primary: colorCelestePastel,
          secondary: colorAzulActivo,
          surface: colorBlanco,
          onSurface: colorTextoPrincipal,
          // <<< FIX: 'surfaceVariant' obsoleto reemplazado >>>
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

  final homeScreenKey = GlobalKey<HomeScreenState>();

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
        key: homeScreenKey,
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
      ProductosScreen(currentStatus: _activationStatus),
    ];
  }

  Future<void> _reloadActivationStatus() async {
    // <<< FIX: Reemplazado print() con kDebugMode >>>
    if (kDebugMode) {
      print("Recargando estado...");
    }
    final status = await _storage.getActivationStatus();
    if (!mounted) return;
    if (status != _activationStatus) {
      // <<< FIX: Reemplazado print() con kDebugMode >>>
      if (kDebugMode) {
        print("¡Estado cambió a $status!");
      }
      setState(() {
        _activationStatus = status;
        _buildScreens();
      });
    } else {
      // <<< FIX: Reemplazado print() con kDebugMode >>>
      if (kDebugMode) {
        print("Estado no cambió.");
      }
    }
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex == 0) {
      final homeState = homeScreenKey.currentState;
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
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // <<< FIX: `use_build_context_synchronously` --- >>>
            if (!context.mounted) return;
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
}

// Función global para mostrar el menú flotante
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
