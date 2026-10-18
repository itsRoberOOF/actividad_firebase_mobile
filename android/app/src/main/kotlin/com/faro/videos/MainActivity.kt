package com.faro.videos

import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

@OptIn(UnstableApi::class)
class MainActivity : FlutterActivity() {
    private var progressSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val processor = VideoFilterProcessor(applicationContext)

        EventChannel(messenger, PROGRESS_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                progressSink = events
            }

            override fun onCancel(arguments: Any?) {
                progressSink = null
            }
        })

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "applyVideoFilter") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val request = parseRequest(call.arguments)
            if (request == null) {
                result.error(VideoFilterProcessor.INVALID_VIDEO, "Argumentos no válidos.", null)
                return@setMethodCallHandler
            }
            processor.process(
                request,
                onProgress = { stage, progress -> progressSink?.success(mapOf("stage" to stage, "progress" to progress)) },
                onSuccess = { result.success(it) },
                onError = { result.error(it.code, it.message, null) },
            )
        }
    }

    private fun parseRequest(arguments: Any?): VideoFilterRequest? {
        val args = arguments as? Map<*, *> ?: return null
        return VideoFilterRequest(
            inputPath = args["inputPath"] as? String ?: return null,
            outputPath = args["outputPath"] as? String ?: return null,
            overlayPath = args["overlayPath"] as? String ?: return null,
            filter = FilterKind.fromWireName(args["filter"] as? String) ?: return null,
            maxDurationMs = (args["maxDurationMs"] as? Number)?.toLong() ?: 15000L,
            maxHeight = (args["maxHeight"] as? Number)?.toInt() ?: 720,
        )
    }

    private companion object {
        const val METHOD_CHANNEL = "videoteca/video_filters"
        const val PROGRESS_CHANNEL = "videoteca/video_filters/progress"
    }
}
