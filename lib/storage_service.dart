// lib/storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';

// --- LÍMITES DEMO ACTUALIZADOS ---
const int kMaxDemoProfiles = 2; // Solo 1 perfil
const int kMaxDemoClients = 5; // Hasta 5 clientes
const int kMaxDemoProducts = 2; // Hasta 2 productos

class StorageService {
  static const String _activationStatusKey = 'activationStatus';
  static const String _profilesKey = 'profiles';
  static const String _currentProfileKey = 'currentProfile';
  // <<<--- INICIO: NUEVA CONSTANTE --- >>>
  static const String _lastInvoicedClientIdKey = 'lastInvoicedClientId';
  // <<<--- FIN: NUEVA CONSTANTE --- >>>
  final _uuid = const Uuid();

  // --- LÓGICA DE LICENCIA (Sin cambios) ---
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
    ActivationStatus newStatus = ActivationStatus.none;
    if (key == LicenseKeys.demoKey) {
      // Usa la clave de models.dart
      newStatus = ActivationStatus.demo;
    } else if (LicenseKeys.proKeys.contains(key)) {
      // Usa la lista de models.dart
      newStatus = ActivationStatus.pro;
    }
    // Solo guarda si la clave es válida (DEMO o PRO)
    if (newStatus != ActivationStatus.none) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activationStatusKey, newStatus.name.toUpperCase());
    }
    // Devuelve el estado encontrado (o 'none' si la clave no era válida)
    return newStatus;
  }

  // --- LÓGICA DE DATOS (Sin cambios) ---
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
    // <<<--- INICIO: LIMPIAR CLIENTE RECIENTE AL CAMBIAR DE PERFIL --- >>>
    // Esto asegura que el perfil nuevo no muestre el cliente reciente del perfil anterior
    await prefs.remove(_lastInvoicedClientIdKey);
    // <<<--- FIN: LIMPIAR CLIENTE RECIENTE AL CAMBIAR DE PERFIL --- >>>
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

  // --- Funciones CRUD (Sin cambios) ---
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

  // --- Funciones de Importar/Exportar (Sin cambios) ---
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

  // <<<--- INICIO: NUEVOS MÉTODOS --- >>>
  /// Guarda el ID del último cliente usado para facturar
  Future<void> setLastInvoicedClientId(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastInvoicedClientIdKey, clientId);
  }

  /// Obtiene el ID del último cliente usado
  Future<String?> getLastInvoicedClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastInvoicedClientIdKey);
  }
  // <<<--- FIN: NUEVOS MÉTODOS --- >>>
} // Fin StorageService
