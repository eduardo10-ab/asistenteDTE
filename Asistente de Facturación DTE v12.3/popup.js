// popup.js - V23.0: Tour Guiado SOS + Gestor de Reseteo Seguro
import { initializeApp } from "./firebase-app.js";
import { getFirestore, doc, updateDoc, getDoc, setDoc, onSnapshot } from "./firebase-firestore.js";
import { InventoryService } from "./inventory_service.js";

// =========================================================
// 1. CONFIGURACIÓN
// =========================================================
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
const db = getFirestore(app);

// Estado Global
let state = {
    profiles: [],
    clients: [],
    products: [],
    selectedProfile: null,
    selectedClient: null,
    selectedProduct: null
};

// =========================================================
// 2. UTILIDADES DE SISTEMA Y GESTOR DE RESETEO
// =========================================================
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

window.isResetting = false; // Candado de seguridad antibucles

function ejecutarResetSeguro(mensajeAlerta, tipoBorrado = 'SOLO_DATOS', payload = null) {
    if (window.isResetting) return;
    window.isResetting = true;
    console.warn("Iniciando secuencia de Reset Seguro desde Panel Lateral...");

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
                mensaje: "Respaldo automático de emergencia (Panel Lateral)."
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
}

async function actualizarHoraFirebase(licenseKey) {
    if (!licenseKey) return;
    try {
        const ahora = new Date().toLocaleString();
        await updateDoc(doc(db, "licencias", licenseKey), { ultima_conexion: ahora });
    } catch (e) { }
}

async function verificarCambioPlan(licenseKey, currentStatus) {
    if (!licenseKey || licenseKey.startsWith('DEMO')) return;
    try {
        const docRef = doc(db, "licencias", licenseKey);
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
            const data = docSnap.data();
            const planRemoto = data.plan || "PRO";
            const estadoRemoto = data.estado || "ACTIVO";

            if (estadoRemoto !== "ACTIVO" && estadoRemoto !== "SUSPENDIDO" && estadoRemoto !== "RESTRINGIDA") {
                ejecutarResetSeguro("⛔ TU LICENCIA HA SIDO DESACTIVADA REMOTAMENTE.\n\n🛡️ HEMOS DESCARGADO UNA COPIA DE TUS DATOS en tu PC.\n\nLa extensión se reiniciará ahora.", 'COMPLETO');
                return;
            }
            if (planRemoto !== currentStatus) {
                chrome.storage.local.set({ activationStatus: planRemoto }, () => location.reload());
            }
        }
    } catch (e) { }
}

document.addEventListener('DOMContentLoaded', () => {

    // =========================================================
    // 2.5 APLICAR TEMA
    // =========================================================
    chrome.storage.local.get('theme', (res) => {
        if (res.theme === 'light') document.documentElement.classList.add('light-mode');
    });

    chrome.storage.onChanged.addListener((changes, namespace) => {
        if (namespace === 'local' && changes.theme) {
            if (changes.theme.newValue === 'light') document.documentElement.classList.add('light-mode');
            else document.documentElement.classList.remove('light-mode');
        }
    });

    // =========================================================
    // 3. REFERENCIAS UI
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

    const ui = {
        profileInput: document.getElementById('profileInput'),
        profileList: document.getElementById('profileDropdown'),

        clientInput: document.getElementById('clientInput'),
        clientList: document.getElementById('clientDropdown'),
        fillClienteBtn: document.getElementById('fillClienteBtn'),

        productInput: document.getElementById('productInput'),
        productList: document.getElementById('customDropdown'),
        productQty: document.getElementById('productQuantity'),
        addProductoBtn: document.getElementById('addProductoBtn'),

        sendMailIcon: document.getElementById('sendMailIcon'),

        startTourBtn: document.getElementById('startTourBtn'),
        sosEmoji: document.getElementById('sosEmoji'),
        sosText: document.getElementById('sosText')
    };

    // =========================================================
    // 4. LÓGICA DE DROPDOWNS (FACTORY)
    // =========================================================
    function setupDropdown({ input, list, onSelect, itemRenderer, filterFn }) {
        let items = [];

        function render(data) {
            list.innerHTML = '';
            if (data.length === 0) {
                const div = document.createElement('div');
                div.className = 'dropdown-item';
                div.style.color = '#888';
                div.textContent = 'Sin resultados';
                list.appendChild(div);
                return;
            }
            data.forEach(item => {
                const div = document.createElement('div');
                div.className = 'dropdown-item';
                div.innerHTML = itemRenderer(item);

                div.addEventListener('click', () => {
                    input.value = item.displayText || item;
                    list.classList.remove('show');
                    onSelect(item);
                });
                list.appendChild(div);
            });
        }

        input.addEventListener('click', () => {
            render(items);
            list.classList.add('show');
            if (!input.readOnly) input.select();
        });

        if (!input.readOnly) {
            input.addEventListener('input', (e) => {
                const query = e.target.value.toLowerCase();
                const filtered = items.filter(item => filterFn(item, query));
                render(filtered);
                list.classList.add('show');
            });
        }

        document.addEventListener('click', (e) => {
            if (!input.contains(e.target) && !list.contains(e.target)) {
                list.classList.remove('show');
            }
        });

        return {
            setItems: (newItems) => { items = newItems; },
            clear: () => { input.value = ''; items = []; },
            setValue: (text) => { input.value = text; }
        };
    }

    // =========================================================
    // 5. CONFIGURACIÓN DE LOS 3 DROPDOWNS
    // =========================================================
    const profileDropdown = setupDropdown({
        input: ui.profileInput,
        list: ui.profileList,
        itemRenderer: (p) => `<span class="name-text"><span class="scroll-content">${escapeHTML(p)}</span></span>`,
        filterFn: () => true,
        onSelect: (p) => {
            chrome.storage.local.set({ currentProfile: p }, loadPopupData);
        }
    });

    const clientDropdown = setupDropdown({
        input: ui.clientInput,
        list: ui.clientList,
        itemRenderer: (c) => `<span class="name-text"><span class="scroll-content">${escapeHTML(c.nombreCliente)}</span></span>`,
        filterFn: (c, q) => c.nombreCliente.toLowerCase().includes(q),
        onSelect: (c) => {
            state.selectedClient = c;
            ui.fillClienteBtn.disabled = false;
            ui.sendMailIcon.classList.remove('disabled');

            chrome.storage.local.get(null, d => {
                if (d.profiles && d.profiles[d.currentProfile]) {
                    d.profiles[d.currentProfile].lastUsedClientId = c.id;
                    chrome.storage.local.set(d);
                }
            });
        }
    });

    const productDropdown = setupDropdown({
        input: ui.productInput,
        list: ui.productList,
        itemRenderer: (p) => {
            const codeHtml = p.codigo ? `<span class="code-tag">${escapeHTML(p.codigo)}</span>` : '';
            const stockHtml = p.showStock ? `<span class="stock-tag">Stock: ${escapeHTML(p.stock)}</span>` : '';
            return `${codeHtml} <span class="name-text"><span class="scroll-content">${escapeHTML(p.descripcion)}</span></span> ${stockHtml}`;
        },
        filterFn: (p, q) => p.display.toLowerCase().includes(q) || (p.codigo && p.codigo.toLowerCase().includes(q)),
        onSelect: (p) => {
            state.selectedProduct = p;
            ui.productInput.value = p.fullText;

            chrome.storage.local.get(null, d => {
                if (d.profiles && d.profiles[d.currentProfile]) {
                    d.profiles[d.currentProfile].lastUsedProductId = p.id;
                    chrome.storage.local.set(d);
                }
            });
        }
    });

    // =========================================================
    // 6. LOGICA REAL-TIME Y ESCUCHA
    // =========================================================
    let isListening = false;

    function iniciarEscuchaRealTime(licenciaKey) {
        if (!licenciaKey || licenciaKey.startsWith('DEMO')) return;
        if (isListening) return;

        isListening = true;
        console.log("🟢 Panel Lateral: Conectado a actualizaciones en vivo.");

        onSnapshot(doc(db, "datos_usuarios", licenciaKey), (docSnap) => {
            chrome.storage.local.get(null, (local) => {
                if (docSnap.exists()) {
                    const nubeData = docSnap.data();

                    // 🚨 DETECTOR DE ORDEN DE RESETEO SEGURO DESDE EL MASTER
                    if (nubeData.forzarReset === true) {
                        console.warn("⚠️ ALERTA: Orden de reset explícita recibida desde el Master Panel.");
                        ejecutarResetSeguro("⚠️ AVISO DEL ADMINISTRADOR ⚠️\n\nSe ha realizado un restablecimiento completo de sus datos.\n\n🛡️ HEMOS DESCARGADO UNA COPIA DE TUS DATOS automáticamente.\n\nEl Panel Lateral se reiniciará.", 'SOLO_DATOS');
                        return;
                    }

                    // Flujo normal de actualización
                    const localTime = local.last_modified || 0;
                    const cloudTime = nubeData.last_modified || 0;

                    if (cloudTime > localTime) {
                        console.log("☁️ Panel: Recibiendo datos nuevos...");
                        chrome.storage.local.set({
                            profiles: nubeData.profiles,
                            inventoryEnabled: nubeData.inventoryEnabled,
                            last_modified: cloudTime
                        }, () => {
                            loadPopupData();
                        });
                    }
                }
                else {
                    console.log("🛡️ Documento no encontrado en la nube. Manteniendo datos locales intactos.");
                }
            });
        });
    }

    // =========================================================
    // 7. CARGA DE DATOS
    // =========================================================
    function loadPopupData() {
        chrome.storage.local.get(null, (data) => {
            if (ui.productQty) ui.productQty.value = 1;

            if (!data.profiles || !data.currentProfile) {
                const initialData = { profiles: { 'Default': { clients: [], products: [] } }, currentProfile: 'Default' };
                chrome.storage.local.set(initialData, () => loadPopupData());
                return;
            }

            if (data.licencia) {
                verificarCambioPlan(data.licencia, data.activationStatus);
                iniciarEscuchaRealTime(data.licencia);
            }

            const profileKeys = Object.keys(data.profiles);
            profileDropdown.setItems(profileKeys);

            let currentPData = data.profiles[data.currentProfile];
            if (!currentPData) {
                const firstKey = profileKeys[0];
                data.currentProfile = firstKey;
                currentPData = data.profiles[firstKey];
                chrome.storage.local.set({ currentProfile: firstKey });
            }

            profileDropdown.setValue(data.currentProfile);

            state.clients = (currentPData.clients || []).filter(c => !c.deletedAt);
            clientDropdown.setItems(state.clients.map(c => ({ ...c, displayText: c.nombreCliente })));

            if (state.clients.length) {
                ui.fillClienteBtn.disabled = true;
                if (currentPData.lastUsedClientId) {
                    const lastCli = state.clients.find(c => c.id == currentPData.lastUsedClientId);
                    if (lastCli) {
                        clientDropdown.setValue(lastCli.nombreCliente);
                        state.selectedClient = lastCli;
                        ui.fillClienteBtn.disabled = false;
                        ui.sendMailIcon.classList.remove('disabled');
                    } else { ui.clientInput.value = ''; }
                } else { ui.clientInput.value = ''; }
            } else {
                clientDropdown.clear();
                ui.clientInput.placeholder = "No hay clientes";
                ui.fillClienteBtn.disabled = true;
            }

            const prods = (currentPData.products || []).filter(p => !p.deletedAt);
            const plan = data.activationStatus || "DEMO";
            const licenseAllowsInventory = (plan === 'PRO_INV' || plan === 'DEMO_INV');
            const isInventoryEnabled = licenseAllowsInventory && (currentPData.inventoryEnabled !== false);

            state.products = [];
            state.selectedProduct = null;

            if (prods.length) {
                ui.addProductoBtn.disabled = false;
                prods.sort((a, b) => a.descripcion.localeCompare(b.descripcion));

                state.products = prods.map(p => {
                    const stock = p.stock !== undefined ? p.stock : 0;
                    const baseDisplay = p.descripcion;
                    const filterDisplay = isInventoryEnabled ? `${baseDisplay} (Stock: ${stock})` : baseDisplay;
                    const inputDisplay = p.codigo ? `[${p.codigo}] ${p.descripcion}` : p.descripcion;

                    return {
                        id: p.id,
                        codigo: p.codigo || '',
                        descripcion: p.descripcion,
                        display: filterDisplay,
                        fullText: inputDisplay,
                        displayText: inputDisplay,
                        stock: stock,
                        showStock: isInventoryEnabled,
                        raw: p,
                        precio: p.precio,
                        unidadMedida: p.unidadMedida,
                        tipo: p.tipo
                    };
                });

                productDropdown.setItems(state.products);

                if (currentPData.lastUsedProductId) {
                    const lastProd = state.products.find(x => x.id == currentPData.lastUsedProductId);
                    if (lastProd) {
                        productDropdown.setValue(lastProd.fullText);
                        state.selectedProduct = lastProd;
                    } else { ui.productInput.value = ''; }
                } else { ui.productInput.value = ''; }
            } else {
                ui.addProductoBtn.disabled = true;
                ui.productInput.placeholder = "No hay productos";
                productDropdown.clear();
            }

            chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
                if (tabs[0]) chrome.scripting.executeScript({ target: { tabId: tabs[0].id }, func: injectDeleteWatcher });
            });
        });
    }

    // --- SINCRONIZACIÓN ---
    async function sync() {
        if (document.activeElement && document.activeElement.tagName === "INPUT") return;
        chrome.storage.local.get(null, async (localData) => {
            if (!localData.licencia) return;
            const PUBLIC_DEMO_KEYS = ["DEMO-2025", "DEMO-INV-2025"];
            if (localData.licencia && !PUBLIC_DEMO_KEYS.includes(localData.licencia)) {
                try { await actualizarHoraFirebase(localData.licencia); } catch (e) { }
            }
        });
    }
    setInterval(sync, 4000);

    // =========================================================
    // 8. ACCIONES DE BOTONES
    // =========================================================
    ui.fillClienteBtn.addEventListener('click', () => {
        if (!state.selectedClient) return alert("Selecciona un cliente primero");

        chrome.storage.local.get(null, async (d) => {
            d.profiles[d.currentProfile].lastUsedClientId = state.selectedClient.id;
            chrome.storage.local.set(d);

            const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
            chrome.scripting.executeScript({
                target: { tabId: tab.id },
                func: fillClientData,
                args: [state.selectedClient]
            });
        });
    });

    ui.addProductoBtn.addEventListener('click', async () => {
        if (!state.selectedProduct) {
            const txt = ui.productInput.value.trim();
            const match = state.products.find(p => p.fullText === txt || p.descripcion === txt);
            if (match) state.selectedProduct = match;
            else return alert("⚠️ Selecciona un producto de la lista.");
        }

        const qty = parseInt(ui.productQty.value);
        if (qty <= 0) return alert("Cantidad inválida");

        chrome.storage.local.get(null, async (d) => {
            const plan = d.activationStatus || "DEMO";
            const isInv = (plan.includes('INV')) && (d.profiles[d.currentProfile].inventoryEnabled !== false);

            if (isInv) {
                if (state.selectedProduct.stock < qty) {
                    return alert(`⛔ STOCK INSUFICIENTE\nDisponible: ${state.selectedProduct.stock}`);
                }
                state.selectedProduct.stock -= qty;
            }

            d.profiles[d.currentProfile].lastUsedProductId = state.selectedProduct.id;
            const pReal = d.profiles[d.currentProfile].products.find(x => x.id === state.selectedProduct.id);

            if (pReal) {
                const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
                chrome.scripting.executeScript({ target: { tabId: tab.id }, func: fillFormOnly, args: [pReal, qty] });

                if (isInv) {
                    let cliName = "Cliente General";
                    if (state.selectedClient) cliName = state.selectedClient.nombreCliente;
                    else if (ui.clientInput.value) cliName = ui.clientInput.value;

                    chrome.runtime.sendMessage({
                        action: 'START_INVOICE_WATCH',
                        data: {
                            product: pReal,
                            quantity: qty,
                            profileName: d.currentProfile,
                            tabId: tab.id,
                            clientName: cliName
                        }
                    }, () => { let ignorar = chrome.runtime.lastError; });
                }
            }
            chrome.storage.local.set(d);
        });
    });

    ui.sendMailIcon.addEventListener('click', () => {
        if (!state.selectedClient || !state.selectedClient.email) return alert('Cliente sin correo o no seleccionado.');
        const c = state.selectedClient;

        chrome.storage.local.get(null, (d) => {
            const perfil = d.currentProfile;
            const ventas = d.profiles[perfil].ventas || [];

            let codigoGen = "---";
            let numControl = "---";
            let totalPagar = "$0.00";

            if (ventas.length > 0) {
                const ultimaVenta = ventas[ventas.length - 1];
                if (ultimaVenta.codigo) codigoGen = ultimaVenta.codigo;
                if (ultimaVenta.numeroControl) numControl = ultimaVenta.numeroControl;
                if (ultimaVenta.total) totalPagar = "$" + parseFloat(ultimaVenta.total).toFixed(2);
            }

            const subject = "Documento Tributario Electrónico";
            const body = `Estimado cliente, ${c.nombreCliente}

Muchas gracias por su compra.

A continuación, le adjunto los archivos de su factura electrónica.

Saludos. –
____________________________________________________________________
Resumen del Documento:
 
Código de Generación: ${codigoGen}
Número de Control: ${numControl}
Total a pagar: ${totalPagar}`;

            const link = `mailto:${c.email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
            window.open(link);
        });
    });

    // =========================================================
    // 9. LÓGICA DEL TOUR (ACTUALIZADA)
    // =========================================================
    if (ui.startTourBtn) {
        let tourActivo = false;

        const resetVisuals = () => {
            tourActivo = false;
            ui.startTourBtn.classList.remove('is-active');

            if (ui.sosEmoji) ui.sosEmoji.textContent = '🆘';
            if (ui.sosText) ui.sosText.style.display = 'none';
        };

        ui.startTourBtn.addEventListener('click', async () => {
            const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

            if (!tab.url.startsWith('http')) return alert("El tour solo funciona en la página del Ministerio.");

            if (tourActivo) {
                try {
                    await chrome.tabs.sendMessage(tab.id, { action: "STOP_TOUR" });
                } catch (e) { console.log("Tour ya cerrado"); }
                resetVisuals();
            } else {
                try {
                    tourActivo = true;
                    ui.startTourBtn.classList.add('is-active');

                    if (ui.sosEmoji) ui.sosEmoji.textContent = '❌';
                    if (ui.sosText) ui.sosText.style.display = 'inline-block';

                    await chrome.scripting.insertCSS({ target: { tabId: tab.id }, files: ['driver.css'] });
                    await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ['driver.min.js'] });
                    await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ['tour_runner.js'] });

                } catch (err) {
                    console.error(err);
                    resetVisuals();
                    alert("Error al cargar el tour.");
                }
            }
        });

        chrome.runtime.onMessage.addListener((req, sender, sendResponse) => {
            if (req.action === "TOUR_ENDED") resetVisuals();
            sendResponse({ status: "ok" });
            return true;
        });
    }

    chrome.runtime.onMessage.addListener((req, sender, sendResponse) => {
        if (req.action === "CLOSE_SIDEPANEL") window.close();
        if (req.action.includes("RESTORE") || req.action.includes("RESET")) loadPopupData();
        sendResponse({ status: "ok" });
        return true;
    });

    window.addEventListener('blur', () => {
        ui.profileList.classList.remove('show');
        ui.clientList.classList.remove('show');
        ui.productList.classList.remove('show');
    });

    loadPopupData();
});

// =========================================================
// 9. SCRIPTS INYECTADOS
// =========================================================
function injectDeleteWatcher() {
    if (window.hasDeleteWatcher) return;
    window.hasDeleteWatcher = true;
    document.body.addEventListener('click', function (e) {
        const btn = e.target.closest('button.btn.btn-outline-primary.btn-add');
        const icon = e.target.classList.contains('fa-times');
        if (btn || (icon && e.target.closest('button'))) {
            const row = e.target.closest('tr');
            if (row && row.cells[1] && row.cells[2]) {
                chrome.runtime.sendMessage({
                    action: "RESTORE_ROW_STOCK",
                    productName: row.cells[1].textContent.trim(),
                    quantity: row.cells[2].textContent.trim()
                }, () => { let ignorar = chrome.runtime.lastError; });
            }
        }
    });
}

async function fillFormOnly(product, quantity) {
    function setVal(sel, val) {
        const inputs = document.querySelectorAll(sel);
        for (const el of inputs) {
            if (el.offsetParent !== null) {
                el.value = val;
                ['input', 'change', 'blur'].forEach(ev => el.dispatchEvent(new Event(ev, { bubbles: true })));
                return;
            }
        }
    }
    const unit = product.unidadMedida || '59';
    let type = '1';
    if (product.tipo === 'Servicio') type = '2';
    if (product.tipo === 'Bien y Servicio') type = '3';

    const desc = product.codigo ? `[${product.codigo}] ${product.descripcion}` : product.descripcion;

    setVal("select[formcontrolname='unidad']", unit);
    setVal("select[formcontrolname='tipoItem']", type);
    setVal("select[formcontrolname='tipo']", type);
    setVal("input[formcontrolname='descripcion']", desc);
    setVal("input[formcontrolname='producto']", desc);
    setVal("input[formcontrolname='Tipo Producto']", desc);
    setVal("input[formcontrolname='precioUnitario']", product.precio);
    setVal("input[formcontrolname='precio']", product.precio);
    setVal("input[formcontrolname='cantidad']", quantity);
}

async function fillClientData(client) {
    const fire = (el, ev) => el.dispatchEvent(new Event(ev, { bubbles: true }));
    const wait = (sel) => new Promise(r => { let t = 0, i = setInterval(() => { if (document.querySelector(sel)) { clearInterval(i); r(document.querySelector(sel)) } if ((t += 100) > 5000) { clearInterval(i); r(null) } }, 100) });
    const fill = (sel, val) => {
        const els = document.querySelectorAll(sel);
        for (const el of els) if (el.offsetParent !== null) { el.value = val; fire(el, 'input'); fire(el, 'change'); fire(el, 'blur'); return; }
    };
    const fillList = (val, sels) => { for (const s of sels) fill(s, val); };

    async function fillNg(sel, val) {
        const el = document.querySelector(sel); if (!el || !val) return;
        fire(el, 'mousedown');
        const input = await wait('div.ng-input > input'); if (input) { input.value = val; fire(input, 'input'); }
        const panel = await wait('.ng-dropdown-panel'); if (panel) {
            await new Promise(r => setTimeout(r, 300));
            const opts = Array.from(panel.querySelectorAll('.ng-option'));
            const target = opts.find(o => o.textContent.trim().startsWith(val)) || opts[0];
            if (target) fire(target, 'click');
        }
    }

    async function fillDrop(sels, val) {
        if (!val) return;
        for (const s of sels) {
            const el = document.querySelector(s);
            if (el) {
                if (el.tagName === 'SELECT') {
                    const opts = Array.from(el.options);
                    const t = opts.find(o => o.value === val) || opts.find(o => o.text.toUpperCase().includes(val.toUpperCase()));
                    if (t) { el.value = t.value; fire(el, 'change'); fire(el, 'blur'); return; }
                } else if (el.tagName === 'NG-SELECT') { await fillNg(s, val); return; }
            }
        }
    }

    fillList(client.nit, ["input[formcontrolname='nit']", 'input[id*="nit"]']);
    fillList(client.nombreCliente, ["input[formcontrolname='nombreReceptor']", "input[formcontrolname='nombreCliente']", "input[formcontrolname='nombre']"]);
    await fillDrop(["ng-select[formcontrolname='paises']", "select[formcontrolname='paises']"], client.pais);

    if (client.tipoPersona) {
        const t = client.tipoPersona === "NATURAL" ? "NATURAL" : (client.tipoPersona === "JURÍDICA" ? "JURÍDICA" : null);
        if (t) await fillDrop(["select[formcontrolname='tipoPersona']"], t);
    }
    fillList(client.nrc, ["input[formcontrolname='nrcCliente']", "input[formcontrolname='nrc']", "input[formcontrolname='nrcReceptor']"]);
    fillList(client.nombreComercial, ["input[formcontrolname='nombreComercial']"]);

    const actC = (client.actividadEconomica || "").split(' - ')[0];
    await fillDrop(["ng-select[formcontrolname='codActividad']", "ng-select[formcontrolname='actividadEconomica']", "select[formcontrolname='actividadEconomica']"], actC);
    fillList(client.actividadEconomica, ["input[formcontrolname='descActividad']", "input[formcontrolname='actividadEconomica']"]);

    await fillDrop(["ng-select[formcontrolname='departamento']", "select[formcontrolname='departamento']"], (client.departamento || "").split(' - ')[0]);
    await fillDrop(["ng-select[formcontrolname='municipio']", "select[formcontrolname='municipio']"], (client.municipio || "").split(' - ')[0]);

    fillList(client.direccion, ["textarea[formcontrolname='complementoReceptor']", "textarea[formcontrolname='complemento']", "input[formcontrol-name='direccion']"]);
    fillList(client.email, ["input[formcontrolname='correoReceptor']", "input[formcontrolname='correo']"]);
    fillList(client.telefono, ["input[formcontrolname='telefonoReceptor']", "input[formcontrolname='telefono']"]);

    const docSel = document.querySelector("select[formcontrolname='tipoDocumento']");
    if (docSel) {
        let v = null, s = ["input[formcontrolname='otro']"];
        const t = docSel.options[docSel.selectedIndex].text.toLowerCase();
        if (t.includes('dui')) { v = client.dui; s = ["input[formcontrolname='dui']"]; }
        else if (t.includes('pasaporte')) v = client.pasaporte;
        else if (t.includes('residente')) v = client.carnetResidente;
        else if (t.includes('otro')) v = client.otroDocumento;
        if (v) fillList(v, s);
    } else fillList(client.dui, ["input[formcontrolname='dui']"]);
}