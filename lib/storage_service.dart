// lib/storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'models.dart';

// --- LÍMITES DEMO ACTUALIZADOS ---
const int kMaxDemoProfiles = 2; // Solo 1 perfil
const int kMaxDemoClients = 5; // Hasta 5 clientes
const int kMaxDemoProducts = 2; // Hasta 2 productos

class StorageService {
  static const String _activationStatusKey = 'activationStatus';
  static const String _profilesKey = 'profiles';
  static const String _currentProfileKey = 'currentProfile';
  static const String _lastInvoicedClientIdKey = 'lastInvoicedClientId';
  static const String _deviceIdKey =
      'device_unique_id'; // Nueva clave para el ID del dispositivo

  final _uuid = const Uuid();

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
      return ActivationStatus.demo;
    }

    // 2. Validación ROBUSTA en la nube para PRO
    try {
      final deviceId = await _getOrCreateDeviceId();
      print("Intentando activar $key con deviceId: $deviceId");

      // Llamada a tu Cloud Function 'validateLicense'
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'validateLicense',
      );

      // <<<--- CAMBIO: Usamos un Map literal directamente --->>>
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
        return newStatus;
      } else {
        // El servidor dijo que NO. Lanzamos el error para que la UI lo muestre.
        throw data['message'] ?? 'Error de activación desconocido.';
      }
    } on FirebaseFunctionsException catch (e) {
      print('Error de Cloud Function: ${e.code} - ${e.message}');
      // Si el error es 'invalid-argument', lo mostramos tal cual para depurar
      if (e.code == 'invalid-argument') {
        throw 'Error de validación: ${e.message}';
      }
      throw 'No se pudo conectar con el servidor de validación. Revisa tu conexión.';
    } catch (e) {
      print('Error general de activación: $e');
      rethrow; // Reenviamos el error exacto (ej. "Clave ya usada")
    }
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
      } catch (e) {
        print(
          "Error decodificando perfiles: $e. Creando perfil predeterminado.",
        );
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
    await prefs.setString(_profilesKey, jsonEncode(encodableMap));
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

  Future<List<Cliente>> getClientes() async {
    final profile = await _getCurrentProfile();
    profile.clients.sort(
      (a, b) => a.nombreCliente.toLowerCase().compareTo(
        b.nombreCliente.toLowerCase(),
      ),
    );
    return profile.clients;
  }

  Future<List<Producto>> getProductos() async {
    final profile = await _getCurrentProfile();
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
      profile.clients.add(cliente);
    } else {
      final index = profile.clients.indexWhere((c) => c.id == cliente.id);
      if (index != -1) {
        profile.clients[index] = cliente;
      } else {
        profile.clients.add(cliente);
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
      profile.products.add(producto);
    } else {
      final index = profile.products.indexWhere((p) => p.id == producto.id);
      if (index != -1) {
        profile.products[index] = producto;
      } else {
        profile.products.add(producto);
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
    print("Exportar datos...");
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
    print("Importar datos...");
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
      print("Error detallado al importar: $e");
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
} // Fin StorageService
