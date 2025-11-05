package com.facturacion.sv.app_factura

import android.media.MediaScannerConnection
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "com.facturacion.sv.app_factura/files"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"scanFile" -> {
					val path = call.argument<String>("path")
					if (path != null) {
						try {
							MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
							result.success(true)
						} catch (e: Exception) {
							result.error("SCAN_ERROR", e.message, null)
						}
					} else {
						result.error("NO_PATH", "No se proporcionó path", null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
