// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async' show StreamSubscription, unawaited;
import '../models.dart';

// Para el listener
typedef DataChangeCallback = Function(Map<String, dynamic>?);

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _licensesCollection = 'licencias';
  static const String _usuariosDataCollection = 'datos_usuarios';
  static const String _adminKey = 'ADMIN-2025-MASTER'; // Clave maestra admin

  static Future<void> _ensureAnonymousSignIn() async {
    if (_auth.currentUser != null) return;
    await _auth.signInAnonymously();
  }

  // --- 1. VALIDAR SI ES ADMIN ---
  static bool isAdminKey(String key) {
    return key == _adminKey;
  }

  // --- 2. OBTENER TODAS LAS LICENCIAS (solo para Admin) ---
  Future<List<LicenseData>> getAllLicenses() async {
    try {
      await _ensureAnonymousSignIn();
      final snapshot = await _db.collection(_licensesCollection).get();
      return snapshot.docs
          .map((doc) => LicenseData.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // --- 3. OBTENER UNA LICENCIA ESPECÍFICA ---
  Future<LicenseData?> getLicense(String licenseKey) async {
    try {
      await _ensureAnonymousSignIn();

      // En la web el ID del documento suele ser la licencia.
      final byId = await _db
          .collection(_licensesCollection)
          .doc(licenseKey)
          .get();
      if (byId.exists) return LicenseData.fromFirestore(byId);

      final snapshot = await _db
          .collection(_licensesCollection)
          .where('key', isEqualTo: licenseKey)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return LicenseData.fromFirestore(snapshot.docs.first);
    } catch (e) {
      return null;
    }
  }

  Future<DocumentReference<Map<String, dynamic>>?> _findLicenseDocReference(
    String licenseKey,
  ) async {
    final byIdRef = _db.collection(_licensesCollection).doc(licenseKey);
    final byId = await byIdRef.get();
    if (byId.exists) return byIdRef;

    final byKey = await _db
        .collection(_licensesCollection)
        .where('key', isEqualTo: licenseKey)
        .limit(1)
        .get();

    if (byKey.docs.isNotEmpty) {
      return byKey.docs.first.reference;
    }

    final byLicencia = await _db
        .collection(_licensesCollection)
        .where('licencia', isEqualTo: licenseKey)
        .limit(1)
        .get();

    if (byLicencia.docs.isNotEmpty) {
      return byLicencia.docs.first.reference;
    }

    return null;
  }

  // --- 3.1 VALIDAR Y AMARRAR LICENCIA DESDE FIRESTORE (fallback sin Functions) ---
  Future<Map<String, dynamic>> validateLicenseDirectly({
    required String licenseKey,
    required String deviceId,
  }) async {
    try {
      await _ensureAnonymousSignIn();
      final docRef = await _findLicenseDocReference(licenseKey);
      if (docRef == null) {
        return {'success': false, 'message': 'Clave de licencia no válida.'};
      }

      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (data == null) {
        return {'success': false, 'message': 'No se pudo leer la licencia.'};
      }

      final license = LicenseData.fromFirestore(snapshot);
      if (!license.isActive) {
        return {
          'success': false,
          'message': 'Esta licencia ha sido revocada o suspendida.',
        };
      }

      final currentDevice = (data['deviceId'] ?? '').toString();
      if (currentDevice.isEmpty) {
        try {
          await docRef.update({
            'deviceId': deviceId,
            'activatedAt': FieldValue.serverTimestamp(),
            'lastValidatedAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied') rethrow;
        }
        return {
          'success': true,
          'tier': license.tier,
          'message': '¡Activación exitosa!',
        };
      }

      if (currentDevice == deviceId) {
        try {
          await docRef.update({
            'lastValidatedAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied') rethrow;
        }
        return {
          'success': true,
          'tier': license.tier,
          'message': 'Licencia validada.',
        };
      }

      return {
        'success': false,
        'message': 'Esta licencia ya está activada en otro dispositivo.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error validando licencia en Firestore.',
      };
    }
  }

  // --- 4. OBTENER DATOS DE USUARIO (perfiles, clientes, productos) ---
  Future<Map<String, dynamic>?> getUserData(String licenseKey) async {
    try {
      await _ensureAnonymousSignIn();
      final doc = await _db
          .collection(_usuariosDataCollection)
          .doc(licenseKey)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // --- 5. SINCRONIZAR DATOS LOCALES A FIRESTORE ---
  Future<bool> syncUserData({
    required String licenseKey,
    required Map<String, dynamic> profiles,
    required bool inventoryEnabled,
  }) async {
    try {
      await _ensureAnonymousSignIn();
      await _db.collection(_usuariosDataCollection).doc(licenseKey).set({
        'profiles': profiles,
        'inventoryEnabled': inventoryEnabled,
        // Usamos milisegundos para mantener compatibilidad con la extensión web
        'last_modified': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      return false;
    }
  }

  // --- 6. DESCARGAR DATOS DESDE FIRESTORE ---
  Future<Map<String, dynamic>?> downloadUserData(String licenseKey) async {
    try {
      await _ensureAnonymousSignIn();
      final doc = await _db
          .collection(_usuariosDataCollection)
          .doc(licenseKey)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      return data;
    } catch (e) {
      return null;
    }
  }

  // --- 7. LISTENER EN TIEMPO REAL (para sincronización bidireccional) ---
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
  listenToUserDataChanges(String licenseKey, DataChangeCallback onDataChanged) {
    unawaited(_ensureAnonymousSignIn());
    return _db
        .collection(_usuariosDataCollection)
        .doc(licenseKey)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            onDataChanged(doc.data());
          }
        }, onError: (error) {});
  }

  // --- 8. OBTENER CLIENTES DE UNA LICENCIA (para Admin) ---
  Future<List<Cliente>> getClientsForLicense(String licenseKey) async {
    try {
      await _ensureAnonymousSignIn();
      final userData = await getUserData(licenseKey);
      if (userData == null) return [];

      final profilesMap = userData['profiles'] ?? {};
      final allClients = <Cliente>[];

      if (profilesMap is Map) {
        for (var profileData in profilesMap.values) {
          if (profileData is Map && profileData['clients'] != null) {
            final clients = (profileData['clients'] as List<dynamic>)
                .map((c) => Cliente.fromJson(c as Map<String, dynamic>))
                .toList();
            allClients.addAll(clients);
          }
        }
      }

      return allClients;
    } catch (e) {
      return [];
    }
  }

  // --- 9. ACTUALIZAR ESTADO DE LICENCIA (solo Admin) ---
  Future<bool> updateLicenseStatus({
    required String licenseKey,
    required bool isActive,
  }) async {
    try {
      await _ensureAnonymousSignIn();

      final estado = isActive ? 'ACTIVO' : 'SUSPENDIDO';

      // Prioriza actualización por ID de documento (esquema web).
      final byIdRef = _db.collection(_licensesCollection).doc(licenseKey);
      final byId = await byIdRef.get();
      if (byId.exists) {
        await byIdRef.update({'estado': estado, 'isActive': isActive});
        return true;
      }

      final snapshot = await _db
          .collection(_licensesCollection)
          .where('key', isEqualTo: licenseKey)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return false;

      await snapshot.docs.first.reference.update({
        'estado': estado,
        'isActive': isActive,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- 10. AGREGAR NUEVA LICENCIA (solo Admin) ---
  Future<bool> addNewLicense({
    required String licenseKey,
    required String tier,
    required String businessName,
  }) async {
    try {
      await _ensureAnonymousSignIn();
      final newDoc = _db.collection(_licensesCollection).doc();
      await newDoc.set({
        'key': licenseKey,
        'tier': tier,
        'businessName': businessName,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastValidatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }
}

// --- MODELO DE DATOS DE LICENCIA ---
class LicenseData {
  final String id;
  final String key;
  final String tier;
  final String businessName;
  final bool isActive;
  final String? deviceId;
  final DateTime? createdAt;
  final DateTime? activatedAt;
  final DateTime? lastValidatedAt;

  LicenseData({
    required this.id,
    required this.key,
    required this.tier,
    required this.businessName,
    required this.isActive,
    this.deviceId,
    this.createdAt,
    this.activatedAt,
    this.lastValidatedAt,
  });

  factory LicenseData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    final dynamic isActiveValue = data?['isActive'];
    final String estado = (data?['estado'] ?? '').toString().toUpperCase();
    final bool computedIsActive = isActiveValue is bool
        ? isActiveValue
        : (estado == 'ACTIVO' ||
              estado == 'RESTRINGIDA' ||
              estado == 'PAUSADA');

    return LicenseData(
      id: doc.id,
      key: (data?['key'] ?? data?['licencia'] ?? doc.id).toString(),
      tier: (data?['tier'] ?? data?['plan'] ?? 'DEMO').toString(),
      businessName:
          (data?['businessName'] ??
                  data?['nombreEmpresa'] ??
                  data?['empresa'] ??
                  'Sin nombre')
              .toString(),
      isActive: computedIsActive,
      deviceId: data?['deviceId'],
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate(),
      activatedAt: (data?['activatedAt'] as Timestamp?)?.toDate(),
      lastValidatedAt: (data?['lastValidatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'tier': tier,
      'businessName': businessName,
      'isActive': isActive,
      'deviceId': deviceId,
      'createdAt': createdAt,
      'activatedAt': activatedAt,
      'lastValidatedAt': lastValidatedAt,
    };
  }
}
