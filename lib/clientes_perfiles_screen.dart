// lib/clientes_perfiles_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Para Future.delayed

// --- Importaciones ---
import 'models.dart';
import 'storage_service.dart';
import 'cliente_form.dart';
// import 'main.dart'; // <--- Eliminado

// --- INICIO: IMPORTACIONES OCR ---
import 'package:image_picker/image_picker.dart';
import 'scan_dui_util.dart'; // El que ya teníamos
import 'scan_passport_util.dart'; // El parser de pasaportes
// --- FIN: IMPORTACIONES OCR ---

// --- COLORES ESPECÍFICOS (Semánticos, están bien) ---
const Color dangerColor = Color(0xFFD9534F);
const Color warningColor = Color(0xFFF0AD4E);
const Color successColor = Color(0xFF28a745);
const Color tealColor = Colors.teal;

// --- INICIO: COLORES DE MARCA AÑADIDOS ---
const Color colorCelestePastel = Color(0xFF80D8FF);
const Color colorAzulActivo = Color(0xFF40C4FF);
// --- FIN: COLORES DE MARCA AÑADIDOS ---

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

  String _clientType = 'El Salvador'; // 'El Salvador' o 'Extranjero'

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

  // --- Lógica de Perfiles (sin cambios) ---
  void _onAddProfile() async {
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
    if (!mounted) return;
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Perfil'),
        content: Text(
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
        if (!mounted) return;
        _showError(e.toString());
      }
    }
  }

  // --- LÓGICA DE ESCANEO ---

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

  Future<XFile?> _pickImage(String prompt) async {
    if (!mounted) return null;
    _showScanMessage(prompt);
    await Future.delayed(const Duration(milliseconds: 1500));
    final ImagePicker picker = ImagePicker();
    return await picker.pickImage(source: ImageSource.camera);
  }

  Future<void> _onScanDUI() async {
    final XFile? frontImage = await _pickImage(
      'Toma foto a la PARTE FRONTAL del DUI',
    );
    if (frontImage == null) {
      _showMessage('Escaneo cancelado.');
      return;
    }

    final XFile? backImage = await _pickImage(
      'Excelente. Ahora toma foto a la PARTE TRASERA',
    );
    if (backImage == null) {
      _showMessage('Escaneo cancelado.');
      return;
    }

    if (!mounted) return;
    _showLoadingDialog();

    try {
      final Map<String, String> datosExtraidos = await DuiParser.parseDUI(
        frontImage.path,
        backImage.path,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra el indicador de carga

      final clientePrellenado = Cliente(
        id: '',
        nombreCliente: datosExtraidos['nombre'] ?? '',
        dui: datosExtraidos['dui'] ?? '',
        nit: datosExtraidos['nit'] ?? '',
        direccion: datosExtraidos['direccion'] ?? '',
        pais: datosExtraidos['pais'] ?? 'EL SALVADOR',
        departamento: datosExtraidos['departamento'] ?? '',
        municipio: datosExtraidos['municipio'] ?? '',
      );

      _showFormWithData(clientePrellenado);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showError('Error al escanear DUI: ${e.toString()}');
    }
  }

  Future<void> _onScanPasaporte() async {
    final XFile? image = await _pickImage(
      'Tome foto a la página principal del PASAPORTE',
    );
    if (image == null) {
      _showMessage('Escaneo cancelado.');
      return;
    }

    if (!mounted) return;
    _showLoadingDialog();

    try {
      final Map<String, String> datosExtraidos =
          await PassportParser.parsePassport(image.path);

      if (!mounted) return;
      Navigator.pop(context);

      // --- INICIO: CAMBIO ---
      // Se combinan 'direccion' (Lugar de Nacimiento) y 'pais'
      final String pais = datosExtraidos['pais'] ?? '';
      final String lugarNacimiento = datosExtraidos['direccion'] ?? '';

      final String direccionComplemento;
      if (lugarNacimiento.isNotEmpty && pais.isNotEmpty) {
        direccionComplemento = '$lugarNacimiento, $pais';
      } else {
        direccionComplemento = lugarNacimiento;
      }

      final clientePrellenado = Cliente(
        id: '',
        nombreCliente: datosExtraidos['nombre'] ?? '',
        pasaporte: datosExtraidos['pasaporte'] ?? '',
        pais: pais,
        direccion: direccionComplemento, // <-- 'SANTA ANA, EL SALVADOR'
        departamento: '00 - Otro (Para extranjero)', // <-- CORREGIDO
        municipio: '00 - Otro (Para extranjero)', // <-- CORREGIDO
        tipoPersona: 'NATURAL',
      );
      // --- FIN: CAMBIO ---

      _showFormWithData(clientePrellenado);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showError('Error al escanear Pasaporte: ${e.toString()}');
    }
  }

  void _onScanCarnetResidencial() {
    _showError('Función para escanear Carnet Residencial no implementada.');
  }

  void _onScanOtroDocumento() {
    _showError('Función para escanear Otro Documento no implementada.');
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showFormWithData(Cliente cliente) {
    setState(() {
      _clienteParaEditar = cliente;
      _mostrarFormCliente = true;
    });
  }

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
    final secondaryButtonStyle = OutlinedButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurface.withAlpha(
        204,
      ), // 80% opacity
      side: BorderSide(color: theme.dividerColor),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
    final bool allowWriteActions =
        widget.currentStatus != ActivationStatus.none;
    final bool isPro = widget.currentStatus == ActivationStatus.pro;

    return Scaffold(
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
                                color: dangerColor.withAlpha(
                                  allowWriteActions ? 204 : 102, // 80% o 40%
                                ),
                              ),
                              label: Text(
                                'Eliminar',
                                style: TextStyle(
                                  color: dangerColor.withAlpha(
                                    allowWriteActions ? 230 : 102, // 90% o 40%
                                  ),
                                ),
                              ),
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
                      : Column(
                          key: const ValueKey('botones'),
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 4.0,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                                color: theme.inputDecorationTheme.fillColor,
                                border: Border.all(
                                  color: theme
                                      .inputDecorationTheme
                                      .enabledBorder!
                                      .borderSide
                                      .color,
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: _clientType,
                                underline: Container(),
                                isExpanded: true,
                                dropdownColor: theme.cardColor,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _clientType = value);
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(
                                    value: 'El Salvador',
                                    child: Text('Cliente de El Salvador'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Extranjero',
                                    child: Text('Cliente Extranjero / Turista'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_clientType == 'El Salvador')
                              _buildSalvadoranButtons(
                                allowWriteActions,
                                isPro,
                                _clientes.length,
                              )
                            else
                              _buildForeignerButtons(allowWriteActions),
                          ],
                        ),
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
                            onLongPress: allowWriteActions
                                ? () => _onDeleteCliente(cliente.id)
                                : null,
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
                                color: theme.cardColor,
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
                                      color: allowWriteActions
                                          ? theme.colorScheme.onSurfaceVariant
                                          : theme.disabledColor,
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

  // --- Widgets de Botones (sin cambios) ---
  Widget _buildSalvadoranButtons(
    bool allowWriteActions,
    bool isPro,
    int clientCount,
  ) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: allowWriteActions ? _onScanDUI : null,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Escanear DUI con IA'),
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
                allowWriteActions && (isPro || clientCount < kMaxDemoClients)
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
                  : (isPro || clientCount < kMaxDemoClients
                        ? 'Agregar Nuevo Cliente'
                        : 'Límite DEMO alcanzado'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForeignerButtons(bool allowWriteActions) {
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 45),
      foregroundColor: colorAzulActivo,
      side: const BorderSide(color: colorAzulActivo),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );

    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: allowWriteActions ? _onScanPasaporte : null,
          icon: const Icon(Icons.contact_mail_outlined),
          label: const Text('Escanear Pasaporte con IA'),
          style: buttonStyle,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: allowWriteActions ? _onScanCarnetResidencial : null,
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Escanear Carnet Residencial con IA'),
          style: buttonStyle,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: allowWriteActions ? _onScanOtroDocumento : null,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Escanear Otro Documento'),
          style: buttonStyle,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: allowWriteActions
                ? () {
                    setState(() {
                      _clienteParaEditar = Cliente(
                        id: '',
                        pais: '',
                      ); // Inicia con país vacío en lugar de 'EL SALVADOR'
                      _mostrarFormCliente = true;
                    });
                  }
                : null,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Agregar Cliente Manualmente'),
          ),
        ),
      ],
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
