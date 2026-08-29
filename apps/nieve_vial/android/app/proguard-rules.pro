# Flutter/Plugins que ya tienes
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.work.** { *; }
-dontwarn org.bouncycastle.**

# Play Core / Feature Delivery (evita los Missing class ... tasks)
-keep class com.google.android.play.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.**
-dontwarn com.google.android.play.core.tasks.**

# Deferred components (aunque uses NoOp)
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.** { *; }