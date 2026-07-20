# WorkManager creates its Room database implementation by class name during
# AndroidX Startup, before Flutter starts. Keep the generated implementation
# and its nested callbacks intact in minified release builds.
-keep class androidx.work.impl.WorkDatabase_Impl** { *; }

# Room also resolves generated database implementations reflectively.
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Database class * { *; }
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations,AnnotationDefault
