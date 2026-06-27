// lib/productos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- Importaciones ---
import 'models.dart';
import 'storage_service.dart';
import 'app_data.dart'; // Para kUnidadesMedida
import 'package:provider/provider.dart';
import 'profile_avatar_menu.dart';

// --- COLORES ESPECÍFICOS ---
const Color dangerColor = Color(0xFFD9534F);
const Color warningColor = Color(0xFFF0AD4E);
const Color successColor = Color(0xFF28a745);

class ProductosScreen extends StatefulWidget {
  final ActivationStatus currentStatus;
  const ProductosScreen({super.key, required this.currentStatus});

  @override
  State<ProductosScreen> createState() => ProductosScreenState();
}

class ProductosScreenState extends State<ProductosScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final StorageService _storage;
  List<Producto> _productos = [];
  bool _isLoading = true;
  Producto? _productoParaEditar;
  String _currentProfileName = "";
  List<String> _perfiles = [];

  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _storage.addListener(_onStorageChanged);
    loadData(widget.currentStatus);
  }

  @override
  void didUpdateWidget(covariant ProductosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStatus != oldWidget.currentStatus) {
      loadData(widget.currentStatus);
    }
  }

  @override
  void dispose() {
    _storage.removeListener(_onStorageChanged);
    super.dispose();
  }

  void _onStorageChanged() {
    if (!mounted) return;
    loadData(widget.currentStatus);
  }

  Future<void> loadData(ActivationStatus status) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final profileName = await _storage.getCurrentProfileName();
      final profileNames = await _storage.getProfileNames();
      final productos = await _storage.getProductos();
      if (!mounted) return;
      setState(() {
        _productos = productos;
        _currentProfileName = profileName;
        _perfiles = profileNames;
        _isLoading = false;
        _productoParaEditar = null;
      });
    } catch (e) {
      if (!mounted) return;
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
    FocusManager.instance.primaryFocus?.unfocus();

    // Validar límite de productos en modo demo
    if (widget.currentStatus == ActivationStatus.demo && producto.id.isEmpty) {
      if (_productos.isNotEmpty) {
        _showError(
          'Modo Demo: Máximo 1 producto permitido. Actualiza a Pro para agregar más.',
        );
        return;
      }
    }

    try {
      await _storage.saveProducto(producto);
      _showMessage(
        producto.id.isEmpty ? 'Producto guardado.' : 'Producto actualizado.',
      );
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
    if (!mounted) return;
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
        loadData(widget.currentStatus);
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final bool allowWriteActions =
        widget.currentStatus != ActivationStatus.none;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Gestionar Productos'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ProfileAvatarMenu(
              perfilActivo: _currentProfileName,
              perfiles: _perfiles,
              activationStatus: widget.currentStatus,
              onCambiarPerfil: (p) async {
                if (p != null) {
                  await _storage.switchProfile(p);
                  loadData(widget.currentStatus);
                }
              },
              onAfterConfiguracion: () => loadData(widget.currentStatus),
              onCerrarSesion: () async {
                await Provider.of<StorageService>(
                  context,
                  listen: false,
                ).signOutUser();
                loadData(widget.currentStatus);
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => loadData(widget.currentStatus),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final profileAndForm = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox.shrink(),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: ExpansionTile(
                            key: ValueKey(_productoParaEditar?.id ?? 'nuevo'),
                            initiallyExpanded: _productoParaEditar != null,
                            maintainState: true,
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            shape: const RoundedRectangleBorder(
                              side: BorderSide.none,
                            ),
                            collapsedShape: const RoundedRectangleBorder(
                              side: BorderSide.none,
                            ),
                            iconColor: theme.colorScheme.onSurfaceVariant,
                            collapsedIconColor:
                                theme.colorScheme.onSurfaceVariant,
                            title: Text(
                              _productoParaEditar != null
                                  ? 'Editar Ítem'
                                  : 'Agregar Nuevo Ítem',
                              style: theme.textTheme.titleMedium,
                            ),
                            children: [
                              const SizedBox(height: 12),
                              _ProductoForm(
                                status: widget.currentStatus,
                                productoInicial: _productoParaEditar,
                                showTitle: false,
                                onSave: _onSaveProducto,
                                onCancel: () {
                                  setState(() {
                                    _productoParaEditar = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  final productsList = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ítems Guardados',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
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
                              'Límite alcanzado ($kMaxDemoProducts productos). Actualiza a PRO para agregar más.',
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
                                      color: theme.cardTheme.color,
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
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Unidad: ${kUnidadesMedida[producto.unidadMedida] ?? '??'} - Precio: \$${producto.precio}',
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: allowWriteActions
                                                ? theme.colorScheme.onSurface
                                                      .withValues(alpha: 0.6)
                                                : Colors.grey.withAlpha(128),
                                            size: 20,
                                          ),
                                          onPressed: allowWriteActions
                                              ? () => _onDeleteProducto(
                                                  producto.id,
                                                )
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
                  );

                  if (!wide) {
                    return ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        profileAndForm,
                        const SizedBox(height: 24),
                        productsList,
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: profileAndForm),
                        const SizedBox(width: 16),
                        Expanded(flex: 6, child: productsList),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// --- CLASE _ProductoForm ---
class _ProductoForm extends StatefulWidget {
  final ActivationStatus status;
  final Producto? productoInicial;
  final bool showTitle;
  final Function(Producto) onSave;
  final VoidCallback onCancel;
  const _ProductoForm({
    required this.status,
    this.productoInicial,
    this.showTitle = true,
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
    _precioCtrl.text = _isEditing ? _producto.precio : '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
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
        (widget.status == ActivationStatus.demo);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            Text(
              _isEditing ? 'Editar Ítem' : 'Agregar Nuevo Ítem',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
          ],
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
                            if (val != null) {
                              setState(() => _producto.tipo = val);
                            }
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
                            if (val != null) {
                              setState(() => _producto.unidadMedida = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildTextFormField(
                    controller: _descripcionCtrl,
                    label: 'Producto o Servicio*',
                    validator: (val) =>
                        (val == null || val.isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 18),
                  _buildTextFormField(
                    controller: _precioCtrl,
                    label: 'Precio Unitario (\$)*',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                    ],
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Campo requerido';
                      }

                      if (double.tryParse(val) == null) {
                        return 'Ingrese un número válido';
                      }
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
          // ... (resto de validaciones)
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
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

    final T? currentValue = (items.any((item) => item.value == value))
        ? value
        : null;

    return DropdownButtonFormField<T>(
      initialValue: currentValue,
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item.value,
              child: DefaultTextStyle(
                style: (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color ?? Colors.black,
                ),
                child: item.child,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      dropdownColor: theme.cardTheme.color,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      menuMaxHeight: 400,
    );
  }
}
