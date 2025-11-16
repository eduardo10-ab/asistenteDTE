// lib/js_injection.dart
// --- VERSIÓN 17 (Interceptor de Descarga + Relleno de popup.js) ---

// Esta variable contiene TODO el código JS que se inyectará en la web
const String jsInjector = r'''

// --- INICIO: INTERCEPTORES DE PDF Y LINKS ---
(function() {
    console.log('[PDF DEBUG] Instalando interceptores y overrides...');
    // Escuchar mensajes desde popups (postMessage) y reenviarlos a FlutterChannel
    if (window.addEventListener) {
        window.addEventListener('message', function(ev) {
            try {
                var data = ev.data;
                if (!data) return;
                // data puede ser string JSON o un objeto
                if (typeof data === 'string') {
                    try { data = JSON.parse(data); } catch(e) { /* no JSON */ }
                }
                if (data && data.action === 'pdfBlob') {
                    if (window.FlutterChannel && window.FlutterChannel.postMessage) {
                        window.FlutterChannel.postMessage(JSON.stringify(data));
                        console.log('[PDF DEBUG] Reenviado pdfBlob desde message event a FlutterChannel');
                    } else {
                        console.warn('[PDF DEBUG] FlutterChannel no disponible para reenviar pdfBlob');
                    }
                }
            } catch(e) { console.error('Error en message listener:', e); }
        }, false);
    }
    
    // XHR override para capturar respuestas PDF
    const originalXHR = window.XMLHttpRequest;
    window.XMLHttpRequest = function() {
        const xhr = new originalXHR();
        const originalOpen = xhr.open;
        const originalSend = xhr.send;
        
        xhr.open = function() {
            console.log('[PDF DEBUG] XHR.open:', arguments[1]);
            xhr._url = arguments[1];
            return originalOpen.apply(xhr, arguments);
        };
        
        xhr.send = function() {
            xhr.addEventListener('load', function() {
                const contentType = xhr.getResponseHeader('Content-Type');
                if (contentType && contentType.includes('pdf')) {
                    console.log('[PDF DEBUG] ¡PDF detectado en XHR!', xhr._url);
                    try {
                        const blob = xhr.response;
                        const reader = new FileReader();
                        reader.onload = () => {
                            const base64 = reader.result.split(',')[1];
                            window.FlutterChannel.postMessage(JSON.stringify({
                                action: 'pdfBlob',
                                base64: base64,
                                filename: 'dte_' + Date.now() + '.pdf'
                            }));
                            console.log('[PDF DEBUG] PDF enviado a Flutter');
                        };
                        reader.readAsDataURL(blob);
                    } catch(e) {
                        console.error('[PDF DEBUG] Error procesando PDF:', e);
                    }
                }
            });
            return originalSend.apply(xhr, arguments);
        };
        return xhr;
    };

    // Interceptar clicks en enlaces
    document.addEventListener('click', function(event) {
        const target = event.target;
        const closestLink = target.closest('a');
        
        console.log('[PDF DEBUG] Click detectado:', {
            target: target.tagName,
            href: target.href || (closestLink && closestLink.href),
            text: target.textContent || (closestLink && closestLink.textContent)
        });

        // Si es un botón o enlace con texto "Descargar" o similar
        if (target.textContent && target.textContent.toLowerCase().includes('descargar')) {
            console.log('[PDF DEBUG] Botón descargar detectado');
            event.preventDefault();
            event.stopPropagation();
            
            // Buscar el PDF en la página
            const pdfElement = document.querySelector('embed[type="application/pdf"], object[type="application/pdf"], iframe[src*="pdf"]');
            if (pdfElement) {
                const src = pdfElement.src || pdfElement.data;
                console.log('[PDF DEBUG] PDF encontrado:', src);
                
                fetch(src)
                    .then(r => r.blob())
                    .then(blob => {
                        const reader = new FileReader();
                        reader.onload = () => {
                            const base64 = reader.result.split(',')[1];
                            window.FlutterChannel.postMessage(JSON.stringify({
                                action: 'pdfBlob',
                                base64: base64,
                                filename: 'dte_' + Date.now() + '.pdf'
                            }));
                            console.log('[PDF DEBUG] PDF enviado a Flutter desde click');
                        };
                        reader.readAsDataURL(blob);
                    });
            }
        }
    }, true);

    // Eliminada la funcionalidad de dom_dump para producción

    // Monitorear cambios en el DOM para detectar PDFs
    new MutationObserver((mutations) => {
        for (const m of mutations) {
            if (m.addedNodes) {
                m.addedNodes.forEach(node => {
                    if (node.nodeType === 1) { // Es un elemento
                        const pdfElements = node.querySelectorAll('embed[type="application/pdf"], object[type="application/pdf"], iframe[src*="pdf"]');
                        pdfElements.forEach(el => {
                            console.log('[PDF DEBUG] PDF detectado en DOM:', el);
                            const src = el.src || el.data;
                            if (src) {
                                console.log('[PDF DEBUG] Intentando obtener PDF de:', src);
                                fetch(src)
                                    .then(r => r.blob())
                                    .then(blob => {
                                        const reader = new FileReader();
                                        reader.onload = () => {
                                            const base64 = reader.result.split(',')[1];
                                            window.FlutterChannel.postMessage(JSON.stringify({
                                                action: 'pdfBlob',
                                                base64: base64,
                                                filename: 'dte_' + Date.now() + '.pdf'
                                            }));
                                            console.log('[PDF DEBUG] PDF enviado a Flutter desde observer');
                                        };
                                        reader.readAsDataURL(blob);
                                    });
                            }
                        });
                    }
                });
            }
        }
    }).observe(document, { childList: true, subtree: true });

})();

// --- INICIO: INTERCEPTOR DE NAVEGACIÓN Y PDF/BLOB ---
(function() {
    console.log('[PDF DEBUG] Instalando interceptores...');

    // Función para debuggear eventos
    function logEvent(event, context) {
        console.log(`[PDF DEBUG] ${context}:`, {
            type: event.type,
            url: event.url || (event.target && event.target.href),
            target: event.target && event.target.tagName,
            currentTarget: event.currentTarget && event.currentTarget.tagName,
            timeStamp: event.timeStamp
        });
    }

    // Interceptar click en enlaces
    document.addEventListener('click', function(event) {
        logEvent(event, 'Click detectado');
        const link = event.target.closest('a');
        if (link) {
            console.log('[PDF DEBUG] Link encontrado:', {
                href: link.href,
                target: link.target,
                download: link.download,
                rel: link.rel
            });
        }
    }, true);

    // XHR override para detectar PDF
    const originalXHR = window.XMLHttpRequest;
    window.XMLHttpRequest = function() {
        const xhr = new originalXHR();
        const originalOpen = xhr.open;
        xhr.open = function() {
            console.log('[PDF DEBUG] XHR abierto:', arguments[1]);
            originalOpen.apply(xhr, arguments);
        };
        const originalSend = xhr.send;
        xhr.send = function() {
            xhr.addEventListener('load', function() {
                const contentType = xhr.getResponseHeader('Content-Type');
                console.log('[PDF DEBUG] XHR completado:', {
                    url: xhr._url,
                    contentType: contentType
                });
                if (contentType && contentType.includes('pdf')) {
                    console.log('[PDF DEBUG] ¡PDF detectado en XHR!');
                }
            });
            originalSend.apply(xhr, arguments);
        };
        return xhr;
    };

    // Fetch override
    const originalFetch = window.fetch;
    window.fetch = async function(input, init) {
        console.log('[PDF DEBUG] Fetch iniciado:', input);
        const response = await originalFetch.apply(window, arguments);
        const contentType = response.headers.get('Content-Type');
        console.log('[PDF DEBUG] Fetch completado:', {
            url: input,
            contentType: contentType
        });
        if (contentType && contentType.includes('pdf')) {
            console.log('[PDF DEBUG] ¡PDF detectado en fetch!');
        }
        return response;
    };

    // Interceptar navegación
    const navInterceptor = function(event) {
        try {
            if (event.url && event.url.startsWith('blob:')) {
                console.log('NavInterceptor: Detectada URL blob:', event.url);
                event.preventDefault();
                fetch(event.url)
                    .then(r => r.blob())
                    .then(blob => {
                        if (blob.type === 'application/pdf' || event.url.toLowerCase().includes('pdf')) {
                            console.log('Es un PDF, enviando como base64...');
                            const reader = new FileReader();
                            reader.onload = () => {
                                const base64 = reader.result.split(',')[1];
                                window.FlutterChannel.postMessage(JSON.stringify({
                                    action: 'pdfBlob',
                                    base64: base64,
                                    filename: `dte_${Date.now()}.pdf`
                                }));
                            };
                            reader.readAsDataURL(blob);
                        } else {
                            blob.text().then(text => {
                                window.FlutterChannel.postMessage(JSON.stringify({
                                    action: 'downloadFromBlob',
                                    jsonContent: text
                                }));
                            });
                        }
                    });
                return false;
            }
        } catch(e) {
            console.error('Error en navInterceptor:', e);
        }
    };

    // Instalar interceptor
    if (window.addEventListener) {
        window.addEventListener('beforeunload', navInterceptor, true);
        window.addEventListener('click', navInterceptor, true);
    }
})();

// --- INICIO: INTERCEPTOR DE DESCARGAS Y ESTADO (MEJORADO) ---
if (typeof chrome === 'undefined') { var chrome = {}; }
if (typeof chrome.runtime === 'undefined') { chrome.runtime = {}; }
if (typeof chrome.runtime.sendMessage !== 'function' || chrome.runtime.sendMessage.toString().indexOf('FlutterChannel') === -1) {
  const originalSendMessage = chrome.runtime.sendMessage || function() {};
  
  chrome.runtime.sendMessage = function(request, callback) {
    console.log('chrome.runtime.sendMessage interceptado!', request);
    
    // ESTA ES LA ACCIÓN QUE BUSCAMOS
    if (request && request.action === 'downloadDTE') {
      console.log('Acción downloadDTE detectada. Enviando a Flutter...');
      
      // Notificar inicio del procesamiento
      if (window.FlutterChannel && window.FlutterChannel.postMessage) {
        window.FlutterChannel.postMessage(JSON.stringify({
          action: 'downloadDTE',
          processingStarted: true
        }));
        
        // Enviar los datos después
        window.FlutterChannel.postMessage(JSON.stringify(request));
      } else {
        console.error('El canal "FlutterChannel" no está disponible.');
      }
      
      if (callback) { callback({ status: 'recibido por flutter' }); }
    } 
    else {
      // Si no es la acción de descarga, deja que continúe
      console.log('Acción no reconocida, pasando a la función original.');
      originalSendMessage(request, callback);
    }
  };
  console.log('Interceptor mejorado de chrome.runtime.sendMessage instalado.');
}
// --- FIN: INTERCEPTOR DE DESCARGAS ---

// --- Manejo de pop-ups y window.open ---
(function(){
    try {
        const originalWindowOpen = window.open;
        window.open = function(url, name, specs) {
            try {
                console.log('[PDF DEBUG] window.open called', { url: url, name: name, specs: specs });

                // Si es about:blank, permitimos y monitoreamos la ventana
                if (!url || url === 'about:blank') {
                    console.log('Detectado about:blank popup, creando ventana y monitoreando...');
                    const popup = originalWindowOpen.apply(window, arguments);

                    // Notificar a Flutter que se abrió un popup (debug)
                    try {
                        if (window.FlutterChannel && window.FlutterChannel.postMessage) {
                            window.FlutterChannel.postMessage(JSON.stringify({ action: 'popupOpened', url: url || 'about:blank', name: name || '', specs: specs || '' }));
                        }
                    } catch(e) { console.error('Error notificando popupOpened:', e); }

                    if (popup) {
                        // Intentar inyectar script en el popup cuando esté listo. Hacemos polling hasta un timeout.
                        let tries = 0;
                        const maxTries = 40; // 40 * 250ms = 10s
                        const interval = setInterval(() => {
                            try {
                                if (!popup || popup.closed) { clearInterval(interval); return; }
                                const doc = popup.document;
                                if (doc && (doc.readyState === 'complete' || doc.body)) {
                                    clearInterval(interval);
                                            try {
                                                // Intento inmediato: buscar enlaces data: directamente en el popup y enviar pdfBlob si existe
                                                try {
                                                    try {
                                                        const anchors = Array.from(doc.querySelectorAll('a[download], a[href^="data:"]'));
                                                        if (anchors && anchors.length) {
                                                            for (const a of anchors) {
                                                                try {
                                                                    const href = a.getAttribute('href') || a.href || '';
                                                                    if (href && href.startsWith('data:')) {
                                                                        const m = href.match(/^data:(.+?);base64,(.+)$/);
                                                                        if (m) {
                                                                            const base64 = m[2];
                                                                            const downloadName = a.getAttribute('download') || ('dte_' + Date.now() + '.pdf');
                                                                            if (window.FlutterChannel && window.FlutterChannel.postMessage) {
                                                                                window.FlutterChannel.postMessage(JSON.stringify({ action: 'pdfBlob', base64: base64, filename: downloadName }));
                                                                                console.log('[PDF DEBUG] pdfBlob enviado DIRECTAMENTE desde opener (data: link)');
                                                                            } else {
                                                                                console.warn('[PDF DEBUG] FlutterChannel no disponible para enviar pdfBlob desde opener');
                                                                            }
                                                                            // Si se envió uno, rompemos el loop para evitar duplicados
                                                                            break;
                                                                        }
                                                                    }
                                                                } catch(e) { console.error('[PDF DEBUG] Error procesando anchor en popup:', e); }
                                                            }
                                                        }
                                                    } catch(e) { console.error('[PDF DEBUG] Error buscando anchors data: en popup:', e); }

                                                    // Eliminado domDump para producción
                                                } catch(e) { console.error('[PDF DEBUG] Error en el proceso del popup:', e); }

                                        const script = doc.createElement('script');
                                        script.type = 'text/javascript';
                                        script.text = `
                                            console.log('Observer instalado en popup (injected)');
                                            function findPdfElement() {
                                                return document.querySelector('embed[type="application/pdf"], object[type="application/pdf"], iframe[src*="pdf"]');
                                            }
                                            async function extractPdf(element) {
                                                try {
                                                    const src = element.src || element.data;
                                                    if (!src) return;
                                                    console.log('Popup: PDF encontrado:', src);
                                                    const response = await fetch(src);
                                                    const blob = await response.blob();
                                                    const reader = new FileReader();
                                                    reader.onload = function() {
                                                        const base64 = reader.result.split(',')[1];
                                                        try { window.opener.postMessage(JSON.stringify({ action: 'pdfBlob', base64: base64, filename: 'dte_' + Date.now() + '.pdf' }), '*'); } catch(e) { console.error('Error posting pdfBlob to opener via postMessage:', e); }
                                                    };
                                                    reader.readAsDataURL(blob);
                                                } catch(e) { console.error('Error extrayendo PDF en popup:', e); }
                                            }
                                            function findDataLink() {
                                                return document.querySelector('a[download][href^="data:"]') || document.querySelector('a[href^="data:"]');
                                            }
                                            function extractDataLink(el) {
                                                try {
                                                    if (!el) return;
                                                    const href = el.href || el.getAttribute('href') || '';
                                                    const downloadName = el.getAttribute && el.getAttribute('download') ? el.getAttribute('download') : ('dte_' + Date.now() + '.pdf');
                                                    const m = href.match(/^data:(.+?);base64,(.+)$/);
                                                    if (m) {
                                                        const mime = m[1];
                                                        const base64 = m[2];
                                                            try {
                                                            window.opener.postMessage(JSON.stringify({ action: 'pdfBlob', base64: base64, filename: downloadName }), '*');
                                                        } catch(e) { console.error('Error posting data: blob to opener via postMessage:', e); }
                                                    }
                                                } catch(e) { console.error('Error extracting data link in popup:', e); }
                                            }
                                            new MutationObserver((mutations, observer) => {
                                                const pdfElement = findPdfElement();
                                                if (pdfElement) { extractPdf(pdfElement); observer.disconnect(); return; }
                                                const dataLink = findDataLink();
                                                if (dataLink) { extractDataLink(dataLink); observer.disconnect(); return; }
                                            }).observe(document.documentElement || document, { childList: true, subtree: true });
                                            const existing = findPdfElement(); if (existing) extractPdf(existing);
                                            const existingLink = findDataLink(); if (existingLink) extractDataLink(existingLink);
                                        `;
                                        (doc.head || doc.documentElement).appendChild(script);
                                        console.log('[PDF DEBUG] Injector script appended to popup');
                                    } catch(e) {
                                        console.error('Error injecting into popup:', e);
                                    }
                                }
                                tries++;
                                if (tries >= maxTries) { clearInterval(interval); }
                            } catch(e) { console.error('Error polling popup.document:', e); clearInterval(interval); }
                        }, 250);
                    }
                    return popup;
                }

                // Para URLs normales (no about:blank), notificar a Flutter
                if (window.FlutterChannel && window.FlutterChannel.postMessage) {
                    window.FlutterChannel.postMessage(JSON.stringify({ action: 'openWindow', url: url }));
                    return null;
                }
            } catch(e) {
                console.error('Error en window.open override:', e);
            }
            return originalWindowOpen.apply(window, arguments);
        };

        // Captura clicks en enlaces con target="_blank" y redirígelos a Flutter SOLO si no son about:blank
        document.addEventListener('click', function(evt) {
            try {
                let el = evt.target;
                while (el && el.tagName !== 'A') el = el.parentElement;
                if (el && el.tagName === 'A' && el.target === '_blank' && el.href) {
                    // Si el href es about:blank o vacío, permitir el comportamiento por defecto
                    if (!el.href || el.href === 'about:blank') {
                        return; // no preventDefault
                    }
                    evt.preventDefault();
                    if (window.FlutterChannel && window.FlutterChannel.postMessage) {
                        window.FlutterChannel.postMessage(JSON.stringify({ action: 'openWindow', url: el.href }));
                    } else {
                        window.location.href = el.href;
                    }
                }
            } catch(e) {
                console.error('Error en listener de enlaces _blank:', e);
            }
        }, true);
    } catch(e) {
        console.warn('No se pudo instalar override de window.open:', e);
    }
})();

// --- Observador para detectar viewers/embed de PDF y enviar el blob a Flutter ---
(function(){
    try {
        const processed = new WeakSet();

        async function fetchBlobAsBase64(url) {
            try {
                const resp = await fetch(url);
                const blob = await resp.blob();
                // Solo procesar si es PDF
                if (blob.type && blob.type.indexOf('pdf') === -1) {
                    return null;
                }
                return await new Promise((resolve, reject) => {
                    const reader = new FileReader();
                    reader.onloadend = function() {
                        const dataUrl = reader.result; // data:application/pdf;base64,....
                        resolve(dataUrl);
                    };
                    reader.onerror = function(e) { reject(e); };
                    reader.readAsDataURL(blob);
                });
            } catch(e) {
                console.error('Error fetching blob for PDF:', e);
                return null;
            }
        }

        function tryProcessElement(el) {
            if (!el || processed.has(el)) return;
            let src = el.src || el.data || (el.getAttribute && el.getAttribute('src')) || '';
            // Si es un enlace <a> con href tipo data:..., procesarlo
            try {
                if (el.tagName && el.tagName.toLowerCase() === 'a') {
                    const href = (el.href || (el.getAttribute && el.getAttribute('href')) || '').toString();
                    if (href && href.startsWith('data:')) {
                        processed.add(el);
                        const m = href.match(/^data:(.+?);base64,(.+)$/);
                        if (m) {
                            const base64 = m[2];
                            const filename = (el.getAttribute && el.getAttribute('download')) ? el.getAttribute('download') : ('dte_' + Date.now() + '.pdf');
                            if (window.FlutterChannel && window.FlutterChannel.postMessage) {
                                window.FlutterChannel.postMessage(JSON.stringify({ action: 'pdfBlob', base64: base64, filename: filename }));
                            }
                        }
                        return;
                    }
                }
            } catch(e) { console.error('Error procesando anchor data:', e); }
            if (!src && el.type && el.type.indexOf('pdf') !== -1) {
                // some viewers may embed blob in child nodes
                const childEmbed = el.querySelector && (el.querySelector('embed') || el.querySelector('iframe'));
                if (childEmbed) src = childEmbed.src || childEmbed.getAttribute('src') || '';
            }
            if (src && (src.startsWith('blob:') || src.toLowerCase().endsWith('.pdf') || src.indexOf('/pdf')!==-1)) {
                processed.add(el);
                (async ()=>{
                    const dataUrl = await fetchBlobAsBase64(src);
                    if (dataUrl && window.FlutterChannel && window.FlutterChannel.postMessage) {
                        // quitar el prefijo data:application/pdf;base64,
                        const base64 = dataUrl.split(',')[1] || dataUrl;
                        window.FlutterChannel.postMessage(JSON.stringify({ action: 'pdfBlob', base64: base64, filename: 'dte_${Date.now()}.pdf' }));
                    }
                })();
            }
        }

        const observer = new MutationObserver((mutations) => {
            for (const m of mutations) {
                if (m.addedNodes && m.addedNodes.length) {
                    m.addedNodes.forEach(node => {
                        if (node.nodeType !== 1) return;
                        const tag = node.tagName && node.tagName.toLowerCase();
                        if (tag === 'embed' || tag === 'object' || tag === 'iframe' || tag === 'div') {
                            tryProcessElement(node);
                        } else {
                            // buscar embed/iframe dentro del nodo
                            const found = node.querySelector && (node.querySelector('embed, object, iframe'));
                            if (found) tryProcessElement(found);
                        }
                    });
                }
            }
        });

        observer.observe(document, { childList: true, subtree: true });
        // Intentar procesar elementos ya existentes
        ['embed','object','iframe'].forEach(tag => {
            document.querySelectorAll(tag).forEach(el => tryProcessElement(el));
        });

        console.log('PDF embed observer instalado');
    } catch(e) {
        console.warn('No se pudo instalar PDF observer:', e);
    }
})();


// --- FUNCIONES AUXILIARES (HELPERS DE AUTOCOMPLETADO) ---
// <<< INICIO: Helpers de popup.js original (SIMPLES) >>>
function waitForElement(selector, timeout = 5000) {
    return new Promise((resolve) => {
        const intervalTime = 100;
        let elapsedTime = 0;
        const interval = setInterval(() => {
            const element = document.querySelector(selector);
            if (element) {
                clearInterval(interval);
                resolve(element);
            }
            elapsedTime += intervalTime;
            if (elapsedTime >= timeout) {
                clearInterval(interval);
                console.warn(`Timeout: Elemento "${selector}" no encontrado.`);
                resolve(null);
            }
        }, intervalTime);
    });
}

// Esta es la función 'advancedFill' SIMPLE del popup.js original.
function advancedFill(selector, value) {
    if (value === null || value === undefined || !selector) return false;
    const field = document.querySelector(selector);
    if (!field) return false;
    field.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    field.value = value;
    field.dispatchEvent(new Event('input', { bubbles: true }));
    field.dispatchEvent(new Event('change', { bubbles: true }));
    field.dispatchEvent(new Event('blur', { bubbles: true }));
    return true;
}

function fillField(value, selectors) {
    if (value === null || value === undefined || value === "" || !selectors) return;
    for (const selector of selectors) {
        if (advancedFill(selector, value)) {
            return;
        }
    }
}

// Esta es la función 'fillNgSelect' SIMPLE del popup.js original.
async function fillNgSelect(selector, value) {
    if (value === null || value === undefined || !selector) return;
    const ngSelect = document.querySelector(selector);
    if (!ngSelect) return;
    if (value === "") {
        const clearButton = ngSelect.querySelector('.ng-clear-wrapper');
        if (clearButton) clearButton.dispatchEvent(new MouseEvent('click', { bubbles: true }));
        return;
    }
    ngSelect.dispatchEvent(new Event('mousedown', { bubbles: true }));
    const input = await waitForElement('div.ng-input > input[type="text"]');
    if (!input) return;
    input.value = value;
    input.dispatchEvent(new Event('input', { bubbles: true })); // Evento 'input' es clave
    const dropdownPanel = await waitForElement('.ng-dropdown-panel');
    if (!dropdownPanel) return;
    const options = dropdownPanel.querySelectorAll('.ng-option');
    let targetOption = Array.from(options).find(opt => opt.textContent.trim().startsWith(value));
    if (targetOption) {
        targetOption.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    } else {
        const firstOption = dropdownPanel.querySelector('.ng-option');
        if (firstOption) firstOption.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    }
}

function fillStandardSelect(field, value) {
    const options = Array.from(field.options);
    let targetOption = options.find(opt => opt.value === value);
    if (!targetOption) {
        targetOption = options.find(opt => opt.text.toUpperCase().includes(value.toUpperCase()));
    }
    if (targetOption) {
        field.value = targetOption.value;
        field.dispatchEvent(new Event('change', { bubbles: true }));
        field.dispatchEvent(new Event('blur', { bubbles: true }));
        return true;
    }
    return false;
}

async function fillDropdown(selectors, value) {
    if (value === null || value === undefined) return;
    for (const selector of selectors) {
        const element = document.querySelector(selector);
        if (element) {
            const tagName = element.tagName.toUpperCase();
            if (tagName === 'SELECT') {
                if (fillStandardSelect(element, value)) return;
            } else if (tagName === 'NG-SELECT') {
                await fillNgSelect(selector, value);
                return;
            }
        }
    }
}
// <<< FIN: Helpers de popup.js original >>>


// <<< --- INICIO: LÓGICA DE CLIENTE (v16) ACTUALIZADA --- >>>
async function fillClientData(client) {
    // Pausa inicial
    await new Promise(resolve => setTimeout(resolve, 500));
    console.log('--- INICIANDO fillClientData (v16 - Lógica popup.js) ---');
    console.log(JSON.stringify(client));

    const nitField = document.querySelector("input[formcontrolname='nit']");
    const facturaDocTypeField = document.querySelector("select[formcontrolname='tipoDocumento']");

    if (nitField) {
        // --- ESTAMOS EN CRÉDITO FISCAL (o similar, que SÍ tiene NIT) ---
        console.log('Detectado formulario de Crédito Fiscal (con NIT).');
        
        // Esta es la lógica EXACTA del popup.js original
        fillField(client.nit, ["input[formcontrolname='nit']", 'input[id*="nit"]']);
        fillField(client.nombreCliente, ["input[formcontrolname='nombreReceptor']", "input[formcontrolname='nombreCliente']", "input[formcontrolname='nombre']", 'input[id*="nombre"]']);
        await fillDropdown(["ng-select[formcontrolname='paises']", "select[formcontrolname='paises']", "ng-select[id*='paises']"], client.pais);
    
        if (client.tipoPersona) {
            let valorTipoPersona = (client.tipoPersona.toUpperCase() === "JURÍDICA") ? "JURÍDICA" : "NATURAL";
            await fillDropdown(["select[formcontrolname='tipoPersona']"], valorTipoPersona);
        }

        fillField(client.nrc, ["input[formcontrolname='nrcCliente']", "input.form-control[formcontrolname='nrcCliente']", "input[formcontrolname='nrc']", "input[id*='nrc']", "input[formcontrolname='nrcReceptor']"]);
        fillField(client.nombreComercial, ["input[formcontrolname='nombreComercial']", 'input[id*="comercial"]']);

        // --- LÓGICA ACTIVIDAD ECONÓMICA (de popup.js) ---
        const actividadValue = client.actividadEconomica || "";
        const actividadCode = actividadValue.split(' - ')[0];
        await fillDropdown(["ng-select[formcontrolname='actividadEconomica']", "ng-select[formcontrolname='codigoActividadEconomica']", "ng-select[formcontrolname='codigoActividad']", "ng-select[formcontrolname='codActividad']", "select[formcontrolname='actividadEconomica']", "select[id*='actividadEconomica']"], actividadCode);
        fillField(client.actividadEconomica, ["input[placeholder='Descripción de Actividad Económica']", "input[list='actividadesList']", "input[formcontrolname='actividadEconomica']", "input[formcontrolname='descActividad']"]);
        // --- FIN LÓGICA ACTIVIDAD ECONÓMICA ---

        const deptoValue = client.departamento || "";
        const deptoCode = deptoValue.split(' - ')[0];
        const municipioValue = client.municipio || "";
        const municipioCode = municipioValue.split(' - ')[0];
        
        await fillDropdown(["ng-select[formcontrolname='departamento']", "select[formcontrolname='departamento']"], deptoCode);
        await new Promise(resolve => setTimeout(resolve, 400)); // Pausa para que carguen los municipios
        await fillDropdown(["ng-select[formcontrolname='municipio']", "select[formcontrolname='municipio']"], municipioCode);

        fillField(client.direccion, ["textarea[formcontrolname='complementoReceptor']", "textarea[formcontrolname='complemento']", 'textarea[id*="direccion"]', "input[formcontrol-name='direccion']"]);
        fillField(client.email, ["input[formcontrolname='correoReceptor']", "input[formcontrolname='correo']", 'input[type="email"]']);
        fillField(client.telefono, ["input[formcontrolname='telefonoReceptor']", "input[formcontrolname='telefono']", 'input[type="tel"]']);

    } else if (facturaDocTypeField) {
        // --- ESTAMOS EN FACTURA (Consumidor Final, SIN NIT) ---
        console.log('Detectado formulario de Factura (sin NIT).');
        
        let documentoARellenar = null;
        let tipoDocValue = null;
        let campoDocumentoSelector = null;

        if (client.dui && client.dui.length > 0) { 
            tipoDocValue = "DUI"; 
            documentoARellenar = client.dui; 
            campoDocumentoSelector = "input[formcontrolname='dui']";
        
        // --- INICIO: CAMBIO ---
        } else if (client.pasaporte && client.pasaporte.length > 0) { 
            tipoDocValue = "PASAPORTE"; 
            documentoARellenar = client.pasaporte; 
            campoDocumentoSelector = "input[formcontrolname='otro']"; // <-- CAMPO CORREGIDO
        
        } else if (client.carnetResidente && client.carnetResidente.length > 0) { 
            tipoDocValue = "RESIDENTE"; 
            documentoARellenar = client.carnetResidente; 
            campoDocumentoSelector = "input[formcontrolname='carnetResidente']";
        
        } else if (client.otroDocumento && client.otroDocumento.length > 0) { 
            tipoDocValue = "OTRO"; 
            documentoARellenar = client.otroDocumento; 
            campoDocumentoSelector = "input[formcontrolname='otro']"; // <-- CAMPO CORREGIDO
        // --- FIN: CAMBIO ---
            
        } else if (client.nit && client.nit.length > 0) {
            tipoDocValue = "NIT";
            documentoARellenar = client.nit;
            campoDocumentoSelector = "input[formcontrolname='nit']"; 
        }

        if(tipoDocValue) {
             await fillDropdown(["select[formcontrolname='tipoDocumento']"], tipoDocValue);
             await new Promise(resolve => setTimeout(resolve, 200)); 
        }
        if (documentoARellenar && campoDocumentoSelector) {
            fillField(documentoARellenar, [campoDocumentoSelector, "input[formcontrolname='numDocumento']"]);
        }

        fillField(client.nombreCliente, ["input[formcontrolname='nombre']", "input[formcontrolname='nombreReceptor']"]);
        
        const deptoCode = (client.departamento || "").split(' - ')[0];
        await fillDropdown(["ng-select[formcontrolname='departamento']", "select[formcontrolname='departamento']"], deptoCode);
        await new Promise(resolve => setTimeout(resolve, 200));
        
        const municCode = (client.municipio || "").split(' - ')[0];
        await fillDropdown(["ng-select[formcontrolname='municipio']", "select[formcontrolname='municipio']"], municCode);

        fillField(client.direccion, ["textarea[formcontrolname='complemento']", "textarea[formcontrolname='complementoReceptor']"]);
        fillField(client.email, ["input[formcontrolname='correoReceptor']", "input[formcontrolname='correo']", "input[type='email']"]);
        fillField(client.telefono, ["input[formcontrolname='telefonoReceptor']", "input[formcontrolname='telefono']", "input[type='tel']"]);

    } else {
        console.warn('No se pudo detectar el tipo de formulario (ni Factura ni CCF). Se intentará rellenar todo.');
        // Fallback
        fillField(client.nit, ["input[formcontrolname='nit']"]);
        fillField(client.nombreCliente, ["input[formcontrolname='nombreReceptor']", "input[formcontrolname='nombreCliente']", "input[formcontrolname='nombre']", "input[id*='nombre']"]);
        fillField(client.nrc, ["input[formcontrolname='nrcCliente']", "input[formcontrolname='nrc']"]);
        fillField(client.nombreComercial, ["input[formcontrolname='nombreComercial']"]);
    }
    
    console.log('--- FIN fillClientData (v16) ---');
}
// <<< --- FIN: LÓGICA DE CLIENTE (v16) ACTUALIZADA --- >>>


// --- LÓGICA DE PRODUCTO (Basada en popup.js) ---
async function addProductToInvoice(product) {
    await new Promise(resolve => setTimeout(resolve, 500));
    console.log('--- INICIANDO addProductToInvoice (v16) ---');
    
    function fillField(selectors, value) {
        if (value === null || value === undefined) return;
        for (const selector of selectors) {
            if (advancedFill(selector, value)) return;
        }
    }
    
    function fillSelect(selectors, value) {
         if (value === null || value === undefined) return;
         for (const selector of selectors) {
             const field = document.querySelector(selector);
             if (field && field.tagName.toUpperCase() === 'SELECT') {
                if (fillStandardSelect(field, value)) return;
             }
         }
    }

    const unitCode = product.unidadMedida || "59";
    fillSelect(["select[formcontrolname='unidad']", "select[formcontrolname='codigoUnidad']"], unitCode);
    
    let tipoCode;
    switch (product.tipo) { 
        case 'Bien': tipoCode = '1'; break; 
        case 'Servicio': tipoCode = '2'; break; 
        case 'Bien y Servicio': tipoCode = '3'; break; 
        default: tipoCode = '1'; 
    }
    fillSelect(["select[formcontrolname='tipo']", "select[formcontrolname='tipoItem']"], tipoCode);
    
    fillField([
        "input[formcontrolname='Tipo Producto']", // Selector de popup.js
        "input[formcontrolname='producto']", 
        "textarea[formcontrolname='descripcion']",
        "input[formcontrolname='nombre']"
    ], product.descripcion);
    
    fillField(["input[formcontrolname='precio']", "input[formcontrolname='precioUnitario']"], product.precio);
    
    const cantidadInput = document.querySelector("input[formcontrolname='cantidad']");
    if (cantidadInput && (!cantidadInput.value || cantidadInput.value === "0")) {
        fillField(["input[formcontrolname='cantidad']"], "1");
    }
     console.log('--- FIN addProductToInvoice (v16) ---');
}
''';
