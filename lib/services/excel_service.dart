import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';

class ExcelService {
  Future<File> generarReporteVentasExcel({
    required String nombrePerfil,
    required List<Venta> ventas,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['REPORTE DE VENTAS'];
    final fechaGeneracion = DateTime.now();

    final ventasOrdenadas = [...ventas]
      ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

    final totalMonto = ventasOrdenadas.fold<double>(
      0,
      (acc, venta) => acc + (double.tryParse(venta.total ?? '0') ?? 0),
    );

    _appendTitleRows(
      sheet,
      titulo: 'REPORTE DE VENTAS ($nombrePerfil)',
      fechaGeneracion: fechaGeneracion,
      periodo: 'TODO EL HISTORIAL',
      totalRegistros: ventasOrdenadas.length,
      totalMonto: totalMonto,
    );

    sheet.appendRow([
      TextCellValue('FECHA'),
      TextCellValue('HORA'),
      TextCellValue('TIPO DTE'),
      TextCellValue('COD. GENERACIÓN'),
      TextCellValue('N# DE CONTROL'),
      TextCellValue('CLIENTE'),
      TextCellValue('TOTAL (\$)'),
      TextCellValue('ESTADO'),
    ]);

    for (final venta in ventasOrdenadas) {
      final fechaTexto = venta.fecha ?? '-';
      final horaTexto = venta.hora ?? '-';
      final tipoTexto = venta.tipo?.isNotEmpty == true
          ? venta.tipo!
          : 'Factura';
      final codigoTexto = venta.codigo?.isNotEmpty == true
          ? venta.codigo!
          : venta.id;
      final estadoTexto = _formatEstado(venta.estado ?? 'PROCESADO');

      sheet.appendRow([
        TextCellValue(fechaTexto),
        TextCellValue(horaTexto),
        TextCellValue(tipoTexto),
        TextCellValue(codigoTexto),
        TextCellValue(venta.numeroControl ?? '-'),
        TextCellValue(venta.cliente ?? 'Cliente General'),
        TextCellValue(venta.total ?? '0.00'),
        TextCellValue(estadoTexto),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el reporte de ventas');
    }

    final directory = await getTemporaryDirectory();
    final sanitizedProfile = nombrePerfil.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final filename =
        'reporte_ventas_${sanitizedProfile}_${fechaGeneracion.millisecondsSinceEpoch}.xlsx';
    final file = File('${directory.path}/$filename');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> generarReportePerfilExcel({
    required String nombrePerfil,
    required Perfil perfil,
  }) async {
    final excel = Excel.createExcel();

    final productosSheet = excel['Productos'];
    productosSheet.appendRow([
      TextCellValue('Descripcion'),
      TextCellValue('Tipo'),
      TextCellValue('Unidad Medida'),
      TextCellValue('Precio'),
    ]);

    for (final producto in perfil.products) {
      productosSheet.appendRow([
        TextCellValue(producto.descripcion),
        TextCellValue(producto.tipo),
        TextCellValue(producto.unidadMedida),
        TextCellValue(producto.precio),
      ]);
    }

    final clientesSheet = excel['Clientes'];
    clientesSheet.appendRow([
      TextCellValue('Nombre Cliente'),
      TextCellValue('NIT'),
      TextCellValue('NRC'),
      TextCellValue('Email'),
      TextCellValue('Telefono'),
      TextCellValue('Departamento'),
      TextCellValue('Municipio'),
      TextCellValue('Direccion'),
    ]);

    for (final cliente in perfil.clients) {
      clientesSheet.appendRow([
        TextCellValue(cliente.nombreCliente),
        TextCellValue(cliente.nit),
        TextCellValue(cliente.nrc),
        TextCellValue(cliente.email),
        TextCellValue(cliente.telefono),
        TextCellValue(cliente.departamento),
        TextCellValue(cliente.municipio),
        TextCellValue(cliente.direccion),
      ]);
    }

    final resumenSheet = excel['Resumen'];
    final fecha = DateTime.now();
    resumenSheet.appendRow([TextCellValue('Reporte generado')]);
    resumenSheet.appendRow([TextCellValue(fecha.toIso8601String())]);
    resumenSheet.appendRow([TextCellValue('Perfil')]);
    resumenSheet.appendRow([TextCellValue(nombrePerfil)]);
    resumenSheet.appendRow([TextCellValue('Total clientes')]);
    resumenSheet.appendRow([IntCellValue(perfil.clients.length)]);
    resumenSheet.appendRow([TextCellValue('Total productos')]);
    resumenSheet.appendRow([IntCellValue(perfil.products.length)]);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo Excel');
    }

    final directory = await getTemporaryDirectory();
    final sanitizedProfile = nombrePerfil.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final filename =
        'reporte_${sanitizedProfile}_${fecha.millisecondsSinceEpoch}.xlsx';
    final file = File('${directory.path}/$filename');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _appendTitleRows(
    Sheet sheet, {
    required String titulo,
    required DateTime fechaGeneracion,
    required String periodo,
    required int totalRegistros,
    required double totalMonto,
  }) {
    sheet.appendRow([TextCellValue(titulo)]);
    sheet.appendRow([
      TextCellValue('GENERADO: ${_formatDateTime(fechaGeneracion)}'),
    ]);
    sheet.appendRow([TextCellValue('PERIODO MOSTRADO: $periodo')]);
    sheet.appendRow([TextCellValue('TOTAL REGISTROS: $totalRegistros')]);
    sheet.appendRow([
      TextCellValue('TOTAL MONTO: ${totalMonto.toStringAsFixed(2)}'),
    ]);
    sheet.appendRow([TextCellValue('')]);
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    final isPm = hour >= 12;
    final normalizedHour = hour % 12 == 0 ? 12 : hour % 12;
    final period = isPm ? 'p. m.' : 'a. m.';
    return '$normalizedHour:$minute:$second $period';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)}, ${_formatTime(dateTime)}';
  }

  String _formatEstado(String estado) {
    final normalized = estado.trim().toUpperCase();
    return normalized.isEmpty ? 'PROCESADO' : normalized;
  }
}
