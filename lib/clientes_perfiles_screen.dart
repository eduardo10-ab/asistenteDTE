// lib/clientes_perfiles_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Para Future.delayed

// --- Importaciones ---
import 'models.dart';
import 'storage_service.dart';
import 'cliente_form.dart';
import 'main.dart'; // Para colores del tema general

// --- INICIO: IMPORTACIONES OCR ---
import 'package:image_picker/image_picker.dart';
import 'scan_dui_util.dart';
// --- FIN: IMPORTACIONES OCR ---

// --- COLORES ESPECÍFICOS ---
const Color dangerColor = Color(0xFFD9534F);
const Color warningColor = Color(0xFFF0AD4E);
const Color successColor = Color(0xFF28a745);
const Color tealColor = Colors.teal;

class ClientesPerfilesScreen extends StatefulWidget {
  final ActivationStatus currentStatus;
  const ClientesPerfilesScreen({super.key, required this.currentStatus});

  @override
  State<ClientesPerfilesScreen> createState() => _ClientesPerfilesScreenState();
}

class _ClientesPerfilesScreenState extends State<ClientesPerfilesScreen> {
  final StorageService _storage = StorageService();

  List<String> _perfiles = [];
  String? _perfilActivo;
  List<Cliente> _clientes = [];
  bool _isLoading = true;
  Cliente? _clienteParaEditar;
  bool _mostrarFormCliente = false;

  @override
  void initState() {
    super.initState();
    _loadAllData(widget.currentStatus);
  }

  @override
  void didUpdateWidget(covariant ClientesPerfilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStatus != oldWidget.currentStatus) {
      _loadAllData(widget.currentStatus);
    }
  }

  Future<void> _loadAllData(ActivationStatus status) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final profile = await _storage.getCurrentProfileName();
      final names = await _storage.getProfileNames();
      final clientes = await _storage.getClientes();
      // <<< FIX: `use_build_context_synchronously` --- >>>
      if (!mounted) return;
      setState(() {
        _perfilActivo = profile;
        _perfiles = names;
        _clientes = clientes;
        _isLoading = false;
        _mostrarFormCliente = false;
        _clienteParaEditar = null;
      });
    } catch (e) {
      // <<< FIX: `use_build_context_synchronously` --- >>>
      if (!mounted) return;
      _showError(e.toString());
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

  // --- Lógica de Perfiles ---
  void _onAddProfile() async {
    // <<< FIX: `use_build_context_synchronously` --- >>>
    if (!mounted) return;
    final name = await _showInputDialog(
      'Crear Nuevo Perfil',
      'Nombre del perfil:',
    );
    if (name == null || name.isEmpty) return;
    try {
      await _storage.addProfile(name);
      _showMessage('Perfil "$name" creado.');
      _loadAllData(widget.currentStatus);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _onRenameProfile() async {
    // <<< FIX: `use_build_context_synchronously` --- >>>
    if (!mounted) return;
    final name = await _showInputDialog(
      'Renombrar Perfil',
      'Nuevo nombre:',
      initialValue: _perfilActivo,
    );
    if (name == null || name.isEmpty || name == _perfilActivo) return;
    try {
      await _storage.renameProfile(name);
      _showMessage('Perfil renombrado a "$name".');
      _loadAllData(widget.currentStatus);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _onDeleteProfile() async {
    // <<< FIX: `use_build_context_synchronously` --- >>>
    if (!mounted) return;
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Perfil'),
        content: Text(
          // <<< FIX: `unnecessary_brace_in_string_interps` --- >>>
          '¿Seguro que quieres eliminar el perfil "$_perfilActivo"? Esta acción no se puede deshacer.',
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
        await _storage.deleteProfile();
        _showMessage('Perfil eliminado.');
        _loadAllData(widget.currentStatus);
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _onSwitchProfile(String? newProfile) async {
    if (newProfile != null && newProfile != _perfilActivo) {
      try {
        await _storage.switchProfile(newProfile);
        _loadAllData(widget.currentStatus);
      } catch (e) {
        // <<< FIX: `use_build_context_synchronously` --- >>>
        if (!mounted) return;
        _showError(e.toString());
      }
    }
  }

  // --- INICIO: LÓGICA DE ESCANEO DUI MODIFICADA ---

  // Helper para mostrar un Snackbar/Toast que guía al usuario
  void _showScanMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  // Helper para tomar la foto
  Future<XFile?> _pickImage(String prompt) async {
    if (!mounted) return null;

    // Mostrar el prompt
    _showScanMessage(prompt);
    // Damos tiempo al usuario de leer el mensaje antes de que se abra la cámara
    await Future.delayed(const Duration(milliseconds: 1500));

    final ImagePicker picker = ImagePicker();
    return await picker.pickImage(source: ImageSource.camera);
  }

  Future<void> _onScanDUI() async {
    // 1. Obtener PARTE FRONTAL
    final XFile? frontImage = await _pickImage(
      'Toma foto a la PARTE FRONTAL del DUI',
    );
    if (frontImage == null) {
      _showMessage('Escaneo cancelado.');
      return;
    }

    // 2. Obtener PARTE TRASERA
    final XFile? backImage = await _pickImage(
      'Excelente. Ahora toma foto a la PARTE TRASERA',
    );
    if (backImage == null) {
      _showMessage('Escaneo cancelado.');
      return;
    }

    if (!mounted) return;

    // 3. Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      // 4. Procesar AMBAS imágenes
      final Map<String, String> datosExtraidos = await DuiParser.parseDUI(
        frontImage.path,
        backImage.path,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra el indicador de carga

      // 5. Crear un cliente pre-llenado
      final clientePrellenado = Cliente(
        id: '', // Es un cliente nuevo
        nombreCliente: datosExtraidos['nombre'] ?? '',
        dui: datosExtraidos['dui'] ?? '',
        direccion: datosExtraidos['direccion'] ?? '',
        pais: datosExtraidos['pais'] ?? 'EL SALVADOR',
        departamento: datosExtraidos['departamento'] ?? '',
        municipio: datosExtraidos['municipio'] ?? '',
      );

      // 6. Mostrar el formulario con los datos
      setState(() {
        _clienteParaEditar = clientePrellenado;
        _mostrarFormCliente = true;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cierra el indicador de carga
      _showError('Error al escanear: ${e.toString()}');
    }
  }
  // --- FIN: NUEVA LÓGICA DE ESCANEO DUI ---

  // --- Lógica de Clientes ---
  void _onSaveCliente(Cliente cliente) async {
    try {
      await _storage.saveCliente(cliente);
      _showMessage(
        cliente.id.isEmpty ? 'Cliente guardado.' : 'Cliente actualizado.',
      );
      _loadAllData(widget.currentStatus);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _mostrarFormCliente = false;
        _clienteParaEditar = null;
      });
    }
  }

  void _onDeleteCliente(String id) async {
    // <<< FIX: `use_build_context_synchronously` --- >>>
    if (!mounted) return;
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: const Text('¿Seguro que quieres eliminar este cliente?'),
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
        await _storage.deleteCliente(id);
        _showMessage('Cliente eliminado.');
        _loadAllData(widget.currentStatus);
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  // --- Lógica de Importar/Exportar ---
  void _onExport() async {
    try {
      final json = await _storage.exportData();
      await Clipboard.setData(ClipboardData(text: json));
      _showMessage('Datos copiados al portapapeles.');
    } catch (e) {
      _showError('Error al exportar: ${e.toString()}');
    }
  }

  void _onImport() async {
    // <<< FIX: `use_build_context_synchronously` --- >>>
    if (!mounted) return;
    final jsonToImport = await _showInputDialog(
      'Importar Copia',
      'Pega el contenido JSON aquí:',
      maxLines: 5,
    );
    if (jsonToImport == null || jsonToImport.isEmpty) return;
    try {
      await _storage.importData(jsonToImport);
      _showMessage('Datos importados. Recargando...');
      _loadAllData(widget.currentStatus);
    } catch (e) {
      _showError('Error al importar: ${e.toString()}');
    }
  }

  Future<String?> _showInputDialog(
    String title,
    String label, {
    String? initialValue,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);
    // <<< FIX: `use_build_context_synchronously` --- >>>
    // (Asegurarse de que el context de build esté disponible antes de llamar a showDialog)
    // En este caso, 'context' se pasa desde el 'build' que llama a esta función.
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          maxLines: maxLines,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // <<< FIX: `MaterialStateProperty` y `withOpacity` obsoletos reemplazados >>>
    final secondaryButtonStyle = OutlinedButton.styleFrom(
      foregroundColor: colorTextoPrincipal.withAlpha(204), // 80% opacity
      side: BorderSide(color: Colors.grey[300]!),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
    final bool allowWriteActions =
        widget.currentStatus != ActivationStatus.none;
    final bool isPro = widget.currentStatus == ActivationStatus.pro;

    return Scaffold(
      backgroundColor: colorBlanco,
      appBar: AppBar(title: const Text('Clientes y Perfiles')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionCard(
                  title: 'Gestión de Perfiles',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.currentStatus == ActivationStatus.demo)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'VERSIÓN LIMITADA: Límite de $kMaxDemoProfiles perfiles.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        'Perfil Activo:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _perfilActivo,
                        items: _perfiles
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                        onChanged: _onSwitchProfile,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          overflow: TextOverflow.ellipsis,
                        ),
                        // <<< FIX: `value` obsoleto, reemplazado por `initialValue` o
                        // `decoration` (aquí 'decoration' es lo correcto) >>>
                        decoration: const InputDecoration(),
                        isExpanded: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: allowWriteActions
                                  ? _onRenameProfile
                                  : null,
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Renombrar'),
                              style: secondaryButtonStyle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: allowWriteActions
                                  ? _onDeleteProfile
                                  : null,
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                // <<< FIX: `withOpacity` obsoleto >>>
                                color: dangerColor.withAlpha(
                                  allowWriteActions ? 204 : 102, // 80% o 40%
                                ),
                              ),
                              label: Text(
                                'Eliminar',
                                style: TextStyle(
                                  // <<< FIX: `withOpacity` obsoleto >>>
                                  color: dangerColor.withAlpha(
                                    allowWriteActions ? 230 : 102, // 90% o 40%
                                  ),
                                ),
                              ),
                              // <<< FIX: `MaterialStateProperty` obsoleto >>>
                              style: ButtonStyle(
                                foregroundColor:
                                    WidgetStateProperty.resolveWith<Color?>((
                                      Set<WidgetState> states,
                                    ) {
                                      if (states.contains(
                                        WidgetState.disabled,
                                      )) {
                                        return Colors.grey.withAlpha(102);
                                      }
                                      return dangerColor.withAlpha(230);
                                    }),
                                side:
                                    WidgetStateProperty.resolveWith<BorderSide>(
                                      (Set<WidgetState> states) {
                                        final color =
                                            states.contains(
                                              WidgetState.disabled,
                                            )
                                            ? Colors.grey.withAlpha(51)
                                            : dangerColor.withAlpha(128);
                                        return BorderSide(color: color);
                                      },
                                    ),
                              ).merge(secondaryButtonStyle),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              allowWriteActions &&
                                  (isPro || _perfiles.length < kMaxDemoProfiles)
                              ? _onAddProfile
                              : null,
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(
                            !allowWriteActions
                                ? 'Activa la app para crear perfiles'
                                : (isPro || _perfiles.length < kMaxDemoProfiles
                                      ? 'Crear Nuevo Perfil'
                                      : 'Límite DEMO alcanzado'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: allowWriteActions ? _onExport : null,
                              icon: const Icon(
                                Icons.file_upload_outlined,
                                size: 18,
                              ),
                              label: const Text('Copia Seg.'),
                              // <<< FIX: `MaterialStateProperty` obsoleto >>>
                              style: ButtonStyle(
                                foregroundColor:
                                    WidgetStateProperty.resolveWith<Color?>((
                                      Set<WidgetState> states,
                                    ) {
                                      return states.contains(
                                            WidgetState.disabled,
                                          )
                                          ? Colors.grey
                                          : tealColor;
                                    }),
                                side:
                                    WidgetStateProperty.resolveWith<BorderSide>(
                                      (Set<WidgetState> states) {
                                        final color =
                                            states.contains(
                                              WidgetState.disabled,
                                            )
                                            ? Colors.grey
                                            : tealColor;
                                        return BorderSide(
                                          color: color.withAlpha(128),
                                        );
                                      },
                                    ),
                              ).merge(secondaryButtonStyle),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: allowWriteActions ? _onImport : null,
                              icon: const Icon(
                                Icons.file_download_outlined,
                                size: 18,
                              ),
                              label: const Text('Importar'),
                              // <<< FIX: `MaterialStateProperty` obsoleto >>>
                              style: ButtonStyle(
                                foregroundColor:
                                    WidgetStateProperty.resolveWith<Color?>((
                                      Set<WidgetState> states,
                                    ) {
                                      return states.contains(
                                            WidgetState.disabled,
                                          )
                                          ? Colors.grey
                                          : successColor;
                                    }),
                                side:
                                    WidgetStateProperty.resolveWith<BorderSide>(
                                      (Set<WidgetState> states) {
                                        final color =
                                            states.contains(
                                              WidgetState.disabled,
                                            )
                                            ? Colors.grey
                                            : successColor;
                                        return BorderSide(
                                          color: color.withAlpha(128),
                                        );
                                      },
                                    ),
                              ).merge(secondaryButtonStyle),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Directorio de Clientes',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _mostrarFormCliente
                      ? ClienteForm(
                          key: ValueKey(_clienteParaEditar?.id ?? 'nuevo'),
                          clienteInicial: _clienteParaEditar,
                          onSave: _onSaveCliente,
                          onCancel: () {
                            setState(() {
                              _mostrarFormCliente = false;
                              _clienteParaEditar = null;
                            });
                          },
                        )
                      :
                        // --- INICIO: SECCIÓN DE BOTONES MODIFICADA ---
                        Column(
                          key: const ValueKey('botones'),
                          children: [
                            OutlinedButton.icon(
                              onPressed: allowWriteActions ? _onScanDUI : null,
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text(
                                'Escanear DUI para autocompletar',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 45),
                                foregroundColor: colorAzulActivo,
                                side: const BorderSide(color: colorAzulActivo),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    allowWriteActions &&
                                        (isPro ||
                                            _clientes.length < kMaxDemoClients)
                                    ? () {
                                        setState(() {
                                          _clienteParaEditar = null;
                                          _mostrarFormCliente = true;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.add, size: 20),
                                label: Text(
                                  !allowWriteActions
                                      ? 'Activa la app para agregar clientes'
                                      : (isPro ||
                                                _clientes.length <
                                                    kMaxDemoClients
                                            ? 'Agregar Nuevo Cliente'
                                            : 'Límite DEMO alcanzado'),
                                ),
                              ),
                            ),
                          ],
                        ),
                  // --- FIN: SECCIÓN DE BOTONES MODIFICADA ---
                ),
                const SizedBox(height: 16),
                _clientes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            'No hay clientes guardados.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _clientes.length,
                        itemBuilder: (context, index) {
                          final cliente = _clientes[index];
                          return InkWell(
                            onTap: allowWriteActions
                                ? () {
                                    setState(() {
                                      _clienteParaEditar = cliente;
                                      _mostrarFormCliente = true;
                                    });
                                  }
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
                                          cliente.nombreCliente,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cliente.nit.isNotEmpty
                                              ? cliente.nit
                                              : (cliente.dui.isNotEmpty
                                                    ? cliente.dui
                                                    : 'Sin documento'),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      // <<< FIX: `withOpacity` obsoleto >>>
                                      color: allowWriteActions
                                          ? colorTextoSecundario
                                          : Colors.grey.withAlpha(128), // 50%
                                      size: 20,
                                    ),
                                    onPressed: allowWriteActions
                                        ? () => _onDeleteCliente(cliente.id)
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

  Widget _buildSectionCard({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
