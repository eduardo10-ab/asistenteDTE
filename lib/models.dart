// lib/models.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'main.dart';
// --- CLASES DE LICENCIA (Portado de options.js) ---
class LicenseKeys {
  static const String demoKey = "DEMO-2025";
  static final List<String> proKeys = [
    // Estas son las claves de tu options.js, ya decodificadas de Base64
    "W7X4-9N3K-R8F2-L6A1", "T5B3-E1H7-C4J2-G8V6", "X3Z8-M6P4-Q2R9-Y7S5",
    "F9G1-L7K3-H5B4-D2F8", "V6C2-T8J5-E4A9-M1P7", "K8R3-Y7S1-W4Z6-N2B9",
    "Q2H5-D9V8-G1C4-J7T3", "A1M7-P4E9-B2K6-R8L5", "N6S2-F8G5-T1W9-C3H4",
    "Y9K4-V6B8-D3K1-E7R2", "L5A9-R2P7-M3N1-G8F4", "H1D8-K4T2-W7S6-V3B9",
    "B4G7-E3Q9-K2R5-F1L0", "D8N2-T6W1-Y4S3-P9M5", "M3V6-C9H2-S7A4-R1K8",
    "Z5S1-G4J7-L9P3-W8N2", "E9Q4-K8R1-F2D7-T3V6", "R7B3-N6S9-A1M4-H5C2",
    "W2T5-V8B1-J4G7-Y9E3", "C6H9-L2K5-S8N1-P4M7", "G1J8-D4N3-V7C6-T2B5",
    "P4M2-A7R9-K1L6-S3H8", "S8N5-E1Q3-B6G2-W7S4", "Y3V7-T9W4-H2C1-R8K5",
    "J6G0-F5D8-M1P9-N4S7", "X1Z4-K7R2-T5B8-L9A3", "H9C5-W3T1-S6N8-G4J3",
    "R2L8-A4M1-P7E3-B9V7", "T7B1-Y9V4-E2Q6-K5R3", "N3S8-D6F2-C1H9-G7K4",
    "A6N9-P1U7-L4K2-R8B5", "F2D5-J8G1-W3T7-S9N4", "K4R7-V1B3-H6C9-Q2E5",
    "V8B2-S4N6-T1W5-M7P9", "C3H6-G9J1-L7K4-R2B8", "Q7E1-W5T9-Y2V3-A8M4",
    "S1N9-R4K2-P8M6-J7G3", "M5P3-B8V1-A6R9-H4C7", "D9N6-K2Q1-S7N4-T8W3",
    "G4J0-C7H1-B9V5-E3Q8", "W1T8-A3M6-R9K4-L2B7", "P7E9-S2N5-V4B1-J6G3",
    "R3K6-B9V2-L4A8-C1H7", "H8C4-G1J7-T5W3-N6S2", "E2Q5-V7B9-M3P1-Y4R8",
    "K9R1-D6F4-S2N8-A7M3", "L4A7-H3C2-V6B1-T9W5", "J8G3-T1W9-N5S4-F2D7",
    "B2V6-M7P1-R9K3-E4Q8", "Y2W9-E4Q1-P6M3-S8N7"
    // Añade el resto de tus claves aquí
  ];
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
      default:
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
      default:
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
      default:
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
      clients: (json['clients'] as List<dynamic>?)
          ?.map((c) => Cliente.fromJson(c as Map<String, dynamic>))
          .toList() ??
          [],
      products: (json['products'] as List<dynamic>?)
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
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
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