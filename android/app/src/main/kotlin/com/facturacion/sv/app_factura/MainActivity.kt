package com.facturacion.sv.app_factura

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Environment
import android.provider.MediaStore
import android.content.ContentValues
import android.net.Uri
import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Build

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.facturacion.sv.app_factura/files"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        scanFile(path, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Path cannot be null", null)
                    }
                }
                "saveToDownloads" -> {
                    val data = call.argument<ByteArray>("data")
                    val filename = call.argument<String>("filename")
                    if (data != null && filename != null) {
                        saveToDownloads(data, filename, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Data or filename cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // --- FUNCIÓN PARA ELIMINAR EL ERROR DE PERMISO DENIED ---
    private fun saveToDownloads(data: ByteArray, filename: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ (API 29+): Usamos MediaStore API (Scoped Storage)
            val resolver = contentResolver
            val mimeType = when {
                filename.endsWith(".json") -> "application/json"
                filename.endsWith(".pdf") -> "application/pdf"
                else -> "application/octet-stream"
            }

            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }

            var uri: Uri? = null
            try {
                uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                if (uri == null) {
                    result.error("WRITE_FAILED", "Failed to create new MediaStore record.", null)
                    return
                }

                resolver.openOutputStream(uri)?.use { outputStream ->
                    outputStream.write(data)
                    outputStream.flush()
                }

                // Devolvemos el path del archivo, que es crucial para OpenFilex
                val path = getRealPathFromUri(uri)
                if (path != null) {
                    result.success(path)
                } else {
                    result.success("") // Devolver cadena vacía si no se puede obtener la ruta real
                }
            } catch (e: Exception) {
                if (uri != null) {
                    // Borrar el registro incompleto si falla la escritura
                    resolver.delete(uri, null, null)
                }
                result.error("WRITE_ERROR", "Error writing file to MediaStore: ${e.localizedMessage}", e.toString())
            }
        } else {
            // Android 9 e inferiores: Usamos el método de archivo directo (que requiere el permiso en Manifest)
            try {
                // Usamos el path hardcodeado que funcionaba en versiones antiguas
                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (!downloadsDir.exists()) {
                    downloadsDir.mkdirs()
                }
                val file = java.io.File(downloadsDir, filename)
                file.writeBytes(data)

                scanFile(file.absolutePath, result)
            } catch (e: Exception) {
                result.error("WRITE_ERROR_LEGACY", "Error writing file to Downloads folder: ${e.localizedMessage}", e.toString())
            }
        }
    }

    // Función auxiliar para obtener la ruta del archivo a partir del URI (Necesario para OpenFilex)
    private fun getRealPathFromUri(contentUri: Uri): String? {
        val cursor = contentResolver.query(contentUri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)
        return cursor?.use {
            if (it.moveToFirst()) {
                it.getString(it.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA))
            } else {
                null
            }
        }
    }

    // --- FUNCIÓN DE ESCANEO DE ARCHIVOS (EXISTENTE EN TU CÓDIGO) ---
    private fun scanFile(path: String, result: MethodChannel.Result) {
        MediaScannerConnection.scanFile(
            this,
            arrayOf(path),
            null
        ) { _, uri ->
            // La función scanFile es solo para notificar a la galería, no devuelve nada útil.
            // Para mantener la consistencia con el código Flutter, devolvemos éxito.
            result.success(true) 
        }
    }
}