# 📋 Análisis y Plan de Actualización: Web App → App Android/Flutter

**Fecha**: 27 de abril de 2026  
**Estado**: Análisis Completado - Planificación de Ejecución

---

## 📊 PARTE 1: ANÁLISIS COMPARATIVO

### 1.1 Arquitectura General

| Aspecto | Web App (Chrome Extension) | App Android (Flutter) |
|--------|--------------------------|----------------------|
| **Tipo** | Chrome Extension MV3 | Aplicación Flutter Multiplataforma |
| **Entorno** | Navegador/Web | WebView + Native |
| **Almacenamiento** | `chrome.storage.local` | `SharedPreferences` + Firebase |
| **UI Framework** | HTML/CSS/JavaScript vanilla | Flutter (Dart) + Material Design |
| **Versión** | v12.3 | v1.0.0+1 |
| **Base de datos** | Firebase Firestore | Firebase Firestore |

### 1.2 Funcionalidades Identificadas en Web App

#### 🎯 Core Features:
1. **Gestión de Perfiles** (`popup.js`)
   - Crear/editar perfiles de facturación
   - Seleccionar perfil activo
   - Sincronización con Firestore

2. **Gestión de Clientes** (`popup.js`)
   - Listar clientes por perfil
   - Agregar/editar clientes
   - Búsqueda y filtrado

3. **Gestión de Productos** (`inventory_service.js`)
   - Listar productos
   - Control de inventario (stock)
   - Descuento de inventario por venta

4. **Facturación** (`background.js`)
   - Interceptación de ventas en MH
   - Captura de número de control y sello
   - Registro de transacciones
   - Subida a Firestore (usuarios PRO)

5. **Correos** (`mail_service.js`)
   - OAuth2 con Gmail
   - Extracción de facturas DTE (.json)
   - Descarga de archivos adjuntos

6. **Generación de Reportes** (`generadorExcel.js`)
   - Reporte de kardex/inventario
   - Agrupación por producto
   - Cálculo de costo promedio
   - Exportación a Excel

7. **Sistema de Licencias**
   - DEMO (limitado): 2 perfiles, 5 clientes, 2 productos
   - PRO (completo): sin límites
   - Validación en nube (Cloud Functions)

8. **Interceptación de PDF** (`js_injection.dart`)
   - Captura de PDFs generados
   - Conversión a Base64
   - Descarga automática

9. **Tour Guiado** (`tour_runner.js`, `driver.min.js`)
   - Asistencia visual al usuario
   - Reset seguro de datos

### 1.3 Estado de Implementación en Flutter

#### ✅ Implementado:
- ✅ Estructura base con WebView
- ✅ Firebase (Firestore, Cloud Functions)
- ✅ SharedPreferences para almacenamiento local
- ✅ Sistema de licencias (DEMO/PRO)
- ✅ Gestión de perfiles
- ✅ Gestión de clientes
- ✅ Gestión de productos
- ✅ Inyección JS (PDF interceptor, llenar popups)
- ✅ Visualizador de PDFs
- ✅ Menú flotante (home, rutas)
- ✅ Pantalla de correos
- ✅ Sistema de temas (claro/oscuro)

#### ⚠️ Parcialmente Implementado:
- ⚠️ **Sincronización de datos**: Los datos se guardan en SharedPreferences pero no siempre se sincronizaban con Firestore
- ⚠️ **Gestión de vendas/transacciones**: Captura básica pero falta flujo completo
- ⚠️ **Correos**: Pantalla creada pero lógica de descarga parcial

#### ❌ NO Implementado:
- ❌ **Generador de Excel/Kardex**: No existe equivalente en Flutter
- ❌ **Tour guiado**: No hay implementación de tour/onboarding
- ❌ **Descarga de facturas desde Gmail**: Falta integrar mail_service.js
- ❌ **Reset seguro avanzado**: Sistema básico sin doble seguridad
- ❌ **Interceptación de ventas automática**: Falta capturar transacciones en WebView

### 1.4 Diferencias Técnicas Clave

#### Almacenamiento:
```
Web App:          chrome.storage.local → Firestore (sync manual)
Flutter:          SharedPreferences → Firestore (sync manual)
```

#### Permisos:
```
Web App (Chrome):  storage, activeTab, sidePanel, identity, host_permissions
Flutter (Android): INTERNET, READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE
```

#### Validación de Licencia:
```
Web App:          validar en popup.js → Cloud Function
Flutter:          storage_service.dart → Cloud Function (¡Pero falta implementar!)
```

#### Sincronización de Datos:
```
Web App:          subirCambiosANube() en background.js (automático en ciertos eventos)
Flutter:          ❌ FALTA: No hay sincronización automática a Firestore
```

---

## 🔍 HALLAZGOS CRÍTICOS

### Prioridad ALTA:

1. **Falta Sincronización Firestore**
   - Los datos locales NO se sincronizaban automáticamente a la nube
   - Impacto: Datos perdidos si app se desinstala
   - Solución: Implementar sincronización en StorageService

2. **Generador de Excel no existe**
   - Web app tiene `generadorExcel.js` con función `generarKardexExcel()`
   - Flutter: ❌ Necesita librería Excel (excel, csv, etc.)
   - Impacto: Usuarios PRO no pueden generar reportes

3. **Gestión de Facturas/Ventas incompleta**
   - Web app captura ventas automáticamente en background.js
   - Flutter: WebView inyecta JS pero falta procesar respuestas
   - Impacto: Historial de ventas vacío

4. **Lógica de Mail Service no migrada**
   - Web app: mail_service.js con OAuth2 Gmail
   - Flutter: Pantalla correo_screen.dart pero sin lógica
   - Impacto: No se pueden descargar facturas desde Gmail

5. **Tour/Onboarding ausente**
   - Web app: tour_runner.js + driver.min.js
   - Flutter: ❌ Sin implementación
   - Impacto: Experiencia pobre para nuevos usuarios

### Prioridad MEDIA:

6. **Validación de Licencia en nube incompleta**
   - storage_service.dart declara Cloud Function pero lógica pendiente
   - Impacto: Modo PRO puede no validarse correctamente

7. **Interceptación de PDFs limitada**
   - Solo captura PDFs de respuestas XHR
   - Web app captura más casos (clicks, iframes, embeds)
   - Impacto: Algunos PDFs no se descargan

8. **Reset seguro básico**
   - Flutter: Sin confirmaciones dobles ni alertas PRO
   - Web app: Sistema robusto con candados antibucles
   - Impacto: Riesgo de borrado accidental

---

## 🎯 PARTE 2: PLAN DE EJECUCIÓN

### FASE 1: Sincronización de Datos (CRÍTICA)
**Duración estimada: 2-3 horas**

#### Tarea 1.1: Implementar sincronización automática a Firestore
- [ ] Crear método `syncToFirestore()` en StorageService
- [ ] Agregar watchers en cada operación (guardar perfil, cliente, producto, venta)
- [ ] Implementar reintentos en caso de fallo
- [ ] Agregar indicador visual de sincronización

#### Tarea 1.2: Implementar descarga de datos desde Firestore
- [ ] Crear método `loadFromFirestore()` en StorageService
- [ ] Ejecutar al iniciar app si user es PRO
- [ ] Manejar conflictos (local vs. nube)
- [ ] Agregar sincronización en tiempo real (listeners)

**Archivos a modificar:**
- `lib/storage_service.dart`
- `lib/main.dart` (agregar sync en inicialización)

---

### FASE 2: Generador de Excel/Reportes
**Duración estimada: 3-4 horas**

#### Tarea 2.1: Integrar librería Excel
- [ ] Agregar dependencia: `excel` o `syncfusion_flutter_xlsio`
- [ ] Crear archivo `lib/services/excel_service.dart`
- [ ] Portar lógica de `generadorExcel.js`

#### Tarea 2.2: Implementar generación de Kardex
- [ ] Crear método `generarKardexExcel()` en ExcelService
- [ ] Agregar columnas: fecha, doc, ticket, cliente, entradas, salidas, saldos
- [ ] Implementar cálculo de costo promedio
- [ ] Agregar formateo y colores

#### Tarea 2.3: Agregar botón en UI
- [ ] Nuevo botón en `lib/configuracion_screen.dart`
- [ ] Mostrar diálogo de progreso
- [ ] Guardar archivo en descargas
- [ ] Notificar al usuario cuando termine

**Archivos a crear:**
- `lib/services/excel_service.dart`

**Archivos a modificar:**
- `pubspec.yaml` (agregar dependencia)
- `lib/configuracion_screen.dart`

---

### FASE 3: Gestión de Facturas/Ventas
**Duración estimada: 2-3 horas**

#### Tarea 3.1: Capturar ventas interceptadas
- [ ] Mejorar `js_injection.dart` para capturar respuesta de venta
- [ ] Extraer: número de control, sello, monto, cliente
- [ ] Enviar datos a Flutter mediante FlutterChannel

#### Tarea 3.2: Procesar y guardar ventas
- [ ] Crear método `saveSale()` en StorageService
- [ ] Almacenar en perfil actual
- [ ] Registrar movimiento de inventario
- [ ] Sincronizar a Firestore

#### Tarea 3.3: Mostrar historial de ventas
- [ ] Crear nuevo archivo `lib/ventas_screen.dart`
- [ ] Listar ventas del perfil actual
- [ ] Filtros por fecha, cliente, estado
- [ ] Opción para reenviar/descargar PDF

**Archivos a crear:**
- `lib/ventas_screen.dart`

**Archivos a modificar:**
- `lib/js_injection.dart`
- `lib/storage_service.dart`
- `lib/main.dart` (agregar ruta)
- `lib/menu_flotante_widget.dart` (agregar botón)

---

### FASE 4: Integración de Mail Service
**Duración estimada: 2-3 horas**

#### Tarea 4.1: Implementar OAuth2 con Gmail
- [ ] Crear archivo `lib/services/mail_service.dart`
- [ ] Portar lógica de `mail_service.js`
- [ ] Usar plugin: `google_sign_in` + `googleapis`
- [ ] Implementar autorización interactiva

#### Tarea 4.2: Descargar facturas desde Gmail
- [ ] Buscar mensajes con `filename:json`
- [ ] Extraer archivos adjuntos
- [ ] Importar automáticamente como clientes/productos

#### Tarea 4.3: Integrar con correo_screen.dart
- [ ] Botón "Sincronizar con Gmail"
- [ ] Mostrar progreso y resultados
- [ ] Agregar reintentos

**Archivos a crear:**
- `lib/services/mail_service.dart`

**Archivos a modificar:**
- `pubspec.yaml` (agregar google_sign_in, googleapis)
- `lib/correo_screen.dart`

---

### FASE 5: Tour/Onboarding
**Duración estimada: 1-2 horas**

#### Tarea 5.1: Crear flujo de onboarding
- [ ] Crear archivo `lib/onboarding_screen.dart`
- [ ] Primera ejecución → mostrar tour
- [ ] Mostrar pasos clave (crear perfil, agregar cliente, facturar)
- [ ] Usar plugin: `showcaseview` o `tutorial_coach_mark`

#### Tarea 5.2: Reset seguro mejorado
- [ ] Agregar confirmación doble en pantalla de configuración
- [ ] Mostrar advertencia si hay datos PRO
- [ ] Registrar en log (audit trail)

**Archivos a crear:**
- `lib/onboarding_screen.dart`

**Archivos a modificar:**
- `pubspec.yaml` (agregar showcaseview)
- `lib/configuracion_screen.dart`
- `lib/main.dart` (agregar lógica de "primera ejecución")

---

### FASE 6: Mejoras en Interceptación de PDF
**Duración estimada: 1 hora**

#### Tarea 6.1: Ampliar cobertura de captura de PDF
- [ ] Capturar más casos: iframes, embeds, descargas directas
- [ ] Mejorar XHR override en `js_injection.dart`
- [ ] Agregar listeners para eventos de click en botones "Descargar"

**Archivos a modificar:**
- `lib/js_injection.dart`

---

### FASE 7: Testing y QA
**Duración estimada: 2-3 horas**

#### Tarea 7.1: Tests unitarios
- [ ] Tests para StorageService (guardar/cargar)
- [ ] Tests para ExcelService (generación)
- [ ] Tests para sincronización Firestore

#### Tarea 7.2: Tests de integración
- [ ] Flujo completo: crear perfil → agregar cliente → facturar → sincronizar
- [ ] Validar datos en Firestore
- [ ] Generación de reporte Excel

#### Tarea 7.3: Manual testing
- [ ] Probar en device Android real
- [ ] Validar permisos
- [ ] Validar sincronización con red intermitente

**Archivos a crear:**
- `test/storage_service_test.dart`
- `test/excel_service_test.dart`

---

## 📦 DEPENDENCIAS A AGREGAR

```yaml
# pubspec.yaml - Nuevas dependencias

# Excel/Reportes
excel: ^4.0.3
syncfusion_flutter_xlsio: ^25.0.0  # Alternativa

# Mail Service
google_sign_in: ^6.2.1
googleapis: ^12.2.0

# Tour/Onboarding
showcaseview: ^2.0.5
# Alternativa: tutorial_coach_mark: ^1.2.9

# PDF (mejoras)
pdf: ^3.10.7
printing: ^5.11.3

# Sincronización de datos
riverpod: ^2.5.1  # Estado global (alternativa a Provider)

# Logging mejorado
logger: ^2.0.0
```

---

## 🔧 ORDEN DE EJECUCIÓN RECOMENDADO

1. **FASE 1** (Sincronización) - CRÍTICA
   - Sin esto, todo lo demás perderá datos

2. **FASE 3** (Gestión de Ventas) - IMPORTANTE
   - Core del negocio: capturar facturas

3. **FASE 2** (Excel) - IMPORTANTE
   - Reporte crítico para usuarios PRO

4. **FASE 4** (Mail Service) - MEDIA
   - Feature conveniente pero no bloqueante

5. **FASE 5** (Onboarding) - MEDIA
   - UX pero no funcionalidad core

6. **FASE 6** (PDF Mejorado) - BAJA
   - Optimización

7. **FASE 7** (Testing) - CONTINUO
   - Validar cada fase

---

## 📋 CHECKLIST DE VALIDACIÓN FINAL

Antes de considerar completa la actualización:

- [ ] Datos se sincronizan a Firestore automáticamente
- [ ] Reporte Excel se genera correctamente
- [ ] Facturas se capturan y guardan
- [ ] Correos se descargan desde Gmail
- [ ] Tour se muestra en primera ejecución
- [ ] PDF se intercepta y descarga
- [ ] Modo DEMO limita correctamente (2 perfiles, 5 clientes, 2 productos)
- [ ] Modo PRO valida con Cloud Function
- [ ] Tests pasan
- [ ] App funciona offline (sincroniza cuando hay conectividad)
- [ ] Datos no se pierden tras crash o desinstalación (en PRO)
- [ ] UI es intuitiva y responsiva

---

## 📌 NOTAS IMPORTANTES

1. **Versión de Firebase**: Actualizar si es necesario
2. **Cloud Functions**: Revisar que estén actualizadas (`validateLicense`, etc.)
3. **Permisos Android**: Agregar en `AndroidManifest.xml` si es necesario
4. **Testing Device**: Usar device con Android 10+
5. **Documentación**: Actualizar README con nuevas features
6. **Changelog**: Documentar cambios versión a versión

---

**Próximo paso**: Comenzar FASE 1 (Sincronización a Firestore)
