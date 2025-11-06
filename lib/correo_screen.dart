// lib/correo_screen.dart
import 'package:flutter/material.dart';
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
  List<Cliente> _otherClients = [];
  String _currentProfileName = "";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // Método público para ser llamado desde main.dart
  Future<void> loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final allClients = await _storage.getClientes();
      final recentClientId = await _storage.getLastInvoicedClientId();
      final profileName = await _storage.getCurrentProfileName();

      Cliente? foundRecent;
      List<Cliente> foundOthers = [];

      if (recentClientId != null) {
        // Separa al cliente reciente de los demás
        for (var client in allClients) {
          if (client.id == recentClientId) {
            foundRecent = client;
          } else {
            foundOthers.add(client);
          }
        }
      } else {
        // Si no hay cliente reciente, todos son "otros"
        foundOthers = allClients;
      }

      if (!mounted) return;
      setState(() {
        _recentClient = foundRecent;
        _otherClients = foundOthers;
        _currentProfileName = profileName;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar clientes: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colorBlanco,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Correo'), // Título principal
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadData, // Permite refrescar la lista
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Sección Cliente Reciente ---
                  Text(
                    'Facturado Recientemente',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _recentClient == null
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorGrisClaro.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Ningún cliente seleccionado recientemente.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : _buildClientCard(theme, _recentClient!),

                  // --- Sección Todos los Clientes ---
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
                    child: Text(
                      'Directorio de Clientes',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _otherClients.isEmpty && _recentClient != null
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorGrisClaro.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'No hay otros clientes en este perfil.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _otherClients.length,
                          itemBuilder: (context, index) {
                            return _buildClientCard(
                              theme,
                              _otherClients[index],
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  /// Construye el Card para un cliente
  Widget _buildClientCard(ThemeData theme, Cliente cliente) {
    return Card(
      key: ValueKey(cliente.id),
      elevation: 0,
      color: colorGrisClaro, // Color de fondo gris claro
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Acción al tocar el card (ej. enviar correo)
          // Implementar si se desea
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Enviar correo a ${cliente.nombreCliente}')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Columna de información (Nombre y Correo)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nombreCliente.isNotEmpty
                          ? cliente.nombreCliente
                          : '(Cliente sin nombre)',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cliente.email.isNotEmpty ? cliente.email : '(Sin correo)',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Icono de Correo a la derecha
              const SizedBox(width: 16),
              Icon(Icons.mail_outline, color: colorTextoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}
