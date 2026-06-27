// inventory_service.js
// V4.2: Búsqueda Bilateral (Limpia tanto la factura como el inventario) + Logs

// --- HELPER INTERNO: LIMPIAR NOMBRE ---
// Quita corchetes al inicio, ej: "[ABC] Producto" -> "PRODUCTO"
function limpiarTexto(texto) {
    if (!texto) return "";
    return String(texto)
        .replace(/^\[.*?\]\s*/, "") // Quitar [Codigo] del inicio
        .trim()
        .toUpperCase();
}

export const InventoryService = {

    // =========================================================
    // 1. MÉTODOS VISUALES (Popup)
    // =========================================================

    validarYDescontarStock: function(productSelector, qtyRequested) {
        if (!this.validarStockVisual(productSelector, qtyRequested)) return false;
        this.descontarVisualmente(productSelector, qtyRequested);
        return true;
    },

    validarStockVisual: function(productSelector, qtyRequested) {
        const selectedOption = productSelector.options[productSelector.selectedIndex];
        if (!selectedOption) return false;

        let text = selectedOption.textContent;
        let match = text.match(/\(Stock: (-?\d+)\)/);
        
        if (match) {
            let currentVisualStock = parseInt(match[1]);
            if (currentVisualStock < qtyRequested) {
                alert(`⛔ STOCK INSUFICIENTE\nDisponible: ${currentVisualStock}\nSolicitado: ${qtyRequested}`);
                return false;
            }
        }
        return true;
    },

    descontarVisualmente: function(productSelector, qty) {
        const selectedOption = productSelector.options[productSelector.selectedIndex];
        if (!selectedOption) return;
        
        let text = selectedOption.textContent;
        let match = text.match(/\(Stock: (-?\d+)\)/);
        
        if (match) {
            let current = parseInt(match[1]);
            let nuevo = current - qty;
            let cleanText = text.replace(/\(Stock: -?\d+\)/, '').trim();
            selectedOption.textContent = `${cleanText} (Stock: ${nuevo})`;
        }
    },

    // =========================================================
    // 2. LÓGICA DE NEGOCIO
    // =========================================================

    registrarMovimiento: function(tipo, productoNombre, cantidad, referencia, cliente) {
        return new Promise((resolve) => {
            chrome.storage.local.get(null, (data) => {
                const perfil = data.currentProfile;
                if (!data.profiles[perfil].inventory_history) {
                    data.profiles[perfil].inventory_history = [];
                }
                
                data.profiles[perfil].inventory_history.push({
                    fecha: new Date().toISOString(),
                    fechaLegible: new Date().toLocaleString(),
                    tipo: tipo,
                    producto: productoNombre,
                    cantidad: cantidad,
                    referencia: referencia,
                    cliente: cliente || "General",
                    usuario: data.nombreUsuario || "Sistema"
                });
                
                chrome.storage.local.set(data, () => resolve(true));
            });
        });
    },

    // --- PROCESAR VENTA (DESCONTAR) ---
    procesarVentaConfirmada: function(itemsVendidos, codigoGeneracion, nombreCliente) {
        if (!itemsVendidos || itemsVendidos.length === 0) return;

        console.log("📦 Procesando inventario para:", codigoGeneracion);

        chrome.storage.local.get(null, (data) => {
            const perfil = data.currentProfile;
            const profileData = data.profiles[perfil];
            if (!profileData) return;

            let products = profileData.products || [];
            let historial = profileData.inventory_history || [];
            let huboCambios = false;

            itemsVendidos.forEach(item => {
                const rawName = item.descripcion || item.description || item.nombre || item.producto || "";
                const cantRaw = item.cantidad || item.quantity || item.cant || 0;
                const cantidad = parseFloat(cantRaw);
                const codigoItem = String(item.codigo || "").trim().toUpperCase();

                if (!rawName || cantidad <= 0) return;

                const nombreItemLimpio = limpiarTexto(rawName);

                // BÚSQUEDA ROBUSTA
                const prodIndex = products.findIndex(p => {
                    const nombreInvOriginal = String(p.descripcion || "").toUpperCase();
                    const nombreInvLimpio = limpiarTexto(p.descripcion);
                    const codigoInv = String(p.codigo || "").trim().toUpperCase();

                    // 1. Coincidencia de Código (Prioridad Máxima)
                    if (codigoItem && codigoInv && codigoItem === codigoInv) return true;

                    // 2. Coincidencia de Nombre (Limpio vs Limpio)
                    // Esto permite que "[WE] Prueba" coincida con "Prueba" o con "[WE] Prueba"
                    if (nombreItemLimpio === nombreInvLimpio) return true;

                    // 3. Coincidencia Exacta (Fallback)
                    if (String(rawName).trim().toUpperCase() === nombreInvOriginal) return true;

                    return false;
                });

                if (prodIndex !== -1) {
                    let stockActual = parseFloat(products[prodIndex].stock) || 0;
                    products[prodIndex].stock = stockActual - cantidad;
                    huboCambios = true;

                    historial.push({
                        fecha: new Date().toISOString(),
                        fechaLegible: new Date().toLocaleString(),
                        tipo: 'SALIDA',
                        producto: products[prodIndex].descripcion,
                        cantidad: cantidad,
                        referencia: codigoGeneracion,
                        cliente: nombreCliente || "Cliente General",
                        usuario: "Sistema"
                    });
                    console.log(`✅ MATCH! Descontado: ${products[prodIndex].descripcion}`);
                } else {
                    console.warn(`❌ NO ENCONTRADO: ${rawName} (Limpio: ${nombreItemLimpio})`);
                }
            });

            if (huboCambios) {
                if (historial.length > 1000) historial = historial.slice(0, 1000);
                data.profiles[perfil].products = products;
                data.profiles[perfil].inventory_history = historial;
                chrome.storage.local.set(data, () => {
                    chrome.runtime.sendMessage({ action: 'INVENTORY_UPDATED' });
                });
            }
        });
    },

    // --- REVERTIR VENTA (DEVOLVER AL STOCK) ---
    revertirVenta: function(itemsVendidos, referencia, motivo) {
        return new Promise((resolve) => {
            console.log("♻️ INICIANDO PROCESO DE REVERSIÓN...");

            if (!itemsVendidos || itemsVendidos.length === 0) {
                console.warn("⚠️ Lista de items vacía, nada que devolver.");
                resolve(false);
                return;
            }

            chrome.storage.local.get(null, (data) => {
                const perfil = data.currentProfile;
                const profileData = data.profiles[perfil];
                if (!profileData) { 
                    console.error("❌ Perfil no encontrado.");
                    resolve(false); return; 
                }

                let products = profileData.products || [];
                let historial = profileData.inventory_history || [];
                let huboCambios = false;

                itemsVendidos.forEach(item => {
                    const rawName = item.descripcion || item.description || item.nombre || "";
                    const cantidad = parseFloat(item.cantidad || item.quantity || 0);
                    const itemCod = String(item.codigo || "").trim().toUpperCase();

                    if (cantidad > 0) {
                        const nombreItemLimpio = limpiarTexto(rawName);
                        
                        console.log(`🔎 Buscando en inventario para devolver: "${nombreItemLimpio}" (Cod: ${itemCod})`);

                        const prodIndex = products.findIndex(p => {
                            const nombreInvLimpio = limpiarTexto(p.descripcion);
                            const codigoInv = String(p.codigo || "").trim().toUpperCase();

                            // LOGICA DE MATCH IGUAL QUE EN EL DESCUENTO
                            if (itemCod && codigoInv && itemCod === codigoInv) return true;
                            if (nombreItemLimpio === nombreInvLimpio) return true;
                            
                            return false;
                        });

                        if (prodIndex !== -1) {
                            let stockActual = parseFloat(products[prodIndex].stock) || 0;
                            products[prodIndex].stock = stockActual + cantidad;
                            huboCambios = true;

                            historial.push({
                                fecha: new Date().toISOString(),
                                fechaLegible: new Date().toLocaleString(),
                                tipo: 'ENTRADA',
                                producto: products[prodIndex].descripcion,
                                cantidad: cantidad,
                                referencia: referencia,
                                cliente: "REINTEGRO (Eliminación)",
                                usuario: data.nombreUsuario || "Sistema"
                            });
                            console.log(`✅ REINTEGRADO: ${products[prodIndex].descripcion} (+${cantidad}). Nuevo Stock: ${products[prodIndex].stock}`);
                        } else {
                            console.warn(`❌ FALLÓ BUSQUEDA REVERSIÓN: "${rawName}" no coincide con nada en inventario.`);
                        }
                    }
                });

                if (huboCambios) {
                    data.profiles[perfil].products = products;
                    data.profiles[perfil].inventory_history = historial;
                    
                    chrome.storage.local.set(data, () => {
                        console.log("💾 Reversión guardada en DB local.");
                        chrome.runtime.sendMessage({ action: 'INVENTORY_UPDATED' });
                        resolve(true); // ÉXITO
                    });
                } else {
                    console.warn("⚠️ No se realizó ningún cambio en el stock.");
                    resolve(false);
                }
            });
        });
    }
};