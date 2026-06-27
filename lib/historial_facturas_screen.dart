import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'models.dart';
import 'storage_service.dart';
import 'core/ui/app_colors.dart';

class HistorialFacturasScreen extends StatefulWidget {
  const HistorialFacturasScreen({super.key});

  @override
  State<HistorialFacturasScreen> createState() =>
      _HistorialFacturasScreenState();
}

class _HistorialFacturasScreenState extends State<HistorialFacturasScreen> {
  late StorageService storageService;
  List<Venta> ventasFiltradas = [];
  String filtroEstado = 'Todo el Historial';
  String busquedaCliente = '';
  bool isLoading = false;
  bool _storageListenerRegistered = false;

  @override
  void initState() {
    super.initState();
    storageService = context.read<StorageService>();
    storageService.addListener(_onStorageChanged);
    _storageListenerRegistered = true;
    _cargarFacturas();
  }

  @override
  void dispose() {
    if (_storageListenerRegistered) {
      storageService.removeListener(_onStorageChanged);
    }
    super.dispose();
  }

  void _onStorageChanged() {
    if (!mounted) return;
    _cargarFacturas(fromRemote: false);
  }

  Future<void> _cargarFacturas({bool fromRemote = true}) async {
    setState(() {
      isLoading = true;
    });

    try {
      Perfil? perfil;
      if (fromRemote) {
        await storageService.refreshDataFromFirestore();
        perfil = await storageService.getCurrentProfileDataFromFirestore();
      }

      perfil ??= await storageService.getCurrentProfileData();
      final perfilFinal = perfil;
      final ventas = perfilFinal.ventas;

      // Aplicar filtros
      ventasFiltradas = ventas.where((v) {
        final filtroEstadoOk =
            filtroEstado == 'Todo el Historial' ||
            v.estado?.contains(filtroEstado) == true;
        final filtroBusquedaOk =
            busquedaCliente.isEmpty ||
            v.cliente?.toLowerCase().contains(busquedaCliente.toLowerCase()) ==
                true;
        return filtroEstadoOk && filtroBusquedaOk;
      }).toList();

      // Ordenar por fecha descendente (más recientes primero)
      ventasFiltradas.sort((a, b) {
        final timestampA = a.timestamp ?? 0;
        final timestampB = b.timestamp ?? 0;
        return timestampB.compareTo(timestampA);
      });
    } catch (e) {
      final _ = e;
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Color _getEstadoColor(String? estado) {
    if (estado == null) return Colors.grey;
    if (estado.contains('PROCESADO')) return Colors.green;
    if (estado.contains('NO PROCESADO')) return Colors.orange;
    if (estado.contains('ANULADO')) return Colors.red;
    return Colors.grey;
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) {
        busquedaCliente = value;
        _cargarFacturas();
      },
      decoration: InputDecoration(
        hintText: 'Buscar cliente o código...',
        prefixIcon: Icon(
          Icons.search,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Facturación'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: isLoading ? null : _cargarFacturas,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _buildSearchField(),
              ),
            ),
          ),
          // Tabla de facturas
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ventasFiltradas.isEmpty
                ? Center(
                    child: Text(
                      'No hay facturas registradas',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargarFacturas,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 720;

                        if (isCompact) {
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: ventasFiltradas.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final venta = ventasFiltradas[index];
                              return _FacturaCard(
                                venta: venta,
                                estadoColor: _getEstadoColor(venta.estado),
                                onTap: () => _mostrarDetalleFactura(venta),
                              );
                            },
                          );
                        }

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Fecha')),
                                DataColumn(label: Text('Hora')),
                                DataColumn(label: Text('Tipo')),
                                DataColumn(label: Text('Código')),
                                DataColumn(label: Text('N# Control')),
                                DataColumn(label: Text('Cliente')),
                                DataColumn(label: Text('Total')),
                                DataColumn(label: Text('Estado')),
                              ],
                              rows: ventasFiltradas
                                  .map(
                                    (venta) => DataRow(
                                      cells: [
                                        DataCell(Text(venta.fecha ?? '-')),
                                        DataCell(
                                          Text(
                                            venta.hora != null &&
                                                    venta.hora!
                                                        .trim()
                                                        .isNotEmpty
                                                ? venta.hora!
                                                : '-',
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(
                                                alpha: 0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              venta.tipo ?? 'Factura',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            venta.codigo ?? '-',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            venta.numeroControl ?? '-',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            venta.cliente != null &&
                                                    venta.cliente!
                                                        .trim()
                                                        .isNotEmpty
                                                ? venta.cliente!
                                                : 'Cliente General',
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '\$${(venta.total != null && venta.total!.trim().isNotEmpty) ? venta.total : '0.00'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getEstadoColor(
                                                venta.estado,
                                              ).withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              venta.estado ?? '-',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _getEstadoColor(
                                                  venta.estado,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleFactura(Venta venta) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final estadoColor = _getEstadoColor(venta.estado);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venta.cliente != null && venta.cliente!.trim().isNotEmpty
                        ? venta.cliente!
                        : 'Cliente General',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _detalleChip('Fecha', venta.fecha ?? '-'),
                      _detalleChip('Hora', venta.hora ?? '-'),
                      _detalleChip('Tipo', venta.tipo ?? 'Factura'),
                      _detalleChip('Estado', venta.estado ?? '-'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detalleItem('Código', venta.codigo ?? '-'),
                  _detalleItem('N# Control', venta.numeroControl ?? '-'),
                  _detalleItem('Total', '\$${venta.total ?? '0.00'}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: estadoColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        venta.estado ?? '-',
                        style: TextStyle(
                          color: estadoColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detalleItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _detalleChip(String label, String value) {
    return Chip(label: Text('$label: $value'));
  }
}

class _FacturaCard extends StatelessWidget {
  const _FacturaCard({
    required this.venta,
    required this.estadoColor,
    required this.onTap,
  });

  final Venta venta;
  final Color estadoColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cliente = venta.cliente != null && venta.cliente!.trim().isNotEmpty
        ? venta.cliente!
        : 'Cliente General';
    final total = venta.total != null && venta.total!.trim().isNotEmpty
        ? venta.total!
        : '0.00';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: Theme.of(context).cardTheme.color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      venta.estado ?? '-',
                      style: TextStyle(
                        color: estadoColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniInfo(label: 'Fecha', value: venta.fecha ?? '-'),
                  _MiniInfo(label: 'Hora', value: venta.hora ?? '-'),
                  _MiniInfo(label: 'Total', value: '\$$total'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                venta.codigo ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorTextoSecundario),
              ),
              const SizedBox(height: 4),
              Text(
                venta.numeroControl ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorTextoSecundario),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface.withValues(alpha: 0.8)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Text('$label: $value', style: theme.textTheme.bodySmall),
    );
  }
}
