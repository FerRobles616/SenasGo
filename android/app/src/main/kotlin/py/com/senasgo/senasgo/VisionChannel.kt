package py.com.senasgo.senasgo

import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/**
 * Puente con MediaPipe Tasks (oficial de Google) para la práctica con cámara.
 *
 * - HandLandmarker: detecta la palma, ubica 21 puntos por mano (en la imagen y
 *   en 3D, en metros) y sigue la mano entre cuadros (modo VIDEO).
 * - PoseLandmarker (lite): cara, hombros y torso, para evaluar el "lugar".
 *
 * Flutter manda cada cuadro ya derecho y espejado (como la vista previa) en
 * RGBA. Todo corre en un hilo propio; nada sale del teléfono.
 */
class VisionChannel(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "senasgo/vision")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var hands: HandLandmarker? = null
    private var pose: PoseLandmarker? = null
    private var bitmap: Bitmap? = null
    private var lastTimestamp = -1L
    private var delegate = "none"

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> worker.execute {
                val ok = try {
                    load()
                    true
                } catch (e: Throwable) {
                    Log.e(TAG, "No se pudieron cargar los modelos", e)
                    false
                }
                main.post { result.success(mapOf("ok" to ok, "delegate" to delegate)) }
            }

            "detect" -> {
                val bytes = call.argument<ByteArray>("rgba")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val ts = (call.argument<Number>("timestampMs") ?: 0).toLong()
                if (bytes == null || width <= 0 || height <= 0) {
                    result.error("bad_args", "Cuadro inválido", null)
                    return
                }
                worker.execute {
                    val out = try {
                        detect(bytes, width, height, ts)
                    } catch (e: Throwable) {
                        Log.e(TAG, "Error detectando", e)
                        null
                    }
                    main.post { result.success(out) }
                }
            }

            "close" -> worker.execute {
                close()
                main.post { result.success(null) }
            }

            else -> result.notImplemented()
        }
    }

    private fun load() {
        if (hands != null) return
        // GPU primero (más rápido y frío); si el equipo no lo soporta, CPU.
        for (d in listOf(Delegate.GPU, Delegate.CPU)) {
            try {
                hands = HandLandmarker.createFromOptions(
                    context,
                    HandLandmarker.HandLandmarkerOptions.builder()
                        .setBaseOptions(
                            BaseOptions.builder()
                                .setModelAssetPath("mediapipe/hand_landmarker.task")
                                .setDelegate(d)
                                .build()
                        )
                        .setRunningMode(RunningMode.VIDEO)
                        .setNumHands(2)
                        .setMinHandDetectionConfidence(0.5f)
                        .setMinHandPresenceConfidence(0.5f)
                        .setMinTrackingConfidence(0.5f)
                        .build()
                )
                pose = PoseLandmarker.createFromOptions(
                    context,
                    PoseLandmarker.PoseLandmarkerOptions.builder()
                        .setBaseOptions(
                            BaseOptions.builder()
                                .setModelAssetPath("mediapipe/pose_landmarker_lite.task")
                                .setDelegate(d)
                                .build()
                        )
                        .setRunningMode(RunningMode.VIDEO)
                        .setNumPoses(1)
                        .setMinPoseDetectionConfidence(0.5f)
                        .setMinPosePresenceConfidence(0.5f)
                        .setMinTrackingConfidence(0.5f)
                        .build()
                )
                delegate = d.name.lowercase()
                return
            } catch (e: Throwable) {
                Log.w(TAG, "Delegado ${d.name} no disponible: ${e.message}")
                close()
            }
        }
        throw IllegalStateException("MediaPipe no disponible en este equipo")
    }

    private fun detect(bytes: ByteArray, width: Int, height: Int, ts: Long): Map<String, Any>? {
        val handModel = hands ?: return null
        var bmp = bitmap
        if (bmp == null || bmp.width != width || bmp.height != height) {
            bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            bitmap = bmp
        }
        bmp!!.copyPixelsFromBuffer(ByteBuffer.wrap(bytes))
        val image = BitmapImageBuilder(bmp).build()
        // El modo VIDEO exige marcas de tiempo crecientes.
        val stamp = if (ts <= lastTimestamp) lastTimestamp + 1 else ts
        lastTimestamp = stamp

        val handResult = handModel.detectForVideo(image, stamp)
        val handList = ArrayList<Map<String, Any>>()
        for (i in handResult.landmarks().indices) {
            val lm = handResult.landmarks()[i]
            val world = handResult.worldLandmarks().getOrNull(i)
            val cat = handResult.handedness().getOrNull(i)?.firstOrNull()
            val points = DoubleArray(63)
            for (j in 0 until 21) {
                points[j * 3] = lm[j].x().toDouble()
                points[j * 3 + 1] = lm[j].y().toDouble()
                points[j * 3 + 2] = lm[j].z().toDouble()
            }
            val worldPoints = DoubleArray(63)
            if (world != null) {
                for (j in 0 until 21) {
                    worldPoints[j * 3] = world[j].x().toDouble()
                    worldPoints[j * 3 + 1] = world[j].y().toDouble()
                    worldPoints[j * 3 + 2] = world[j].z().toDouble()
                }
            }
            handList.add(
                mapOf(
                    "points" to points,
                    "world" to worldPoints,
                    // MediaPipe Tasks etiqueta como si la imagen NO estuviera
                    // espejada: con nuestra imagen (selfie), "Left" es la mano
                    // derecha real. Verificado con video de un señante.
                    "right" to (cat?.categoryName() == "Left"),
                    "score" to (cat?.score()?.toDouble() ?: 0.0),
                )
            )
        }

        val out = HashMap<String, Any>()
        out["hands"] = handList
        val poseModel = pose
        if (poseModel != null) {
            val poseResult = poseModel.detectForVideo(image, stamp)
            val body = poseResult.landmarks().firstOrNull()
            if (body != null) {
                val p = DoubleArray(body.size * 4)
                for (j in body.indices) {
                    p[j * 4] = body[j].x().toDouble()
                    p[j * 4 + 1] = body[j].y().toDouble()
                    p[j * 4 + 2] = body[j].z().toDouble()
                    p[j * 4 + 3] = body[j].visibility().orElse(0f).toDouble()
                }
                out["pose"] = p
            }
        }
        return out
    }

    private fun close() {
        hands?.close()
        pose?.close()
        hands = null
        pose = null
        lastTimestamp = -1L
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.execute { close() }
        worker.shutdown()
    }

    companion object {
        private const val TAG = "SenasGoVision"
    }
}
