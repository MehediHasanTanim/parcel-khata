package com.parcelkhata.parcel_khata

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth (biometric prompt) requires a FragmentActivity.
// Also receives plain text shared from other apps (e.g. a WhatsApp message)
// so it can open the "Paste order" screen. Text stays on the device.
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var pendingText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingText = extractSharedText(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "parcel_khata/share").also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "getSharedText") {
                    result.success(pendingText)
                    pendingText = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = extractSharedText(intent) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("shared", text) else pendingText = text
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)
    }
}
