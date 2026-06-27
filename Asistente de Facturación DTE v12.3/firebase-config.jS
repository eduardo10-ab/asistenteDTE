// firebase-config.js
// IMPORTANTE: Usamos ./ para indicar que están en la misma carpeta
import { initializeApp } from "./firebase-app.js";
import { 
    getFirestore, 
    doc, 
    getDoc, 
  getDocFromServer,
    setDoc, 
    updateDoc, 
    onSnapshot // <--- ¡ESTA ES LA CLAVE PARA EL TIEMPO REAL!
} from "./firebase-firestore.js";

// Tu configuración sigue igual
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

// Exportamos todas las funciones necesarias
export { db, doc, getDoc, getDocFromServer, setDoc, updateDoc, onSnapshot };