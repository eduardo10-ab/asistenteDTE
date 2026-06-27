// lib/models.dart

import 'package:flutter/material.dart';
import 'core/ui/app_colors.dart';

// --- CLASES DE LICENCIA ---
class LicenseKeys {
  static const String demoKey = "DEMO-2025";
  static const String adminKey = "ADMIN-2025-MASTER"; // Clave maestra admin
}

enum ActivationStatus {
  none,
  demo,
  pro;

  // <<<--- INICIO: NUEVA PROPIEDAD PARA LA CÁPSULA --- >>>
  String get chipLabel {
    switch (this) {
      case ActivationStatus.pro:
        return 'PREMIUM';
      case ActivationStatus.demo:
        return 'DEMO';
      case ActivationStatus.none:
        return 'INACTIVO'; // Aquí está el cambio
    }
  }
  // <<<--- FIN: NUEVA PROPIEDAD --- >>>

  String get displayName {
    switch (this) {
      case ActivationStatus.pro:
        return 'Versión completa';
      case ActivationStatus.demo:
        return 'Versión limitada';
      case ActivationStatus.none:
        return 'Sin activación';
    }
  }

  String get description {
    switch (this) {
      case ActivationStatus.pro:
        return '¡Tienes acceso completo a todas las funciones!';
      case ActivationStatus.demo:
        return 'Versión limitada: Funcionalidades limitadas.';
      case ActivationStatus.none:
        return 'La aplicación no está activada. Introduce la clave en la pantalla de Inicio.';
    }
  }

  Color get color {
    switch (this) {
      case ActivationStatus.pro:
        return Colors.green[800] ?? Colors.green;
      case ActivationStatus.demo:
        return Colors.orange[800] ?? Colors.orange;
      case ActivationStatus.none:
        return colorTextoSecundario;
    }
  }
}

// --- MODELO DE PERFIL ---
class Perfil {
  List<Cliente> clients;
  List<Producto> products;
  List<Venta> ventas;

  Perfil({required this.clients, required this.products, required this.ventas});

  factory Perfil.empty() => Perfil(clients: [], products: [], ventas: []);

  factory Perfil.fromJson(Map<String, dynamic> json) {
    List<dynamic> normalizeList(dynamic value) {
      if (value is List<dynamic>) return value;
      if (value is Map) return value.values.toList();
      return const [];
    }

    List<T> safeParseList<T>(
      dynamic value,
      T Function(Map<String, dynamic>) parser,
    ) {
      final items = normalizeList(value);
      final parsed = <T>[];
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          try {
            parsed.add(parser(item));
          } catch (_) {
            // Se ignoran elementos corruptos para no perder todo el perfil.
          }
        } else if (item is Map) {
          try {
            parsed.add(parser(Map<String, dynamic>.from(item)));
          } catch (_) {
            // Se ignoran elementos corruptos para no perder todo el perfil.
          }
        }
      }
      return parsed;
    }

    return Perfil(
      clients: safeParseList(json['clients'], Cliente.fromJson),
      products: safeParseList(json['products'], Producto.fromJson),
      ventas: safeParseList(json['ventas'], Venta.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clients': clients.map((c) => c.toJson()).toList(),
      'products': products.map((p) => p.toJson()).toList(),
      'ventas': ventas.map((v) => v.toJson()).toList(),
    };
  }
}

// --- MODELO DE CLIENTE ---
class Cliente {
  String id;
  String nombreCliente;
  String nit;
  String nrc;
  String tipoPersona; // "NATURAL" o "JURÍDICA"
  String pais;
  String dui;
  String pasaporte;
  String carnetResidente;
  String otroDocumento;
  String nombreComercial;
  String actividadEconomica;
  String departamento;
  String municipio;
  String distrito;
  int lastModified; // timestamp de última modificación
  String direccion;
  String email;
  String telefono;
  int? deletedAt;

  Cliente({
    required this.id,
    int? lastModified,
    this.nombreCliente = '',
    this.nit = '',
    this.nrc = '',
    this.tipoPersona = 'NATURAL',
    this.pais = 'EL SALVADOR',
    this.dui = '',
    this.pasaporte = '',
    this.carnetResidente = '',
    this.otroDocumento = '',
    this.nombreComercial = '',
    this.actividadEconomica = '',
    this.departamento = '',
    this.municipio = '',
    this.distrito = '',
    this.direccion = '',
    this.email = '',
    this.telefono = '',
    this.deletedAt,
  }) : lastModified = lastModified ?? DateTime.now().millisecondsSinceEpoch;

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      lastModified: json['lastModified'] is int
          ? json['lastModified']
          : (json['lastModified'] is String
                ? int.tryParse(json['lastModified'])
                : null),
      nombreCliente: json['nombreCliente'] ?? '',
      nit: json['nit'] ?? '',
      nrc: json['nrc'] ?? '',
      tipoPersona: json['tipoPersona'] ?? 'NATURAL',
      pais: json['pais'] ?? 'EL SALVADOR',
      dui: json['dui'] ?? '',
      pasaporte: json['pasaporte'] ?? '',
      carnetResidente: json['carnetResidente'] ?? '',
      otroDocumento: json['otroDocumento'] ?? '',
      nombreComercial: json['nombreComercial'] ?? '',
      actividadEconomica: json['actividadEconomica'] ?? '',
      departamento: json['departamento'] ?? '',
      municipio: json['municipio'] ?? '',
      distrito: json['distrito'] ?? '',
      direccion: json['direccion'] ?? '',
      email: json['email'] ?? '',
      telefono: json['telefono'] ?? '',
      deletedAt: json['deletedAt'] is int
          ? json['deletedAt']
          : (json['deletedAt'] is String
                ? int.tryParse(json['deletedAt'])
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lastModified': lastModified,
      'nombreCliente': nombreCliente,
      'nit': nit,
      'nrc': nrc,
      'tipoPersona': tipoPersona,
      'pais': pais,
      'dui': dui,
      'pasaporte': pasaporte,
      'carnetResidente': carnetResidente,
      'otroDocumento': otroDocumento,
      'nombreComercial': nombreComercial,
      'actividadEconomica': actividadEconomica,
      'departamento': departamento,
      'municipio': municipio,
      'distrito': distrito,
      'direccion': direccion,
      'email': email,
      'telefono': telefono,
      if (deletedAt != null) 'deletedAt': deletedAt,
    };
  }
}

// --- MODELO DE PRODUCTO ---
class Producto {
  int lastModified; // timestamp de última modificación
  String id;
  String tipo; // "Bien", "Servicio", etc.
  String unidadMedida; // "59", "1", etc.
  String descripcion;
  String precio;
  int? deletedAt;

  Producto({
    required this.id,
    this.tipo = 'Bien',
    int? lastModified,
    this.unidadMedida = '59',
    this.descripcion = '',
    this.precio = '0.00',
    this.deletedAt,
  }) : lastModified = lastModified ?? DateTime.now().millisecondsSinceEpoch;

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: json['tipo'] ?? 'Bien',
      lastModified: json['lastModified'] is int
          ? json['lastModified']
          : (json['lastModified'] is String
                ? int.tryParse(json['lastModified'])
                : null),
      unidadMedida: json['unidadMedida'] ?? '59',
      descripcion: json['descripcion'] ?? '',
      precio: json['precio']?.toString() ?? '0.00',
      deletedAt: json['deletedAt'] is int
          ? json['deletedAt']
          : (json['deletedAt'] is String
                ? int.tryParse(json['deletedAt'])
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo,
      'lastModified': lastModified,
      'unidadMedida': unidadMedida,
      'descripcion': descripcion,
      'precio': precio,
      if (deletedAt != null) 'deletedAt': deletedAt,
    };
  }
}

// --- MODELO DE VENTA/FACTURA ---
class Venta {
  String id;
  String? fecha; // 'dd/M/yyyy' formato
  String? hora; // 'HH:mm:ss' formato
  int? timestamp; // milliseconds since epoch
  String? codigo; // codigoGeneracion
  String? numeroControl;
  String? sello;
  String? total; // monto como string con decimales
  String? cliente; // nombreCliente
  String? tipo; // tipoDte
  String? estado; // 'PROCESADO', 'NO PROCESADO', etc.
  List<dynamic> items;

  Venta({
    this.id = '',
    this.fecha,
    this.hora,
    this.timestamp,
    this.codigo,
    this.numeroControl,
    this.sello,
    this.total,
    this.cliente,
    this.tipo,
    this.estado,
    List<dynamic>? items,
  }) : items = items ?? [];

  factory Venta.fromJson(Map<String, dynamic> json) {
    // Helper local: busca la primera clave válida en el map (incluye búsqueda simple en submap)
    String? findFirstString(Map m, List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k) && m[k] != null) {
          final v = m[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
          if (v is num) return v.toString();
        }
      }
      // buscar en sub-objetos comunes
      for (final k in m.keys) {
        final v = m[k];
        if (v is Map) {
          final found = findFirstString(v, keys);
          if (found != null) return found;
        }
      }
      return null;
    }

    // Extraer total que puede ser string o num
    String? totalVal;
    if (json.containsKey('total')) {
      final t = json['total'];
      if (t is String && t.trim().isNotEmpty) totalVal = t.trim();
      if (t is num) totalVal = t.toStringAsFixed(2);
    } else {
      totalVal = findFirstString(json, [
        'total',
        'monto',
        'montoTotal',
        'totalPagar',
      ]);
    }

    final clienteVal = findFirstString(json, [
      'cliente',
      'nombreCliente',
      'nombre',
      'receptor',
    ]);
    final horaVal = findFirstString(json, ['hora', 'horaLegible', 'time']);
    final timestampVal = (json['timestamp'] is int)
        ? json['timestamp']
        : (json['timestamp'] is String
              ? int.tryParse(json['timestamp'])
              : null);

    return Venta(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      fecha: _normalizeFechaFormat(
        json['fecha']?.toString() ??
            findFirstString(json, ['fecha', 'fechaLegible', 'fechaEmi']),
      ),
      hora: _normalizeHoraFormat(horaVal),
      timestamp: timestampVal,
      codigo:
          json['codigo']?.toString() ?? json['codigoGeneracion']?.toString(),
      numeroControl:
          json['numeroControl']?.toString() ??
          findFirstString(json, ['numeroControl', 'nroControl', 'control']),
      sello: json['sello']?.toString(),
      total: totalVal,
      cliente: clienteVal,
      tipo: json['tipo']?.toString() ?? json['tipoDte']?.toString(),
      estado: json['estado']?.toString(),
      items: (json['items'] as List<dynamic>?) ?? [],
    );
  }

  // Helper static: Normalizar fecha de ISO format a dd/M/yyyy
  static String? _normalizeFechaFormat(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return null;

    final fecha = fechaStr.trim();

    // Si ya está en formato dd/M/yyyy o similar, no cambiar
    if (fecha.contains('/')) {
      return fecha;
    }

    // Intentar parsear como ISO datetime (2026-02-21T00:00:00.000 o 2026-02-21)
    try {
      if (fecha.contains('T') || fecha.length >= 10) {
        final dateTime = DateTime.parse(fecha);
        // Retornar en formato dd/M/yyyy
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (_) {
      // Ignorar errores de parsing
    }

    return fecha; // Retornar como está si no se puede parsear
  }

  // Helper static: Normalizar hora de ISO datetime a HH:mm:ss
  static String? _normalizeHoraFormat(String? horaStr) {
    if (horaStr == null || horaStr.isEmpty) return null;

    final hora = horaStr.trim();

    // Si contiene T, es ISO datetime, extraer solo la hora
    if (hora.contains('T')) {
      try {
        final dateTime = DateTime.parse(hora);
        final hours = dateTime.hour.toString().padLeft(2, '0');
        final minutes = dateTime.minute.toString().padLeft(2, '0');
        final seconds = dateTime.second.toString().padLeft(2, '0');
        return '$hours:$minutes:$seconds';
      } catch (_) {
        // Ignorar errores de parsing
      }
    }

    return hora; // Retornar como está
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fecha': fecha,
      'hora': hora,
      'timestamp': timestamp,
      'codigo': codigo,
      'numeroControl': numeroControl,
      'sello': sello,
      'total': total,
      'cliente': cliente,
      'tipo': tipo,
      'estado': estado,
      'items': items,
    };
  }
}
