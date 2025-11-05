// lib/menu_flotante_widget.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert'; // Para jsonEncode

// Importaciones
import 'js_injection.dart';
import 'models.dart';
import 'storage_service.dart';
import 'main.dart'; // Importa main.dart para colores del tema

class MenuFlotanteWidget extends StatefulWidget {
  final WebViewController? webViewController;
  const MenuFlotanteWidget({super.key, this.webViewController});

  @override
  State<MenuFlotanteWidget> createState() => _MenuFlotanteWidgetState();
}

class _MenuFlotanteWidgetState extends State<MenuFlotanteWidget> {
  final StorageService _storage = StorageService();

  // Variables de estado (sin cambios en la lógica)
  List<Cliente> _clientes = [];
  List<Producto> _productos = [];
  String? _clienteSel;
  String? _productoSel;
  bool _isLoading = true;
  bool get _puedeInyectar => widget.webViewController != null;

  @override
  void initState() { super.initState(); _loadDataFromStorage(); }

  // --- Lógica Interna (sin cambios) ---
  Future<void> _loadDataFromStorage() async { /* ... (igual que antes) ... */ setState(() { _isLoading = true; }); final clientes = await _storage.getClientes(); final productos = await _storage.getProductos(); setState(() { _clientes = clientes; _productos = productos; if (clientes.isNotEmpty) { _clienteSel = clientes.first.id; } if (productos.isNotEmpty) { _productoSel = productos.first.id; } _isLoading = false; }); }
  void _inyectarCliente() { /* ... (igual que antes) ... */ if (!_puedeInyectar || _clienteSel == null) return; final cliente = _clientes.firstWhere((c) => c.id == _clienteSel); final clienteJson = jsonEncode(cliente.toJson()); widget.webViewController!.runJavaScript(jsInjector); widget.webViewController!.runJavaScript('fillClientData($clienteJson);'); Navigator.pop(context); }
  void _inyectarProducto() { /* ... (igual que antes) ... */ if (!_puedeInyectar || _productoSel == null) return; final producto = _productos.firstWhere((p) => p.id == _productoSel); final productoJson = jsonEncode(producto.toJson()); widget.webViewController!.runJavaScript(jsInjector); widget.webViewController!.runJavaScript('addProductToInvoice($productoJson);'); Navigator.pop(context); }

  @override
  Widget build(BuildContext context) {
    // Calcula padding inferior para elevar el menú
    // Ajusta estos valores si necesitas cambiar la posición vertical
    const double fabHeight = 152.0; // Altura estándar del FAB
    const double desiredBottomMargin = 8.0; // Margen sobre el FAB
    final double bottomPadding = fabHeight + desiredBottomMargin + MediaQuery.of(context).padding.bottom;

    return Padding(
      // Padding ajustado para alineación derecha (ajusta el 16 izquierdo si prefieres más centrado)
      padding: EdgeInsets.fromLTRB(136, 16, 1, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end, // Alineado a la derecha
        children: [
          // --- Contenedor de botones ---
          Container(
            width: 250, // Ancho mantenido
            decoration: BoxDecoration(
              // <<< CAMBIO: Fondo Blanco >>>
              color: colorBlanco,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4) ), ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _isLoading
                  ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())) // Usa color del tema
                  : Column(
                children: [
                  _buildMenuButton(
                    'Rellenar Cliente',
                    Icons.person_add_alt_1,
                    (_puedeInyectar && _clienteSel != null) ? _inyectarCliente : null,
                  ),
                  // <<< CAMBIO: Color del Divider >>>
                  Divider(height: 1, color: colorGrisClaro, indent: 16, endIndent: 16), // Gris claro
                  _buildMenuButton(
                    'Agregar Ítem',
                    Icons.add_shopping_cart,
                    (_puedeInyectar && _productoSel != null) ? _inyectarProducto : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Botón de Cerrar (X) ---
          FloatingActionButton(
            mini: true,
            onPressed: () => Navigator.pop(context),
            backgroundColor: colorBlanco, // Fondo blanco
            foregroundColor: colorTextoPrincipal, // Icono oscuro
            elevation: 2,
            tooltip: 'Cerrar',
            child: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  // --- WIDGET DE BOTÓN (MODIFICADO TEXTO GRIS OSCURO) ---
  Widget _buildMenuButton(String text, IconData icon, VoidCallback? onPressed) {
    final bool isEnabled = onPressed != null;

    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            CircleAvatar( // Mantenemos círculo gris claro con icono celeste
              radius: 18,
              backgroundColor: colorGrisClaro,
              child: Icon(
                icon,
                size: 20,
                color: isEnabled ? colorCelestePastel : Colors.grey[400], // Icono celeste
              ),
            ),
            const SizedBox(width: 20),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600, // Mantenemos grueso
                // <<< CAMBIO: Texto Gris Oscuro >>>
                color: isEnabled ? colorTextoPrincipal : colorTextoSecundario, // Gris oscuro / Gris claro
              ),
            ),
          ],
        ),
      ),
    );
  }
} // Fin de _MenuFlotanteWidgetState