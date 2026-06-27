/**
 * Módulo para interactuar con la API de Gmail.
 * Maneja la autenticación OAuth2 y la extracción de facturas DTE (.json)
 */

let memoryTokenObj = null;

export async function authorizeUser(interactive = true) {
    // 1. Check if we have a valid cached token
    const tokenObj = memoryTokenObj || await new Promise(res => chrome.storage.local.get('gAuthTokenObj', data => res(data.gAuthTokenObj)));
    
    if (tokenObj && tokenObj.token && tokenObj.expiry > Date.now()) {
        return tokenObj.token;
    }
    
    if (!interactive) {
        return Promise.reject(new Error("No valid token in cache and interactive is false"));
    }
    
    // 2. Fetch a new one
    return new Promise((resolve, reject) => {
        const manifest = chrome.runtime.getManifest();
        const clientId = manifest.oauth2.client_id;
        const scopes = manifest.oauth2.scopes.join(' ');
        const redirectUri = chrome.identity.getRedirectURL();

        const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&response_type=token&redirect_uri=${encodeURIComponent(redirectUri)}&scope=${encodeURIComponent(scopes)}`;

        chrome.identity.launchWebAuthFlow({
            url: authUrl,
            interactive: interactive
        }, function(redirectUrl) {
            if (chrome.runtime.lastError || !redirectUrl) {
                return reject(chrome.runtime.lastError || new Error("Auth failed"));
            }
            
            const urlObj = new URL(redirectUrl);
            const params = new URLSearchParams(urlObj.hash.substring(1));
            const token = params.get('access_token');
            const expiresIn = params.get('expires_in');
            
            if (token) {
                const expiry = Date.now() + (parseInt(expiresIn || 3599) * 1000) - 60000;
                const newTokenObj = { token, expiry };
                memoryTokenObj = newTokenObj;
                chrome.storage.local.set({ gAuthTokenObj: newTokenObj }, () => resolve(token));
            } else {
                reject(new Error("No token found"));
            }
        });
    });
}

export async function fetchUserEmail(token) {
    try {
        const response = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/profile', {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        if (response.ok) {
            const data = await response.json();
            return data.emailAddress;
        }
    } catch (e) { console.error("Error obteniendo perfil:", e); }
    return null;
}

export async function logoutUser() {
    return new Promise(async (resolve) => {
        const tokenObj = memoryTokenObj || await new Promise(res => chrome.storage.local.get('gAuthTokenObj', data => res(data.gAuthTokenObj)));
        const token = tokenObj ? tokenObj.token : null;
        
        memoryTokenObj = null;
        chrome.storage.local.remove('gAuthTokenObj', () => {
             if (token) {
                 fetch('https://accounts.google.com/o/oauth2/revoke?token=' + token)
                     .then(() => resolve())
                     .catch(() => resolve());
             } else {
                 resolve();
             }
        });
    });
}

// Búsqueda de correos (Ajustar "filename:json" para asegurar que tenga json)
export async function fetchRecentInvoices(token, timeQuery = "newer_than:30d") {
    const query = `filename:json ${timeQuery} -in:sent`;
    console.log("Consultando Gmail sugerido:", query);
    
    // Primero obtener la lista de mensajes
    const searchUrl = new URL('https://gmail.googleapis.com/gmail/v1/users/me/messages');
    searchUrl.searchParams.append('q', query);
    searchUrl.searchParams.append('maxResults', '500');

    const response = await fetch(searchUrl.toString(), {
        headers: {
            'Authorization': `Bearer ${token}`
        }
    });

    if (!response.ok) {
        throw new Error('No se pudo acceder a la bandeja de entrada de Gmail.');
    }

    const data = await response.json();
    if (!data.messages || data.messages.length === 0) {
        return [];
    }

    // Por cada mensaje, traer el contenido
    const invoices = [];
    for (const message of data.messages) {
        const fullMessage = await getMessageDetails(message.id, token);
        if (fullMessage) {
            const extracted = await extractJsonAttachments(fullMessage, message.id, token);
            if (extracted && extracted.length > 0) {
                invoices.push(...extracted);
            }
        }
    }
    
    return invoices;
}

async function getMessageDetails(messageId, token) {
    const url = `https://gmail.googleapis.com/gmail/v1/users/me/messages/${messageId}`;
    const response = await fetch(url, {
        headers: {
            'Authorization': `Bearer ${token}`
        }
    });
    if (!response.ok) return null;
    return await response.json();
}

async function extractJsonAttachments(message, messageId, token) {
    const attachmentsToFetch = [];
    
    // Extraer la fecha del correo
    const dateHeader = message.payload.headers.find(h => h.name === 'Date');
    const emailDate = dateHeader ? new Date(dateHeader.value) : new Date();

    // Función recursiva para buscar partes adjuntas json en el payload
    function findAttachments(parts) {
        if (!parts) return;
        for (const part of parts) {
            if (part.filename && part.filename.toLowerCase().endsWith('.json') && part.body) {
                attachmentsToFetch.push({
                    filename: part.filename,
                    attachmentId: part.body.attachmentId,
                    data: part.body.data,
                    mimeType: part.mimeType
                });
            }
            if (part.parts) {
                findAttachments(part.parts);
            }
        }
    }

    findAttachments(message.payload.parts);
    if(message.payload.filename && message.payload.filename.toLowerCase().endsWith('.json') && message.payload.body) {
        // En caso que el payload raíz sea el attachment
        attachmentsToFetch.push({
            filename: message.payload.filename,
            attachmentId: message.payload.body.attachmentId,
            data: message.payload.body.data,
            mimeType: message.payload.mimeType
        });
    }

    const results = [];
    for (const att of attachmentsToFetch) {
        let base64 = null;
        
        // Si tiene attachmentId, debemos descargar el contenido por API extra
        if (att.attachmentId) {
            const attUrl = `https://gmail.googleapis.com/gmail/v1/users/me/messages/${messageId}/attachments/${att.attachmentId}`;
            const attResp = await fetch(attUrl, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (attResp.ok) {
                const attData = await attResp.json();
                base64 = attData.data;
            }
        } else if (att.data) {
            // Si el archivo era pequeño, Gmail lo adjunta directamente en body.data sin attachmentId
            base64 = att.data;
        }

        if (base64) {
            // Formato de Gmail usa URL-safe base64 (- por + y _ por /) y puede faltarle padding
            base64 = base64.replace(/-/g, '+').replace(/_/g, '/');
            while (base64.length % 4 !== 0) {
                base64 += '=';
            }
            
            let jsonText = "";
            let parsed = null;
            try {
                const binString = atob(base64);
                
                try {
                    // Intento 1: Legacy (funcionaba para el 99% de facturas sin fallos de BOM)
                    jsonText = decodeURIComponent(escape(binString));
                    // Remover posible BOM si existiera
                    if (jsonText.charCodeAt(0) === 0xFEFF) jsonText = jsonText.slice(1);
                    parsed = JSON.parse(jsonText);
                } catch (e1) {
                    // Intento 2: TextDecoder moderno (falla si el binString es gigante para algunos callbacks, o BOM)
                    const bytes = new Uint8Array(binString.length);
                    for (let i = 0; i < binString.length; i++) {
                        bytes[i] = binString.charCodeAt(i);
                    }
                    jsonText = new TextDecoder().decode(bytes);
                    if (jsonText.charCodeAt(0) === 0xFEFF) jsonText = jsonText.slice(1);
                    parsed = JSON.parse(jsonText);
                }
            } catch (err) {
                console.error("Error crítico decodificando base64 o JSON:", err);
                results.push({
                    id: messageId + '_ERRDEC_' + Date.now(),
                    fechaEmi: "Error",
                    emailDate: new Date().toISOString(),
                    proveedor: "⚠️ Archivo dañado o codificado raro",
                    nit: "N/A",
                    control: err.message,
                    sello: "N/A",
                    total: 0,
                    tipo: "Error",
                    originalJson: {},
                    rawJson: "",
                    filename: att.filename
                });
                continue; // Saltar al siguiente adjunto
            }
            
            try {
                function findDTERoot(obj) {
                    if (!obj || typeof obj !== 'object') return null;
                    if (obj.identificacion && obj.identificacion.version && obj.emisor && obj.resumen) return obj;
                    if (obj.identificacion && obj.emisor && obj.resumen) return obj;
                    
                    for (const key of Object.keys(obj)) {
                        if (typeof obj[key] === 'object') {
                            const res = findDTERoot(obj[key]);
                            if (res) return res;
                        }
                    }
                    return null;
                }

                const doc = findDTERoot(parsed);

                if (doc) {
                    const dteTypes = {
                        "01": "Factura",
                        "03": "CCF",
                        "04": "Remisión",
                        "05": "Not. Crédito",
                        "06": "Not. Débito",
                        "07": "Retención",
                        "11": "Exportación",
                        "14": "Suj. Excluido",
                        "15": "Donación"
                    };
                    const tipoCod = doc.identificacion.tipoDte;
                    const tipoDocName = dteTypes[tipoCod] || tipoCod || "DTE";

                    results.push({
                        id: messageId + '_' + Date.now() + Math.random(),
                        fechaEmi: doc.identificacion.fecEmi || new Date().toISOString().split('T')[0],
                        emailDate: new Date().toISOString(),
                        proveedor: doc.emisor.nombre,
                        nit: doc.emisor.nit || doc.emisor.nrc,
                        codigoGeneracion: doc.identificacion.codigoGeneracion,
                        control: doc.identificacion.numeroControl,
                        sello: doc.selloRecepcion || 'N/A',
                        total: parseFloat(doc.resumen.totalPagar || 0),
                        tipo: tipoDocName,
                        originalJson: parsed,
                        rawJson: jsonText,
                        filename: att.filename
                    });
                } else {
                    results.push({
                        id: messageId + '_ERR_' + Date.now(),
                        fechaEmi: new Date().toISOString().split('T')[0],
                        emailDate: new Date().toISOString(),
                        proveedor: "⚠️ Formato JSON irreconocible",
                        nit: "N/A",
                        control: "N/A",
                        sello: "N/A",
                        total: 0,
                        tipo: "Error",
                        originalJson: parsed,
                        rawJson: jsonText,
                        filename: att.filename
                    });
                    console.warn("Adjunto JSON ignorado por no ser DTE:", att.filename);
                }
            } catch (e) {
                console.error("Error parseando adjunto JSON DTE:", e);
                results.push({
                    id: messageId + '_ERR_CRASH_' + Date.now(),
                    fechaEmi: new Date().toISOString().split('T')[0],
                    emailDate: new Date().toISOString(),
                    proveedor: "⚠️ Fallo inesperado en el sistema DTE",
                    nit: "N/A",
                    control: "Crash interno",
                    sello: "N/A",
                    total: 0,
                    tipo: "Error",
                    originalJson: parsed,
                    rawJson: jsonText || "",
                    filename: att.filename
                });
            }
        }
    }
    
    return results;
}
