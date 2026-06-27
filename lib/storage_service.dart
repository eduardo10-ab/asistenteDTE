// lib/storage_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'models.dart';
import 'services/firestore_service.dart';

// --- LÍMITES DEMO ACTUALIZADOS ---
const int kMaxDemoProfiles = 2; // Solo 1 perfil
const int kMaxDemoClients = 5; // Hasta 5 clientes
const int kMaxDemoProducts = 1; // Máximo 1 producto en modo demo

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
  String? _activeRealtimeSyncLicenseKey;
  bool _backgroundSyncInProgress = false;
  DateTime? _lastBackgroundSyncAt;
  static const Duration _minBackgroundSyncInterval = Duration(seconds: 20);

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
          } on FirebaseFunctionsException catch (_) {
            // seguimos probando otras regiones
            continue;
          }
        }

        // Si ninguna región devolvió la función, informar al usuario con detalle
        return _activateViaFirestoreFallback(key, deviceId);
      }

      // Si el error es 'invalid-argument', lo mostramos tal cual para depurar
      if (e.code == 'invalid-argument') {
        throw 'Error de validación: ${e.message}';
      }

      return _activateViaFirestoreFallback(key, deviceId);
    } catch (e) {
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

    // SINCRONIZAR CON FIRESTORE si el usuario es PRO
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
      final _ = e;
    }
  }

  // --- OBTENER CLAVE DE LICENCIA ACTUAL (PÚBLICA) ---
  Future<String?> getCurrentLicenseKey() => _getCurrentLicenseKeyFromPrefs();

  // --- OBTENER CLAVE DE LICENCIA ACTUAL (PRIVADA) ---
  Future<String?> _getCurrentLicenseKeyFromPrefs() async {
    if (_currentLicenseKey != null) return _currentLicenseKey;

    final prefs = await SharedPreferences.getInstance();
    _currentLicenseKey = prefs.getString(_licenseKeyKey);
    if (_currentLicenseKey != null && _userDataSubscription == null) {
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
      return;
    }

    if (_userDataSubscription != null &&
        _activeRealtimeSyncLicenseKey == licenseKey) {
      return;
    }

    await _userDataSubscription?.cancel();
    _activeRealtimeSyncLicenseKey = licenseKey;
    _userDataSubscription = _firestoreService.listenToUserDataChanges(
      licenseKey,
      (data) async {
        if (data == null) {
          return;
        }
        await _applyFirestoreData(data);
      },
    );
  }

  // --- CARGAR DATOS DESDE FIRESTORE ---
  Future<void> _loadDataFromFirestore(String licenseKey) async {
    try {
      final cloudData = await _firestoreService.downloadUserData(licenseKey);
      if (cloudData == null) {
        return;
      }
      await _applyFirestoreData(cloudData);
    } catch (e) {
      final _ = e;
    }
  }

  Future<void> _applyFirestoreData(Map<String, dynamic> cloudData) async {
    if (cloudData['profiles'] == null) {
      return;
    }

    final cloudProfiles = cloudData['profiles'] as Map<String, dynamic>;

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
    final profile = await _getCurrentProfile();

    // Luego, en background, sincronizamos con Firestore si es PRO
    // No ejecutamos el sync demasiado seguido para evitar reinicios
    // en cascada cuando la UI se actualiza varias veces.
    if (_shouldRunBackgroundSync()) {
      unawaited(_backgroundSyncFromFirestore());
    }

    return profile;
  }

  bool _shouldRunBackgroundSync() {
    if (_backgroundSyncInProgress) {
      return false;
    }
    if (_lastBackgroundSyncAt == null) {
      return true;
    }
    return DateTime.now().difference(_lastBackgroundSyncAt!) >=
        _minBackgroundSyncInterval;
  }

  /// Sincroniza desde Firestore en background sin bloquear la UI.
  Future<void> _backgroundSyncFromFirestore() async {
    if (_backgroundSyncInProgress) {
      return;
    }

    _backgroundSyncInProgress = true;

    try {
      final licenseKey = await _getCurrentLicenseKeyFromPrefs();
      if (licenseKey == null || licenseKey == LicenseKeys.demoKey) return;

      final cloudData = await _firestoreService.downloadUserData(licenseKey);
      if (cloudData == null) return;

      await _applyFirestoreData(cloudData);
    } catch (e) {
      final _ = e;
    } finally {
      _backgroundSyncInProgress = false;
      _lastBackgroundSyncAt = DateTime.now();
    }
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

  /// Encuentra el directorio de Descargas real del dispositivo Android,
  /// probando todos los nombres posibles (Download, Downloads, Descargas…)
  Future<Directory> _findRealDownloadsDir() async {
    try {
      final extDirs = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (extDirs != null && extDirs.isNotEmpty) {
        // La ruta típica es: /storage/emulated/0/Android/data/<pkg>/files/Downloads
        // Subimos hasta la raíz del almacenamiento externo
        final rootStorage = extDirs.first.path.split('/Android').first;
        // Probar todos los nombres comunes
        for (final name in [
          'Download',
          'Downloads',
          'Descargas',
          'descargas',
          'DESCARGAS',
        ]) {
          final dir = Directory('$rootStorage/$name');
          if (await dir.exists()) {
            return dir;
          }
        }
        // Ninguno existe: crear Download como fallback
        final fallback = Directory('$rootStorage/Download');
        await fallback.create(recursive: true);
        return fallback;
      }
    } catch (e) {
      // Error buscando Descargas
    }
    // Fallback final: directorio de documentos de la app
    return getApplicationDocumentsDirectory();
  }

  /// Obtiene la carpeta destino para una factura con la estructura:
  /// Descargas/asistente de facturacion DTE/facturas emitidas/[perfil]/[año]/[mes]/
  /// JSON y PDF se guardan juntos en la misma carpeta.
  Future<Directory> _getFacturaDestDir() async {
    final baseDir = Platform.isAndroid
        ? await _findRealDownloadsDir()
        : await getApplicationDocumentsDirectory();

    final profileName = await getCurrentProfileName();
    final now = DateTime.now();
    const meses = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final month = '${now.month.toString().padLeft(2, '0')} ${meses[now.month]}';
    final safeProfile = profileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();

    final destDir = Directory(
      '${baseDir.path}'
      '/Asistente de Facturacion DTE'
      '/Facturas Emitidas'
      '/$safeProfile'
      '/${now.year}'
      '/$month',
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    return destDir;
  }

  // Mantener getFacturasDirectory por compatibilidad con llamadas existentes
  Future<Directory> getFacturasDirectory() async => _getFacturaDestDir();

  /// Genera un nombre de archivo seguro con formato: CLIENTE_DD-MM-YYYY.extension
  String _generateSafeFilename(
    String nombreCliente,
    DateTime fecha,
    String extension,
  ) {
    // Limpiar nombre del cliente: solo letras, números y espacios -> guiones bajos
    final safeName = nombreCliente
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toUpperCase();

    // Formato de fecha: DD-MM-YYYY
    final dateStr =
        '${fecha.day.toString().padLeft(2, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.year}';

    return '${safeName}_$dateStr.$extension';
  }

  /// Guarda un JSON de factura en la carpeta del mes/año/perfil.
  /// El JSON mantiene su nombre original sin modificaciones
  Future<File> saveFacturaJson(String filename, String content) async {
    final dir = await _getFacturaDestDir();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, flush: true);
    return file;
  }

  /// Guarda un PDF de factura en la misma carpeta que el JSON.
  /// Si se proveen clientName y fecha, usa formato: CLIENTE_DD-MM-YYYY.pdf
  Future<File> saveFacturaPdf(
    String filename,
    List<int> bytes, {
    String? clientName,
    DateTime? fecha,
  }) async {
    final dir = await _getFacturaDestDir();

    // Si se provee nombre de cliente y fecha, generar nombre personalizado
    String finalFilename = filename;
    if (clientName != null && fecha != null) {
      finalFilename = _generateSafeFilename(clientName, fecha, 'pdf');
    }

    final file = File('${dir.path}/$finalFilename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Busca los archivos más recientes (JSON y PDF) de un cliente en la carpeta de facturas
  /// Busca recursivamente en todas las subcarpetas del perfil actual
  Future<Map<String, File?>> findClientLatestFiles(String clientName) async {
    try {
      final baseDir = Platform.isAndroid
          ? await _findRealDownloadsDir()
          : await getApplicationDocumentsDirectory();

      final profileName = await getCurrentProfileName();
      final safeProfile = profileName
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();

      final profileDir = Directory(
        '${baseDir.path}'
        '/Asistente de Facturacion DTE'
        '/Facturas Emitidas'
        '/$safeProfile',
      );

      if (!await profileDir.exists()) {
        return {'json': null, 'pdf': null};
      }

      // Buscar recursivamente en todas las subcarpetas
      final files = profileDir.listSync(recursive: true);

      final safeName = clientName
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toUpperCase();

      File? latestJson;
      File? latestPdf;
      DateTime? latestJsonDate;
      DateTime? latestPdfDate;

      // Primera pasada: buscar el PDF del cliente
      for (final item in files) {
        if (item is File) {
          final name = item.path.split('/').last.split('\\').last;
          final stat = item.statSync();
          final modified = stat.modified;

          // Buscar PDFs que empiecen con el nombre del cliente
          if (name.endsWith('.pdf') &&
              name.toUpperCase().startsWith(safeName)) {
            if (latestPdf == null || modified.isAfter(latestPdfDate!)) {
              latestPdf = item;
              latestPdfDate = modified;
              if (kDebugMode) print('✅ PDF encontrado: ${item.path}');
            }
          }
        }
      }

      // Segunda pasada: si encontramos PDF, buscar JSON en la misma carpeta
      if (latestPdf != null) {
        final pdfDir = latestPdf.parent.path;
        if (kDebugMode) print('🔍 Buscando JSON en: $pdfDir');

        for (final item in files) {
          if (item is File && item.parent.path == pdfDir) {
            final name = item.path.split('/').last.split('\\').last;

            if (name.endsWith('.json')) {
              final stat = item.statSync();
              final modified = stat.modified;

              if (latestJson == null || modified.isAfter(latestJsonDate!)) {
                latestJson = item;
                latestJsonDate = modified;
              }
            }
          }
        }
      }

      return {'json': latestJson, 'pdf': latestPdf};
    } catch (e) {
      return {'json': null, 'pdf': null};
    }
  }

  /// Registra una venta generada desde el WebView en el perfil activo
  /// y la sincroniza a Firestore para que aparezca en la webapp y en el historial.
  Future<void> addVenta(Venta venta) async {
    final profiles = await _loadProfilesData();
    final profileName = await getCurrentProfileName();
    final profile = profiles[profileName] ?? Perfil.empty();

    // Evitar duplicados por código de generación o ID
    final existingIndex = profile.ventas.indexWhere(
      (v) =>
          (venta.codigo != null &&
              venta.codigo!.isNotEmpty &&
              v.codigo == venta.codigo) ||
          (venta.id.isNotEmpty && v.id == venta.id),
    );

    if (existingIndex != -1) {
      // Actualizar si ya existe (puede venir con más datos)
      profile.ventas[existingIndex] = venta;
    } else {
      profile.ventas.add(venta);
    }

    profiles[profileName] = profile;
    // _saveProfilesData guarda localmente Y sincroniza a Firestore automáticamente
    await _saveProfilesData(profiles);
    notifyListeners(); // Refresca dashboard e historial en la UI
  }

  /// Establece el modo DEMO localmente (true = demo, false = none).
  Future<void> setDemoMode(bool enabled) async {
    if (enabled) {
      await _saveActivationLocally(ActivationStatus.demo);
    } else {
      await _saveActivationLocally(ActivationStatus.none);
      // No eliminar la clave automáticamente; activar PRO debe hacerse via activateLicense
    }
    notifyListeners();
  }

  /// Cierra sesión: abandona sincronía en tiempo real y borra la licencia local.
  Future<void> signOutUser() async {
    try {
      await _userDataSubscription?.cancel();
    } catch (_) {}
    _userDataSubscription = null;
    _activeRealtimeSyncLicenseKey = null;
    _currentLicenseKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKeyKey);
    await _saveActivationLocally(ActivationStatus.none);

    // Limpiar TODOS los datos del perfil actual al cerrar sesión
    try {
      final profileName = await getCurrentProfileName();
      final profiles = await _loadProfilesData();
      if (profiles.containsKey(profileName)) {
        // Crear perfil vacío (sin clientes, productos ni ventas)
        profiles[profileName] = Perfil(clients: [], products: [], ventas: []);
        await _saveProfilesData(profiles);
      }
    } catch (e) {
      // Error al limpiar datos
    }

    notifyListeners();
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
      distrito: cliente.distrito,
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
