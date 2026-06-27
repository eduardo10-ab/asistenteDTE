// content_loader.js - EL PUENTE OFICIAL

// 1. INYECTAR EL ESPÍA (injected.js) EN LA PÁGINA
const script = document.createElement('script');
script.src = chrome.runtime.getURL('injected.js');
script.onload = function() {
    this.remove(); // Se borra la etiqueta <script> para ser sigiloso, pero el código queda corriendo
};
(document.head || document.documentElement).appendChild(script);

// 2. ESCUCHAR AL ESPÍA Y PASAR EL MENSAJE AL BACKGROUND
window.addEventListener('message', (event) => {
    // Solo aceptamos mensajes de nuestra propia ventana, mismo origen y con nuestro sello
    if (event.source !== window || event.origin !== window.location.origin || !event.data || event.data.type !== 'DTE_DETECTADO_REAL') {
        return;
    }

    console.log("🌉 Puente: Recibido de la página -> Enviando a Background");

    // --- PROTECCIÓN TOTAL (TRY-CATCH) ---
    // Esto es lo único que detiene el error "Extension context invalidated"
    try {
        if (!chrome.runtime || !chrome.runtime.sendMessage) {
            // Si la extensión murió por completo, salimos silenciosamente
            return;
        }

        chrome.runtime.sendMessage({
            action: 'GUARDAR_VENTA_INTERCEPTADA',
            datos: event.data.payload
        }, (response) => {
            // Capturamos errores asíncronos (como cierre de puerto)
            if (chrome.runtime.lastError) {
                // Silencio es salud: Ignoramos el error
            }
        });
    } catch (e) {
        // Capturamos errores síncronos (Contexto invalidado)
        // Aquí cae el error rojo y lo eliminamos para que no ensucie la consola
        console.log("Nota: La extensión se reinició. Conexión restablecida.");
    }
});