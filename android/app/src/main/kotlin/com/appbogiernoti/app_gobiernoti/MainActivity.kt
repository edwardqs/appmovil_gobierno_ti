package com.appbogiernoti.app_gobiernoti

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Configure window flags to improve graphics compatibility
        window.setFlags(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )
        
        // Disable window animations that might cause buffer issues
        window.setWindowAnimations(0)
        
        // Set preferred pixel format for better compatibility
        window.setFormat(android.graphics.PixelFormat.RGBA_8888)
    }
}