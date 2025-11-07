// Importamos específicamente las herramientas de 2da generación (v2)
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

exports.validateLicense = onCall({ cors: true }, async (request) => {
    // --- DIAGNÓSTICO ---
    // En Gen 2, los datos que envía Flutter viven dentro de 'request.data'
    const data = request.data || {};
    logger.info("=== [V4 GEN 2] DATOS RECIBIDOS ===", { structuredData: true, data: data });

    const userKey = data.key;
    const deviceId = data.deviceId;

    // --- VALIDACIÓN DE ENTRADA ---
    if (!userKey) {
        throw new HttpsError('invalid-argument', 'La clave de licencia es obligatoria (recibido nulo).');
    }
    if (!deviceId) {
        throw new HttpsError('invalid-argument', 'El ID del dispositivo es obligatorio (recibido nulo).');
    }

    // --- LÓGICA PRINCIPAL ---
    const licensesRef = admin.firestore().collection('licenses');

    try {
        const snapshot = await licensesRef.where('key', '==', userKey).limit(1).get();

        if (snapshot.empty) {
            logger.warn(`Clave no encontrada: ${userKey}`);
            return { success: false, message: "Clave de licencia no válida." };
        }

        const doc = snapshot.docs[0];
        const licenseData = doc.data();

        if (licenseData.isActive === false) {
            logger.warn(`Licencia inactiva intentó acceder: ${userKey}`);
            return { success: false, message: "Esta licencia ha sido revocada." };
        }

        // CASO 1: Licencia NUEVA
        if (!licenseData.deviceId) {
            logger.info(`Activando licencia nueva: ${userKey} para dispositivo: ${deviceId}`);
            await doc.ref.update({
                deviceId: deviceId,
                activatedAt: admin.firestore.FieldValue.serverTimestamp(),
                lastValidatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            return { success: true, tier: licenseData.tier || 'PRO', message: "¡Activación exitosa!" };
        }

        // CASO 2: Mismo dispositivo (Re-validación)
        if (licenseData.deviceId === deviceId) {
            logger.info(`Re-validación correcta para: ${userKey}`);
            await doc.ref.update({
                lastValidatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            return { success: true, tier: licenseData.tier || 'PRO', message: "Licencia validada." };
        }

        // CASO 3: Intento de uso en otro dispositivo
        logger.warn(`BLOQUEO DE SEGURIDAD: ${userKey}. Dueño: ${licenseData.deviceId} vs Intruso: ${deviceId}`);
        return {
            success: false,
            message: "Esta licencia ya está activada en otro dispositivo."
        };

    } catch (error) {
        logger.error("Error interno crítico:", error);
        throw new HttpsError('internal', 'Error del servidor al procesar la licencia.');
    }
});