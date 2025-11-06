// lib/correo_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'storage_service.dart';
import 'main.dart'; // Para los colores

class CorreoScreen extends StatefulWidget {
  final ActivationStatus currentStatus;
  const CorreoScreen({super.key, required this.currentStatus});

  @override
  State<CorreoScreen> createState() => CorreoScreenState();
}

class CorreoScreenState extends State<CorreoScreen> {
  final StorageService _storage = StorageService();
  bool _isLoading = true;
  Cliente? _recentClient;
  List<Cliente> _allClients = [];
  List<Cliente> _filteredClients = [];
  String _currentProfileName = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterClients(_searchController.text);
  }

  void _filterClients(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredClients = _allClients;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredClients = _allClients.where((client) {
        return client.nombreCliente.toLowerCase().contains(lowerQuery) ||
            client.email.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final allClients = await _storage.getClientes();
      final recentClientId = await _storage.getLastInvoicedClientId();
      final profileName = await _storage.getCurrentProfileName();

      Cliente? foundRecent;
      if (recentClientId != null) {
        try {
          foundRecent = allClients.firstWhere((c) => c.id == recentClientId);
        } catch (e) {
          foundRecent = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _recentClient = foundRecent;
        _allClients = allClients;
        _filteredClients = allClients;
        _currentProfileName = profileName;
        _isLoading = false;
      });
      if (_searchController.text.isNotEmpty) {
        _filterClients(_searchController.text);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      print("Error cargando datos en CorreoScreen: $e");
    }
  }

  Future<void> _launchEmailApp(Cliente cliente) async {
    if (cliente.email.isEmpty) {
      _showError('Este cliente no tiene un correo electrónico registrado.');
      return;
    }

    const String subject = "Documento Tributario Electrónico";
    final String body =
        """
Estimado cliente, ${cliente.nombreCliente}
Muchas gracias por su compra.

A continuación le adjunto su factura electrónica.

Saludos.
""";

    final Uri mailtoUri = Uri(
      scheme: 'mailto',
      path: cliente.email,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      if (!await launchUrl(mailtoUri, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir la app de correo.');
      }
    } catch (e) {
      _showError('Error al abrir la app de correo: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colorBlanco,
      appBar: AppBar(
        title: const Text('Correo'),
        // <<< CAMBIO: Se eliminaron elevation, backgroundColor y foregroundColor
        // para usar los valores por defecto del tema (igual que Inicio) >>>
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildProfileSection(theme),
                  const SizedBox(height: 24),
                  Text(
                    'Facturado Recientemente',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _recentClient == null
                      ? _buildEmptyStateCard(
                          theme,
                          'Ningún cliente seleccionado recientemente.',
                        )
                      : _buildClientCard(theme, _recentClient!),
                  const SizedBox(height: 24),
                  Text(
                    'Directorio de Clientes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: colorGrisClaro,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _filteredClients.isEmpty
                      ? _buildEmptyStateCard(
                          theme,
                          _allClients.isEmpty
                              ? 'No hay clientes en este perfil.'
                              : 'No se encontraron resultados.',
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredClients.length,
                          itemBuilder: (context, index) {
                            return _buildClientCard(
                              theme,
                              _filteredClients[index],
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorCelestePastel.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorCelestePastel.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_circle, color: colorAzulActivo, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERFIL ACTIVO',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorAzulActivo,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentProfileName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorGrisClaro.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildClientCard(ThemeData theme, Cliente cliente) {
    return Card(
      key: ValueKey(cliente.id),
      elevation: 0,
      color: colorGrisClaro,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _launchEmailApp(cliente),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nombreCliente.isNotEmpty
                          ? cliente.nombreCliente
                          : '(Cliente sin nombre)',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cliente.email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        cliente.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorTextoSecundario,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorBlanco,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: colorAzulActivo,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
