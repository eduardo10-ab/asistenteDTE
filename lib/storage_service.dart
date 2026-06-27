// lib/storage_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'models.dart';
import 'services/firestore_service.dart';

// --- LÍMITES DEMO ACTUALIZADOS ---
const int kMaxDemoProfiles = 2; // Solo 1 perfil
const int kMaxDemoClients = 5; // Hasta 5 clientes
const int kMaxDemoProducts = 2; // Hasta 2 productos

class StorageService extends ChangeNotifier {
  static const String _activationStatusKey = 'activationStatus';
  static const String _profilesKey = 'profiles';
  static const String _currentProfileKey = 'currentProfile';
  static const String _lastInvoicedClientIdKey = 'lastInvoicedClientId';
  static const String _deviceIdKey = 'device_unique_id';
  static const String _licenseKeyKey =
      'license_key'; // Guardar la clave de licencia actual

  final _uuid = const Uuid();
  late FirestoreService _firestoreService;
  String? _currentLicenseKey; // Para caché de la licencia actual
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userDataSubscription;

  StorageService() {
    _firestoreService = FirestoreService();
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    super.dispose();
  }

  // --- 1. Obtener ID Único del Dispositivo ---
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4(); // Genera un nuevo ID único
      await prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  // --- 2. LÓGICA DE LICENCIA (ACTUALIZADA A LA NUBE) ---
  Future<ActivationStatus> getActivationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final statusString = prefs.getString(_activationStatusKey);
    switch (statusString) {
      case 'PRO':
        return ActivationStatus.pro;
      case 'DEMO':
        return ActivationStatus.demo;
      default:
        return ActivationStatus.none;
    }
  }

  Future<ActivationStatus> activateLicense(String userKey) async {
    final key = userKey.trim().toUpperCase();

    // 1. Chequeo rápido local para la DEMO genérica
    if (key == LicenseKeys.demoKey) {
      await _saveActivationLocally(ActivationStatus.demo);
      await _saveLicenseKey(key); // Guardar clave de licencia
      return ActivationStatus.demo;
    }

    // 2. Validación ROBUSTA en la nube para PRO
    final deviceId = await _getOrCreateDeviceId();
    try {
      // <<< FIX: `print` reemplazado por `kDebugMode` >>>
      if (kDebugMode) {
        print("Intentando activar $key con deviceId: $deviceId");
      }

      // Llamada a tu Cloud Function 'validateLicense'
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'validateLicense',
      );

      final result = await callable.call({'key': key, 'deviceId': deviceId});

      final data = result.data as Map<dynamic, dynamic>;
      final bool success = data['success'] == true;

      if (success) {
        // ¡El servidor dijo que SÍ!
        final String tier = data['tier'] ?? 'DEMO';
        ActivationStatus newStatus = (tier == 'PRO')
            ? ActivationStatus.pro
            : ActivationStatus.demo;

        await _saveActivationLocally(newStatus);
        await _saveLicenseKey(key); // Guardar clave de licencia

        // Si es PRO, cargar datos desde Firestore
        if (newStatus == ActivationStatus.pro) {
          await _loadDataFromFirestore(key);
          await startRealtimeSync();
        }

        return newStatus;
      } else {
        // El servidor dijo que NO. Lanzamos el error para que la UI lo muestre.
        throw data['message'] ?? 'Error de activación desconocido.';
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('Error de Cloud Function: ${e.code} - ${e.message}');
      }

      // Si la callable no se encuentra en el proyecto, intentamos regiones comunes
      if (e.code == 'not-found') {
        // Regiones comunes donde podría haberse desplegado la función
        const List<String> fallbackRegions = [
          'us-central1',
          'southamerica-east1',
          'europe-west1',
        ];

        for (final region in fallbackRegions) {
          try {
            if (kDebugMode) print('Intentando callable en región: $region');
            final HttpsCallable callableRegion = FirebaseFunctions.instanceFor(
              region: region,
            ).httpsCallable('validateLicense');
            final resultRegion = await callableRegion.call({
              'key': key,
              'deviceId': deviceId,
            });
            final dataRegion = resultRegion.data as Map<dynamic, dynamic>;
            final bool successRegion = dataRegion['success'] == true;
            if (successRegion) {
              final String tier = dataRegion['tier'] ?? 'DEMO';
              ActivationStatus newStatus = (tier == 'PRO')
                  ? ActivationStatus.pro
                  : ActivationStatus.demo;
              await _saveActivationLocally(newStatus);
              await _saveLicenseKey(key);
              if (newStatus == ActivationStatus.pro) {
                await _loadDataFromFirestore(key);
                await startRealtimeSync();
              }
              return newStatus;
            } else {
              throw dataRegion['message'] ?? 'Error de activación desconocido.';
            }
          } on FirebaseFunctionsException catch (e2) {
            if (kDebugMode) {
              print('Región $region -> ${e2.code} : ${e2.message}');
            }
            // seguimos probando otras regiones
            continue;
          }
        }

        // Si ninguna región devolvió la función, informar al usuario con detalle
        if (kDebugMode) {
          print('Fallback a validación directa por Firestore (sin Functions).');
        }
        return _activateViaFirestoreFallback(key, deviceId);
      }

      // Si el error es 'invalid-argument', lo mostramos tal cual para depurar
      if (e.code == 'invalid-argument') {
        throw 'Error de validación: ${e.message}';
      }

      if (kDebugMode) {
        print('Fallback por error callable: ${e.code}. Intentando Firestore.');
      }
      return _activateViaFirestoreFallback(key, deviceId);
    } catch (e) {
      if (kDebugMode) {
        print('Error general de activación: $e');
      }
      rethrow; // Reenviamos el error exacto (ej. "Clave ya usada")
    }
  }

  Future<ActivationStatus> _activateViaFirestoreFallback(
    String key,
    String deviceId,
  ) async {
    final response = await _firestoreService.validateLicenseDirectly(
      licenseKey: key,
      deviceId: deviceId,
    );

    final success = response['success'] == true;
    if (!success) {
      throw response['message'] ?? 'No se pudo validar la licencia.';
    }

    final String tier = (response['tier'] ?? 'DEMO').toString();
    final ActivationStatus newStatus = (tier == 'PRO')
        ? ActivationStatus.pro
        : ActivationStatus.demo;

    await _saveActivationLocally(newStatus);
    await _saveLicenseKey(key);
    if (newStatus == ActivationStatus.pro) {
      await _loadDataFromFirestore(key);
      await startRealtimeSync();
    }

    return newStatus;
  }

  Future<void> _saveActivationLocally(ActivationStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activationStatusKey, status.name.toUpperCase());
  }

  // ==================================================================
  // --- LÓGICA DE DATOS (SIN CAMBIOS DESDE AQUÍ HACIA ABAJO) ---
  // ==================================================================
  Future<Map<String, Perfil>> _loadProfilesData() async {
    final prefs = await SharedPreferences.getInstance();
    String? profilesJson = prefs.getString(_profilesKey);
    Map<String, Perfil> profilesMap = {};
    if (profilesJson == null || profilesJson.isEmpty) {
      profilesMap = {'Perfil Predeterminado': Perfil.empty()};
      await _saveProfilesData(profilesMap);
      await switchProfile('Perfil Predeterminado');
    } else {
      try {
        Map<String, dynamic> decodedData = jsonDecode(profilesJson);
        profilesMap = decodedData.map(
          (key, value) =>
              MapEntry(key, Perfil.fromJson(value as Map<String, dynamic>)),
        );

        final savedCurrentProfile = prefs.getString(_currentProfileKey);
        if (profilesMap.isNotEmpty) {
          if (savedCurrentProfile == null ||
              !profilesMap.containsKey(savedCurrentProfile)) {
            await switchProfile(profilesMap.keys.first);
          }
        }
      } catch (e) {
        // <<< FIX: `print` reemplazado por `kDebugMode` >>>
        if (kDebugMode) {
          print(
            "Error decodificando perfiles: $e. Creando perfil predeterminado.",
          );
        }
        profilesMap = {'Perfil Predeterminado': Perfil.empty()};
        await _saveProfilesData(profilesMap);
        await switchProfile('Perfil Predeterminado');
      }
    }
    return profilesMap;
  }

  Future<void> _saveProfilesData(Map<String, Perfil> profilesMap) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> encodableMap = profilesMap.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    encodableMap = _purgeSoftDeletedInRawProfiles(encodableMap);
    await prefs.setString(_profilesKey, jsonEncode(encodableMap));

    // ✅ SINCRONIZAR CON FIRESTORE si el usuario es PRO
    _syncToFirestore(encodableMap);
  }

  // --- SINCRONIZAR CON FIRESTORE ---
  Future<void> _syncToFirestore(Map<String, dynamic> profilesData) async {
    try {
      final licenseKey = await _getCurrentLicenseKeyFromPrefs();
      if (licenseKey == null || licenseKey == 'DEMO-2025') {
        // No sincronizar datos DEMO
        return;
      }

      await _firestoreService.syncUserData(
        licenseKey: licenseKey,
        profiles: profilesData,
        inventoryEnabled: false,
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ Error sincronizando a Firestore: $e');
    }
  }

  // --- OBTENER CLAVE DE LICENCIA ACTUAL (PÚBLICA) ---
  Future<String?> getCurrentLicenseKey() => _getCurrentLicenseKeyFromPrefs();

  // --- OBTENER CLAVE DE LICENCIA ACTUAL (PRIVADA) ---
  Future<String?> _getCurrentLicenseKeyFromPrefs() async {
    if (_currentLicenseKey != null) return _currentLicenseKey;

    final prefs = await SharedPreferences.getInstance();
    _currentLicenseKey = prefs.getString(_licenseKeyKey);
    if (_currentLicenseKey != null) {
      unawaited(startRealtimeSync());
    }
    return _currentLicenseKey;
  }

  // --- GUARDAR CLAVE DE LICENCIA ---
  Future<void> _saveLicenseKey(String licenseKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_licenseKeyKey, licenseKey);
    _currentLicenseKey = licenseKey;
  }

  Future<void> startRealtimeSync() async {
    final licenseKey = await getCurrentLicenseKey();
    if (licenseKey == null || licenseKey == LicenseKeys.demoKey) {
      if (kDebugMode) {
        print(
          '⏭️ Realtime sync omitido: licenseKey=$licenseKey (DEMO no sincroniza)',
        );
      }
      return;
    }

    if (kDebugMode) {
      print('🔄 Iniciando listener en tiempo real para: $licenseKey');
    }

    await _userDataSubscription?.cancel();
    _userDataSubscription = _firestoreService.listenToUserDataChanges(
      licenseKey,
      (data) async {
        if (data == null) {
          if (kDebugMode) print('ℹ️ Firestore listener: data es null');
          return;
        }
        if (kDebugMode) {
          print('🔔 Firestore cambio detectado, aplicando datos...');
        }
        await _applyFirestoreData(data);
      },
    );
    if (kDebugMode) {
      print('✅ Listener iniciado correctamente');
    }
  }

  // --- CARGAR DATOS DESDE FIRESTORE ---
  Future<void> _loadDataFromFirestore(String licenseKey) async {
    try {
      final cloudData = await _firestoreService.downloadUserData(licenseKey);
      if (cloudData == null) {
        if (kDebugMode) print('ℹ️ No hay datos en Firestore para sincronizar');
        return;
      }
      await _applyFirestoreData(cloudData);
    } catch (e) {
      if (kDebugMode) print('⚠️ Error cargando datos de Firestore: $e');
    }
  }

  Future<void> _applyFirestoreData(Map<String, dynamic> cloudData) async {
    if (cloudData['profiles'] == null) {
      if (kDebugMode) print('⚠️ FIRESTORE: No hay perfiles en cloudData');
      return;
    }

    final cloudProfiles = cloudData['profiles'] as Map<String, dynamic>;
    if (kDebugMode) {
      print(
        '🌐 FIRESTORE: Recibidas ${cloudProfiles.length} perfiles del servidor',
      );
      for (final key in cloudProfiles.keys) {
        final profile = cloudProfiles[key];
        if (profile is Map) {
          final ventasCount =
              (profile['ventas'] as List<dynamic>?)?.length ?? 0;
          print('  Perfil[$key]: $ventasCount ventas');
          // Mostrar detalle de las primeras ventas para depuración
          if (ventasCount > 0) {
            final ventasList = profile['ventas'] as List<dynamic>;
            for (int i = 0; i < ventasList.length && i < 5; i++) {
              final v = ventasList[i];
              if (v is Map) {
                print('    Venta[$i] keys: ${v.keys.toList()}');
                // print small sample of values
                for (final k in v.keys) {
                  final val = v[k];
                  if (val == null) continue;
                  final sval = val is String
                      ? (val.length > 60 ? '${val.substring(0, 60)}...' : val)
                      : val.toString();
                  print('      $k: $sval');
                }
              } else {
                print('    Venta[$i]: $v');
              }
            }
          }
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final mergedProfiles = _purgeSoftDeletedInRawProfiles(cloudProfiles);

    await prefs.setString(_profilesKey, jsonEncode(mergedProfiles));

    final profilesData = cloudData['profiles'];
    if (profilesData is Map && profilesData.isNotEmpty) {
      final currentProfile = prefs.getString(_currentProfileKey);
      if (currentProfile == null || !profilesData.containsKey(currentProfile)) {
        await prefs.setString(
          _currentProfileKey,
          profilesData.keys.first.toString(),
        );
      }
    }

    if (kDebugMode) {
      print('✅ Datos descargados de Firestore y mergeados con datos locales');
    }

    notifyListeners();
  }

  Future<void> refreshDataFromFirestore() async {
    final licenseKey = await getCurrentLicenseKey();
    if (licenseKey == null || licenseKey == LicenseKeys.demoKey) {
      return;
    }

    await _loadDataFromFirestore(licenseKey);
  }

  Future<String> getCurrentProfileName() async {
    final prefs = await SharedPreferences.getInstance();
    String? current = prefs.getString(_currentProfileKey);
    if (current == null) {
      final profiles =
          await _loadProfilesData(); // Asegura que exista al menos uno
      current = profiles.keys.first;
      await switchProfile(current); // Guarda el perfil actual si no existía
    }
    return current;
  }

  Future<List<String>> getProfileNames() async {
    final profiles = await _loadProfilesData();
    return profiles.keys.toList();
  }

  Future<void> switchProfile(String profileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentProfileKey, profileName);
    // Limpiar cliente reciente al cambiar de perfil
    await prefs.remove(_lastInvoicedClientIdKey);
  }

  Future<Perfil> _getCurrentProfile() async {
    final profiles = await _loadProfilesData();
    final currentProfileName =
        await getCurrentProfileName(); // Asegura que haya un perfil actual
    return profiles[currentProfileName] ??
        Perfil.empty(); // Devuelve perfil vacío si algo falla
  }

  Future<Perfil> getCurrentProfileData() async {
    final refreshedProfile = await getCurrentProfileDataFromFirestore();
    if (refreshedProfile != null) {
      if (kDebugMode) {
        print(
          '🌐 PROFILE REFRESHED FROM FIRESTORE: ${refreshedProfile.ventas.length} ventas, '
          '${refreshedProfile.clients.length} clientes, ${refreshedProfile.products.length} productos',
        );
      }
      return refreshedProfile;
    }

    final profile = await _getCurrentProfile();
    if (kDebugMode) {
      print(
        '📋 PROFILE LOADED: ${profile.ventas.length} ventas, '
        '${profile.clients.length} clientes, ${profile.products.length} productos',
      );
      for (int i = 0; i < profile.ventas.length && i < 5; i++) {
        final v = profile.ventas[i];
        print(
          '  Venta[$i]: id=${v.id}, cliente=${v.cliente}, fecha=${v.fecha}, hora=${v.hora}, '
          'codigo=${v.codigo}, numeroControl=${v.numeroControl}, total=${v.total}, '
          'tipo=${v.tipo}, estado=${v.estado}, timestamp=${v.timestamp}',
        );
      }
    }
    return profile;
  }

  Future<Perfil?> getCurrentProfileDataFromFirestore() async {
    final licenseKey = await getCurrentLicenseKey();
    if (licenseKey == null || licenseKey == LicenseKeys.demoKey) {
      return null;
    }

    final cloudData = await _firestoreService.downloadUserData(licenseKey);
    if (cloudData == null) {
      return null;
    }

    final profilesData = cloudData['profiles'];
    if (profilesData is! Map || profilesData.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    String? currentProfile = prefs.getString(_currentProfileKey);
    if (currentProfile == null || !profilesData.containsKey(currentProfile)) {
      currentProfile = profilesData.keys.first.toString();
    }

    final currentProfileData = profilesData[currentProfile];
    if (currentProfileData is Map<String, dynamic>) {
      return Perfil.fromJson(currentProfileData);
    }
    if (currentProfileData is Map) {
      return Perfil.fromJson(Map<String, dynamic>.from(currentProfileData));
    }

    return null;
  }

  Future<List<Cliente>> getClientes() async {
    final profile = await _getCurrentProfile();
    profile.clients = profile.clients
        .where((cliente) => cliente.deletedAt == null)
        .toList();
    profile.clients.sort(
      (a, b) => a.nombreCliente.toLowerCase().compareTo(
        b.nombreCliente.toLowerCase(),
      ),
    );
    return profile.clients;
  }

  Future<List<Producto>> getProductos() async {
    final profile = await _getCurrentProfile();
    profile.products = profile.products
        .where((producto) => producto.deletedAt == null)
        .toList();
    profile.products.sort(
      (a, b) =>
          a.descripcion.toLowerCase().compareTo(b.descripcion.toLowerCase()),
    );
    return profile.products;
  }

  // --- Funciones CRUD ---

  Future<void> saveCliente(Cliente cliente) async {
    final status = await getActivationStatus();
    if (status == ActivationStatus.none) {
      throw ('Necesitas activar la aplicación (DEMO o PRO) para guardar clientes.');
    }

    final profiles = await _loadProfilesData();
    final profileName = await getCurrentProfileName();
    final profile = profiles[profileName] ?? Perfil.empty();

    if (status == ActivationStatus.demo &&
        profile.clients.length >= kMaxDemoClients &&
        cliente.id.isEmpty) {
      throw ('Límite DEMO: No puedes agregar más de $kMaxDemoClients clientes.');
    }

    if (cliente.id.isEmpty) {
      cliente.id = _uuid.v4();
      profile.clients.add(_updateClienteTimestamp(cliente));
    } else {
      final index = profile.clients.indexWhere((c) => c.id == cliente.id);
      if (index != -1) {
        profile.clients[index] = _updateClienteTimestamp(cliente);
      } else {
        profile.clients.add(_updateClienteTimestamp(cliente));
      } // Fallback: add if not found
    }
    profiles[profileName] = profile;
    await _saveProfilesData(profiles);
  }

  Future<void> deleteCliente(String clienteId) async {
    final status = await getActivationStatus();
    if (status == ActivationStatus.none) {
      throw ('Necesitas activar la aplicación (DEMO o PRO) para eliminar clientes.');
    }

    final profiles = await _loadProfilesData();
    final profileName = await getCurrentProfileName();
    final profile = profiles[profileName];
    if (profile != null) {
      profile.clients.removeWhere((c) => c.id == clienteId);
      profiles[profileName] = profile;
      await _saveProfilesData(profiles);
    }
  }

  Future<void> saveProducto(Producto producto) async {
    final status = await getActivationStatus();
    if (status == ActivationStatus.none) {
      throw ('Necesitas activar la aplicación (DEMO o PRO) para guardar productos.');
    }

    final profiles = await _loadProfilesData();
    final profileName = await getCurrentProfileName();
    final profile = profiles[profileName] ?? Perfil.empty();

    if (status == ActivationStatus.demo &&
        profile.products.length >= kMaxDemoProducts &&
        producto.id.isEmpty) {
      throw ('Límite DEMO: No puedes agregar más de $kMaxDemoProducts productos.');
    }

    if (producto.id.isEmpty) {
      producto.id = _uuid.v4();
      profile.products.add(_updateProductoTimestamp(producto));
    } else {
      final index = profile.products.indexWhere((p) => p.id == producto.id);
      if (index != -1) {
        profile.products[index] = _updateProductoTimestamp(producto);
      } else {
        profile.products.add(_updateProductoTimestamp(producto));
      } // Fallback: add if not found
    }
    profiles[profileName] = profile;
    await _saveProfilesData(profiles);
  }

  Future<void> deleteProducto(String productoId) async {
    final status = await getActivationStatus();
    if (status == ActivationStatus.none) {
      throw ('Necesitas activar la aplicación (DEMO o PRO) para eliminar productos.');
    }

    final profiles = await _loadProfilesData();
    final profileName = await getCurrentProfileName();
    final profile = profiles[profileName];
    if (profile != null) {
      profile.products.removeWhere((p) => p.id == productoId);
      profiles[profileName] = profile;
      await _saveProfilesData(profiles);
    }
  }

  Future<void> addProfile(String profileName) async {
    final status = await getActivationStatus();
    if (status == ActivationStatus.none) {
      throw ('Necesitas activar la aplicación (DEMO o PRO) para agregar perfiles.');
    }

    final profiles = await _loadProfilesData();
    if (profiles.containsKey(profileName)) {
      throw ('Ya existe un perfil con ese nombre.');
    }

    if (status == ActivationStatus.demo &&
        profiles.length >= kMaxDemoProfiles) {
      throw ('Límite DEMO: Solo puedes tener $kMaxDemoProfiles perfil. Actualiza a PRO para más.');
    }

    profiles[profileName] = Perfil.empty();
    await _saveProfilesData(profiles);
    await switchProfile(profileName);
  }

  Future<void> renameProfile(String newName) async {
    final status = await getActivationStatus();
    if (status == ActivationStatus.none) {
      throw ('Necesitas activar la aplicación (DEMO o PRO) para renombrar perfiles.');
    }

    final profiles = await _loadProfilesData();
    final oldName = await getCurrentProfileName();
    if (newName.isEmpty || newName == oldName) return;
    if (profiles.containsKey(newName)) {
      throw ('Ya existe un perfil con ese nombre.');
    }
    final data = profiles.remove(oldName); // Usa remove para obtener y quitar
    profiles[newName] = data ?? Perfil.empty();
    await _saveProfilesData(profiles);
    await switchProfile(newName);
  }

  Future<void> deleteProfile() async {
    final status = await getActivationStatus();
    if (status == ActivationStatus.none) {
      throw ('Necesitas activar la aplicación (DEMO o PRO) para eliminar perfiles.');
    }

    final profiles = await _loadProfilesData();
    final profileToDelete = await getCurrentProfileName();
    if (profiles.length <= 1) {
      throw ('No puedes eliminar el único perfil existente.');
    }
    profiles.remove(profileToDelete);
    await _saveProfilesData(profiles);
    await switchProfile(profiles.keys.first);
  }

  // --- Funciones de Importar/Exportar ---
  Future<String> exportData() async {
    final status = await getActivationStatus();
    if (status == ActivationStatus.none) {
      throw ('Necesitas activar la aplicación (DEMO o PRO) para exportar datos.');
    }
    // <<< FIX: `print` reemplazado por `kDebugMode` >>>
    if (kDebugMode) {
      print("Exportar datos...");
    }
    final profiles = await _loadProfilesData();
    final currentProfile = await getCurrentProfileName();
    final data = {
      'profiles': profiles.map((k, v) => MapEntry(k, v.toJson())),
      'currentProfile': currentProfile,
    };
    return jsonEncode(data);
  }

  Future<void> importData(String jsonString) async {
    final status = await getActivationStatus();
    if (status == ActivationStatus.none) {
      throw ('Necesitas activar la aplicación (DEMO o PRO) para importar datos.');
    }
    // <<< FIX: `print` reemplazado por `kDebugMode` >>>
    if (kDebugMode) {
      print("Importar datos...");
    }
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (data.containsKey('profiles') && data.containsKey('currentProfile')) {
        // Validación básica del formato interno antes de guardar
        final profilesData = data['profiles'] as Map<String, dynamic>;
        // Intenta decodificar el primer perfil para ver si la estructura es correcta
        if (profilesData.isNotEmpty) {
          Perfil.fromJson(profilesData.values.first as Map<String, dynamic>);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_profilesKey, jsonEncode(data['profiles']));
        await prefs.setString(
          _currentProfileKey,
          data['currentProfile'] as String,
        );
      } else {
        throw ('El archivo no tiene el formato correcto (faltan claves principales).');
      }
    } catch (e) {
      // <<< FIX: `print` reemplazado por `kDebugMode` >>>
      if (kDebugMode) {
        print("Error detallado al importar: $e");
      }
      throw ('Error al leer o validar el archivo JSON. Asegúrate de que el formato sea correcto.');
    }
  }

  // --- Nuevos métodos para cliente reciente ---
  Future<void> setLastInvoicedClientId(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastInvoicedClientIdKey, clientId);
  }

  Future<String?> getLastInvoicedClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastInvoicedClientIdKey);
  }

  // --- Helper: Actualizar timestamp de cliente antes de guardar ---
  Cliente _updateClienteTimestamp(Cliente cliente) {
    return Cliente(
      id: cliente.id,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      nombreCliente: cliente.nombreCliente,
      nit: cliente.nit,
      nrc: cliente.nrc,
      tipoPersona: cliente.tipoPersona,
      pais: cliente.pais,
      dui: cliente.dui,
      pasaporte: cliente.pasaporte,
      carnetResidente: cliente.carnetResidente,
      otroDocumento: cliente.otroDocumento,
      nombreComercial: cliente.nombreComercial,
      actividadEconomica: cliente.actividadEconomica,
      departamento: cliente.departamento,
      municipio: cliente.municipio,
      direccion: cliente.direccion,
      email: cliente.email,
      telefono: cliente.telefono,
      deletedAt: null,
    );
  }

  // --- Helper: Actualizar timestamp de producto antes de guardar ---
  Producto _updateProductoTimestamp(Producto producto) {
    return Producto(
      id: producto.id,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      tipo: producto.tipo,
      unidadMedida: producto.unidadMedida,
      descripcion: producto.descripcion,
      precio: producto.precio,
      deletedAt: null,
    );
  }

  // --- Merge: Combina perfiles locales y servidor usando timestamps ---
  // ignore: unused_element
  Map<String, dynamic> _mergeProfilesWithServerData(
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) {
    final Map<String, dynamic> result = {};
    final allProfileKeys = {...localData.keys, ...serverData.keys};

    for (final profileKey in allProfileKeys) {
      final localProfile = localData[profileKey] as Map<String, dynamic>?;
      final serverProfile = serverData[profileKey] as Map<String, dynamic>?;

      if (localProfile == null) {
        result[profileKey] = serverProfile;
        continue;
      }

      if (serverProfile == null) {
        result[profileKey] = localProfile;
        continue;
      }

      result[profileKey] = {
        'clients': _mergeItems(
          localProfile['clients'] as List<dynamic>? ?? [],
          serverProfile['clients'] as List<dynamic>? ?? [],
        ),
        'products': _mergeItems(
          localProfile['products'] as List<dynamic>? ?? [],
          serverProfile['products'] as List<dynamic>? ?? [],
        ),
        'ventas': _mergeItems(
          localProfile['ventas'] as List<dynamic>? ?? [],
          serverProfile['ventas'] as List<dynamic>? ?? [],
        ),
      };
    }

    return result;
  }

  List<dynamic> _mergeItems(
    List<dynamic> localItems,
    List<dynamic> serverItems,
  ) {
    final Map<String, dynamic> itemsMap = {};

    // Procesar items del servidor (web)
    for (final item in serverItems) {
      if (item is Map<String, dynamic>) {
        var itemKey = _getItemKey(item);
        // Si no hay key, generar una automática en lugar de descartar
        if (itemKey.isEmpty) {
          itemKey = _generateFallbackKey(item);
        }
        itemsMap[itemKey] = item;
      }
    }

    // Procesar items locales (Android)
    for (final item in localItems) {
      if (item is Map<String, dynamic>) {
        var itemKey = _getItemKey(item);
        // Si no hay key local, generar una automática
        if (itemKey.isEmpty) {
          itemKey = _generateFallbackKey(item);
        }

        final serverItem = itemsMap[itemKey];
        if (serverItem is Map<String, dynamic>) {
          final localTs = _getItemTimestamp(item);
          final serverTs = _getItemTimestamp(serverItem);

          final preferredItem = localTs >= serverTs ? item : serverItem;
          final fallbackItem = localTs >= serverTs ? serverItem : item;
          itemsMap[itemKey] = _mergeItemMaps(preferredItem, fallbackItem);
        } else {
          itemsMap[itemKey] = item;
        }
      }
    }

    return itemsMap.values.toList();
  }

  Map<String, dynamic> _mergeItemMaps(
    Map<String, dynamic> preferredItem,
    Map<String, dynamic> fallbackItem,
  ) {
    final merged = Map<String, dynamic>.from(fallbackItem);

    final preferredDeletedAt = _extractInt(preferredItem['deletedAt']);
    final fallbackDeletedAt = _extractInt(fallbackItem['deletedAt']);
    if (preferredDeletedAt != null || fallbackDeletedAt != null) {
      final resolvedDeletedAt =
          (preferredDeletedAt ?? 0) >= (fallbackDeletedAt ?? 0)
          ? preferredDeletedAt
          : fallbackDeletedAt;
      if (resolvedDeletedAt != null) {
        merged['deletedAt'] = resolvedDeletedAt;
      }
    }

    for (final entry in preferredItem.entries) {
      final key = entry.key;
      final preferredValue = entry.value;
      final fallbackValue = merged[key];

      if (!_hasValue(fallbackValue) && _hasValue(preferredValue)) {
        merged[key] = preferredValue;
      } else if (_hasValue(preferredValue)) {
        merged[key] = preferredValue;
      }
    }

    return merged;
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  String _getItemKey(Map<String, dynamic> item) {
    final id = item['id']?.toString().trim() ?? '';
    if (id.isNotEmpty) return id;

    final codigo =
        item['codigo']?.toString().trim() ??
        item['codigoGeneracion']?.toString().trim() ??
        '';
    if (codigo.isNotEmpty) return codigo;

    final numeroControl = item['numeroControl']?.toString().trim() ?? '';
    if (numeroControl.isNotEmpty) return numeroControl;

    final timestamp = item['timestamp'];
    if (timestamp is int) return timestamp.toString();
    if (timestamp is String && timestamp.trim().isNotEmpty) {
      return timestamp.trim();
    }

    return '';
  }

  // Generar key fallback para items sin identifiers usando contenido del item
  String _generateFallbackKey(Map<String, dynamic> item) {
    // Usar una combinación de campos disponibles para crear un key único
    final fecha = item['fecha']?.toString() ?? '';
    final hora = item['hora']?.toString() ?? '';
    final cliente = item['cliente']?.toString() ?? '';
    final total = item['total']?.toString() ?? '';

    final keyContent = '$fecha|$hora|$cliente|$total';
    // Hash simple del contenido
    return 'fallback_${keyContent.hashCode.abs()}';
  }

  int _getItemTimestamp(dynamic item) {
    if (item == null) return 0;
    if (item is Map<String, dynamic>) {
      final deletedAt = _extractInt(item['deletedAt']);
      if (deletedAt != null) return deletedAt;

      final ts = item['lastModified'];
      if (ts is int) return ts;
      if (ts is String) return int.tryParse(ts) ?? 0;

      final timestamp = item['timestamp'];
      if (timestamp is int) return timestamp;
      if (timestamp is String) return int.tryParse(timestamp) ?? 0;
    }
    return 0;
  }

  int? _extractInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> _purgeSoftDeletedInRawProfiles(
    Map<String, dynamic> rawProfiles,
  ) {
    final cleaned = <String, dynamic>{};

    rawProfiles.forEach((profileName, profileData) {
      if (profileData is! Map) {
        cleaned[profileName] = profileData;
        return;
      }

      final profile = Map<String, dynamic>.from(profileData);

      final clients = (profile['clients'] as List<dynamic>? ?? [])
          .where((item) => !_isSoftDeletedMap(item))
          .toList();
      final products = (profile['products'] as List<dynamic>? ?? [])
          .where((item) => !_isSoftDeletedMap(item))
          .toList();

      profile['clients'] = clients;
      profile['products'] = products;
      cleaned[profileName] = profile;
    });

    return cleaned;
  }

  bool _isSoftDeletedMap(dynamic item) {
    if (item is! Map) return false;
    final dynamic deletedAt = item['deletedAt'];
    if (deletedAt == null) return false;
    if (deletedAt is int) return true;
    if (deletedAt is String) return deletedAt.trim().isNotEmpty;
    return false;
  }
} // Fin StorageService
