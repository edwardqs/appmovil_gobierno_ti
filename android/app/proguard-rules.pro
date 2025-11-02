# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase specific rules
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Biometric authentication
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Graphics and rendering optimizations
-keep class android.graphics.** { *; }
-keep class android.opengl.** { *; }
-keep class android.hardware.** { *; }
-dontwarn android.graphics.**
-dontwarn android.opengl.**
-dontwarn android.hardware.**

# Graphics buffer and gralloc optimizations
-keep class android.view.Surface { *; }
-keep class android.view.SurfaceView { *; }
-keep class android.view.TextureView { *; }
-keep class android.graphics.SurfaceTexture { *; }
-keep class android.hardware.HardwareBuffer { *; }

# NDK and native libraries
-keep class androidx.multidex.** { *; }
-dontwarn androidx.multidex.**

# Prevent obfuscation of graphics-related classes
-keepnames class * extends android.view.View
-keepnames class * extends android.graphics.drawable.Drawable

# Suppress ApkAssets warnings and optimize resource handling
-dontwarn android.content.res.ApkAssets
-keep class android.content.res.ApkAssets { *; }
-dontwarn android.content.res.AssetManager
-keep class android.content.res.AssetManager { *; }

# Optimize APK resource loading
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Reduce logging and debug information in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Suppress resource-related warnings
-dontwarn android.content.res.**
-dontwarn android.app.ApplicationPackageManager
-dontwarn android.content.pm.PackageManager