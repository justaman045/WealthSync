# WorkManager's Room database is created reflectively at runtime by Room:
#   Class.forName("androidx.work.impl.WorkDatabase_Impl")
#        .getDeclaredConstructor().newInstance()
# Room ships `-keep class * extends androidx.room.RoomDatabase` (which keeps the
# class name) but under R8 full mode that does NOT protect the generated no-arg
# constructor: R8 shrinks `WorkDatabase_Impl.<init>()` away and the app crashes
# at launch inside androidx.startup's InitializationProvider with
# `NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []`.
# Keep the class name AND its constructors explicitly.
-keep class * extends androidx.room.RoomDatabase {
    <init>(...);
}

# ML Kit Text Recognition Keep Rules
-keep class com.google.mlkit.vision.text.** { *; }

# The app ships only the Latin text recognizer. The chinese/devangari/japanese/
# korean modules are excluded from the build (see build.gradle.kts), but
# google_mlkit_text_recognition still references their option classes from a
# runtime switch. Silence R8 on those — the branches are dead at runtime and
# the classes are intentionally absent.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
