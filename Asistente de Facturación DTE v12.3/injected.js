// injected.js - V12.0: BLOQUEO TOTAL DE ANULACIONES Y MONTOS CERO

(function() {
    function tryParse(str) {
        try { return JSON.parse(str); } catch (e) { return null; }
    }

    // --- 1. RADAR RECURSIVO ---
    function buscarClaveRecursiva(obj, keyBusqueda) {
        if (!obj || typeof obj !== 'object') return null;
        if (obj.hasOwnProperty(keyBusqueda) && obj[keyBusqueda]) return obj[keyBusqueda];
        for (let key in obj) {
            if (key.toLowerCase().includes("relacionado")) continue; 
            if (obj.hasOwnProperty(key) && typeof obj[key] === 'object') {
                const res = buscarClaveRecursiva(obj[key], keyBusqueda);
                if (res) return res;
            }
        }
        return null;
    }

    // --- A. CAPTURA VISUAL ---
    function capturarValorVisual() {
        // Estrategia Inputs
        const selectoresInput = [
            "input[formcontrolname='montoPago']", "input[formcontrolname='totalPagar']",
            "input[formcontrolname='totalOperacion']", "input[formcontrolname='montoTotal']",
            "input[id='totalPago']", "input.total-amount"
        ];
        for (const selector of selectoresInput) {
            const input = document.querySelector(selector);
            if (input) {
                let val = input.value || input.getAttribute('value');
                if (val) {
                    val = val.toString().replace(/[^0-9.]/g, '');
                    if (val && parseFloat(val) > 0) return val;
                }
            }
        }
        // Estrategia Texto
        const etiquetasClave = ["TOTAL A PAGAR", "TOTAL OPERACIÓN", "MONTO TOTAL", "TOTAL"];
        const elementosTexto = document.querySelectorAll("td, th, div, label, span, strong, b");
        for (const el of elementosTexto) {
            const texto = (el.innerText || "").toUpperCase().trim().replace(":", "");
            if (etiquetasClave.includes(texto)) {
                let hermano = el.nextElementSibling;
                let intentos = 3; 
                while (hermano && intentos > 0) {
                    const valTexto = (hermano.innerText || "").trim();
                    if (valTexto.includes("$") || /^[0-9.,]+$/.test(valTexto)) {
                        const valLimpio = valTexto.replace(/[^0-9.]/g, '');
                        if (valLimpio && parseFloat(valLimpio) >= 0) return valLimpio;
                    }
                    hermano = hermano.nextElementSibling;
                    intentos--;
                }
            }
        }
        return "0.00"; 
    }

    function capturarTipoVisual() {
        const MAPA_VISUAL = {
            "CRÉDITO FISCAL": "Crédito Fiscal", "EXPORTACIÓN": "Exportación",
            "SUJETO EXCLUIDO": "Sujeto Excluido", "NOTA DE REMISIÓN": "Nota de Remisión",
            "NOTA DE CRÉDITO": "Nota de Crédito", "NOTA DE DÉBITO": "Nota de Débito",
            "RETENCIÓN": "Retención", "LIQUIDACIÓN": "Liquidación", "DONACIÓN": "Donación",
            "FACTURA": "Factura"
        };
        const headers = document.querySelectorAll("h1, h2, h3, h4, h5, .title");
        for (const h of headers) {
            if(!h.innerText) continue;
            const txt = h.innerText.toUpperCase();
            for (const [key, val] of Object.entries(MAPA_VISUAL)) {
                if (txt.includes(key)) return val;
            }
        }
        return "Factura";
    }

    function capturarClienteVisual() {
        const selectores = [
            "input[formcontrolname='nombre']", "input[formcontrolname='razonSocial']",
            "input[formcontrolname='nombreComercial']", "input[formcontrolname='nombreReceptor']"
        ];
        for (const sel of selectores) {
            const input = document.querySelector(sel);
            if (input && input.value && input.value.trim().length > 2) return input.value.trim().toUpperCase();
        }
        return null;
    }

    function capturarItemsVisuales() {
        const items = [];
        const tablas = document.querySelectorAll("table");
        tablas.forEach(tabla => {
            const ths = tabla.querySelectorAll("th");
            let idxDesc = -1, idxCant = -1;
            ths.forEach((th, i) => {
                const t = th.innerText.toLowerCase();
                if (t.includes("descrip") || t.includes("producto")) idxDesc = i;
                if (t.includes("cant")) idxCant = i;
            });
            if (idxDesc >= 0 && idxCant >= 0) {
                tabla.querySelectorAll("tbody tr").forEach(fila => {
                    const tds = fila.querySelectorAll("td");
                    if (tds[idxDesc] && tds[idxCant]) {
                        const d = tds[idxDesc].innerText.trim();
                        const c = parseFloat(tds[idxCant].innerText.replace(/[^0-9.]/g, '')) || 1;
                        if (d.length > 1) items.push({ descripcion: d, cantidad: c });
                    }
                });
            }
        });
        return items;
    }

    // --- E. REPORTE INTELIGENTE (Cerebro) ---
    function reportarDTE(origen, data, requestBody, urlRequest) {
        
        // 1. 🛡️ FILTRO URL: Si dice "anular" o "invalidar", ADIÓS.
        const urlStr = (urlRequest || "").toLowerCase();
        if (urlStr.includes('anulardte') || urlStr.includes('invalidar')) {
            console.warn("⛔ Anulación detectada por URL. Ignorando.");
            return; 
        }

        // 2. Extracción de Datos
        let codigoGen = null;
        if (data && data.identificacion && data.identificacion.codigoGeneracion) codigoGen = data.identificacion.codigoGeneracion;
        else if (data && data.dteJson && data.dteJson.identificacion && data.dteJson.identificacion.codigoGeneracion) codigoGen = data.dteJson.identificacion.codigoGeneracion;
        
        if (!codigoGen) codigoGen = buscarClaveRecursiva(data, 'codigoGeneracion');
        if (!codigoGen && requestBody) codigoGen = buscarClaveRecursiva(requestBody, 'codigoGeneracion');

        const sello = buscarClaveRecursiva(data, 'selloRecibido') || buscarClaveRecursiva(data, 'firma');

        // 3. 🛡️ FILTRO MONTO CERO (LA REGLA DE ORO)
        // Si detectamos código, verificamos el monto visual antes de enviar nada.
        if (codigoGen || sello) {
            const montoVisual = capturarValorVisual();
            const montoNum = parseFloat(montoVisual);

            // ¡AQUÍ ESTÁ LA MAGIA! Si es 0.00, no se envía.
            if (montoNum === 0) {
                console.warn("⛔ DTE con Monto $0.00 detectado (Posible Anulación). Ignorando.");
                return;
            }

            const clienteVisual = capturarClienteVisual(); 
            const tipoVisual = capturarTipoVisual();
            const itemsVisuales = capturarItemsVisuales();

            const payload = {
                _origen: origen,
                _solicitudOriginal: requestBody,
                _respuesta: data,
                _montoVisual: montoVisual,
                _tipoVisual: tipoVisual,
                _clienteVisual: clienteVisual,
                _itemsVisuales: itemsVisuales,
                codigoGeneracion: codigoGen,
                selloRecibido: sello
            };

            // Solo enviamos si pasó todos los filtros
            window.postMessage({ type: 'DTE_DETECTADO_REAL', payload: payload }, window.location.origin);
        }
    }

    // --- INTERCEPTORES (Con captura de URL mejorada) ---
    const originalFetch = window.fetch;
    window.fetch = async (...args) => {
        let reqBody = null;
        // Captura robusta de URL (soporta objetos Request)
        let url = "";
        if (args[0]) {
            url = (typeof args[0] === 'string') ? args[0] : (args[0].url || args[0].toString());
        }

        if (args[1] && args[1].body) reqBody = tryParse(args[1].body);

        const response = await originalFetch(...args);
        const clone = response.clone();
        
        clone.json().then(data => reportarDTE('FETCH', data, reqBody, url)).catch(() => {});
        return response;
    };

    const originalOpen = XMLHttpRequest.prototype.open;
    const originalSend = XMLHttpRequest.prototype.send;
    
    XMLHttpRequest.prototype.open = function(method, url) {
        this._requestUrl = url; 
        this.addEventListener('load', function() {
            const data = tryParse(this.responseText);
            reportarDTE('XHR', data, this._reqBody, this._requestUrl);
        });
        originalOpen.apply(this, arguments);
    };
    
    XMLHttpRequest.prototype.send = function(body) {
        if (body) this._reqBody = tryParse(body);
        originalSend.apply(this, arguments);
    };

    console.log("🛡️ Injected v12.3: Filtro Estricto ($0.00 + Anulaciones) ACTIVO");
})();

(function() { window.fillFormOnly = async function(p, q) {}; })();