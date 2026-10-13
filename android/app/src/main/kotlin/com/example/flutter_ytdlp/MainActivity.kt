package com.example.flutter_ytdlp

import android.app.DownloadManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

import io.flutter.embedding.android.FlutterFragmentActivity


class MainActivity : FlutterFragmentActivity() {

    // ── Channel dùng chung cho ytdlp feature ──────────────────────────────────
    private val YTDLP_CHANNEL = "ytdlp_channel"
    private val activityScope  = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val ytdlpModule get() = YtdlpPython.module(applicationContext)

    override fun onDestroy() {
        super.onDestroy()
        activityScope.cancel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, YTDLP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Storage utils ─────────────────────────────────────────
                    "getDownloadDir" -> {
                        val dir = Environment.getExternalStoragePublicDirectory(
                            Environment.DIRECTORY_DOWNLOADS
                        ).absolutePath
                        result.success(dir)
                    }

                    "getSdkVersion" -> {
                        result.success(Build.VERSION.SDK_INT)
                    }

                    "openFolder" -> {
                        try {
                            val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                            } else {
                                val uri = Uri.parse(
                                    "content://com.android.externalstorage.documents/root/primary"
                                )
                                val fallback = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "vnd.android.document/root")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallback)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("OPEN_FOLDER_ERROR", e.message, null)
                        }
                    }

                    "getBackendInfo" -> {
                        activityScope.launch {
                            try {
                                val info = ytdlpModule.callAttr("get_backend_info").toString()
                                withContext(Dispatchers.Main) { result.success(info) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("BACKEND_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    // ── yt-dlp: analyze ───────────────────────────────────────
                    "analyze" -> {
                        val url = call.argument<String>("url") ?: ""
                        activityScope.launch {
                            try {
                                val res = ytdlpModule.callAttr("analyze", url).toString()
                                withContext(Dispatchers.Main) { result.success(res) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("ANALYZE_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    // ── yt-dlp: foreground download queue ─────────────────────
                    "enqueueDownload" -> {
                        val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                        val taskId = arguments["taskId"] as? String ?: ""
                        if (taskId.isEmpty()) {
                            result.error("DOWNLOAD_ERROR", "Missing taskId", null)
                            return@setMethodCallHandler
                        }
                        DownloadForegroundService.enqueue(applicationContext, arguments)
                        result.success("{\"accepted\":true}")
                    }

                    "getDownloadTask" -> {
                        val taskId = call.argument<String>("taskId") ?: ""
                        result.success(
                            DownloadForegroundService.readTask(applicationContext, taskId)
                        )
                    }

                    "getDownloadTasks" -> {
                        result.success(DownloadForegroundService.readTasks(applicationContext))
                    }

                    "removeFinishedDownload" -> {
                        val taskId = call.argument<String>("taskId") ?: ""
                        DownloadForegroundService.removeFinished(applicationContext, taskId)
                        result.success(null)
                    }

                    "clearFinishedDownloads" -> {
                        DownloadForegroundService.clearFinished(applicationContext)
                        result.success(null)
                    }

                    // ── yt-dlp: cooperative cancellation ──────────────────────
                    "cancelDownload" -> {
                        val taskId = call.argument<String>("taskId") ?: ""
                        val before = DownloadForegroundService.readTask(
                            applicationContext,
                            taskId
                        )
                        val cancellable = before != null && listOf(
                            "queued",
                            "preparing",
                            "downloading",
                            "waitingToRetry",
                        ).any { before.contains("\"status\":\"$it\"") }
                        if (taskId.isEmpty() || !cancellable) {
                            result.success("{\"accepted\":false,\"stopped\":false}")
                            return@setMethodCallHandler
                        }

                        DownloadForegroundService.cancel(applicationContext, taskId)
                        activityScope.launch {
                            val stopped = withTimeoutOrNull(15_000) {
                                while (true) {
                                    val snapshot = DownloadForegroundService.readTask(
                                        applicationContext,
                                        taskId
                                    )
                                    if (snapshot?.contains("\"status\":\"cancelled\"") == true) {
                                        return@withTimeoutOrNull true
                                    }
                                    delay(100)
                                }
                            } == true
                            withContext(Dispatchers.Main) {
                                result.success("{\"accepted\":true,\"stopped\":$stopped}")
                            }
                        }
                    }

                    // ── yt-dlp: poll progress ─────────────────────────────────
                    "getProgress" -> {
                        val taskId = call.argument<String>("taskId") ?: ""
                        if (taskId.isEmpty()) {
                            result.error("PROGRESS_ERROR", "Missing taskId", null)
                            return@setMethodCallHandler
                        }
                        activityScope.launch {
                            try {
                                val res = ytdlpModule.callAttr("get_progress", taskId).toString()
                                withContext(Dispatchers.Main) { result.success(res) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("PROGRESS_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    "getPlaylistEntries" -> {
                        val url = call.argument<String>("url") ?: ""
                        activityScope.launch {
                            try {
                                val res = ytdlpModule.callAttr("get_playlist_entries", url).toString()
                                withContext(Dispatchers.Main) { result.success(res) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("PLAYLIST_ENTRIES_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    // ── Audio extraction: native MediaExtractor + MediaMuxer ──
                    "extractAudio" -> {
                        val inputPath  = call.argument<String>("inputPath")  ?: ""
                        val outputPath = call.argument<String>("outputPath") ?: ""
                        activityScope.launch {
                            try {
                                val success = AudioExtractor.extractToM4a(inputPath, outputPath)
                                withContext(Dispatchers.Main) { result.success(success) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("EXTRACT_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }

    }

}
