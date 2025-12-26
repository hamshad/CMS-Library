#Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Maps (if used, keeping just in case)
# -keep class com.google.android.gms.maps.** { *; }
# -keep interface com.google.android.gms.maps.** { *; }

# Square OkHttp
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# Gson
# -keep class sun.misc.Unsafe { *; }
# -keep class com.google.gson.** { *; }

# Mobile Scanner
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# AndroidX and Support
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**
-dontwarn android.support.**

# General
-dontwarn **
