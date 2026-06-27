// options.js - Versión V12.0: Protección "Salvavidas" (Descarga antes de borrar)

import { db, doc, getDoc, getDocFromServer, onSnapshot } from './firebase-config.js';
import { updateDoc, setDoc } from "./firebase-firestore.js";
import { InventoryService } from "./inventory_service.js";
import { generarKardexExcel, generarReporteKardexDetallado, generarReporteVentasExcel } from "./generadorExcel.js";
import { authorizeUser, fetchRecentInvoices, logoutUser, fetchUserEmail } from './mail_service.js';

const G_LOCATION_DATA = {
    "El Salvador": [
        { "code": "01", "name": "Ahuachapán", "municipalities": [{ "code": "13", "name": "AHUACHAPAN NORTE" }, { "code": "14", "name": "AHUACHAPAN CENTRO" }, { "code": "15", "name": "AHUACHAPAN SUR" }] },
        { "code": "02", "name": "Santa Ana", "municipalities": [{ "code": "14", "name": "SANTA ANA NORTE" }, { "code": "15", "name": "SANTA ANA CENTRO" }, { "code": "16", "name": "SANTA ANA ESTE" }, { "code": "17", "name": "SANTA ANA OESTE" }] },
        { "code": "03", "name": "Sonsonate", "municipalities": [{ "code": "17", "name": "SONSONATE NORTE" }, { "code": "18", "name": "SONSONATE CENTRO" }, { "code": "19", "name": "SONSONATE ESTE" }, { "code": "20", "name": "SONSONATE OESTE" }] },
        { "code": "04", "name": "Chalatenango", "municipalities": [{ "code": "34", "name": "CHALATENANGO NORTE" }, { "code": "35", "name": "CHALATENANGO CENTRO" }, { "code": "36", "name": "CHALATENANGO SUR" }] },
        { "code": "05", "name": "La Libertad", "municipalities": [{ "code": "23", "name": "LA LIBERTAD NORTE" }, { "code": "24", "name": "LA LIBERTAD CENTRO" }, { "code": "25", "name": "LA LIBERTAD OESTE" }, { "code": "26", "name": "LA LIBERTAD ESTE" }, { "code": "27", "name": "LA LIBERTAD COSTA" }, { "code": "28", "name": "LA LIBERTAD SUR" }] },
        { "code": "06", "name": "San Salvador", "municipalities": [{ "code": "20", "name": "SAN SALVADOR NORTE" }, { "code": "21", "name": "SAN SALVADOR OESTE" }, { "code": "22", "name": "SAN SALVADOR ESTE" }, { "code": "23", "name": "SAN SALVADOR CENTRO" }, { "code": "24", "name": "SAN SALVADOR SUR" }] },
        { "code": "07", "name": "Cuscatlán", "municipalities": [{ "code": "17", "name": "CUSCATLAN NORTE" }, { "code": "18", "name": "CUSCATLAN SUR" }] },
        { "code": "08", "name": "La Paz", "municipalities": [{ "code": "23", "name": "LA PAZ OESTE" }, { "code": "24", "name": "LA PAZ CENTRO" }, { "code": "25", "name": "LA PAZ ESTE" }] },
        { "code": "09", "name": "Cabañas", "municipalities": [{ "code": "10", "name": "CABAÑAS OESTE" }, { "code": "11", "name": "CABAÑAS ESTE" }] },
        { "code": "10", "name": "San Vicente", "municipalities": [{ "code": "14", "name": "SAN VICENTE NORTE" }, { "code": "15", "name": "SAN VICENTE SUR" }] },
        { "code": "11", "name": "Usulután", "municipalities": [{ "code": "24", "name": "USULUTAN NORTE" }, { "code": "25", "name": "USULUTAN ESTE" }, { "code": "26", "name": "USULUTAN OESTE" }] },
        { "code": "12", "name": "San Miguel", "municipalities": [{ "code": "21", "name": "SAN MIGUEL NORTE" }, { "code": "22", "name": "SAN MIGUEL CENTRO" }, { "code": "23", "name": "SAN MIGUEL OESTE" }] },
        { "code": "13", "name": "Morazán", "municipalities": [{ "code": "27", "name": "MORAZAN NORTE" }, { "code": "28", "name": "MORAZAN SUR" }] },
        { "code": "14", "name": "La Unión", "municipalities": [{ "code": "19", "name": "LA UNION NORTE" }, { "code": "20", "name": "LA UNION SUR" }] }
    ]
};

document.addEventListener('DOMContentLoaded', () => {
    console.log("--> CARGANDO V12.0 (Protección Salvavidas) <--");

    // =========================================================
    // 📢 SISTEMA DE NOTIFICACIONES DE NUEVA VERSIÓN
    // =========================================================
    const CURRENT_VERSION = "12.3";

    chrome.storage.local.get('lastSeenVersion', (data) => {
        if (data.lastSeenVersion !== CURRENT_VERSION) {
            const novedades = `
🎉 ¡ACTUALIZACIÓN AUTOMÁTICA: V${CURRENT_VERSION}!

🚀 Novedades de la Versión 12.3

🛒 Nueva Pestaña de Compras (Beta):
📥 Recepción Automática: Ahora la extensión sincroniza y lee tus facturas DTE (archivos .json) directamente desde tu cuenta de Gmail.
📊 Historial Organizado: Clasifica automáticamente tus compras por proveedor, te permite filtrar por fechas y muestra claramente el Código de Generación.
🔑 Integración Sencilla: Agregamos instrucciones paso a paso muy fáciles de seguir para vincular tu cuenta de Google.

✨ Mayor Rendimiento y Seguridad:
🛡️ Protección Avanzada: Tus documentos confidenciales están más seguros que nunca gracias a nuestro nuevo blindaje interno.
♾️ Espacio Ilimitado: Activamos la memoria ilimitada. ¡Ahora podrás guardar años enteros de historial de facturas sin preocuparte por el espacio de tu navegador!
🛑 Privacidad Reforzada: Aseguramos la conexión para que exclusivamente Ministerio de Hacienda hable con la extensión.

⚡ Correcciones Visuales:
👁️ Interfaz más limpia: Mejoramos el diseño del "Historial de Facturación" corrigiendo aquellos cuadritos que a veces se veían mal alineados.

¡Disfruta de la experiencia más segura y rápida de Asistente de Facturación DTE!
`;
            setTimeout(() => {
                alert(novedades);
                chrome.storage.local.set({ lastSeenVersion: CURRENT_VERSION });
            }, 500);
        }
    });

    const PUBLIC_DEMO_KEYS = ["DEMO-2025", "DEMO-INV-2025"];

    function getInstallationId() {
        return new Promise(resolve => {
            chrome.storage.local.get('installationId', (r) => {
                if (r.installationId) { resolve(r.installationId); }
                else {
                    const newId = 'EQ-' + Math.random().toString(36).substr(2, 9).toUpperCase();
                    chrome.storage.local.set({ installationId: newId }, () => resolve(newId));
                }
            });
        });
    }

    async function enviarLatido(licenciaKey) {
        try {
            const thisDeviceId = await getInstallationId();
            const docRef = doc(db, "licencias", licenciaKey);
            const now = new Date();
            const updatePayload = { ultima_conexion: now.toLocaleString(), version_ext: "12.3" };
            updatePayload[`equipos.${thisDeviceId}`] = { ultimo_acceso: now.toLocaleString(), timestamp: Date.now(), version: "12.3" };
            await updateDoc(docRef, updatePayload);
        } catch (e) {
            if (e.code === 'not-found') console.warn("Licencia no encontrada en BD.");
            else console.error("Error latido:", e);
        }
    }

    // =========================================================
    // 🔥 GESTOR CENTRALIZADO DE RESETEOS (RESPALDO + BORRADO) 🔥
    // =========================================================
    window.isResetting = false;

    function ejecutarResetSeguro(mensajeAlerta, tipoBorrado = 'SOLO_DATOS', payload = null) {
        if (window.isResetting) return;
        window.isResetting = true;
        console.warn("Iniciando secuencia de Reset Seguro...");

        chrome.storage.local.get(null, async (localData) => {
            const perfilesActuales = localData.profiles || {};
            const tieneDatos = tieneDatosReales(perfilesActuales);
            const licenciaActual = localData.licencia;

            if (!tieneDatos) {
                console.log("No hay datos para respaldar. Procediendo al borrado directo.");
                finalizarReset(licenciaActual, mensajeAlerta, tipoBorrado, payload);
                return;
            }

            try {
                const fecha = new Date().toISOString().slice(0, 10);
                const backupData = {
                    profiles: perfilesActuales,
                    mensaje: "Respaldo automático de emergencia."
                };

                const blob = new Blob([JSON.stringify(backupData, null, 2)], { type: "application/json" });
                const url = URL.createObjectURL(blob);

                chrome.downloads.download({
                    url: url,
                    filename: `RESPALDO_SEGURIDAD_${fecha}.json`,
                    saveAs: false
                }, (downloadId) => {
                    if (chrome.runtime.lastError) {
                        console.error("Error descarga:", chrome.runtime.lastError);
                        alert("⚠️ Tu administrador solicitó un reseteo.\nNecesitamos permiso para descargar tu copia de seguridad. Haz clic en 'Aceptar'.");
                        const a = document.createElement('a');
                        a.href = url;
                        a.download = `RESPALDO_SEGURIDAD_${fecha}.json`;
                        a.click();
                    }

                    setTimeout(() => {
                        URL.revokeObjectURL(url);
                        finalizarReset(licenciaActual, mensajeAlerta, tipoBorrado, payload);
                    }, 3000);
                });

            } catch (err) {
                console.error("Error crítico durante respaldo:", err);
                window.isResetting = false;
            }
        });
    }

    async function finalizarReset(licencia, mensajeAlerta, tipoBorrado, payload) {
        const resetData = {
            profiles: { 'Mi Perfil': { clients: [], products: [], ventas: [], logs: [] } },
            currentProfile: 'Mi Perfil',
            inventoryEnabled: false,
            last_modified: Date.now(),
            hasSyncedOnce: true
        };

        if (tipoBorrado === 'SOLO_DATOS') {
            if (licencia && typeof db !== 'undefined') {
                try { await setDoc(doc(db, "datos_usuarios", licencia), resetData); } catch (e) { }
            }
            alert(mensajeAlerta);
            chrome.storage.local.set(resetData, () => location.reload());
        }
        else if (tipoBorrado === 'COMPLETO') {
            alert(mensajeAlerta);
            chrome.storage.local.clear(() => location.reload());
        }
        else if (tipoBorrado === 'CAMBIO_CLAVE') {
            alert(mensajeAlerta);
            chrome.storage.local.clear(() => {
                chrome.storage.local.set({ licencia: payload, activationStatus: "PENDING" }, () => location.reload());
            });
        }
    }

    // --- 0. SEGURIDAD INICIAL ---
    chrome.storage.local.get(['licencia', 'activationStatus'], async (r) => {
        if (r.activationStatus && r.licencia) {
            try {
                await enviarLatido(r.licencia);
                const docRef = doc(db, "licencias", r.licencia);
                const docSnap = await getDoc(docRef);
                if (docSnap.exists()) {
                    const data = docSnap.data();
                    if (data.estado !== "ACTIVO" && data.estado !== "SUSPENDIDO" && data.estado !== "RESTRINGIDA" && data.estado !== "pausada") {
                        ejecutarResetSeguro("⛔ TU LICENCIA HA SIDO DESACTIVADA REMOTAMENTE.\n\n🛡️ HEMOS DESCARGADO UNA COPIA DE TUS DATOS en tu PC.\n\nLa extensión se reiniciará ahora.", 'COMPLETO');
                        return;
                    }
                    if (data.plan && data.plan !== r.activationStatus) {
                        alert(`🔄 PLAN ACTUALIZADO A: ${data.plan}`);
                        chrome.storage.local.set({ activationStatus: data.plan }, () => location.reload());
                    }
                }
            } catch (e) { console.log("Offline check."); }
        }
    });

    chrome.runtime.sendMessage({ action: 'CLOSE_SIDEPANEL' }, () => { let ignorar = chrome.runtime.lastError; });

    // =========================================================
    // UTILIDADES
    // =========================================================

    const escapeHTML = (str) => {
        if (!str) return "";
        return String(str).replace(/[&<>'"]/g, 
            tag => ({
                '&': '&amp;',
                '<': '&lt;',
                '>': '&gt;',
                "'": '&#39;',
                '"': '&quot;'
            }[tag]));
    };

    const getStartOfDay = (d) => { const date = new Date(d); date.setHours(0, 0, 0, 0); return date; };
    const getEndOfDay = (d) => { const date = new Date(d); date.setHours(23, 59, 59, 999); return date; };

    const isSameDay = (d1, d2) => {
        return d1.getFullYear() === d2.getFullYear() &&
            d1.getMonth() === d2.getMonth() &&
            d1.getDate() === d2.getDate();
    };

    const isSameMonth = (d1, d2) => {
        return d1.getFullYear() === d2.getFullYear() &&
            d1.getMonth() === d2.getMonth();
    };

    const isInCurrentWeek = (d, now) => {
        const date = getStartOfDay(d);
        const today = getStartOfDay(now);
        const dayOfWeek = today.getDay() || 7;
        const monday = new Date(today);
        monday.setDate(today.getDate() - (dayOfWeek - 1));
        const nextMonday = new Date(monday);
        nextMonday.setDate(monday.getDate() + 7);
        return date >= monday && date < nextMonday;
    };

    const isDateInRange = (dateToCheck, startDateStr, endDateStr) => {
        if (!startDateStr || !endDateStr) return true;
        const d = getStartOfDay(dateToCheck);
        const start = getStartOfDay(startDateStr);
        const end = getEndOfDay(endDateStr);
        return d >= start && d <= end;
    };

    function tieneDatosReales(profiles) {
        if (!profiles) return false;
        for (const key in profiles) {
            const p = profiles[key];
            if ((p.ventas && p.ventas.length > 0) ||
                (p.clients && p.clients.length > 0) ||
                (p.products && p.products.length > 0)) {
                return true;
            }
        }
        return false;
    }

    const getEl = (id) => document.getElementById(id);
    const UI = {
        license: { section: getEl('licenseSection'), input: getEl('licenseKeyInput'), btn: getEl('activateBtn'), error: getEl('licenseError') },
        main: getEl('mainContent'),
        tabs: document.querySelectorAll('.tab-button'),
        demoMsg: getEl('demo-limit-message'),
        upgradeBtn: getEl('upgradeToProBtn'),
        inventoryToggle: getEl('inventoryToggle'),
        inventoryToggleContainer: getEl('inventoryToggleContainer'),
        stockContainer: getEl('stockInputContainer'),
        tabInventarioBtn: getEl('tabInventarioBtn'),
        inventoryBody: getEl('inventoryTableBody'),
        inventoryLogTableBody: getEl('inventoryLogTableBody'),

        btnReporte: getEl('btnReporte'),
        btnReporteKardex: getEl('btnReporteKardex'),
        reportPeriod: getEl('reportPeriod'),
        invDateRange: getEl('invDateRange'),
        invStartDate: getEl('invStartDate'),
        invEndDate: getEl('invEndDate'),

        btnReporteVentas: getEl('btnReporteVentas'),
        salesReportPeriod: getEl('salesReportPeriod'),
        histDateRange: getEl('histDateRange'),
        histStartDate: getEl('histStartDate'),
        histEndDate: getEl('histEndDate'),
        searchHistoryInput: getEl('searchHistoryInput'),
        historyTotalSum: getEl('historyTotalSum'),
        historyTableBody: getEl('historyTableBody'),

        profileSelector: getEl('profileSelector'),
        addProfileBtn: getEl('addProfileBtn'),
        cancelAddProfileBtn: getEl('cancelAddProfileBtn'),
        newProfileGroup: getEl('newProfileInputGroup'),
        newProfileName: getEl('newProfileName'),
        renameProfileBtn: getEl('renameProfileBtn'),
        deleteProfileBtn: getEl('deleteProfileBtn'),
        exportBtn: getEl('exportDataBtn'),
        importBtn: getEl('importDataBtn'),
        importFile: getEl('importFileInput'),
        client: {
            formTitle: getEl('clienteFormTitle'), id: getEl('clientId'), container: getEl('client-management-container'),
            toggleBtn: getEl('toggleClientFormBtn'), saveBtn: getEl('saveCliente'), cancelBtn: getEl('cancelCliente'), list: getEl('clientList'),
            inputs: {
                nombre: getEl('nombreCliente'), nit: getEl('nit'), nrc: getEl('nrc'), dui: getEl('dui'), pasaporte: getEl('pasaporte'),
                carnet: getEl('carnetResidente'), otro: getEl('otroDocumento'), comercial: getEl('nombreComercial'), actividad: getEl('actividadEconomicaInput'),
                depto: getEl('departamentoInput'), muni: getEl('municipioInput'), direccion: getEl('direccion'), email: getEl('email'),
                telefono: getEl('telefono'), tipoPersona: getEl('tipoPersona'), pais: getEl('paisInput')
            },
            datalists: { deptos: getEl('departamentosList'), munis: getEl('municipiosList') }
        },
        product: {
            formTitle: getEl('productoFormTitle'),
            id: getEl('productoId'),
            saveBtn: getEl('saveProducto'),
            cancelBtn: getEl('cancelProducto'),
            list: getEl('productList'),
            inputs: {
                codigo: getEl('codigoProducto'),
                tipo: getEl('tipo'),
                unidad: getEl('unidadMedida'),
                desc: getEl('descripcion'),
                precio: getEl('precio'),
                stock: getEl('stock')
            }
        }
    };

    if (UI.reportPeriod) {
        UI.reportPeriod.addEventListener('change', () => {
            if (UI.reportPeriod.value === 'custom') UI.invDateRange.classList.add('active');
            else UI.invDateRange.classList.remove('active');
        });
    }

    if (UI.salesReportPeriod) {
        UI.salesReportPeriod.addEventListener('change', () => {
            if (UI.salesReportPeriod.value === 'custom') UI.histDateRange.classList.add('active');
            else UI.histDateRange.classList.remove('active');
        });
    }

    function getCleanType(rawType) {
        if (!rawType) return "Factura";
        const t = rawType.toUpperCase().trim();

        // 1. Reforzado: Créditos Fiscales (CCF, 03, DTE 03, Comprobante de Crédito Fiscal, etc.)
        if (t.includes("CRÉDITO FISCAL") || t.includes("CREDITO FISCAL") || t.includes("CCF") || t.includes("03") || t === "DTE 03") return "Crédito Fiscal";

        // 2. Otros tipos
        if (t.includes("EXPORTACIÓN") || t.includes("EXPORTACION") || t.includes("11")) return "Exportación";
        if (t.includes("SUJETO EXCLUIDO") || t.includes("14")) return "Sujeto Excluido";
        if (t.includes("NOTA DE REMISIÓN") || t.includes("NOTA DE REMISION") || t.includes("15")) return "Nota de Remisión";
        if (t.includes("NOTA DE CRÉDITO") || t.includes("NOTA DE CREDITO") || t.includes("05")) return "Nota de Crédito";
        if (t.includes("NOTA DE DÉBITO") || t.includes("NOTA DE DEBITO") || t.includes("06")) return "Nota de Débito";

        // 3. Facturas Normales
        if (t.includes("FACTURA") || t.includes("01") || t === "DTE 01") return "Factura";

        return "Factura";
    }

    function getTypeStyle(cleanType) {
        switch (cleanType) {
            case "Crédito Fiscal": return "background-color: #007bff; color: white;";
            case "Factura": return "background-color: #28a745; color: white;";
            case "Exportación": return "background-color: #17a2b8; color: white;";
            case "Sujeto Excluido": return "background-color: #6f42c1; color: white;";
            default: return "background-color: #343a40; color: white;";
        }
    }

    // --- INICIALIZACIÓN ---
    chrome.storage.local.get('activationStatus', (r) => {
        const status = r.activationStatus;
        if (['PRO', 'PRO_INV', 'DEMO', 'DEMO_INV'].includes(status)) {
            if (UI.license.section) UI.license.section.style.display = 'none';
            if (UI.main) UI.main.style.display = 'block';
            initializeExtension(status);
        } else {
            if (UI.license.section) UI.license.section.style.display = 'block';
            if (UI.main) UI.main.style.display = 'none';
        }
    });

    // --- ACTIVACIÓN ---
    const btnEstandar = document.getElementById('btnUsarDemoEstandar');
    const btnInv = document.getElementById('btnUsarDemoInv');

    if (btnEstandar) btnEstandar.addEventListener('click', () => { if(UI.license.input) UI.license.input.value = "DEMO-2025"; if(UI.license.btn) UI.license.btn.click(); });
    if (btnInv) btnInv.addEventListener('click', () => { if(UI.license.input) UI.license.input.value = "DEMO-INV-2025"; if(UI.license.btn) UI.license.btn.click(); });

    if (UI.license.btn) {
        UI.license.btn.addEventListener('click', async () => {
            const rawKey = UI.license.input.value.trim();
            const btnOriginalText = UI.license.btn.textContent;
            UI.license.btn.textContent = "Validando...";
            UI.license.btn.disabled = true;
            if (UI.license.error) UI.license.error.style.display = 'none';

            if (PUBLIC_DEMO_KEYS.includes(rawKey)) {
                const plan = rawKey.includes("INV") ? "DEMO_INV" : "DEMO";
                await enviarLatido(rawKey);
                chrome.storage.local.set({
                    activationStatus: plan, licenciaValida: true, licencia: rawKey, nombreUsuario: "Usuario Demo",
                    profiles: { 'Mi Perfil Demo': { clients: [], products: [], ventas: [], logs: [] } },
                    currentProfile: 'Mi Perfil Demo',
                    inventoryEnabled: (plan === 'DEMO_INV'),
                    hasSyncedOnce: true
                }, () => {
                    alert(`✅ MODO DEMO PÚBLICA ACTIVADO.`); location.reload();
                });
                return;
            }

            try {
                const docRef = doc(db, "licencias", rawKey);
                const docSnap = await getDoc(docRef);

                if (docSnap.exists()) {
                    const data = docSnap.data();

                    if (data.estado === "ACTIVO" || data.estado === "SUSPENDIDO") {
                        const newStatus = data.plan || "PRO";
                        await enviarLatido(rawKey);
                        UI.license.btn.textContent = "Buscando respaldo...";

                        let datosAGuardar = {
                            activationStatus: newStatus, licenciaValida: true, licencia: rawKey, nombreUsuario: data.usuario || "Usuario",
                            profiles: { 'Mi Perfil': { clients: [], products: [], ventas: [], logs: [] } },
                            currentProfile: 'Mi Perfil',
                            inventoryEnabled: (newStatus === 'PRO_INV' || newStatus === 'DEMO_INV'),
                            last_modified: Date.now(),
                            hasSyncedOnce: true
                        };

                        const isDemoKey = newStatus.includes("DEMO");
                        if (!isDemoKey) {
                            try {
                                const backupDoc = await getDoc(doc(db, "datos_usuarios", rawKey));
                                if (backupDoc.exists()) {
                                    const b = backupDoc.data();
                                    if (b.profiles) {
                                        datosAGuardar.profiles = b.profiles;
                                        datosAGuardar.currentProfile = b.currentProfile || Object.keys(b.profiles)[0];
                                        datosAGuardar.inventoryEnabled = b.inventoryEnabled !== false;
                                        datosAGuardar.last_modified = b.last_modified || Date.now();
                                    }
                                }
                            } catch (e) { console.error("Error nube:", e); }
                        }
                        chrome.storage.local.set(datosAGuardar, () => {
                            alert(`¡Bienvenido ${data.usuario || ""}!\nDatos cargados correctamente.`);
                            location.reload();
                        });
                        return;
                    }
                    else { alert("❌ Licencia INACTIVA."); }
                } else { alert("❌ Licencia no encontrada."); }
            } catch (error) { console.error(error); alert("Error de conexión."); }
            finally { UI.license.btn.textContent = btnOriginalText; UI.license.btn.disabled = false; }
        });
    }

    function initializeExtension(activationStatus) {
        const isDemo = (activationStatus === 'DEMO' || activationStatus === 'DEMO_INV');
        if (isDemo && UI.demoMsg) UI.demoMsg.style.display = 'flex';
        const isInventoryAllowed = (activationStatus === 'PRO_INV' || activationStatus === 'DEMO_INV');

        if (!isInventoryAllowed) {
            if (UI.tabInventarioBtn) UI.tabInventarioBtn.style.display = 'none';
            if (UI.inventoryToggleContainer) UI.inventoryToggleContainer.style.display = 'none';
            chrome.storage.local.set({ inventoryEnabled: false });
        } else {
            if (UI.tabInventarioBtn) UI.tabInventarioBtn.style.display = 'block';
            if (UI.inventoryToggleContainer) UI.inventoryToggleContainer.style.display = 'flex';
        }

        // --- CARGA DE LISTAS ---
        function populateDepartamentos() {
            const list = UI.client.datalists.deptos;
            if (!list) return;
            list.innerHTML = '';
            G_LOCATION_DATA["El Salvador"].forEach(depto => {
                const option = document.createElement('option');
                option.value = `${depto.code} - ${depto.name}`;
                list.appendChild(option);
            });
        }

        function updateMunicipios() {
            const deptoIn = UI.client.inputs.depto;
            const muniIn = UI.client.inputs.muni;
            const list = UI.client.datalists.munis;
            if (!deptoIn || !muniIn || !list) return;
            const val = deptoIn.value;
            if (!val) { muniIn.disabled = true; muniIn.value = ''; list.innerHTML = ''; return; }

            const name = val.includes(' - ') ? val.split(' - ')[1] : val;
            const data = G_LOCATION_DATA["El Salvador"].find(d => d.name === name);

            list.innerHTML = '';
            if (data && data.municipalities) {
                data.municipalities.forEach(m => {
                    const opt = document.createElement('option');
                    opt.value = `${m.code} - ${m.name}`;
                    list.appendChild(opt);
                });
                muniIn.disabled = false;
            } else {
                muniIn.disabled = true;
            }
        }

        if (UI.client.inputs.depto) {
            UI.client.inputs.depto.addEventListener('input', updateMunicipios);
            UI.client.inputs.depto.addEventListener('change', updateMunicipios);
        }
        if (UI.client.inputs.muni) UI.client.inputs.muni.disabled = true;

        populateDepartamentos();

        const actList = document.getElementById('actividadesList');
        if (actList) {
            const fallbackActivities = ["4711 - Venta al por menor en comercios no especializados", "5610 - Actividades de restaurantes"];
            const url = chrome.runtime.getURL('actividades.html');
            fetch(url).then(r => r.ok ? r.text() : null).then(html => {
                if (html) actList.innerHTML = html;
                else actList.innerHTML = fallbackActivities.map(a => `<option value="${a}">`).join('');
            }).catch(() => actList.innerHTML = fallbackActivities.map(a => `<option value="${a}">`).join(''));
        }

        const paisList = document.getElementById('paisesList');
        if (paisList) fetch('paises.html').then(r => r.text()).then(h => paisList.innerHTML = h).catch(console.error);

        function stripSoftDeletedProfiles(rawProfiles) {
            const cleanedProfiles = {};
            const sourceProfiles = rawProfiles || {};

            Object.keys(sourceProfiles).forEach((profileName) => {
                const profile = sourceProfiles[profileName] || {};
                cleanedProfiles[profileName] = {
                    ...profile,
                    clients: (profile.clients || []).filter(c => !c?.deletedAt),
                    products: (profile.products || []).filter(p => !p?.deletedAt),
                };
            });

            return cleanedProfiles;
        }

        async function refreshFromFirestore() {
            return new Promise((resolve) => {
                chrome.storage.local.get('licencia', async (d) => {
                    const licenciaKey = d.licencia;
                    if (!licenciaKey || licenciaKey.startsWith('DEMO')) {
                        console.log('⏭️ refreshFromFirestore omitido para licencia DEMO o vacía');
                        resolve(false);
                        return;
                    }

                    try {
                        const snap = await getDocFromServer(doc(db, 'datos_usuarios', licenciaKey));
                        if (!snap.exists()) {
                            console.log('ℹ️ refreshFromFirestore: el documento remoto no existe');
                            resolve(false);
                            return;
                        }

                        const nubeData = snap.data() || {};
                        const cleanedCloudProfiles = stripSoftDeletedProfiles(nubeData.profiles || {});
                        const rawCloudProfilesJson = JSON.stringify(nubeData.profiles || {});
                        const cleanedCloudProfilesJson = JSON.stringify(cleanedCloudProfiles || {});

                        if (rawCloudProfilesJson !== cleanedCloudProfilesJson) {
                            console.log('🧹 Firestore remoto contenía perfiles soft-deleted; normalizando antes de guardar');
                            await setDoc(doc(db, 'datos_usuarios', licenciaKey), {
                                profiles: cleanedCloudProfiles,
                                last_modified: Date.now(),
                            }, { merge: true });
                        }

                        chrome.storage.local.get(['profiles', 'last_modified'], (localData) => {
                            const localProfilesJson = JSON.stringify(localData.profiles || {});
                            const cloudProfilesJson = cleanedCloudProfilesJson;

                            if (cloudProfilesJson !== localProfilesJson) {
                                console.log('🔄 refreshFromFirestore detectó cambios y actualizó chrome.storage.local');
                                chrome.storage.local.set({
                                    profiles: cleanedCloudProfiles,
                                    inventoryEnabled: nubeData.inventoryEnabled,
                                    last_modified: nubeData.last_modified || Date.now(),
                                }, () => resolve(true));
                                return;
                            }

                            console.log('✅ refreshFromFirestore no encontró diferencias locales');
                            resolve(false);
                        });
                    } catch (error) {
                        console.warn('⚠️ Error refrescando datos desde Firestore:', error);
                        resolve(false);
                    }
                });
            });
        }

        async function commitProfilesMutation(mutator) {
            const licenciaKey = await new Promise((resolve) => {
                chrome.storage.local.get('licencia', (data) => resolve(data.licencia));
            });

            if (!licenciaKey || licenciaKey.startsWith('DEMO')) {
                return false;
            }

            const docRef = doc(db, 'datos_usuarios', licenciaKey);
            const snap = await getDocFromServer(docRef);
            const cloudData = snap.exists() ? (snap.data() || {}) : {};
            const currentProfileName =
                (await new Promise((resolve) => {
                    chrome.storage.local.get('currentProfile', (data) => resolve(data.currentProfile));
                })) || cloudData.currentProfile || 'Mi Perfil';

            const profiles = stripSoftDeletedProfiles(cloudData.profiles || {});
            const nextProfiles = mutator(profiles, currentProfileName, cloudData) || profiles;
            const payload = {
                ...cloudData,
                profiles: nextProfiles,
                currentProfile: currentProfileName,
                last_modified: Date.now(),
            };

            await setDoc(docRef, payload, { merge: true });

            await new Promise((resolve) => {
                chrome.storage.local.set(
                    {
                        profiles: nextProfiles,
                        currentProfile: currentProfileName,
                        inventoryEnabled: payload.inventoryEnabled !== false,
                        last_modified: payload.last_modified,
                    },
                    resolve,
                );
            });

            return true;
        }

        async function loadData() {
            await refreshFromFirestore();
            chrome.storage.local.get(null, (d) => {
                if (!d.profiles) { d = { profiles: { 'Mi Perfil': { clients: [], products: [], ventas: [] } }, currentProfile: 'Mi Perfil' }; chrome.storage.local.set(d); }
                const currentP = d.profiles[d.currentProfile] || { clients: [], products: [], ventas: [] };

                if (isInventoryAllowed) {
                    const invEnabled = currentP.inventoryEnabled !== false;
                    if (UI.inventoryToggle) UI.inventoryToggle.checked = invEnabled;
                    toggleInventoryUI(invEnabled);
                } else { toggleInventoryUI(false); }

                if (UI.profileSelector) {
                    UI.profileSelector.innerHTML = '';
                    Object.keys(d.profiles).forEach(p => {
                        const opt = document.createElement('option'); opt.value = p; opt.textContent = p; UI.profileSelector.appendChild(opt);
                    });
                    UI.profileSelector.value = d.currentProfile;
                }

                let pData = d.profiles[d.currentProfile];
                if (!pData) {
                    console.warn("Perfil corrupto, reseteando...");
                    const first = Object.keys(d.profiles)[0];
                    d.currentProfile = first;
                    pData = d.profiles[first];
                    chrome.storage.local.set({ currentProfile: first });
                }

                renderClients(pData.clients);
                renderProducts(pData.products);

                if (isInventoryAllowed && currentP.inventoryEnabled !== false) {
                    renderInventory(pData.products);
                    renderInventoryLog(pData.inventory_history);
                }
                else if (UI.inventoryBody) {
                    UI.inventoryBody.innerHTML = '<tr><td colspan="4" style="text-align:center; color: #888;">Control de inventario desactivado.</td></tr>';
                }
                renderHistoryTable(pData.ventas);
            });
        }

        if (UI.salesReportPeriod) UI.salesReportPeriod.addEventListener('change', loadData);
        if (UI.histStartDate) UI.histStartDate.addEventListener('change', loadData);
        if (UI.histEndDate) UI.histEndDate.addEventListener('change', loadData);
        if (UI.searchHistoryInput) UI.searchHistoryInput.addEventListener('input', loadData);

        function toggleInventoryUI(isEnabled) {
            const effectiveEnabled = isInventoryAllowed ? isEnabled : false;

            if (UI.stockContainer) UI.stockContainer.style.display = effectiveEnabled ? 'block' : 'none';

            const mainTabsContainer = document.querySelector('.tabs-container');
            if (mainTabsContainer) {
                if (effectiveEnabled) mainTabsContainer.classList.remove('inventory-disabled');
                else mainTabsContainer.classList.add('inventory-disabled');
            }

            const invTabLi = document.getElementById('tab-inventory-li') || document.querySelector('.tabs-container ul li:nth-child(4)');
            if (invTabLi) invTabLi.style.display = effectiveEnabled ? 'block' : 'none';

            const invTabInput = document.getElementById('tab3');
            if (!effectiveEnabled && invTabInput && invTabInput.checked) {
                const clientTab = document.getElementById('tab1');
                if (clientTab) clientTab.checked = true;
            }
        }

        function renderClients(list) {
            if (!UI.client.list) return;
            UI.client.list.innerHTML = '';
            (list || [])
                .filter(c => !c.deletedAt)
                .sort((a, b) => a.nombreCliente.localeCompare(b.nombreCliente))
                .forEach(c => {
                const li = document.createElement('li');
                li.innerHTML = `
                    <div style="flex-grow: 1; text-align: left;">
                        <span style="font-weight: 500;">${escapeHTML(c.nombreCliente)}</span>
                        <span style="color: #A0A0B0; margin-left: 5px;">${escapeHTML(c.nit) ? '- ' + escapeHTML(c.nit) : ''}</span>
                    </div>
                    <div class="item-actions">
                        <button class="edit-btn" data-id="${c.id}">Editar</button>
                        <button class="delete-btn" data-id="${c.id}">Eliminar</button>
                    </div>`;
                UI.client.list.appendChild(li);
            });
        }

        function renderProducts(list) {
            if (!UI.product.list) return;
            UI.product.list.innerHTML = '';
            (list || [])
                .filter(p => !p.deletedAt)
                .sort((a, b) => a.descripcion.localeCompare(b.descripcion))
                .forEach(p => {
                const li = document.createElement('li');
                const showStock = isInventoryAllowed && (UI.inventoryToggle && UI.inventoryToggle.checked);
                let stockHTML = '';
                if (showStock) {
                    const s = parseInt(p.stock) || 0;
                    let color = s <= 0 ? '#D9534F' : (s < 10 ? '#F0AD4E' : '#28a745');
                    stockHTML = `<span style="font-size: 11px; margin-left: 10px; color: ${color}; font-weight: bold;">(Stock: ${s})</span>`;
                }
                const displayCode = p.codigo ? `<span style="color:var(--primary-accent); font-weight:bold; margin-right:5px;">[${escapeHTML(p.codigo)}]</span>` : '';
                li.innerHTML = `
                    <div style="flex-grow: 1; text-align: left;">
                        <span style="font-weight: 500;">${displayCode}${escapeHTML(p.descripcion)}</span>
                        <span style="color: #A0A0B0; margin-left: 5px;">- $${parseFloat(p.precio).toFixed(2)}</span>
                        ${stockHTML}
                    </div>
                    <div class="item-actions">
                        <button class="edit-btn" data-id="${p.id}">Editar</button>
                        <button class="delete-btn" data-id="${p.id}">Eliminar</button>
                    </div>`;
                UI.product.list.appendChild(li);
            });
        }

        function renderInventory(list) {
            if (!UI.inventoryBody) return;
            UI.inventoryBody.innerHTML = '';
            const activeList = (list || []).filter(p => !p.deletedAt);
            if (activeList.length === 0) { UI.inventoryBody.innerHTML = '<tr><td colspan="4" style="text-align:center;">No hay productos.</td></tr>'; return; }
            activeList.forEach(p => {
                const s = parseInt(p.stock) || 0; let cls = s <= 0 ? 'stock-out' : (s < 10 ? 'stock-low' : 'stock-ok');
                const displayDesc = p.codigo ? `[${escapeHTML(p.codigo)}] ${escapeHTML(p.descripcion)}` : escapeHTML(p.descripcion);
                UI.inventoryBody.innerHTML += `<tr><td>${displayDesc}</td><td>${escapeHTML(p.tipo)}</td><td>$${parseFloat(p.precio).toFixed(2)}</td><td><span class="stock-badge ${cls}">${s}</span></td></tr>`;
            });
        }

        function renderInventoryLog(history) {
            if (!UI.inventoryLogTableBody) return;
            UI.inventoryLogTableBody.innerHTML = '';
            const list = history || [];

            if (list.length === 0) {
                UI.inventoryLogTableBody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:#888; padding: 20px;">No hay movimientos registrados.</td></tr>';
                return;
            }
            const recentList = list.slice(-50).reverse();
            recentList.forEach(h => {
                const tr = document.createElement('tr');
                const tagClass = (h.tipo === 'ENTRADA') ? 'tag-entrada' : 'tag-salida';
                const signo = (h.tipo === 'ENTRADA') ? '+' : '-';
                const rowStyle = (h.tipo === 'ENTRADA') ? '' : 'background-color: rgba(0,0,0,0.1);';
                const safeRef = escapeHTML(h.referencia || "N/A");
                let refDisplay = safeRef.length > 20 ? `<span class="ref-code" title="${safeRef}">${safeRef.substring(0, 20)}...</span>` : safeRef;
                tr.innerHTML = `
                    <td style="${rowStyle}">${escapeHTML(h.fechaLegible)}</td>
                    <td style="${rowStyle}"><span class="${tagClass}">${escapeHTML(h.tipo)}</span></td>
                    <td style="${rowStyle}">${escapeHTML(h.producto)}</td>
                    <td style="${rowStyle}"><b>${signo}${h.cantidad}</b></td>
                    <td style="${rowStyle}">${refDisplay}</td>
                `;
                UI.inventoryLogTableBody.appendChild(tr);
            });
        }

        function renderHistoryTable(ventas) {
            if (!UI.historyTableBody) return;
            UI.historyTableBody.innerHTML = '';

            const headerRow = document.querySelector('#historyTable thead tr');
            if (headerRow && !headerRow.querySelector('.action-col')) {
                headerRow.insertAdjacentHTML('beforeend', '<th class="action-col" style="width: 50px;">Acción</th>');
            }

            let total = 0;
            const term = UI.searchHistoryInput ? UI.searchHistoryInput.value.toLowerCase() : '';
            const periodKey = UI.salesReportPeriod ? UI.salesReportPeriod.value : 'all';
            const now = new Date();

            const listaFiltrada = (ventas || []).filter(v => {
                const matchText = (v.cliente || '').toLowerCase().includes(term) || (v.codigo || '').toLowerCase().includes(term);
                if (!matchText) return false;

                let vDate = null;
                if (v.timestamp) vDate = new Date(Number(v.timestamp));
                else if (v.fecha) {
                    const parts = v.fecha.split('/');
                    if (parts.length === 3) vDate = new Date(parts[2], parts[1] - 1, parts[0]);
                }

                if (!vDate || isNaN(vDate.getTime())) return periodKey === 'all';

                if (periodKey === 'custom') {
                    const start = UI.histStartDate.value;
                    const end = UI.histEndDate.value;
                    if (start && end) return isDateInRange(vDate, start, end);
                    return true;
                }
                if (periodKey === 'all') return true;
                if (periodKey === 'today') return isSameDay(vDate, now);
                if (periodKey === 'week') return isInCurrentWeek(vDate, now);
                if (periodKey === 'month') return isSameMonth(vDate, now);
                return false;
            }).reverse();

            listaFiltrada.forEach(v => {
                const monto = parseFloat(v.total) || 0;
                let estadoActual = (v.estado || 'PROCESADO').trim().toUpperCase();

                // --- NUEVA REGLA ESTRICTA ---
                if (estadoActual !== 'INVALIDADO') {
                    estadoActual = 'PROCESADO';
                }

                // Sumamos si o si todos los procesados
                if (estadoActual === 'PROCESADO') { total += monto; }

                let tipoRaw = v.tipo || 'Factura';
                let tipoClean = getCleanType(tipoRaw);
                let tipoStyle = getTypeStyle(tipoClean);

                // Ahora solo hay dos colores: Gris (Invalidado) o Verde (Procesado)
                let bgSelect = estadoActual === 'INVALIDADO' ? '#6c757d' : '#28a745';

                const selectEstado = `<select class="status-selector" data-ts="${v.timestamp}" style="background-color: ${bgSelect}; color: white; border: none; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: bold; cursor: pointer; outline: none; width: 100%;"><option value="PROCESADO" ${estadoActual === 'PROCESADO' ? 'selected' : ''} style="color:#000; background-color:#fff;">PROCESADO</option><option value="INVALIDADO" ${estadoActual === 'INVALIDADO' ? 'selected' : ''} style="color:#000; background-color:#fff;">INVALIDADO</option></select>`;

                UI.historyTableBody.innerHTML += `<tr>
                    <td>${escapeHTML(v.fecha)}</td>
                    <td>${escapeHTML(v.hora)}</td>
                    <td><span style="font-size:11px; font-weight:600; padding:3px 8px; border-radius:12px; white-space:nowrap; ${tipoStyle}">${escapeHTML(tipoClean)}</span></td>
                    <td><small>${escapeHTML(v.codigo)}</small></td>
                    <td><small style="color:#A0A0B0;">${escapeHTML(v.numeroControl) || 'N/A'}</small></td>
                    <td>${escapeHTML(v.cliente)}</td>
                    <td style="text-align:right;">$${monto.toFixed(2)}</td>
                    <td style="width: 120px;">${selectEstado}</td>
                    <td style="text-align:center; white-space: nowrap;">
                        <button class="resend-email-btn" data-ts="${v.timestamp}" style="background:none; border:none; cursor:pointer; font-size:16px; margin-right:5px; opacity:0.8; transition:transform 0.2s;" title="Preparar Correo">📧</button>
                        <button class="delete-sale-btn" data-ts="${v.timestamp}" style="background:none; border:none; cursor:pointer; font-size:14px; opacity:0.7; transition:opacity 0.2s;" title="Eliminar Registro">❌</button>
                    </td>
                </tr>`;
            });
            if (UI.historyTotalSum) UI.historyTotalSum.innerText = `$${total.toFixed(2)}`;
        }

        if (UI.historyTableBody) {
            UI.historyTableBody.addEventListener('change', (e) => {
                if (e.target.classList.contains('status-selector')) {
                    const newStatus = e.target.value;
                    const ts = parseInt(e.target.dataset.ts);
                    if (newStatus === 'INVALIDADO') e.target.style.backgroundColor = '#6c757d';
                    else if (newStatus === 'PROCESADO') e.target.style.backgroundColor = '#28a745';
                    else e.target.style.backgroundColor = '#dc3545';
                    chrome.storage.local.get(null, d => { const profile = d.profiles[d.currentProfile]; if (profile && profile.ventas) { const idx = profile.ventas.findIndex(x => x.timestamp === ts); if (idx !== -1) { profile.ventas[idx].estado = newStatus; d.last_modified = Date.now(); chrome.storage.local.set(d, () => { loadData(); respaldarEnNube(d); }); } } });
                }
            });

            UI.historyTableBody.addEventListener('click', (e) => {
                if (e.target.classList.contains('resend-email-btn')) {
                    const ts = parseInt(e.target.dataset.ts);

                    chrome.storage.local.get(null, (d) => {
                        const profile = d.profiles[d.currentProfile];
                        const venta = profile.ventas.find(x => x.timestamp === ts);

                        if (!venta) return alert("❌ Error: Registro de venta no encontrado.");

                        // 1. Buscar si el cliente tiene un correo guardado en la base de datos
                        const clienteInfo = profile.clients.find(c => c.nombreCliente.trim().toLowerCase() === (venta.cliente || "").trim().toLowerCase());
                        const emailDestino = (clienteInfo && clienteInfo.email) ? clienteInfo.email : "";

                        // 2. Si no tiene correo, avisamos pero permitimos seguir
                        if (!emailDestino) {
                            if (!confirm(`⚠️ El cliente "${venta.cliente}" no tiene un correo guardado.\n\n¿Deseas abrir el borrador de todas formas para escribir el correo manualmente?`)) {
                                return; // Cancelar si el usuario no quiere abrirlo
                            }
                        }

                        // 3. Preparar la estructura y texto del borrador
                        const cleanType = getCleanType(venta.tipo || 'Factura');
                        const montoStr = parseFloat(venta.total || 0).toFixed(2);

                        const asunto = encodeURIComponent(`Envío de ${cleanType} - ${venta.cliente}`);

                        let cuerpo = `Estimado cliente, ${venta.cliente}\n\n`;
                        cuerpo += `Muchas gracias por su compra.\n\n`;
                        cuerpo += `A continuación, le adjunto los archivos de su factura electrónica.\n\n`;
                        cuerpo += `Saludos. –\n`;
                        cuerpo += `____________________________________________________________________\n`;
                        cuerpo += `Resumen del Documento:\n\n`;
                        cuerpo += `Código de Generación: ${venta.codigo}\n`;
                        if (venta.numeroControl) cuerpo += `Número de Control: ${venta.numeroControl}\n`;
                        cuerpo += `Total a pagar: $${montoStr}\n`;

                        // 4. Disparar el gestor de correo predeterminado
                        const mailtoUrl = `mailto:${emailDestino}?subject=${asunto}&body=${encodeURIComponent(cuerpo)}`;
                        const a = document.createElement('a');
                        a.href = mailtoUrl;
                        document.body.appendChild(a);
                        a.click();
                        document.body.removeChild(a);
                    });
                }
                if (e.target.classList.contains('delete-sale-btn')) {
                    const ts = parseInt(e.target.dataset.ts);

                    if (!confirm("⚠️ ¿Eliminar registro?")) return;

                    chrome.storage.local.get(null, async (d_inicial) => {
                        const profile = d_inicial.profiles[d_inicial.currentProfile];
                        const venta = profile.ventas.find(x => x.timestamp === ts);
                        let reintegroRealizado = false;

                        if (venta && venta.items && venta.items.length > 0) {
                            if (confirm(`📦 Esta venta contiene ${venta.items.length} productos.\n\n¿Quieres DEVOLVER las cantidades al inventario?`)) {
                                reintegroRealizado = await InventoryService.revertirVenta(venta.items, venta.numeroControl || venta.codigo, "Eliminación de Registro");
                            }
                        }

                        chrome.storage.local.get(null, (d_final) => {
                            const profileFinal = d_final.profiles[d_final.currentProfile];

                            profileFinal.ventas = profileFinal.ventas.filter(x => x.timestamp !== ts);
                            d_final.last_modified = Date.now();

                            chrome.storage.local.set(d_final, () => {
                                loadData();
                                respaldarEnNube(d_final);
                                let msg = "✅ Registro eliminado.";
                                if (reintegroRealizado) msg += "\n📦 Inventario restaurado.";
                                alert(msg);
                            });
                        });
                    });
                }
            });
        }

        if (UI.searchHistoryInput) UI.searchHistoryInput.addEventListener('input', loadData);
        if (UI.salesReportPeriod) UI.salesReportPeriod.addEventListener('change', loadData);

        function saveProduct() {
            chrome.storage.local.get(null, async () => {
                const id = UI.product.id.value;
                const normalizedProductId = id
                    ? (Number.isFinite(Number(id)) && String(Number(id)) === String(id).trim() ? Number(id) : id)
                    : Date.now();

                const baseProduct = {
                    id: normalizedProductId,
                    codigo: UI.product.inputs.codigo.value.trim(),
                    tipo: UI.product.inputs.tipo.value,
                    unidadMedida: UI.product.inputs.unidad.value,
                    descripcion: UI.product.inputs.desc.value,
                    precio: UI.product.inputs.precio.value,
                    stock: 0,
                };

                if (!baseProduct.descripcion) return alert('Descripción obligatoria');

                let quantityChange = 0;
                let movementType = null;

                await commitProfilesMutation((profiles, currentProfile) => {
                    const profile = profiles[currentProfile] || { clients: [], products: [], ventas: [] };
                    const products = profile.products || [];
                    const oldP = id ? products.find((p) => String(p.id) === String(id)) : null;
                    const newP = { ...baseProduct };

                    if (isInventoryAllowed && UI.inventoryToggle.checked) {
                        const inputStock = parseInt(UI.product.inputs.stock.value) || 0;
                        const previousStock = oldP ? (parseInt(oldP.stock) || 0) : 0;
                        newP.stock = inputStock;

                        const diff = inputStock - previousStock;
                        if (diff > 0) {
                            movementType = 'ENTRADA';
                            quantityChange = diff;
                        } else if (diff < 0) {
                            movementType = 'SALIDA (AJUSTE)';
                            quantityChange = Math.abs(diff);
                        }
                    } else if (oldP) {
                        newP.stock = oldP.stock;
                    }

                    profile.products = id
                        ? products.map((p) => String(p.id) === String(id) ? newP : p)
                        : [...products, newP];

                    profiles[currentProfile] = profile;
                    return profiles;
                });

                if (movementType && quantityChange > 0) {
                    await InventoryService.registrarMovimiento(
                        movementType,
                        baseProduct.descripcion,
                        quantityChange,
                        id ? 'Ajuste Manual de Inventario' : 'Carga Inicial',
                    );
                }

                resetProductForm();
                await loadData();
                alert("✅ Producto guardado correctamente.");
            });
        }

        if (UI.btnReporte) {
            UI.btnReporte.addEventListener('click', () => {
                chrome.storage.local.get(['inventory_history', 'profiles', 'currentProfile', 'nombreUsuario', 'nitUsuario'], d => {
                    const profileLogs = d.profiles[d.currentProfile].inventory_history || [];
                    const logs = profileLogs.length > 0 ? profileLogs : (d.inventory_history || []);

                    const products = d.profiles[d.currentProfile].products || [];

                    if (logs.length === 0) return alert("No hay movimientos registrados en el inventario para generar el reporte.");

                    const periodKey = UI.reportPeriod.value;
                    const now = new Date();
                    const logsFiltrados = logs.filter(l => {
                        const lDate = new Date(l.fecha);
                        if (periodKey === 'custom') {
                            const s = UI.invStartDate.value;
                            const e = UI.invEndDate.value;
                            return s && e ? isDateInRange(lDate, s, e) : true;
                        }
                        if (periodKey === 'today') return isSameDay(lDate, now);
                        if (periodKey === 'week') return isInCurrentWeek(lDate, now);
                        if (periodKey === 'month') return isSameMonth(lDate, now);
                        return true;
                    });

                    if (logsFiltrados.length === 0) return alert("No hay movimientos en el periodo seleccionado.");

                    const logsOrdenados = logsFiltrados.sort((a, b) => new Date(a.fecha) - new Date(b.fecha));

                    let periodoTexto = "";
                    if (periodKey === 'custom' && UI.invStartDate.value) {
                        periodoTexto = `${UI.invStartDate.value} AL ${UI.invEndDate.value}`;
                    } else {
                        const inicio = new Date(logsOrdenados[0].fecha).toLocaleDateString();
                        const fin = new Date(logsOrdenados[logsOrdenados.length - 1].fecha).toLocaleDateString();
                        periodoTexto = `${inicio} AL ${fin}`;
                    }

                    const metaData = {
                        usuario: d.nombreUsuario || "CONTRIBUYENTE GENERAL",
                        nit: d.nitUsuario || "0000-000000-000-0",
                        periodo: periodoTexto,
                        nombrePerfil: d.currentProfile || "Perfil"
                    };

                    generarKardexExcel(logsOrdenados, products, metaData);
                });
            });
        }

        if (UI.btnReporteKardex) {
            UI.btnReporteKardex.addEventListener('click', () => {
                chrome.storage.local.get(['inventory_history', 'profiles', 'currentProfile', 'nombreUsuario', 'nitUsuario'], d => {
                    const profileLogs = d.profiles[d.currentProfile].inventory_history || [];
                    const logs = profileLogs.length > 0 ? profileLogs : (d.inventory_history || []);
                    const products = d.profiles[d.currentProfile].products || [];

                    if (logs.length === 0) {
                        alert("No hay movimientos para generar el reporte detallado.");
                        return;
                    }

                    const periodKey = UI.reportPeriod.value;
                    const now = new Date();
                    const logsFiltrados = logs.filter(l => {
                        const lDate = new Date(l.fecha);
                        if (periodKey === 'custom') {
                            const s = UI.invStartDate.value;
                            const e = UI.invEndDate.value;
                            return s && e ? isDateInRange(lDate, s, e) : true;
                        }
                        if (periodKey === 'today') return isSameDay(lDate, now);
                        if (periodKey === 'week') return isInCurrentWeek(lDate, now);
                        if (periodKey === 'month') return isSameMonth(lDate, now);
                        return true;
                    });

                    if (logsFiltrados.length === 0) return alert("No hay movimientos en el periodo seleccionado.");

                    const logsOrdenados = logsFiltrados.sort((a, b) => new Date(a.fecha) - new Date(b.fecha));

                    let periodoTexto = "";
                    if (periodKey === 'custom' && UI.invStartDate.value) {
                        periodoTexto = `${UI.invStartDate.value} AL ${UI.invEndDate.value}`;
                    } else {
                        const inicio = new Date(logsOrdenados[0].fecha).toLocaleDateString();
                        const fin = new Date(logsOrdenados[logsOrdenados.length - 1].fecha).toLocaleDateString();
                        periodoTexto = `${inicio} AL ${fin}`;
                    }

                    const metaData = {
                        usuario: d.nombreUsuario || "FERRETERIA WILLY",
                        nombrePerfil: d.currentProfile,
                        periodo: periodoTexto
                    };

                    generarReporteKardexDetallado(logsOrdenados, products, metaData);
                });
            });
        }

        if (UI.btnReporteVentas) {
            UI.btnReporteVentas.addEventListener('click', () => {
                chrome.storage.local.get(null, d => {
                    const perfil = d.currentProfile;
                    const ventas = d.profiles[perfil].ventas || [];

                    if (ventas.length === 0) return alert("No hay ventas registradas.");

                    const periodKey = UI.salesReportPeriod.value;
                    const now = new Date();

                    let filteredVentas = ventas.filter(v => {
                        let vDate = null;
                        if (v.timestamp) vDate = new Date(Number(v.timestamp));
                        else if (v.fecha) {
                            const parts = v.fecha.split('/');
                            if (parts.length === 3) vDate = new Date(parts[2], parts[1] - 1, parts[0]);
                        }

                        if (!vDate || isNaN(vDate.getTime())) return periodKey === 'all';

                        if (periodKey === 'custom') {
                            const start = UI.histStartDate.value;
                            const end = UI.histEndDate.value;
                            if (start && end) return isDateInRange(vDate, start, end);
                            return true;
                        }
                        if (periodKey === 'all') return true;
                        if (periodKey === 'today') return isSameDay(vDate, now);
                        if (periodKey === 'week') return isInCurrentWeek(vDate, now);
                        if (periodKey === 'month') return isSameMonth(vDate, now);
                        return false;
                    }).reverse();

                    if (filteredVentas.length === 0) return alert(`No hay ventas para el periodo seleccionado.`);

                    let periodText = "";
                    if (periodKey === 'custom' && UI.histStartDate.value) {
                        periodText = `${UI.histStartDate.value} AL ${UI.histEndDate.value}`;
                    } else {
                        const periodMap = { 'all': 'TODO EL HISTORIAL', 'today': 'HOY', 'week': 'ESTA SEMANA', 'month': 'ESTE MES' };
                        periodText = periodMap[periodKey] || periodKey.toUpperCase();
                    }

                    generarReporteVentasExcel(filteredVentas, perfil, periodText);
                });
            });
        }

        if (UI.product.saveBtn) UI.product.saveBtn.addEventListener('click', saveProduct);
        if (UI.product.cancelBtn) UI.product.cancelBtn.addEventListener('click', resetProductForm);

        if (UI.product.list) UI.product.list.addEventListener('click', e => {
            const id = String(e.target.dataset.id || '');
            if (e.target.classList.contains('edit-btn')) {
                chrome.storage.local.get(null, d => {
                    const p = d.profiles[d.currentProfile].products.find(x => String(x.id) === id);
                    if (p) {
                        UI.product.formTitle.innerText = 'Editar Ítem';
                        UI.product.id.value = p.id;

                        UI.product.inputs.codigo.value = p.codigo || '';

                        UI.product.inputs.tipo.value = p.tipo;
                        UI.product.inputs.unidad.value = p.unidadMedida;
                        UI.product.inputs.desc.value = p.descripcion;
                        UI.product.inputs.precio.value = p.precio;
                        UI.product.inputs.stock.value = p.stock || 0;
                        UI.product.cancelBtn.style.display = 'inline-block';
                    }
                });
            } else if (e.target.classList.contains('delete-btn')) {
                if (confirm('¿Eliminar?')) {
                    commitProfilesMutation((profiles, currentProfile) => {
                        const profile = profiles[currentProfile] || { clients: [], products: [], ventas: [] };
                        profile.products = (profile.products || []).filter((x) => String(x.id) !== id);
                        profiles[currentProfile] = profile;
                        return profiles;
                    }).then(async () => {
                        await loadData();
                        alert("✅ Producto eliminado correctamente.");
                    });
                }
            }
        });

        function resetProductForm() { UI.product.id.value = ''; Object.values(UI.product.inputs).forEach(i => { if (i) i.value = ''; }); UI.product.inputs.unidad.value = '59'; UI.product.inputs.stock.value = '0'; UI.product.cancelBtn.style.display = 'none'; UI.product.formTitle.innerText = 'Agregar Nuevo Ítem'; }

        const clientFormContainer = document.querySelector('#client-management-container .form-container');
        const clientListContainer = document.querySelector('#client-management-container .list-container');

        function toggleListWidth(formVisible) {
            if (formVisible) clientListContainer.classList.remove('compact-mode');
            else clientListContainer.classList.add('compact-mode');
        }

        if (!clientFormContainer.style.display || clientFormContainer.style.display === 'none') toggleListWidth(false);

        function resetClientForm() {
            UI.client.id.value = '';
            Object.values(UI.client.inputs).forEach(i => { if (i) i.value = ''; });
            if (UI.client.inputs.depto) UI.client.inputs.depto.value = '';
            if (UI.client.inputs.muni) {
                UI.client.inputs.muni.value = '';
                UI.client.inputs.muni.disabled = true;
            }
            if (UI.client.formTitle) UI.client.formTitle.innerText = 'Agregar Nuevo Cliente';
        }

        if (UI.client.toggleBtn) UI.client.toggleBtn.addEventListener('click', () => {
            if (clientFormContainer.style.display === 'none') {
                resetClientForm();
                clientFormContainer.style.display = 'block';
                toggleListWidth(true);
                setTimeout(() => {
                    UI.client.container.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    UI.client.inputs.nombre.focus();
                }, 100);
            } else {
                clientFormContainer.style.display = 'none';
                toggleListWidth(false);
            }
        });

        if (UI.client.cancelBtn) UI.client.cancelBtn.addEventListener('click', () => {
            clientFormContainer.style.display = 'none';
            toggleListWidth(false);
        });

        if (UI.client.saveBtn) UI.client.saveBtn.addEventListener('click', () => {
            chrome.storage.local.get(null, async () => {
                const id = UI.client.id.value;

                const normalizedClientId = id
                    ? (Number.isFinite(Number(id)) && String(Number(id)) === String(id).trim() ? Number(id) : id)
                    : Date.now();

                const newC = {
                    id: normalizedClientId,
                    nombreCliente: UI.client.inputs.nombre.value,
                    nit: UI.client.inputs.nit.value,
                    nrc: UI.client.inputs.nrc.value,
                    dui: UI.client.inputs.dui.value,
                    pasaporte: UI.client.inputs.pasaporte.value,
                    carnetResidente: UI.client.inputs.carnet.value,
                    otroDocumento: UI.client.inputs.otro.value,
                    nombreComercial: UI.client.inputs.comercial.value,
                    actividadEconomica: UI.client.inputs.actividad.value,
                    direccion: UI.client.inputs.direccion.value,
                    departamento: UI.client.inputs.depto.value,
                    municipio: UI.client.inputs.muni.value,
                    email: UI.client.inputs.email.value,
                    telefono: UI.client.inputs.telefono.value,
                    tipoPersona: UI.client.inputs.tipoPersona.value,
                    pais: UI.client.inputs.pais.value,
                };

                if (!newC.nombreCliente) return alert("Nombre obligatorio");

                await commitProfilesMutation((profiles, currentProfile) => {
                    const profile = profiles[currentProfile] || { clients: [], products: [], ventas: [] };
                    const clients = profile.clients || [];

                    profile.clients = id
                        ? clients.map((c) => String(c.id) === String(id) ? newC : c)
                        : [...clients, newC];

                    profiles[currentProfile] = profile;
                    return profiles;
                });

                resetClientForm();
                clientFormContainer.style.display = 'none';
                toggleListWidth(false);
                await loadData();
                alert("✅ Cliente guardado correctamente.");
            });
        });

        if (UI.client.list) UI.client.list.addEventListener('click', e => {
            const id = String(e.target.dataset.id || '');
            if (e.target.classList.contains('delete-btn')) {
                if (!confirm("¿Eliminar cliente?")) return;
                e.target.textContent = "...";
                e.target.disabled = true;
                commitProfilesMutation((profiles, currentProfile) => {
                    const profile = profiles[currentProfile] || { clients: [], products: [], ventas: [] };
                    profile.clients = (profile.clients || []).filter((c) => String(c.id) !== id);
                    profiles[currentProfile] = profile;
                    return profiles;
                }).then(async () => {
                    await loadData();
                    alert("✅ Cliente eliminado correctamente.");
                });
            }
            if (e.target.classList.contains('edit-btn')) {
                chrome.storage.local.get(null, d => {
                    const c = d.profiles[d.currentProfile].clients.find(x => String(x.id) === id);
                    if (c) {
                        UI.client.id.value = c.id;
                        Object.keys(UI.client.inputs).forEach(k => {
                            if (UI.client.inputs[k] && k !== 'depto' && k !== 'muni') {
                                UI.client.inputs[k].value = c[k === 'nombre' ? 'nombreCliente' : (k === 'comercial' ? 'nombreComercial' : (k === 'actividad' ? 'actividadEconomica' : (k === 'carnet' ? 'carnetResidente' : (k === 'otro' ? 'otroDocumento' : k))))] || '';
                            }
                        });
                        if (c.departamento) {
                            UI.client.inputs.depto.value = c.departamento;
                            updateMunicipios();
                            UI.client.inputs.muni.value = c.municipio || '';
                        }
                        UI.client.formTitle.innerText = 'Editar Cliente';
                        clientFormContainer.style.display = 'block';
                        toggleListWidth(true);
                        UI.client.container.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    }
                });
            }
        });
        if (UI.profileSelector) UI.profileSelector.addEventListener('change', () => chrome.storage.local.set({ currentProfile: UI.profileSelector.value }, loadData));

        let isAddingProfile = false;
        if (UI.addProfileBtn) UI.addProfileBtn.addEventListener('click', () => { if (isAddingProfile) { const name = UI.newProfileName.value.trim(); if (!name) return alert("Vacío"); const span = UI.addProfileBtn.querySelector('span'); const orig = span.textContent; span.textContent = "Guardando..."; UI.addProfileBtn.disabled = true; chrome.storage.local.get("profiles", d => { if (d.profiles[name]) { span.textContent = orig; UI.addProfileBtn.disabled = false; return alert('Existe'); } d.profiles[name] = { clients: [], products: [], logs: [], ventas: [] }; const upd = { profiles: d.profiles, currentProfile: name, last_modified: Date.now() }; chrome.storage.local.set(upd, async () => { loadData(); await respaldarEnNube(upd); resetProfileUI(); UI.addProfileBtn.disabled = false; alert("✅ Perfil creado correctamente."); }); }); } else showAddProfileUI(); });
        function showAddProfileUI() { UI.newProfileGroup.style.display = 'block'; UI.cancelAddProfileBtn.style.display = 'inline-block'; UI.addProfileBtn.classList.add('adding-state'); UI.addProfileBtn.querySelector('span').textContent = 'Guardar'; UI.addProfileBtn.querySelector('img').style.display = 'none'; isAddingProfile = true; UI.newProfileName.focus(); }
        function resetProfileUI() { UI.newProfileGroup.style.display = 'none'; UI.cancelAddProfileBtn.style.display = 'none'; UI.newProfileName.value = ''; UI.addProfileBtn.classList.remove('adding-state'); UI.addProfileBtn.querySelector('span').textContent = 'Crear Nuevo Perfil'; UI.addProfileBtn.querySelector('img').style.display = 'inline-block'; isAddingProfile = false; }
        if (UI.cancelAddProfileBtn) UI.cancelAddProfileBtn.addEventListener('click', resetProfileUI);
        if (UI.renameProfileBtn) UI.renameProfileBtn.addEventListener('click', () => { chrome.storage.local.get(null, d => { const old = d.currentProfile; const n = prompt("Nuevo nombre:", old); if (n && n.trim() && n !== old) { if (d.profiles[n]) return alert("Ya existe"); d.profiles[n] = d.profiles[old]; delete d.profiles[old]; d.currentProfile = n; chrome.storage.local.set(d, () => { loadData(); respaldarEnNube(d); }); } }); });
        if (UI.deleteProfileBtn) UI.deleteProfileBtn.addEventListener('click', () => { chrome.storage.local.get(null, d => { if (Object.keys(d.profiles).length <= 1) return alert("No puedes borrar el único."); if (confirm("¿Eliminar?")) { delete d.profiles[d.currentProfile]; d.currentProfile = Object.keys(d.profiles)[0]; d.last_modified = Date.now(); chrome.storage.local.set(d, async () => { loadData(); try { await updateDoc(doc(db, "datos_usuarios", d.licencia), { profiles: d.profiles, currentProfile: d.currentProfile, last_modified: d.last_modified }); } catch (e) { } alert("✅ Perfil eliminado correctamente."); }); } }); });
        if (UI.exportBtn) UI.exportBtn.addEventListener('click', () => chrome.storage.local.get(null, d => { const b = new Blob([JSON.stringify({ profiles: d.profiles }, null, 2)], { type: "application/json" }); const a = document.createElement('a'); a.href = URL.createObjectURL(b); a.download = `Respaldo_${new Date().toISOString().slice(0, 10)}.json`; a.click(); }));
        if (UI.importBtn) UI.importBtn.addEventListener('click', () => UI.importFile.click());
        if (UI.importFile) UI.importFile.addEventListener('change', e => { const f = e.target.files[0]; if (!f) return; const r = new FileReader(); r.onload = ev => { try { const imp = JSON.parse(ev.target.result); if (imp.profiles) { chrome.storage.local.set({ profiles: imp.profiles, last_modified: Date.now() }, async () => { alert("Restaurado."); loadData(); await respaldarEnNube(null, true); }); } } catch (e) { alert("Error JSON"); } }; r.readAsText(f); UI.importFile.value = ''; });
        if (UI.upgradeBtn) UI.upgradeBtn.addEventListener('click', async () => { const k = prompt("Clave PRO:"); if (k) { const snap = await getDoc(doc(db, "licencias", k)); if (snap.exists() && snap.data().estado === "ACTIVO") { chrome.storage.local.set({ licencia: k, activationStatus: snap.data().plan || "PRO" }, () => location.reload()); } else alert("Inválida"); } });

        const tabs = document.querySelectorAll('input[name="tab-control"]'); tabs.forEach(t => t.addEventListener('change', () => { if (t.id === 'tab3') loadData(); }));
        if (UI.inventoryToggle) UI.inventoryToggle.addEventListener('change', () => { chrome.storage.local.get(null, d => { d.profiles[d.currentProfile].inventoryEnabled = UI.inventoryToggle.checked; chrome.storage.local.set(d, () => { toggleInventoryUI(UI.inventoryToggle.checked); loadData(); respaldarEnNube(d); }); }); });

        chrome.runtime.onMessage.addListener((m, sender, sendResponse) => {
            if (m.action === 'INVENTORY_UPDATED' || m.action === 'SALES_UPDATED') {
                loadData();
                respaldarEnNube();
            }
            sendResponse({ status: "ok" });
            return true;
        });

        populateDepartamentos();
        loadData();

        // =========================================================================
        // 🔥🔥🔥 ESCUCHA REAL-TIME INTELIGENTE (FIX BUCLE) 🔥🔥🔥
        // =========================================================================

        function iniciarEscuchaRealTime() {
            chrome.storage.local.get(['licencia', 'hasSyncedOnce'], (local) => {
                const licenciaKey = local.licencia;
                const yaSincronizado = local.hasSyncedOnce === true;

                if (!licenciaKey || licenciaKey.startsWith('DEMO')) return;

                console.log("🟢 Iniciando conexión en vivo para:", licenciaKey);

                onSnapshot(doc(db, "datos_usuarios", licenciaKey), (docSnap) => {
                    console.log('📡 Snapshot de datos_usuarios recibido');
                    if (docSnap.exists()) {
                        const nubeData = docSnap.data();
                        console.log('📦 Documento remoto con last_modified:', nubeData.last_modified || 0);

                        if (nubeData.forzarReset === true) {
                            console.warn("⚠️ ORDEN DE RESETEO RECIBIDA DESDE EL MASTER PANEL.");
                            ejecutarResetSeguro("⚠️ ALERTA DE SEGURIDAD ⚠️\n\nTu administrador ha enviado una orden de reseteo remoto.\n\n🛡️ HEMOS DESCARGADO UNA COPIA DE TUS DATOS automáticamente por seguridad.\n\nLa extensión se reiniciará en blanco ahora.", 'SOLO_DATOS');
                            return;
                        }

                        chrome.storage.local.get(['profiles'], (localData) => {
                            const cloudTime = nubeData.last_modified || 0;
                            const localProfilesJson = JSON.stringify(localData.profiles || {});
                            const cloudProfilesJson = JSON.stringify(nubeData.profiles || {});

                            if (!yaSincronizado) chrome.storage.local.set({ hasSyncedOnce: true });

                            if (cloudProfilesJson !== localProfilesJson) {
                                console.log("☁️ Recibiendo actualización remota...");
                                chrome.storage.local.set({
                                    profiles: nubeData.profiles,
                                    inventoryEnabled: nubeData.inventoryEnabled,
                                    last_modified: cloudTime
                                }, () => {
                                    console.log('✅ chrome.storage.local actualizado desde Firestore');
                                    loadData();
                                });
                            } else {
                                console.log('ℹ️ Snapshot recibido pero no hubo cambios de perfiles');
                            }
                        });
                    } else {
                        console.log("🛡️ Nube vacía o documento no existe.");
                    }
                });

                onSnapshot(doc(db, "licencias", licenciaKey), (docSnap) => {
                    console.log('📡 Snapshot de licencias recibido');
                    if (docSnap.exists()) {
                        const data = docSnap.data();
                        const estado = data.estado || "ACTIVO";

                        if (estado !== "ACTIVO" && estado !== "SUSPENDIDO" && estado !== "RESTRINGIDA" && estado !== "pausada") {
                            ejecutarResetSeguro("⛔ TU LICENCIA HA SIDO DESACTIVADA REMOTAMENTE.\n\n🛡️ HEMOS DESCARGADO UNA COPIA DE TUS DATOS en tu PC.\n\nLa extensión se reiniciará ahora.", 'COMPLETO');
                            return;
                        }

                        if (data.plan) {
                            chrome.storage.local.get('activationStatus', (localSt) => {
                                if (localSt.activationStatus !== data.plan) {
                                    chrome.storage.local.set({ activationStatus: data.plan }, () => {
                                        alert("Tu plan se ha actualizado a: " + data.plan);
                                        location.reload();
                                    });
                                }
                            });
                        }
                    }
                });
            });
        }

        iniciarEscuchaRealTime();

        setInterval(() => {
            chrome.storage.local.get('licencia', d => {
                if (d.licencia && !d.licencia.startsWith('DEMO')) {
                    enviarLatido(d.licencia);
                }
            });
        }, 60000);
    }

    async function respaldarEnNube(datosExplicitos = null, overwrite = false) {
        let datos = datosExplicitos;
        if (!datos) { datos = await new Promise(resolve => chrome.storage.local.get(null, resolve)); }
        if (!datos.licencia) { const r = await new Promise(resolve => chrome.storage.local.get('licencia', resolve)); datos.licencia = r.licencia; }
        if (datos.licencia) await enviarLatido(datos.licencia);

        const isDemoPlan = (datos.activationStatus === 'DEMO' || datos.activationStatus === 'DEMO_INV');
        if (PUBLIC_DEMO_KEYS.includes(datos.licencia) || isDemoPlan) { return; }

        if (datos.licencia) {
            const cleanedProfiles = stripSoftDeletedProfiles(datos.profiles || {});
            const dataToUpload = { profiles: cleanedProfiles, currentProfile: datos.currentProfile || "Mi Perfil", inventoryEnabled: datos.inventoryEnabled !== false, last_modified: datos.last_modified || Date.now(), ultima_actualizacion: new Date().toLocaleString(), version_ext: "12.3" };
            try {
                const docRef = doc(db, "datos_usuarios", datos.licencia);
                if (overwrite) {
                    await setDoc(docRef, dataToUpload);
                    console.log("☁️ Restauración total en nube exitosa.");
                } else {
                    await setDoc(docRef, dataToUpload, { merge: true });
                    console.log("☁️ Sincronización exitosa.");
                }
            } catch (e) { console.error("Error al sincronizar:", e); }
        }
    }

    // =========================================================
    // FUNCIÓN DE CAMBIO DE TEMA (MODO OSCURO / CLARO)
    // =========================================================
    const btnToggleTheme = document.getElementById('btnToggleTheme');
    if (btnToggleTheme) {
        // Restaurar estado guardado
        chrome.storage.local.get('theme', (res) => {
            if (res.theme === 'light') {
                document.documentElement.classList.add('light-mode');
                const themeIcon = document.getElementById('themeIcon');
                if (themeIcon) themeIcon.textContent = '🌙';
            }
        });

        // Evento toggle
        btnToggleTheme.addEventListener('click', () => {
            const isLight = document.documentElement.classList.toggle('light-mode');
            chrome.storage.local.set({ theme: isLight ? 'light' : 'dark' });
            const themeIcon = document.getElementById('themeIcon');
            if (themeIcon) themeIcon.textContent = isLight ? '🌙' : '☀️';
        });
    }

    // =========================================================
    // FUNCIÓN DE ADMINISTRADOR: CAMBIO DE CLAVE PROTEGIDO
    // =========================================================

    const btnCambiarClave = document.getElementById('btnCambiarClave');
    if (btnCambiarClave) {
        btnCambiarClave.addEventListener('click', () => {
            const password = prompt("🔒 Ingrese la contraseña de administrador:");
            if (password === "serendipiad2") {
                const nuevaClave = prompt("✅ Contraseña correcta.\n\nIngrese la nueva Clave de Activación:");
                if (nuevaClave && nuevaClave.trim() !== "") {
                    const claveLimpia = nuevaClave.trim();
                    ejecutarResetSeguro(`🔄 Preparando cambio a clave: ${claveLimpia}\n\n🛡️ Hemos descargado una copia de los datos actuales por si acaso.\n\nLa extensión se recargará ahora.`, 'CAMBIO_CLAVE', claveLimpia);
                } else {
                    alert("⚠️ Acción cancelada. No se ingresó ninguna clave válida.");
                }
            } else if (password !== null) {
                alert("❌ Contraseña incorrecta. Acceso denegado.");
            }
        });
    }

    // =========================================================
    // COMPRAS - SINCRONIZACIÓN GMAIL
    // =========================================================
    const btnSyncCompras = document.getElementById('btnSyncCompras');
    if (btnSyncCompras) {
        function filterCompras(data) {
            const period = document.getElementById('comprasReportPeriod')?.value || 'all';
            if (period === 'all') return data;
            
            const now = new Date();
            const startStr = document.getElementById('comprasStartDate')?.value;
            const endStr = document.getElementById('comprasEndDate')?.value;
            
            return data.filter(item => {
                // Ensure item.fechaEmi is a valid string, split by '-', ensure standard format
                const [y, m, d] = (item.fechaEmi || "").split('-');
                const date = new Date(y, m - 1, d);
                if (isNaN(date.getTime())) return true;
                
                if (period === 'today') {
                    return date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth() && date.getDate() === now.getDate();
                } else if (period === 'month') {
                    return date.getMonth() === now.getMonth() && date.getFullYear() === now.getFullYear();
                } else if (period === 'week') {
                    const todayDate = new Date();
                    const firstDay = new Date(todayDate.setDate(todayDate.getDate() - todayDate.getDay()));
                    firstDay.setHours(0,0,0,0);
                    const lastDay = new Date(firstDay);
                    lastDay.setDate(lastDay.getDate() + 6);
                    lastDay.setHours(23,59,59,999);
                    return date >= firstDay && date <= lastDay;
                } else if (period === 'custom') {
                    if (startStr && endStr) {
                         const [sy, sm, sd] = startStr.split('-');
                         const s = new Date(sy, sm - 1, sd);
                         const [ey, em, ed] = endStr.split('-');
                         const e = new Date(ey, em - 1, ed);
                         e.setHours(23, 59, 59, 999);
                         return date >= s && date <= e;
                    }
                }
                return true;
            });
        }

        function loadComprasForProfile() {
            chrome.storage.local.get(['profiles', 'currentProfile'], (res) => {
                const compras = (res.profiles && res.profiles[res.currentProfile] && res.profiles[res.currentProfile].compras) || [];
                const filtered = filterCompras(compras);
                renderComprasTable(filtered);
            });
        }
        
        loadComprasForProfile();
        document.getElementById('profileSelector')?.addEventListener('change', loadComprasForProfile);
        
        const comprasPeriod = document.getElementById('comprasReportPeriod');
        const comprasDateRange = document.getElementById('comprasDateRange');
        if (comprasPeriod) {
            comprasPeriod.addEventListener('change', () => {
                if (comprasPeriod.value === 'custom') {
                    comprasDateRange.style.display = 'inline-block';
                } else {
                    comprasDateRange.style.display = 'none';
                    loadComprasForProfile();
                }
            });
        }
        document.getElementById('comprasStartDate')?.addEventListener('change', loadComprasForProfile);
        document.getElementById('comprasEndDate')?.addEventListener('change', loadComprasForProfile);

        async function checkCurrentGmailAccount() {
            const label = document.getElementById('labelGmailAccount');
            if (label) {
                try {
                    const token = await authorizeUser(false).catch(() => null);
                    if (token) {
                        const email = await fetchUserEmail(token);
                        label.textContent = email ? `${email}` : '';
                    } else {
                        label.textContent = '';
                    }
                } catch (e) { label.textContent = ''; }
            }
        }
        checkCurrentGmailAccount();

        btnSyncCompras.addEventListener('click', async () => {
            try {
                btnSyncCompras.innerHTML = '⚙️ Sincronizando...';
                btnSyncCompras.disabled = true;

                let timeQuery = "newer_than:30d";
                const period = document.getElementById('comprasReportPeriod')?.value || 'month';
                
                if (period === 'today') {
                    timeQuery = "newer_than:1d";
                } else if (period === 'week') {
                    timeQuery = "newer_than:7d";
                } else if (period === 'month') {
                    const now = new Date();
                    timeQuery = `after:${now.getFullYear()}/${(now.getMonth() + 1).toString().padStart(2, '0')}/01`;
                } else if (period === 'custom') {
                    const s = document.getElementById('comprasStartDate')?.value;
                    const e = document.getElementById('comprasEndDate')?.value;
                    let q = "";
                    if (s) q += `after:${s.replace(/-/g, '/')} `;
                    if (e) {
                         const eDate = new Date(e);
                         eDate.setDate(eDate.getDate() + 1); // before: in Gmail is strictly before that date at 00:00:00
                         const ey = eDate.getFullYear();
                         const em = (eDate.getMonth() + 1).toString().padStart(2, '0');
                         const ed = eDate.getDate().toString().padStart(2, '0');
                         q += `before:${ey}/${em}/${ed}`;
                    }
                    timeQuery = q.trim() || "newer_than:30d";
                }

                const token = await authorizeUser();
                checkCurrentGmailAccount();
                const newInvoices = await fetchRecentInvoices(token, timeQuery);
                
                chrome.storage.local.get(['profiles', 'currentProfile'], (res) => {
                    const p = res.currentProfile;
                    if (!res.profiles || !res.profiles[p]) return;
                    
                    let existing = res.profiles[p].compras || [];
                    const newIds = new Set(newInvoices.map(i => i.control));
                    existing = existing.filter(e => !newIds.has(e.control));
                    
                    const merged = [...existing, ...newInvoices];
                    res.profiles[p].compras = merged;
                    
                    chrome.storage.local.set({ profiles: res.profiles }, () => {
                        loadComprasForProfile();
                        btnSyncCompras.innerHTML = 'Sincronizar Gmail';
                        btnSyncCompras.disabled = false;
                        alert(`¡Sincronización completa! Se recuperaron ${newInvoices.length} facturas recientes de Gmail para el perfil actual.`);
                    });
                });
            } catch (e) {
                console.error("Error síncrono correos:", e);
                alert("Ocurrió un error al sincronizar con Gmail: " + e.message);
                btnSyncCompras.innerHTML = 'Sincronizar Gmail';
                btnSyncCompras.disabled = false;
            }
        });

        const btnClearCompras = document.getElementById('btnClearCompras');
        if (btnClearCompras) {
            btnClearCompras.addEventListener('click', () => {
                if (confirm('¿Estás seguro de que deseas vaciar el historial de Compras de ESTE PERFIL?')) {
                    chrome.storage.local.get(['profiles', 'currentProfile'], (res) => {
                        const p = res.currentProfile;
                        if (res.profiles && res.profiles[p]) {
                            res.profiles[p].compras = [];
                            chrome.storage.local.set({ profiles: res.profiles }, () => {
                                renderComprasTable([]);
                                alert('Historial de compras borrado correctamente.');
                            });
                        }
                    });
                }
            });
        }

        const btnSwitchAccount = document.getElementById('btnSwitchAccount');
        if (btnSwitchAccount) {
            btnSwitchAccount.addEventListener('click', async () => {
                if (confirm('¿Deseas cerrar sesión de la cuenta actual para conectar otra?')) {
                    btnSwitchAccount.innerHTML = 'Cerrando...';
                    await logoutUser();
                    btnSwitchAccount.innerHTML = '👤 Cambiar Cuenta';
                    const lbl = document.getElementById('labelGmailAccount');
                    if(lbl) lbl.textContent = '';
                    alert('Sesión cerrada exitosamente. La próxima vez que Sincronices, Chrome te pedirá que elijas una cuenta de Google.');
                }
            });
        }
    }

    function renderComprasTable(data) {
        const tbody = document.getElementById('comprasTableBody');
        const totalEl = document.getElementById('comprasTotalSum');
        if (!tbody) return;
        
        tbody.innerHTML = '';
        let sum = 0;

        if (!data || data.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding: 20px;">Aún no se ha encontrado historial de compras. Usa el botón Sincronizar.</td></tr>';
            if (totalEl) totalEl.textContent = "$0.00";
            return;
        }

        data.sort((a, b) => new Date(b.fechaEmi) - new Date(a.fechaEmi));

        data.forEach(item => {
            const tr = document.createElement('tr');
            
            // Format JSON blob (exact raw string or fallback stringified object)
            const jsonTextContent = item.rawJson || JSON.stringify(item.originalJson, null, 2);
            const downloadUrl = `data:text/json;charset=utf-8,${encodeURIComponent(jsonTextContent)}`;
            
            // Format dates reliably as DD/MM/YYYY
            const [y, m, d] = (item.fechaEmi || "").split('-');
            const displayDate = (y && m && d) ? `${d}/${m}/${y}` : item.fechaEmi;

            // Type Badge to perfectly match Ventas CSS logic
            let tipoClean = typeof getCleanType === 'function' ? getCleanType(item.tipo || 'Factura') : (item.tipo || 'Factura');
            let tipoStyle = typeof getTypeStyle === 'function' ? getTypeStyle(tipoClean) : 'background-color: var(--surface-color); color: var(--text-primary); border: 1px solid var(--border-color);';
            
            tr.innerHTML = `
                <td style="white-space:nowrap;">${displayDate}</td>
                <td><span style="font-size:11px; font-weight:600; padding:3px 8px; border-radius:12px; white-space:nowrap; ${tipoStyle}">${escapeHTML(tipoClean)}</span></td>
                <td>${escapeHTML(item.proveedor)}</td>
                <td>${escapeHTML(item.nit || 'N/A')}</td>
                <td><small style="color:#A0A0B0;">${escapeHTML(item.codigoGeneracion || item.control || 'N/A')}</small></td>
                <td style="text-align: right; color: var(--success-color); font-weight: bold;">$${item.total.toFixed(2)}</td>
                <td style="text-align: center;">
                    <a href="${downloadUrl}" download="${item.filename || 'compra.json'}" title="Descargar Factura Original" style="text-decoration:none; display:inline-block; font-size:11px; padding:3px 8px; border: 1px solid var(--border-color); border-radius:4px; color: var(--text-primary); cursor:pointer; background-color: var(--surface-color);">
                        ⬇️ JSON
                    </a>
                </td>
            `;
            tbody.appendChild(tr);
            sum += parseFloat(item.total);
        });

        if (totalEl) totalEl.textContent = `$${sum.toFixed(2)}`;
    }

});