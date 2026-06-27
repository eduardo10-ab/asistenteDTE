// background.js - V13.0: Doble seguridad contra Anulaciones
import { InventoryService } from "./inventory_service.js";
import { initializeApp } from "./firebase-app.js";
// 1. AÑADIDO: Importamos initializeFirestore
import { getFirestore, doc, setDoc, initializeFirestore } from "./firebase-firestore.js";

// Configuración Firebase (Rellena si no usas el archivo externo)
const firebaseConfig = {
    apiKey: "AIzaSyAT9aEjjB01rj3tPaRbUymBjgZZsPof-JY",
    authDomain: "asistente-de-facturacion-dte.firebaseapp.com",
    projectId: "asistente-de-facturacion-dte",
    storageBucket: "asistente-de-facturacion-dte.firebasestorage.app",
    messagingSenderId: "321407998184",
    appId: "1:321407998184:web:1e63d399acc57aba91915d",
    measurementId: "G-J15T0LHQK0"
};

const app = initializeApp(firebaseConfig);

// 2. MODIFICADO: Usamos initializeFirestore para forzar Long Polling y evitar errores de conexión
const db = initializeFirestore(app, {
    experimentalForceLongPolling: true,
});

async function subirCambiosANube(storageData) {
    if (!storageData.licencia || storageData.licencia.startsWith('DEMO')) return;
    try {
        const docRef = doc(db, "datos_usuarios", storageData.licencia);
        const dataToUpload = {
            profiles: storageData.profiles,
            inventoryEnabled: storageData.inventoryEnabled || false,
            last_modified: Date.now()
        };
        await setDoc(docRef, dataToUpload, { merge: true });
    } catch (error) { console.error("❌ Error subiendo a nube:", error); }
}

chrome.runtime.onInstalled.addListener(() => {
    if (chrome.sidePanel && chrome.sidePanel.setPanelBehavior) {
        chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true }).catch(console.error);
        chrome.action.setPopup({ popup: "" });
    }
    chrome.storage.local.remove('pendingInvoiceTransaction');
});

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'START_INVOICE_WATCH') {
        const transactionData = { ...request.data, timestamp: Date.now() };
        chrome.storage.local.set({ 'pendingInvoiceTransaction': transactionData });
    }

    // --- ESTO SOLUCIONA EL ERROR ---
    // Le avisa a Chrome que el mensaje fue recibido correctamente
    sendResponse({ status: "recibido" });
    return true;
});

// --- HELPERS ---
function esUnItemValido(obj) {
    if (!obj || typeof obj !== 'object') return false;
    const keys = Object.keys(obj).join(" ").toLowerCase();
    return (keys.includes('descrip') || keys.includes('nombre')) &&
        (keys.includes('cant') || keys.includes('precio'));
}
function buscarArrayDeItems(obj) {
    if (!obj || typeof obj !== 'object') return null;
    if (Array.isArray(obj)) {
        if (obj.length > 0 && esUnItemValido(obj[0])) return obj;
        return null;
    }
    for (let key in obj) {
        if (obj.hasOwnProperty(key) && typeof obj[key] === 'object') {
            const resultado = buscarArrayDeItems(obj[key]);
            if (resultado) return resultado;
        }
    }
    return null;
}
function buscarValorRecursivo(obj, keyName) {
    if (!obj || typeof obj !== 'object') return null;
    if (obj.hasOwnProperty(keyName) && obj[keyName]) return obj[keyName];
    for (let key in obj) {
        if (obj.hasOwnProperty(key) && typeof obj[key] === 'object') {
            const found = buscarValorRecursivo(obj[key], keyName);
            if (found) return found;
        }
    }
    return null;
}
function obtenerListaItems(datos) {
    if (datos._itemsVisuales && Array.isArray(datos._itemsVisuales) && datos._itemsVisuales.length > 0) return datos._itemsVisuales;
    let listaEncontrada = null;
    if (datos._solicitudOriginal) listaEncontrada = buscarArrayDeItems(datos._solicitudOriginal);
    if (!listaEncontrada && datos._respuesta) listaEncontrada = buscarArrayDeItems(datos._respuesta);
    return listaEncontrada || [];
}

// 3. INTERCEPTOR PRINCIPAL
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'GUARDAR_VENTA_INTERCEPTADA') {
        const datos = request.datos;
        const codigoGen = datos.codigoGeneracion;
        if (!codigoGen) return;

        chrome.storage.local.get(null, (storage) => {
            if (!storage.profiles) storage.profiles = {};
            if (!storage.currentProfile) {
                const keys = Object.keys(storage.profiles);
                storage.currentProfile = keys.length > 0 ? keys[0] : 'Default';
            }
            const perfil = storage.currentProfile;
            if (!storage.profiles[perfil]) storage.profiles[perfil] = { ventas: [], products: [], inventory_history: [], clients: [] };
            if (!storage.profiles[perfil].ventas) storage.profiles[perfil].ventas = [];

            // A. VALIDACIÓN BÁSICA
            let estado = 'PROCESADO';
            let sello = datos.selloRecibido;
            if (!sello || typeof sello !== 'string' || sello.length < 20) { estado = 'NO PROCESADO'; sello = 'No Generado'; }

            // B. DATOS
            let nombreClienteFinal = "Cliente General";
            if (datos._clienteVisual && datos._clienteVisual.length > 2) nombreClienteFinal = datos._clienteVisual;
            else {
                const receptor = buscarValorRecursivo(datos._respuesta || datos._solicitudOriginal, 'receptor');
                if (receptor && receptor.nombre) nombreClienteFinal = receptor.nombre;
            }
            let numeroControl = buscarValorRecursivo(datos._respuesta || datos._solicitudOriginal, 'numeroControl') || '';

            // =================================================================
            // 🎯 EXTRACCIÓN ESTRICTA: SOLO JSON (Sin lectura de pantalla)
            // =================================================================
            let montoTotal = 0;

            if (datos._respuesta) {
                // Estrategia 1: Búsqueda directa en la estructura estándar de Hacienda
                // El campo suele estar en: resumen -> totalPagar
                if (datos._respuesta.resumen && datos._respuesta.resumen.totalPagar !== undefined) {
                    montoTotal = parseFloat(datos._respuesta.resumen.totalPagar);
                }
                // Estrategia 2: Si falla, buscamos 'montoTotalOperacion'
                else if (datos._respuesta.resumen && datos._respuesta.resumen.montoTotalOperacion !== undefined) {
                    montoTotal = parseFloat(datos._respuesta.resumen.montoTotalOperacion);
                }
                // Estrategia 3: Búsqueda recursiva profunda SOLO en el JSON (por si cambia la estructura)
                else {
                    let val = buscarValorRecursivo(datos._respuesta, 'totalPagar');
                    if (!val) val = buscarValorRecursivo(datos._respuesta, 'montoTotalOperacion');

                    if (val !== null && val !== undefined) {
                        montoTotal = parseFloat(val);
                    }
                }
            }

            // Validación final de seguridad numérica
            if (isNaN(montoTotal)) montoTotal = 0;

            console.log(`💰 Monto extraído del JSON: $${montoTotal}`);
            // =================================================================

            // C. ITEMS
            let rawItems = obtenerListaItems(datos);
            let itemsAProcesar = rawItems.map(item => ({
                descripcion: (item.descripcion || item.description || item.nombre || "").trim(),
                cantidad: parseFloat(item.cantidad || item.quantity || 0),
                codigo: (item.codigo || item.noProducto || null),
                precio: parseFloat(item.precioUni || item.uniPrice || 0)
            })).filter(i => i.cantidad > 0);

            if (itemsAProcesar.length === 0 && storage.pendingInvoiceTransaction) {
                const tx = storage.pendingInvoiceTransaction;
                itemsAProcesar.push({ descripcion: tx.product.descripcion, cantidad: tx.quantity || 1, codigo: tx.product.codigo || null });
            }
            if (storage.pendingInvoiceTransaction) delete storage.pendingInvoiceTransaction;

            // D. PROCESAMIENTO
            const tipoDoc = datos._tipoVisual || "Factura";
            const nuevaVenta = {
                fecha: new Date().toLocaleDateString('es-SV'),
                hora: new Date().toLocaleTimeString('es-SV'),
                timestamp: Date.now(),
                codigo: codigoGen,
                numeroControl: numeroControl,
                sello: sello,
                total: montoTotal.toFixed(2),
                cliente: nombreClienteFinal,
                tipo: tipoDoc,
                estado: estado,
                items: itemsAProcesar
            };

            const idx = storage.profiles[perfil].ventas.findIndex(v => v.codigo === codigoGen);
            let esVentaNueva = false;

            if (idx === -1) {
                // Si es nueva y tiene monto > 0, la guardamos
                if (montoTotal > 0) {
                    storage.profiles[perfil].ventas.push(nuevaVenta);
                    if (estado === 'PROCESADO') esVentaNueva = true;
                }
            } else {
                const ventaExistente = storage.profiles[perfil].ventas[idx];

                // --- 🛡️ SEGURIDAD ANTI-SOBRESCITURA POR ANULACIÓN ---
                // Si la venta existente tiene valor (>0) y la nueva viene en 0, 
                // asumimos que es una anulación mal detectada y NO sobrescribimos.
                const montoViejo = parseFloat(ventaExistente.total || 0);

                if (montoViejo > 0 && montoTotal === 0) {
                    console.warn("🛡️ Intento de sobrescribir venta válida con monto 0. Bloqueado.");
                    // No hacemos nada, dejamos la venta original intacta.
                } else {
                    // Flujo normal de actualización
                    if (itemsAProcesar.length === 0 && ventaExistente.items && ventaExistente.items.length > 0) {
                        nuevaVenta.items = ventaExistente.items;
                    }
                    nuevaVenta.estado = (ventaExistente.estado === 'NO PROCESADO' && estado === 'PROCESADO') ? 'PROCESADO' : ventaExistente.estado;
                    if (ventaExistente.estado === 'NO PROCESADO' && estado === 'PROCESADO') esVentaNueva = true;
                    storage.profiles[perfil].ventas[idx] = nuevaVenta;
                }
            }

            storage.last_modified = Date.now();

            chrome.storage.local.set(storage, () => {
                // Solo notificamos si realmente hubo cambios relevantes
                chrome.runtime.sendMessage({ action: 'SALES_UPDATED' });

                const TIPOS_NO_INVENTARIABLES = ["Nota de Crédito", "Nota de Débito", "Retención", "Liquidación", "Sujeto Excluido"];
                const esTipoPeligroso = TIPOS_NO_INVENTARIABLES.some(t => tipoDoc.includes(t));

                if (esVentaNueva && !esTipoPeligroso && itemsAProcesar.length > 0) {
                    const referencia = numeroControl || codigoGen;
                    InventoryService.procesarVentaConfirmada(itemsAProcesar, referencia, nombreClienteFinal);
                }

                subirCambiosANube(storage);
            });
        });
    }
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (tab.url === 'about:blank') chrome.storage.local.remove('pendingInvoiceTransaction');
});