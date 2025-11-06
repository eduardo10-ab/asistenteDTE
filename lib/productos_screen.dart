// lib/productos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- Importaciones ---
import 'models.dart';
import 'storage_service.dart';
import 'app_data.dart'; // Para kUnidadesMedida
import 'main.dart'; // Para colores del tema general

// --- COLORES ESPECÍFICOS ---
const Color dangerColor = Color(0xFFD9534F);
const Color warningColor = Color(0xFFF0AD4E);
const Color successColor = Color(0xFF28a745);

// Límite definido en storage_service
// const int kMaxDemoItems = 2;

class ProductosScreen extends StatefulWidget {
  // Recibe el estado actual
  final ActivationStatus currentStatus;
  // <<<--- CAMBIO: Se añade 'key' para que MainScreen pueda encontrar este widget --- >>>
  const ProductosScreen({super.key, required this.currentStatus});

  @override
  // <<<--- CAMBIO: Se hace pública la clase State --- >>>
  State<ProductosScreen> createState() => ProductosScreenState();
}

// <<<--- CAMBIO: Se hace pública la clase State --- >>>
class ProductosScreenState extends State<ProductosScreen> {
  final StorageService _storage = StorageService();
  List<Producto> _productos = [];
  bool _isLoading = true;
  Producto? _productoParaEditar;

  // <<<--- INICIO: NUEVA VARIABLE --- >>>
  String _currentProfileName = ""; // Para guardar el nombre del perfil
  // <<<--- FIN: NUEVA VARIABLE --- >>>

  @override
  void initState() {
    super.initState();
    // <<<--- CAMBIO: Se llama al método público --- >>>
    loadData(widget.currentStatus);
  }

  @override
  void didUpdateWidget(covariant ProductosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Esta función ahora solo recarga si el estado de activación (PRO/DEMO) cambia.
    // La recarga por cambio de perfil se maneja desde main.dart
    if (widget.currentStatus != oldWidget.currentStatus) {
      // <<<--- CAMBIO: Se llama al método público --- >>>
      loadData(widget.currentStatus);
    }
  }

  // <<<--- CAMBIO: Método renombrado de _loadData a loadData --- >>>
  Future<void> loadData(ActivationStatus status) async {
    if (!mounted) return; // Asegurarse que el widget esté montado
    setState(() => _isLoading = true);
    try {
      // <<<--- INICIO: NUEVA LÓGICA --- >>>
      // Carga el nombre del perfil Y los productos de ese perfil
      final profileName = await _storage.getCurrentProfileName();
      final productos = await _storage.getProductos();
      // <<<--- FIN: NUEVA LÓGICA --- >>>
      if (!mounted) return;
      setState(() {
        _productos = productos;
        _currentProfileName = profileName; // Guarda el nombre del perfil
        _isLoading = false;
        _productoParaEditar = null;
      });
    } catch (e) {
      _showError('Error al cargar productos: ${e.toString()}');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: dangerColor),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: successColor),
    );
  }

  void _onSaveProducto(Producto producto) async {
    try {
      await _storage.saveProducto(producto);
      _showMessage(
        producto.id.isEmpty ? 'Producto guardado.' : 'Producto actualizado.',
      );
      // <<<--- CAMBIO: Se llama al método público --- >>>
      loadData(widget.currentStatus);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _productoParaEditar = null;
        });
      }
    }
  }

  void _onDeleteProducto(String id) async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text(
          '¿Seguro que quieres eliminar este producto/servicio?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: dangerColor)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _storage.deleteProducto(id);
        _showMessage('Producto eliminado.');
        // <<<--- CAMBIO: Se llama al método público --- >>>
        loadData(widget.currentStatus);
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool allowWriteActions =
        widget.currentStatus != ActivationStatus.none;
    final bool isPro = widget.currentStatus == ActivationStatus.pro;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        // <<<--- INICIO: CAMBIO EN APPBAR --- >>>
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Gestionar Productos'),
            if (_currentProfileName.isNotEmpty && !_isLoading)
              Text(
                _currentProfileName, // Muestra el nombre del perfil
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorTextoSecundario,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        // <<<--- FIN: CAMBIO EN APPBAR --- >>>
        elevation: 0,
        backgroundColor: colorScheme.background,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _ProductoForm(
                      key: ValueKey(_productoParaEditar?.id ?? 'nuevo'),
                      status: widget.currentStatus, // Pasa el status actual
                      productoInicial: _productoParaEditar,
                      onSave: _onSaveProducto,
                      onCancel: () {
                        setState(() {
                          _productoParaEditar = null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Ítems Guardados', style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),

                // Mensaje de Límite DEMO (si aplica)
                if (widget.currentStatus == ActivationStatus.demo &&
                    _productos.length >= kMaxDemoProducts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Límite alcanzado (${kMaxDemoProducts} productos). Actualiza a PRO para agregar más.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                _productos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            'No hay productos guardados.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _productos.length,
                        itemBuilder: (context, index) {
                          final producto = _productos[index];
                          return InkWell(
                            onTap: allowWriteActions
                                ? () => setState(
                                    () => _productoParaEditar = producto,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: colorGrisClaro,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          producto.descripcion,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Unidad: ${kUnidadesMedida[producto.unidadMedida] ?? '??'} - Precio: \$${producto.precio}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: allowWriteActions
                                          ? colorTextoSecundario
                                          : Colors.grey.withOpacity(0.5),
                                      size: 20,
                                    ),
                                    onPressed: allowWriteActions
                                        ? () => _onDeleteProducto(producto.id)
                                        : null,
                                    tooltip: 'Eliminar',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}
// El resto del archivo (_ProductoForm) no necesita cambios
// ... (resto del archivo _ProductoForm sin cambios) ...

// --- CLASE _ProductoForm (AJUSTADA PARA EL TEMA CLARO Y BLOQUEO NONE) ---
class _ProductoForm extends StatefulWidget {
  final ActivationStatus status;
  final Producto? productoInicial;
  final Function(Producto) onSave;
  final VoidCallback onCancel;
  const _ProductoForm({
    super.key,
    required this.status,
    this.productoInicial,
    required this.onSave,
    required this.onCancel,
  });
  @override
  State<_ProductoForm> createState() => _ProductoFormState();
}

class _ProductoFormState extends State<_ProductoForm> {
  final _formKey = GlobalKey<FormState>();
  late Producto _producto;
  bool _isEditing = false;
  final _descripcionCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateFormState();
  }

  @override
  void didUpdateWidget(covariant _ProductoForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.productoInicial != oldWidget.productoInicial) {
      _updateFormState();
    }
  }

  void _updateFormState() {
    _isEditing = widget.productoInicial != null;
    _producto = widget.productoInicial ?? Producto(id: '', unidadMedida: '59');
    _descripcionCtrl.text = _producto.descripcion;
    _precioCtrl.text = _producto.precio;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    if (widget.status == ActivationStatus.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa la aplicación para guardar productos.'),
          backgroundColor: dangerColor,
        ),
      );
      return;
    }
    _validateAndSave();
  }

  void _validateAndSave() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final productoActualizado = Producto(
        id: _producto.id,
        tipo: _producto.tipo,
        unidadMedida: _producto.unidadMedida,
        descripcion: _descripcionCtrl.text,
        precio: _precioCtrl.text,
      );
      final wasEditing = _isEditing;
      _resetForm();
      widget.onSave(productoActualizado);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _descripcionCtrl.clear();
    _precioCtrl.clear();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool allowWriteActions = widget.status != ActivationStatus.none;
    final bool canAddNew =
        widget.status == ActivationStatus.pro ||
        (widget.status ==
            ActivationStatus.demo /* && numProductos < kMaxDemoItems */ );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Editar Ítem' : 'Agregar Nuevo Ítem',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          IgnorePointer(
            ignoring: !allowWriteActions,
            child: Opacity(
              opacity: allowWriteActions ? 1.0 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDropdown<String>(
                          label: 'Tipo',
                          value: _producto.tipo,
                          items: ['Bien', 'Servicio', 'Bien y Servicio']
                              .map(
                                (String item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setState(() => _producto.tipo = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _buildDropdown<String>(
                          label: 'Unidad de Medida',
                          value: _producto.unidadMedida,
                          items: kUnidadesMedida.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setState(() => _producto.unidadMedida = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // <<< CORRECCIÓN: Añadir controller y label >>>
                  _buildTextFormField(
                    controller: _descripcionCtrl,
                    label: 'Producto o Servicio*',
                    validator: (val) =>
                        (val == null || val.isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 18),
                  // <<< CORRECCIÓN: Añadir controller y label >>>
                  _buildTextFormField(
                    controller: _precioCtrl,
                    label: 'Precio Unitario (\$)*',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d*'), // Permite decimales ilimitados
                      ),
                    ],
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Campo requerido';
                      if (double.tryParse(val) == null)
                        return 'Ingrese un número válido';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isEditing)
                TextButton(
                  onPressed: allowWriteActions ? _resetForm : null,
                  child: const Text('Cancelar Edición'),
                ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: allowWriteActions && (_isEditing || canAddNew)
                    ? _guardar
                    : null,
                child: Text(_isEditing ? 'Actualizar Ítem' : 'Guardar Ítem'),
              ),
            ],
          ),
          if (!allowWriteActions)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                'Activa la aplicación para agregar o editar productos.',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),
          if (allowWriteActions && !_isEditing && !canAddNew)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                'Límite DEMO alcanzado.',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  // Widgets _buildTextFormField y _buildDropdown (sin cambios)
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator:
          validator ??
          (val) {
            if (label.endsWith('*') && (val == null || val.isEmpty)) {
              return 'Campo requerido';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<T>(
      value: value,
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item.value,
              child: DefaultTextStyle(
                style: theme.textTheme.bodyLarge ?? const TextStyle(),
                child: item.child!,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
    );
  }
} // Fin de _ProductoFormState
