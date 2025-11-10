plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties // Importar la clase Properties

android {
    namespace = "com.facturacion.sv.app_factura"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    // --- INICIO: Bloque de Configuración de Firma para Producción ---
    signingConfigs {
        create("release") {
            val keystoreProperties = Properties()
            val keystoreFile = rootProject.file("key.properties")
            
            // Cargar las propiedades si el archivo existe
            if (keystoreFile.exists()) {
                keystoreFile.inputStream().use {
                    keystoreProperties.load(it)
                }
            } else {
                // Imprimir error si el archivo no se encuentra (para debugging)
                println("ERROR: El archivo key.properties NO fue encontrado en la carpeta android/. Usando configuracion debug temporal.")
            }

            // Asignar los valores del archivo key.properties
            // Si key.properties no existe, estos valores seran vacios.
            storeFile = file(keystoreProperties.getProperty("storeFile") ?: "")
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }
    // --- FIN: Bloque de Configuración de Firma para Producción ---


    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.facturacion.sv.app_factura"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Se elimina el uso de signingConfigs.getByName("debug") y se usa la nueva configuracion "release"
            signingConfig = signingConfigs.getByName("release") 
        }
    }
}
// Forzar Sincronización
// Forzar Sincronización

flutter {
    source = "../.."
}