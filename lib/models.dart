// lib/models.dart

// import 'dart:convert'; // <<< FIX: Eliminado (no se usa)
import 'package:flutter/material.dart';
import 'main.dart';

// --- CLASES DE LICENCIA (Portado de options.js) ---
class LicenseKeys {
  static const String demoKey = "DEMO-2025";
}

enum ActivationStatus {
  none,
  demo,
  pro;

  String get displayName {
    switch (this) {
      case ActivationStatus.pro:
        return 'Versión completa';
      case ActivationStatus.demo:
        return 'Versión limitada';
      case ActivationStatus.none:
        // <<< FIX: `unreachable_switch_default` (eliminado 'default') >>>
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
        // <<< FIX: `unreachable_switch_default` (eliminado 'default') >>>
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
        // <<< FIX: `unreachable_switch_default` (eliminado 'default') >>>
        return colorTextoSecundario; // Asegúrate de que colorTextoSecundario esté definido o usa Colors.grey
    }
  }
}

// --- MODELO DE PERFIL ---
class Perfil {
  List<Cliente> clients;
  List<Producto> products;

  Perfil({required this.clients, required this.products});

  factory Perfil.empty() => Perfil(clients: [], products: []);

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      clients:
          (json['clients'] as List<dynamic>?)
              ?.map((c) => Cliente.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      products:
          (json['products'] as List<dynamic>?)
              ?.map((p) => Producto.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clients': clients.map((c) => c.toJson()).toList(),
      'products': products.map((p) => p.toJson()).toList(),
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
  String direccion;
  String email;
  String telefono;

  Cliente({
    required this.id,
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
    this.direccion = '',
    this.email = '',
    this.telefono = '',
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
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
      direccion: json['direccion'] ?? '',
      email: json['email'] ?? '',
      telefono: json['telefono'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'direccion': direccion,
      'email': email,
      'telefono': telefono,
    };
  }
}

// --- MODELO DE PRODUCTO ---
class Producto {
  String id;
  String tipo; // "Bien", "Servicio", etc.
  String unidadMedida; // "59", "1", etc.
  String descripcion;
  String precio;

  Producto({
    required this.id,
    this.tipo = 'Bien',
    this.unidadMedida = '59',
    this.descripcion = '',
    this.precio = '0.00',
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: json['tipo'] ?? 'Bien',
      unidadMedida: json['unidadMedida'] ?? '59',
      descripcion: json['descripcion'] ?? '',
      precio: json['precio']?.toString() ?? '0.00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo,
      'unidadMedida': unidadMedida,
      'descripcion': descripcion,
      'precio': precio,
    };
  }
}
