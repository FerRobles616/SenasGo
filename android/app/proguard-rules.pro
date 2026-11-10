# MediaPipe Tasks llama a clases Java desde código nativo (JNI) y usa
# protobuf lite por reflexión: R8 no debe renombrarlas ni quitarlas en release.
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**
-dontwarn javax.annotation.**
-dontwarn com.google.auto.value.**
