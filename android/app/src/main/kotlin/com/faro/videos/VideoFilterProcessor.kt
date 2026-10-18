package com.faro.videos

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import com.google.android.gms.tasks.Tasks
import com.google.common.collect.ImmutableList
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class VideoFilterException(val code: String, message: String) : Exception(message)

data class VideoFilterRequest(
    val inputPath: String,
    val outputPath: String,
    val overlayPath: String,
    val filter: FilterKind,
    val maxDurationMs: Long,
    val maxHeight: Int,
)

/**
 * Burns a face-tracking sprite into a video: analysis (MediaMetadataRetriever + ML Kit) runs on a
 * background thread, export (Media3 Transformer) runs on the main looper.
 */
@OptIn(UnstableApi::class)
class VideoFilterProcessor(private val context: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var busy = false

    fun process(
        request: VideoFilterRequest,
        onProgress: (stage: String, progress: Double) -> Unit,
        onSuccess: (String) -> Unit,
        onError: (VideoFilterException) -> Unit,
    ) {
        if (busy) {
            onError(VideoFilterException(EXPORT_FAILED, "Ya hay un video procesándose."))
            return
        }
        busy = true
        val fail = { e: VideoFilterException -> busy = false; onError(e) }
        executor.execute {
            try {
                val analysis = analyze(request) { p -> mainHandler.post { onProgress(STAGE_ANALYZING, p) } }
                val sprite = BitmapFactory.decodeFile(request.overlayPath)
                    ?: throw VideoFilterException(EXPORT_FAILED, "No se pudo leer el filtro.")
                mainHandler.post {
                    try {
                        export(request, analysis, sprite, onProgress, { busy = false; onSuccess(it) }, fail)
                    } catch (e: Exception) {
                        fail(VideoFilterException(EXPORT_FAILED, e.message ?: "Error al exportar."))
                    }
                }
            } catch (e: VideoFilterException) {
                mainHandler.post { fail(e) }
            } catch (e: Exception) {
                mainHandler.post { fail(VideoFilterException(INVALID_VIDEO, e.message ?: "Video no válido.")) }
            }
        }
    }

    private class Analysis(val track: PlacementTrack, val width: Int, val height: Int)

    private fun analyze(request: VideoFilterRequest, onProgress: (Double) -> Unit): Analysis {
        val retriever = MediaMetadataRetriever()
        val detector = FaceDetection.getClient(
            FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
                .build()
        )
        try {
            try {
                retriever.setDataSource(request.inputPath)
            } catch (e: Exception) {
                throw VideoFilterException(INVALID_VIDEO, "No se pudo abrir el video.")
            }
            val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
                ?: throw VideoFilterException(INVALID_VIDEO, "El video no tiene duración.")
            if (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) != "yes") {
                throw VideoFilterException(INVALID_VIDEO, "El archivo no contiene video.")
            }
            if (durationMs > request.maxDurationMs) {
                throw VideoFilterException(TOO_LONG, "El video supera la duración máxima.")
            }
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            val codedWidth = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val codedHeight = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val quarterTurn = rotation % 180 != 0
            val width = if (quarterTurn) codedHeight else codedWidth
            val height = if (quarterTurn) codedWidth else codedHeight
            if (width <= 0 || height <= 0) throw VideoFilterException(INVALID_VIDEO, "Dimensiones de video no válidas.")

            val times = (0..durationMs step SAMPLE_INTERVAL_MS).toList()
            val samples = ArrayList<kotlin.Pair<Long, Placement>>()
            times.forEachIndexed { index, timeMs ->
                val frame = retriever.getFrameAtTime(timeMs * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
                if (frame != null) {
                    val upright = uprightFrame(frame, rotation, width, height)
                    val scaled = downscale(upright, request.maxHeight)
                    val faces = Tasks.await(detector.process(InputImage.fromBitmap(scaled, 0)))
                    val face = faces.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }
                    val placement = face?.let { FaceGeometry.placement(it.toInput(), request.filter) }
                    if (placement != null) {
                        samples.add(timeMs to PlacementTrack.normalize(placement, scaled.width, scaled.height))
                    }
                    if (scaled !== frame) scaled.recycle()
                    if (upright !== frame && upright !== scaled) upright.recycle()
                    frame.recycle()
                }
                onProgress((index + 1).toDouble() / times.size)
            }
            if (samples.isEmpty()) throw VideoFilterException(NO_FACE, "No se detectó un rostro.")
            return Analysis(PlacementTrack(samples), width, height)
        } finally {
            detector.close()
            retriever.release()
        }
    }

    private fun export(
        request: VideoFilterRequest,
        analysis: Analysis,
        sprite: Bitmap,
        onProgress: (String, Double) -> Unit,
        onSuccess: (String) -> Unit,
        onError: (VideoFilterException) -> Unit,
    ) {
        val output = File(request.outputPath)
        if (output.exists()) output.delete()
        output.parentFile?.mkdirs()

        // Transformer's decoder applies the container rotation before effects run, so effects see
        // the upright frame (same orientation as the analysis frames).
        // maxHeight limits the shorter side: 720p is 1280x720 landscape and 720x1280 portrait.
        val videoEffects = ArrayList<androidx.media3.common.Effect>()
        val shorterSide = minOf(analysis.width, analysis.height)
        if (shorterSide > request.maxHeight) {
            val scale = request.maxHeight.toDouble() / shorterSide
            videoEffects.add(
                Presentation.createForWidthAndHeight(
                    evenPixels(analysis.width * scale),
                    evenPixels(analysis.height * scale),
                    Presentation.LAYOUT_STRETCH_TO_FIT,
                )
            )
        }
        val overlay = FaceTrackingOverlay(sprite, analysis.track)
        videoEffects.add(OverlayEffect(ImmutableList.of(overlay)))

        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(request.inputPath))))
            .setEffects(Effects(emptyList(), videoEffects))
            .build()

        val progressHolder = ProgressHolder()
        var finished = false
        lateinit var transformer: Transformer
        val poll = object : Runnable {
            override fun run() {
                if (finished) return
                if (transformer.getProgress(progressHolder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    onProgress(STAGE_EXPORTING, progressHolder.progress / 100.0)
                }
                mainHandler.postDelayed(this, PROGRESS_POLL_MS)
            }
        }
        transformer = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    finished = true
                    sprite.recycle()
                    onProgress(STAGE_EXPORTING, 1.0)
                    onSuccess(request.outputPath)
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    finished = true
                    sprite.recycle()
                    File(request.outputPath).delete()
                    onError(VideoFilterException(EXPORT_FAILED, exportException.message ?: "Error al exportar."))
                }
            })
            .build()
        onProgress(STAGE_EXPORTING, 0.0)
        transformer.start(item, request.outputPath)
        mainHandler.post(poll)
    }

    companion object {
        const val TOO_LONG = "TOO_LONG"
        const val INVALID_VIDEO = "INVALID_VIDEO"
        const val NO_FACE = "NO_FACE"
        const val EXPORT_FAILED = "EXPORT_FAILED"
        const val STAGE_ANALYZING = "analyzing"
        const val STAGE_EXPORTING = "exporting"
        private const val SAMPLE_INTERVAL_MS = 200L
        private const val PROGRESS_POLL_MS = 200L

        /**
         * MediaMetadataRetriever normally returns frames already rotated for display; if a device
         * returns the coded orientation instead (dimensions not swapped), rotate it here. Rotation
         * metadata is clockwise, as is Matrix.postRotate in y-down bitmap space.
         */
        private fun uprightFrame(frame: Bitmap, rotation: Int, width: Int, height: Int): Bitmap {
            val needsRotation = rotation % 180 != 0 && width != height &&
                (frame.width > frame.height) != (width > height)
            if (!needsRotation) return frame
            val m = Matrix().apply { postRotate(rotation.toFloat()) }
            return Bitmap.createBitmap(frame, 0, 0, frame.width, frame.height, m, true)
        }

        // Video encoders need even dimensions.
        private fun evenPixels(value: Double): Int = (value.roundToInt() / 2) * 2

        private fun downscale(frame: Bitmap, maxHeight: Int): Bitmap {
            if (frame.height <= maxHeight) return frame
            val w = (frame.width.toDouble() * maxHeight / frame.height).roundToInt().coerceAtLeast(1)
            return Bitmap.createScaledBitmap(frame, w, maxHeight, true)
        }

        private fun Face.toInput(): FaceInput {
            fun landmark(type: Int) = getLandmark(type)?.position?.let { Point(it.x.toDouble(), it.y.toDouble()) }
            val b = boundingBox
            return FaceInput(
                leftEye = landmark(FaceLandmark.LEFT_EYE),
                rightEye = landmark(FaceLandmark.RIGHT_EYE),
                noseBase = landmark(FaceLandmark.NOSE_BASE),
                mouthLeft = landmark(FaceLandmark.MOUTH_LEFT),
                mouthRight = landmark(FaceLandmark.MOUTH_RIGHT),
                box = Box(b.left.toDouble(), b.top.toDouble(), b.width().toDouble(), b.height().toDouble()),
            )
        }
    }
}
