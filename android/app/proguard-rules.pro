# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep audioplayers plugin
-keep class com.xyz.audioplayers.** { *; }

# Keep flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep Google Fonts
-keep class com.google.android.gms.** { *; }

# Encrypt package - keep AES and cipher classes
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Prevent obfuscation of model classes used with JSON/serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep generic signature of Call, Response (R8 full mode strips signatures from non-kept items)
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response

# With R8 full mode generic signatures are stripped for classes that are not kept.
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation

# Flutter Waveform
-keep class com.example.flutter_waveform.** { *; }
