package com.example.isometric

import android.content.Context
import android.graphics.BitmapFactory
import com.ultralytics.yolo.BasePredictor
import com.ultralytics.yolo.Predictor
import com.ultralytics.yolo.YOLOTask
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Owns model initialization, inference, and disposal on one native thread. */
internal class PhotoInferenceWorker(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val executor = Executors.newSingleThreadExecutor()
    private val models = mutableMapOf<YOLOTask, LoadedModel>()
    private val channel = MethodChannel(messenger, "com.example.isometric/photo_inference")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "warm" && call.method != "predict") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            executor.execute {
                try {
                    val task = YOLOTask.valueOf(requireNotNull(call.argument<String>("task")).uppercase())
                    require(task == YOLOTask.SEGMENT || task == YOLOTask.DEPTH)
                    val asset = requireNotNull(call.argument<String>("asset"))
                    val model = models.getOrPut(task) { loadModel(asset, task) }
                    val response = if (call.method == "predict") {
                        predict(model.predictor, requireNotNull(call.argument<ByteArray>("image")))
                    } else {
                        null
                    }
                    result.success(response)
                } catch (error: Exception) {
                    result.error("photo_inference_failed", error.message, null)
                }
            }
        }
    }

    private fun loadModel(asset: String, task: YOLOTask): LoadedModel {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        // LiteRT takes a filesystem path. Keep the copy alive for the predictor.
        val file = File.createTempFile("photo-${task.name.lowercase()}-", ".tflite", context.cacheDir)
        try {
            context.assets.open(key).use { input ->
                file.outputStream().use { output -> input.copyTo(output) }
            }
            val predictor = Predictor.create(context, file.absolutePath, task, emptyList(), true)
            return LoadedModel(predictor as BasePredictor, file)
        } catch (error: Exception) {
            file.delete()
            throw error
        }
    }

    private fun predict(predictor: BasePredictor, bytes: ByteArray): Map<String, Any> {
        val bitmap = requireNotNull(BitmapFactory.decodeByteArray(bytes, 0, bytes.size)) {
            "Could not decode capture"
        }
        try {
            val width = bitmap.width
            val height = bitmap.height
            val prediction = predictor.predict(bitmap, width, height)
            val masks = prediction.masks?.masks
            val response = mutableMapOf<String, Any>(
                "detections" to prediction.boxes.mapIndexed { index, box ->
                    mapOf(
                        "classIndex" to box.index,
                        "className" to box.cls,
                        "confidence" to box.conf.toDouble(),
                        "normalizedBox" to mapOf(
                            "left" to box.xywh.left.toDouble() / width,
                            "top" to box.xywh.top.toDouble() / height,
                            "right" to box.xywh.right.toDouble() / width,
                            "bottom" to box.xywh.bottom.toDouble() / height,
                        ),
                        "mask" to masks?.getOrNull(index)?.map { it.toFloatArray() },
                    )
                },
            )
            prediction.depthMap?.let { depth ->
                depth.values?.let { values ->
                    response["depthMap"] = mapOf(
                        "values" to values,
                        "width" to depth.width,
                        "height" to depth.height,
                        "minDepth" to depth.minDepth.toDouble(),
                        "maxDepth" to depth.maxDepth.toDouble(),
                    )
                }
            }
            return response
        } finally {
            bitmap.recycle()
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        executor.execute {
            models.values.forEach { model ->
                try {
                    model.predictor.close()
                } finally {
                    model.file.delete()
                }
            }
            models.clear()
        }
        executor.shutdown()
    }

    private data class LoadedModel(val predictor: BasePredictor, val file: File)
}
