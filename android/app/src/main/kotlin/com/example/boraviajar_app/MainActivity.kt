package com.example.boraviajar_app

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d(TAG, "onNewIntent: ${intent.data}")
    }

    companion object {
        private const val TAG = "BoraViajarAuth"
    }
}
