// tour_runner.js - V42.12: Fix Paso 12 (No saltar) + Overlay Oscuro Visible
(function() {
    console.log("🚀 Iniciando Tour V42.12 (Edición con Foco Visual)...");

    if (typeof window.driver === 'undefined') {
        alert("Error: Driver.js no cargado.");
        return;
    }

    const driverObj = window.driver.js.driver;
    
    // --- 🚫 LISTA NEGRA: PASOS DONDE EL BOTÓN DESAPARECE ---
    const PASOS_SIN_BOTON = [
        "1. Iniciar Sesión",
        "5. Iniciar Sesión",
        "6. Confirmar",
        "7. Ingresar al Sistema de Facturación",
        "9. Confirmar",
        "10. Agregar Detalle",
        "11. Producto o Servicio",
        "13. Guardar Ítem",
        "14. ¿Qué deseas hacer?",
        "17. Agregar Pago",
        "18. Generar Documento",
        "21. Firmar Documento"
    ];

    // --- 🔒 CONTROL DE NAVEGACIÓN ---
    let isMoving = false;
    function avanzarSeguro(tourInstance) {
        if (isMoving) return;
        isMoving = true;
        
        // Antes de movernos, limpiamos la clase para evitar parpadeos
        document.body.classList.remove('tour-ocultar-siguiente');
        
        tourInstance.moveNext();
        setTimeout(() => { isMoving = false; }, 800);
    }

    // --- 🎨 ESTILOS VISUALES (CSS GLOBAL) ---
    function inyectarEstilosVisuales() {
        const estiloId = 'tour-styles-custom';
        if (document.getElementById(estiloId)) return; 

        const css = `
            /* Estilos generales del Popover */
            .driver-popover { 
                max-width: 450px !important; 
                padding: 20px !important; 
                border-radius: 12px !important; 
                background-color: #fff !important; 
                box-shadow: 0 0 50px rgba(0,0,0,0.5) !important; 
                z-index: 2147483647 !important; 
                border: 2px solid #4880FF;
            }
            .driver-popover-title { font-size: 20px !important; font-weight: 800 !important; margin-bottom: 10px !important; color: #2c3e50 !important; }
            .driver-popover-description { font-size: 16px !important; color: #444 !important; line-height: 1.5 !important; }
            .driver-popover-footer { display: flex !important; justify-content: flex-end !important; gap: 8px !important; }
            
            /* Botones */
            .driver-popover-footer button { 
                display: inline-flex !important; 
                padding: 6px 14px !important; 
                border-radius: 5px !important; 
                cursor: pointer !important; 
            }
            .driver-popover-next-btn { background-color: #4880FF !important; color: white !important; border: 1px solid #4880FF !important; text-shadow: none !important; }
            .driver-popover-prev-btn { background-color: #f1f1f1 !important; color: #555 !important; border: 1px solid #ddd !important; }

            /* --- 🔥 LA REGLA MAESTRA PARA OCULTAR EL BOTÓN 🔥 --- */
            body.tour-ocultar-siguiente .driver-popover-footer .driver-popover-next-btn {
                display: none !important;
                visibility: hidden !important;
                opacity: 0 !important;
                pointer-events: none !important;
                width: 0 !important;
                padding: 0 !important;
                margin: 0 !important;
            }

            /* --- MODO EDICIÓN (CORREGIDO: Muestra Overlay Oscuro) --- */
            /* 1. Ya NO ocultamos el overlay (.driver-overlay { display: none }) para que se vea oscuro. */
            
            /* 2. Elevamos los elementos interactivos POR ENCIMA del overlay oscuro */
            body.tour-edit-mode .modal-content,
            body.tour-edit-mode tab,
            body.tour-edit-mode .tab-pane,
            body.tour-edit-mode .swal2-popup { 
                z-index: 2147483647 !important; 
                pointer-events: auto !important; 
                position: relative !important; /* Asegura que el z-index aplique */
            }
        `;
        const style = document.createElement('style');
        style.id = estiloId;
        style.innerText = css;
        document.head.appendChild(style);
    }
    inyectarEstilosVisuales();

    // --- 🧹 LIMPIADOR DE ARIA ---
    if (window.ariaInterval) clearInterval(window.ariaInterval);
    window.ariaInterval = setInterval(() => {
        document.querySelectorAll('[aria-hidden="true"]').forEach(el => {
            if (el.tagName === 'BODY' || el.tagName === 'APP-ROOT') el.removeAttribute('aria-hidden');
        });
    }, 200);

    // --- 🔍 HELPERS ---
    function encontrar(texto) {
        const xpath = `//*[contains(translate(text(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '${texto.toLowerCase()}')]`;
        const snapshot = document.evaluate(xpath, document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
        for (let i = 0; i < snapshot.snapshotLength; i++) {
            let el = snapshot.snapshotItem(i);
            if (el.offsetParent !== null && el.getBoundingClientRect().height > 0) return el;
        }
        return null;
    }

    // --- 📡 RADAR ---
    function activarRadar(selector, textoRequerido, tourInstance) {
        console.log(`📡 Radar activado buscando: ${selector}`);
        if (window.tourInterval) clearInterval(window.tourInterval);
        window.tourInterval = setInterval(() => {
            if (isMoving) return;
            const botones = document.querySelectorAll(selector);
            for (const btn of botones) {
                if (btn.offsetParent === null || btn.getBoundingClientRect().height === 0) continue;
                if (textoRequerido && !btn.innerText.toLowerCase().includes(textoRequerido.toLowerCase())) continue;
                console.log("✅ Objetivo detectado. Avanzando...");
                clearInterval(window.tourInterval);
                setTimeout(() => avanzarSeguro(tourInstance), 500);
                return;
            }
        }, 200); 
    }

    // --- PASOS DEL TOUR ---
    const pasos = [
        { popover: { title: '🔐 Asistente de Facturación', description: 'Bienvenido. Sigue las indicaciones <br> para generar un DTE.', side: "center", align: 'center', doneBtnText: 'Empezar' } },
        { element: 'button.btn.btn-primary', popover: { title: '1. Iniciar Sesión', description: 'Clic en Iniciar Sesión.', side: "bottom", align: 'center' } },
        { element: '#username', popover: { title: '2. Ingresar NIT/DUI', description: 'Luego de escribirlo presionar Siguiente.', side: "bottom", align: 'center' } },
        { element: '#password', popover: { title: '3. Contraseña', description: 'Luego de escribirla presionar Siguiente.', side: "bottom", align: 'center' } },
        { element: 'select[formcontrolname="ambiente"]', popover: { title: '4. Ambiente', description: 'Selecciona "Ambiente Productivo" <br> o "Ambiente para Pruebas" <br> según sea tu caso, luego presiona <br> Siguiente.', side: "top", align: 'center' } },
        { get element() { return document.querySelector('button.btn-outline-primary') || document.querySelector('button[type*="submit"]') || encontrar('Iniciar sesión'); }, popover: { title: '5. Iniciar Sesión', description: 'Click en Iniciar Sesión.', side: "left", align: 'center' } },
        { get element() { const b = Array.from(document.querySelectorAll('button.swal2-confirm')); return b.find(x => x.innerText.trim() === 'OK' && x.offsetWidth > 0) || document.querySelector('button.swal2-confirm'); }, popover: { title: '6. Confirmar', description: 'Clic en <b>OK</b>.', side: "bottom", align: 'center' } },
        { get element() { return encontrar('Sistema de Facturación'); }, popover: { title: '7. Ingresar al Sistema de Facturación', description: 'Click en Sistema de Facturación.', side: "bottom", align: 'center' } },
        { element: 'select.swal2-select', popover: { title: '8. Tipo de Documento', description: 'Selecciona el documento a emitir <br> (Esta ayuda está orientada para Factura y CCF).<br><i>(Clic Siguiente)</i>', side: "right", align: 'center' } },
        { element: 'button.swal2-confirm', popover: { title: '9. Confirmar', description: 'Clic en <b>OK</b>.', side: "left", align: 'center' } },
        { element: '#btnGroupDrop2', popover: { title: '10. Agregar Detalle', description: 'Haz clic en Agregar Detalle.', side: "top", align: 'center' } },
        { get element() { return encontrar('Producto o Servicio'); }, popover: { title: '11. Producto o Servicio', description: 'Clic en "Producto o Servicio".', side: "right", align: 'center' } },
        { get element() { return document.querySelector('.modal-content'); }, popover: { title: '12. Agregar Productos', description: '👉 <b>PANEL LATERAL (Derecha)</b><br>Selecciona tu Producto o Servicio desde el panel lateral. <br> Si no lo tienes, puedes agregarlo <br> desde Configuraciónes (⚙️) o ingresarlo <br> manualmente.<br><br><b>Presiona "Siguiente" cuando termines.</b>', side: "left", align: 'center' } },
        { get element() { return document.querySelector('button[popovertitle="Ítem DTE"]') || encontrar('Agregar ítem') || encontrar('Agregar item'); }, popover: { title: '13. Guardar Ítem', description: 'Clic en "Agregar ítem".<br>', side: "top", align: 'center' } },
        { element: '.swal2-actions', popover: { title: '14. ¿Qué deseas hacer?', description: '🔵 <b>Seguir Adicionando:</b> Agrega Produtos.<br>⚪ <b>Regresar al Documento: <br></b> Seguir el proceso de facturación.', side: "top", align: 'center' } },
        { get element() { return document.querySelector('tab[heading="Receptor"]'); }, popover: { title: '15. Agregar Cliente', description: '👉  <b>PANEL LATERAL (Derecha)</b><br>Selecciona tu cliente desde el panel lateral y presiona Aplicar Datos desde el panel laterla. <br> Si no lo tienes, puedes agregarlo <br> desde Configuraciónes (⚙️) o ingresarlo <br> manualmente.<br><br><b>Presiona "Siguiente" cuando termines.</b>', side: "right", align: 'start' } },
        { element: 'select[formcontrolname="codigo"]', popover: { title: '16. Método de Pago', description: 'Selecciona el método de pago. <br> Billetes y monedas = Efectivo.', side: "top", align: 'center' } },
        { get element() { return document.querySelector('.fa-plus')?.closest('button') || document.querySelector('.fa-plus'); }, popover: { title: '17. Agregar Pago', description: 'Haz clic en el <b>(+)</b>.', side: "top", align: 'center' } },
        { element: 'input[value="Generar Documento"]', popover: { title: '18. Generar Documento', description: 'Haz clic para emitir.', side: "left", align: 'center' } },
        { get element() { const b = Array.from(document.querySelectorAll('button.swal2-confirm')); return b.find(x => x.innerText.includes('Si, crear')) || document.body; }, popover: { title: '19. Confirmar', description: 'Haz clic en <b>"Si, crear documento"</b>.', side: "bottom", align: 'center' } },
        { element: 'input.swal2-input[type="password"]', popover: { title: '20. Clave Privada', description: '🔑 <b>Ingresa tu Clave Privada.</b>.', side: "bottom", align: 'center' } },
        { element: 'button.swal2-confirm', popover: { title: '21. Firmar Documento', description: 'Haz clic en <b>OK</b>.', side: "bottom", align: 'center' } },
        { element: 'body', popover: { title: '🎉 ¡Factura Exitosa!', description: 'Puedes enviar la factura por correo con el botón del panel lateral (📧).', side: "left", align: 'center', doneBtnText: 'Finalizar' } }
    ];

    // --- MOTOR DEL TOUR ---
    window.tourInstance = driverObj({
        allowClose: false,
        overlayClickNext: false,
        showProgress: true,
        animate: true,
        nextBtnText: 'Siguiente',
        prevBtnText: 'Atrás',
        doneBtnText: 'Finalizar',
        steps: pasos,
        onDestroyed: () => { 
            try { 
                document.body.classList.remove('tour-edit-mode'); 
                document.body.classList.remove('tour-ocultar-siguiente'); 
                chrome.runtime.sendMessage({ action: "TOUR_ENDED" }); 
            } catch (e) {} 
        },

        onHighlightStarted: (element, step, options) => {
            // --- 🧹 SEGURIDAD: Detener cualquier radar anterior ---
            if (window.tourInterval) {
                console.log("🛑 Limpiando radar anterior...");
                clearInterval(window.tourInterval);
                window.tourInterval = null;
            }

            const titulo = step.popover.title;
            
            // --- GESTIÓN DE BOTONES ---
            const debeOcultarse = PASOS_SIN_BOTON.some(textoProhibido => titulo.includes(textoProhibido));
            if (debeOcultarse) {
                document.body.classList.add('tour-ocultar-siguiente');
            } else {
                document.body.classList.remove('tour-ocultar-siguiente');
            }

            // --- 2. PASO 2 (USERNAME): Listener para ENTER ---
            if (titulo.includes('2. Ingresar NIT/DUI') && element) {
                element.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter') {
                        setTimeout(() => avanzarSeguro(window.tourInstance), 300);
                    }
                }, { once: true });
            }

            // --- 3. MODALES Y EDICIÓN (PASOS 12 Y 15) ---
            // CORREGIDO: Ahora busca el título exacto "12. Agregar Productos" para activar el modo edición
            const esPasoEdicion = titulo.includes('12. Agregar Productos') || titulo.includes('15. Agregar Cliente');
            if (esPasoEdicion) {
                document.body.classList.add('tour-edit-mode');
                
                // Limpiar tooltips molestos si es el paso 12
                if (titulo.includes('12. Agregar Productos')) {
                    setTimeout(() => {
                        const m = document.querySelector('.modal-content');
                        if (m) m.querySelectorAll('[tooltip],[ngbpopover],[title],[popovertitle]').forEach(e=>e.removeAttribute(e.attributes[0].name));
                    }, 100);
                }
                setTimeout(() => { if(element && element.querySelector) { const i = element.querySelector('input, select'); if(i) i.focus(); } }, 200);
            } else {
                document.body.classList.remove('tour-edit-mode');
            }

            // --- RADARES (Avance automático por detección visual) ---
            if (titulo.includes('18. Generar')) activarRadar('button.swal2-confirm', 'Si, crear', window.tourInstance);
            if (titulo.includes('5. Iniciar Sesión')) activarRadar('button.swal2-confirm', null, window.tourInstance);
            if (titulo.includes('13. Guardar')) activarRadar('.swal2-actions', null, window.tourInstance);
            if (titulo.includes('19. Confirmar')) activarRadar('input.swal2-input[type="password"]', null, window.tourInstance);

            // --- LISTENERS DE CLIC (PARA AVANZAR) ---
            if (!element) return;
            if (element === document.body && step.popover.side !== 'center') return;
            if (element.__tourController) { element.__tourController.abort(); delete element.__tourController; }

            const tagName = element.tagName.toLowerCase();
            const esSelectSwal = element.classList.contains('swal2-select');
            if (tagName === 'input' || tagName === 'textarea' || (tagName === 'select' && !esSelectSwal)) return;
            if (esSelectSwal) return;

            // Excepción SweetAlert
            if (element.classList.contains('swal2-actions')) {
                const btnSeguir = document.querySelector('button.swal2-confirm'); 
                const btnRegresar = document.querySelector('button.swal2-cancel'); 
                if (btnSeguir) btnSeguir.onclick = () => { setTimeout(() => window.tourInstance.drive(12), 500); };
                if (btnRegresar) btnRegresar.onclick = () => { setTimeout(() => avanzarSeguro(window.tourInstance), 500); };
                return;
            }

            // Listener estándar: Solo se agrega SI NO ES PASO DE EDICIÓN
            if (!esPasoEdicion) { 
                const controller = new AbortController();
                element.__tourController = controller;
                setTimeout(() => {
                    element.addEventListener('click', () => { setTimeout(() => avanzarSeguro(window.tourInstance), 500); }, { signal: controller.signal, once: true });
                }, 300);
            }
        }
    });

    if (!window.hasTourListener) {
        window.hasTourListener = true;
        chrome.runtime.onMessage.addListener((msg) => {
            if (msg.action === "STOP_TOUR" && window.tourInstance) window.tourInstance.destroy();
        });
    }

    window.tourInstance.drive();
})();