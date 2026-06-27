// lib/correo_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'storage_service.dart';
import 'package:provider/provider.dart';
import 'core/ui/app_colors.dart';
import 'dart:async';
import 'profile_avatar_menu.dart';

class CorreoScreen extends StatefulWidget {
  final ActivationStatus currentStatus;
  const CorreoScreen({super.key, required this.currentStatus});

  @override
  State<CorreoScreen> createState() => CorreoScreenState();
}

class CorreoScreenState extends State<CorreoScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final StorageService _storage;
  bool _isLoading = true;
  Cliente? _recentClient;
  List<Cliente> _allClients = [];
  late ValueNotifier<List<Cliente>> _filteredClientsNotifier;
  String _currentProfileName = "";
  List<String> _perfiles = [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _storage = Provider.of<StorageService>(context, listen: false);
    _filteredClientsNotifier = ValueNotifier<List<Cliente>>([]);
    _storage.addListener(_onStorageChanged);
    loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _storage.removeListener(_onStorageChanged);
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _filteredClientsNotifier.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce: esperar 300ms después de que el usuario deja de escribir
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _filterClients(_searchController.text);
    });
  }

  void _onStorageChanged() {
    if (!mounted) return;
    loadData();
  }

  void _filterClients(String query) {
    if (query.isEmpty) {
      _filteredClientsNotifier.value = _allClients;
      return;
    }

    final lowerQuery = query.toLowerCase();
    final filtered = _allClients.where((client) {
      return client.nombreCliente.toLowerCase().contains(lowerQuery) ||
          client.email.toLowerCase().contains(lowerQuery);
    }).toList();

    _filteredClientsNotifier.value = filtered;
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final allClients = await _storage.getClientes();
      final recentClientId = await _storage.getLastInvoicedClientId();
      final profileName = await _storage.getCurrentProfileName();
      final profileNames = await _storage.getProfileNames();

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
        _filteredClientsNotifier.value = allClients;
        _currentProfileName = profileName;
        _perfiles = profileNames;
        _isLoading = false;
      });
      if (_searchController.text.isNotEmpty) {
        _filterClients(_searchController.text);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchEmailApp(Cliente cliente) async {
    if (cliente.email.isEmpty) {
      _showError('Este cliente no tiene un correo electrónico registrado.');
      return;
    }

    // Buscar archivos del cliente
    final files = await _storage.findClientLatestFiles(cliente.nombreCliente);
    final jsonFile = files['json'];
    final pdfFile = files['pdf'];

    const String subject = "Documento Tributario Electrónico";
    final String body =
        """
Estimado cliente, ${cliente.nombreCliente}
Muchas gracias por su compra.

A continuación le adjunto su factura electrónica.

Saludos.
""";

    try {
      // Si hay archivos, usar share_plus para adjuntar
      if (jsonFile != null || pdfFile != null) {
        final List<XFile> filesToShare = [];

        if (jsonFile != null && await jsonFile.exists()) {
          filesToShare.add(XFile(jsonFile.path));
        }
        if (pdfFile != null && await pdfFile.exists()) {
          filesToShare.add(XFile(pdfFile.path));
        }

        if (filesToShare.isNotEmpty) {
          // Mostrar diálogo con el correo del cliente antes de compartir
          if (mounted) {
            final bool? shouldContinue = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Enviar factura'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Importante: Se debe copiar el correo, dando clic en el ícono de copiar.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Correo del cliente:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cliente.email,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: cliente.email),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✓ Correo copiado'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: 'Copiar correo',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Archivos a compartir: ${filesToShare.length}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Compartir'),
                  ),
                ],
              ),
            );

            if (shouldContinue != true) {
              return;
            }
          }

          // ignore: deprecated_member_use
          final result = await Share.shareXFiles(
            filesToShare,
            subject: subject,
            text: body,
          );

          if (result.status == ShareResultStatus.success) {
            return;
          }
        }
      }

      // Fallback: abrir email sin adjuntos
      final Uri mailtoUri = Uri(
        scheme: 'mailto',
        path: cliente.email,
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );

      if (!await launchUrl(mailtoUri, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir la app de correo.');
      }
    } catch (e) {
      _showError('Error al enviar correo: ${e.toString()}');
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
    super.build(context); // required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Correo - Clientes'),
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
                  loadData();
                }
              },
              onAfterConfiguracion: loadData,
              onCerrarSesion: () async {
                await Provider.of<StorageService>(
                  context,
                  listen: false,
                ).signOutUser();
                loadData();
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadData,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(child: const SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: Text(
                        'Facturado Recientemente',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: const SizedBox(height: 12)),
                    SliverToBoxAdapter(
                      child: _recentClient == null
                          ? _buildEmptyStateCard(
                              theme,
                              'Ningún cliente seleccionado recientemente.',
                            )
                          : _buildClientCard(theme, _recentClient!),
                    ),
                    SliverToBoxAdapter(child: const SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: Text(
                        'Directorio de Clientes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: const SizedBox(height: 12)),
                    SliverToBoxAdapter(child: _buildSearchInput(theme)),
                    SliverToBoxAdapter(child: const SizedBox(height: 16)),
                    ValueListenableBuilder<List<Cliente>>(
                      valueListenable: _filteredClientsNotifier,
                      builder: (context, filteredClients, _) {
                        return _buildClientDirectory(theme, filteredClients);
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyStateCard(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
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

  Widget _buildSearchInput(ThemeData theme) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Buscar cliente...',
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.text,
      enableInteractiveSelection: true,
      onEditingComplete: () {
        FocusScope.of(context).unfocus();
      },
    );
  }

  Widget _buildClientDirectory(ThemeData theme, List<Cliente> filteredClients) {
    if (filteredClients.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyStateCard(
          theme,
          _allClients.isEmpty
              ? 'No hay clientes en este perfil.'
              : 'No se encontraron resultados.',
        ),
      );
    }

    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      final sortedResults = List<Cliente>.from(filteredClients)
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
      return SliverToBoxAdapter(
        child: Card(
          color: theme.cardTheme.color,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(sortedResults.length * 2 - 1, (index) {
              if (index.isOdd) {
                return Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                  indent: 16,
                  endIndent: 16,
                );
              }
              final cliente = sortedResults[index ~/ 2];
              return _buildClientCard(theme, cliente);
            }),
          ),
        ),
      );
    }

    final grouped = <String, List<Cliente>>{};
    for (final cliente in filteredClients) {
      final groupKey = _formatDateGroup(cliente.lastModified);
      grouped.putIfAbsent(groupKey, () => []).add(cliente);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final aTime = a.value.first.lastModified;
        final bTime = b.value.first.lastModified;
        return bTime.compareTo(aTime);
      });

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = entries[index];
        final items = entry.value;
        return Card(
          color: theme.cardTheme.color,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            initiallyExpanded: false,
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            iconColor: theme.colorScheme.onSurfaceVariant,
            collapsedIconColor: theme.colorScheme.onSurfaceVariant,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text(
              entry.key,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text('${items.length} cliente(s)'),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: items.length > 10
                      ? MediaQuery.of(context).size.height * 0.45
                      : double.infinity,
                ),
                child: ListView.separated(
                  shrinkWrap: items.length <= 10,
                  physics: items.length > 10
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, itemIndex) {
                    final cliente = items[itemIndex];
                    return _buildClientCard(theme, cliente);
                  },
                ),
              ),
            ],
          ),
        );
      }, childCount: entries.length),
    );
  }

  String _formatDateGroup(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildClientCard(ThemeData theme, Cliente cliente) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchEmailApp(cliente),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            title: Text(
              cliente.nombreCliente.isNotEmpty
                  ? cliente.nombreCliente
                  : '(Cliente sin nombre)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
            subtitle: Text(
              cliente.email.isNotEmpty
                  ? cliente.email
                  : 'Sin correo registrado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.mail_outline_rounded,
                color: colorAzulActivo,
                size: 20,
              ),
              onPressed: () => _launchEmailApp(cliente),
              tooltip: 'Enviar correo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ),
    );
  }
}
