// lib/admin_panel_screen.dart

import 'package:flutter/material.dart';
import 'services/firestore_service.dart';
import 'core/ui/app_colors.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _adminKeyController = TextEditingController();
  bool _isAuthenticated = false;
  List<LicenseData> _licenses = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _adminKeyController.dispose();
    super.dispose();
  }

  // --- VALIDAR CLAVE ADMIN ---
  void _validateAdminKey() {
    if (FirestoreService.isAdminKey(_adminKeyController.text.trim())) {
      setState(() {
        _isAuthenticated = true;
        _errorMessage = null;
      });
      _loadAllLicenses();
    } else {
      setState(() {
        _errorMessage = 'Clave admin incorrecta';
        _isAuthenticated = false;
      });
    }
  }

  // --- CARGAR TODAS LAS LICENCIAS ---
  Future<void> _loadAllLicenses() async {
    setState(() => _isLoading = true);
    try {
      final licenses = await _firestoreService.getAllLicenses();
      setState(() {
        _licenses = licenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cargando licencias: $e';
        _isLoading = false;
      });
    }
  }

  // --- DESACTIVAR LICENCIA ---
  Future<void> _deactivateLicense(String licenseKey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar Licencia'),
        content: Text(
          '¿Estás seguro de que deseas desactivar la licencia:\n$licenseKey?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _firestoreService.updateLicenseStatus(
        licenseKey: licenseKey,
        isActive: false,
      );
      if (!mounted) return;
      if (success) {
        _loadAllLicenses();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Licencia desactivada')));
      }
    }
  }

  // --- REACTIVAR LICENCIA ---
  Future<void> _reactivateLicense(String licenseKey) async {
    final success = await _firestoreService.updateLicenseStatus(
      licenseKey: licenseKey,
      isActive: true,
    );
    if (!mounted) return;
    if (success) {
      _loadAllLicenses();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Licencia reactivada')));
    }
  }

  // --- VER CLIENTES DE UNA LICENCIA ---
  Future<void> _viewClientsForLicense(String licenseKey) async {
    final clients = await _firestoreService.getClientsForLicense(licenseKey);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clientes - $licenseKey'),
        content: SizedBox(
          width: double.maxFinite,
          child: clients.isEmpty
              ? const Text('Sin clientes registrados')
              : ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return ListTile(
                      title: Text(client.nombreCliente),
                      subtitle: Text('NIT: ${client.nit}, NRC: ${client.nrc}'),
                      trailing: Text(client.email),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // --- UI: PANTALLA DE AUTENTICACIÓN ---
  Widget _buildAuthenticationScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: colorCelestePastel),
            const SizedBox(height: 24),
            const Text(
              'Panel Administrativo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ingresa tu clave de administrador',
              style: TextStyle(color: colorTextoSecundario),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _adminKeyController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Clave Admin',
                prefixIcon: const Icon(Icons.key),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _validateAdminKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorCelestePastel,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Acceder',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI: PANTALLA DE ADMINISTRACIÓN ---
  Widget _buildAdminScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administrativo'),
        backgroundColor: colorCelestePastel,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllLicenses,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              setState(() {
                _isAuthenticated = false;
                _adminKeyController.clear();
                _licenses = [];
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _licenses.isEmpty
          ? const Center(child: Text('No hay licencias registradas'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _licenses.length,
              itemBuilder: (context, index) {
                final license = _licenses[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ExpansionTile(
                    leading: license.isActive
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.cancel, color: Colors.red),
                    title: Text(
                      license.key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text('${license.businessName} (${license.tier})'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Tipo:', license.tier),
                            _buildInfoRow('Empresa:', license.businessName),
                            _buildInfoRow(
                              'Estado:',
                              license.isActive ? 'Activa' : 'Inactiva',
                            ),
                            _buildInfoRow(
                              'Dispositivo:',
                              license.deviceId ?? 'Sin vincular',
                            ),
                            _buildInfoRow(
                              'Creada:',
                              license.createdAt?.toLocal().toString().split(
                                    '.',
                                  )[0] ??
                                  '-',
                            ),
                            _buildInfoRow(
                              'Validada:',
                              license.lastValidatedAt
                                      ?.toLocal()
                                      .toString()
                                      .split('.')[0] ??
                                  '-',
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _viewClientsForLicense(license.key),
                                  icon: const Icon(Icons.people),
                                  label: const Text('Ver Clientes'),
                                ),
                                if (license.isActive)
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _deactivateLicense(license.key),
                                    icon: const Icon(Icons.block),
                                    label: const Text('Desactivar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                  )
                                else
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _reactivateLicense(license.key),
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('Activar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // --- HELPER: FILA DE INFO ---
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: colorTextoSecundario,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: colorTextoPrincipal),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isAuthenticated
        ? _buildAdminScreen()
        : _buildAuthenticationScreen();
  }
}
