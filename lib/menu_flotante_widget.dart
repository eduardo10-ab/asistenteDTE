// lib/menu_flotante_widget.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert'; // Para jsonEncode

// Importaciones
import 'js_injection.dart';
import 'models.dart';
import 'storage_service.dart';
// import 'main.dart'; // <--- ELIMINADO

// --- COLORES DE MARCA AÑADIDOS ---
const Color colorCelestePastel = Color(0xFF80D8FF);
const Color colorAzulActivo = Color(0xFF40C4FF);

class MenuFlotanteWidget extends StatefulWidget {
  final WebViewController? webViewController;
  const MenuFlotanteWidget({super.key, this.webViewController});

  @override
  State<MenuFlotanteWidget> createState() => _MenuFlotanteWidgetState();
}

class _MenuFlotanteWidgetState extends State<MenuFlotanteWidget> {
  final StorageService _storage = StorageService();

  // Variables de estado
  List<Cliente> _clientes = [];
  List<Producto> _productos = [];

  bool _isLoading = true;
  bool get _puedeInyectar => widget.webViewController != null;

  // Controla las vistas del menú
  bool _mostrandoListaClientes = false;
  bool _mostrandoListaProductos = false;

  @override
  void initState() {
    super.initState();
    _loadDataFromStorage();
  }

  // --- Lógica Interna ---
  Future<void> _loadDataFromStorage() async {
    setState(() {
      _isLoading = true;
    });
    final clientes = await _storage.getClientes();
    final productos = await _storage.getProductos();
    setState(() {
      _clientes = clientes;
      _productos = productos;
      _isLoading = false;
    });
  }

  void _inyectarClienteEspecifico(Cliente cliente) {
    if (!_puedeInyectar) return;
    _storage.setLastInvoicedClientId(cliente.id);
    final clienteJson = jsonEncode(cliente.toJson());
    widget.webViewController!.runJavaScript(jsInjector);
    widget.webViewController!.runJavaScript('fillClientData($clienteJson);');
    Navigator.pop(context); // Cierra el modal
  }

  void _inyectarProductoEspecifico(Producto producto) {
    if (!_puedeInyectar) return;
    final productoJson = jsonEncode(producto.toJson());
    widget.webViewController!.runJavaScript(jsInjector);
    widget.webViewController!.runJavaScript(
      'addProductToInvoice($productoJson);',
    );
    Navigator.pop(context); // Cierra el modal
  }

  @override
  Widget build(BuildContext context) {
    // --- INICIO: SE USAN COLORES DEL TEMA ---
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // --- FIN: SE USAN COLORES DEL TEMA ---

    const double fabHeight = 152.0;
    const double desiredBottomMargin = 8.0;
    final double bottomPadding =
        fabHeight + desiredBottomMargin + MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(136, 16, 1, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // --- Contenedor de botones ---
          Container(
            width: 250,
            decoration: BoxDecoration(
              // --- CAMBIO: Se usa color del tema ---
              color: colorScheme.background,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _isLoading
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _mostrandoListaClientes
                          ? _buildListaClientes(theme)
                          : _mostrandoListaProductos
                          ? _buildListaProductos(theme)
                          : _buildMenuPrincipal(theme),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Botón de Cerrar (X) ---
          FloatingActionButton(
            mini: true,
            onPressed: () => Navigator.pop(context),
            // --- CAMBIO: Se usa color del tema ---
            backgroundColor: colorScheme.background,
            foregroundColor: colorScheme.onBackground,
            elevation: 2,
            tooltip: 'Cerrar',
            child: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuPrincipal(ThemeData theme) {
    return Column(
      key: const ValueKey('menu_principal'),
      children: [
        _buildMenuButton(
          theme,
          'Rellenar Cliente',
          Icons.person_add_alt_1,
          (_puedeInyectar && _clientes.isNotEmpty)
              ? () {
                  setState(() {
                    _mostrandoListaClientes = true;
                  });
                }
              : null,
        ),
        // --- CAMBIO: Se usa color del tema ---
        Divider(
          height: 1,
          color: theme.dividerColor,
          indent: 16,
          endIndent: 16,
        ),
        _buildMenuButton(
          theme,
          'Agregar Ítem',
          Icons.add_shopping_cart,
          (_puedeInyectar && _productos.isNotEmpty)
              ? () {
                  setState(() {
                    _mostrandoListaProductos = true;
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildListaClientes(ThemeData theme) {
    return ConstrainedBox(
      key: const ValueKey('lista_clientes'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Botón de Volver
          InkWell(
            onTap: () {
              setState(() {
                _mostrandoListaClientes = false;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: colorAzulActivo, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Elegir Cliente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      // --- CAMBIO: Se usa color del tema ---
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- CAMBIO: Se usa color del tema ---
          Divider(
            height: 1,
            color: theme.dividerColor,
            indent: 0,
            endIndent: 0,
          ),

          // 2. Lista de Clientes (Scrollable)
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _clientes.length,
              itemBuilder: (context, index) {
                final cliente = _clientes[index];
                return InkWell(
                  onTap: () {
                    _inyectarClienteEspecifico(cliente);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Text(
                      cliente.nombreCliente.isNotEmpty
                          ? cliente.nombreCliente
                          : '(Cliente sin nombre)',
                      style: TextStyle(
                        fontSize: 15,
                        // --- CAMBIO: Se usa color del tema ---
                        color: theme.colorScheme.onBackground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaProductos(ThemeData theme) {
    return ConstrainedBox(
      key: const ValueKey('lista_productos'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Botón de Volver
          InkWell(
            onTap: () {
              setState(() {
                _mostrandoListaProductos = false;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: colorAzulActivo, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Elegir Ítem',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      // --- CAMBIO: Se usa color del tema ---
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- CAMBIO: Se usa color del tema ---
          Divider(
            height: 1,
            color: theme.dividerColor,
            indent: 0,
            endIndent: 0,
          ),

          // 2. Lista de Productos (Scrollable)
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _productos.length,
              itemBuilder: (context, index) {
                final producto = _productos[index];
                return InkWell(
                  onTap: () {
                    _inyectarProductoEspecifico(producto);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Text(
                      producto.descripcion.isNotEmpty
                          ? producto.descripcion
                          : '(Producto sin nombre)',
                      style: TextStyle(
                        fontSize: 15,
                        // --- CAMBIO: Se usa color del tema ---
                        color: theme.colorScheme.onBackground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    ThemeData theme,
    String text,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    final bool isEnabled = onPressed != null;

    String displayText = text;
    if (!isEnabled) {
      if (text == 'Rellenar Cliente' && _clientes.isEmpty) {
        displayText = 'No hay clientes';
      } else if (text == 'Agregar Ítem' && _productos.isEmpty) {
        displayText = 'No hay productos';
      }
    }

    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              // --- CAMBIO: Se usa color del tema ---
              backgroundColor: theme.cardColor,
              child: Icon(
                icon,
                size: 20,
                color: isEnabled
                    ? colorCelestePastel
                    : theme.disabledColor, // Color de marca vs deshabilitado
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  // --- CAMBIO: Se usa color del tema ---
                  color: isEnabled
                      ? theme.colorScheme.onBackground
                      : theme.disabledColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
} // Fin de _MenuFlotanteWidgetState
