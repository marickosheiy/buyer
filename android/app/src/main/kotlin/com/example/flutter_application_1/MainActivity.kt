package com.example.flutter_application_1

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val prefs = getSharedPreferences("lumear_appearance", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumear/appearance")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(prefs.getString("mode", "light"))
                    "write" -> {
                        val mode = call.arguments as? String
                        if (mode in listOf("system", "light", "dark")) {
                            prefs.edit().putString("mode", mode).apply()
                            result.success(null)
                        } else result.error("INVALID_MODE", "Choose system, light or dark.", null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
