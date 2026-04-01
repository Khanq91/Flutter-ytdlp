package com.example.flutter_ytdlp

import android.app.DownloadManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {

    private val CHANNEL = "ytdlp_channel"

    private val activityScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onDestroy() {
        super.onDestroy()
        activityScope.cancel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        val py     = Python.getInstance()
        val module = py.getModule("ytdlp_bridge")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Storage utils ──────────────────────────────
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
                            // Cách 1: Mở Downloads app trực tiếp (hoạt động trên mọi Android)
                            val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            // Nếu không có DownloadManager app thì fallback sang Files
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                            } else {
                                // Cách 2: Mở Files app bằng DocumentsContract
                                val uri = Uri.parse("content://com.android.externalstorage.documents/root/primary")
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

                    // ── yt-dlp: analyze ────────────────────────────
                    "analyze" -> {
                        val url = call.argument<String>("url") ?: ""
//                        CoroutineScope(Dispatchers.IO).launch {
                        activityScope.launch {
                            try {
                                val res = module.callAttr("analyze", url).toString()
                                withContext(Dispatchers.Main) { result.success(res) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("ANALYZE_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    // ── yt-dlp: download ───────────────────────────
                    "download" -> {
                        val url      = call.argument<String>("url")      ?: ""
                        val formatId = call.argument<String>("formatId") ?: "best"
                        val outDir   = call.argument<String>("outputDir")
                            ?: Environment.getExternalStoragePublicDirectory(
                                Environment.DIRECTORY_DOWNLOADS
                            ).absolutePath

//                        CoroutineScope(Dispatchers.IO).launch {
                        activityScope.launch {
                            try {
                                val res = module.callAttr("download", url, formatId, outDir)
                                    .toString()
                                withContext(Dispatchers.Main) { result.success(res) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("DOWNLOAD_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    // ── yt-dlp: poll progress ──────────────────────
                    "getProgress" -> {
//                        CoroutineScope(Dispatchers.IO).launch {
                        activityScope.launch {
                            try {
                                val res = module.callAttr("get_progress").toString()
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
//                        CoroutineScope(Dispatchers.IO).launch {
                        activityScope.launch {
                            try {
                                val res = module.callAttr("get_playlist_entries", url).toString()
                                withContext(Dispatchers.Main) { result.success(res) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("PLAYLIST_ENTRIES_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}