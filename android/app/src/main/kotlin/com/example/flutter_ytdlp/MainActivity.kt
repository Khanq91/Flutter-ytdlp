package com.example.flutter_ytdlp

import android.app.DownloadManager
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import kotlinx.coroutines.*
import java.io.File
import java.nio.ByteBuffer

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
                            val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                            } else {
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
                        // Bug fix: key name aligned with Dart side ("outputDir")
                        val outDir   = call.argument<String>("outputDir")
                            ?: Environment.getExternalStoragePublicDirectory(
                                Environment.DIRECTORY_DOWNLOADS
                            ).absolutePath

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

                    // ── Audio extraction (Phương án 2: native MediaExtractor) ──
                    "extractAudio" -> {
                        val inputPath  = call.argument<String>("inputPath")  ?: ""
                        val outputPath = call.argument<String>("outputPath") ?: ""
                        activityScope.launch {
                            try {
                                val success = extractAudioNative(inputPath, outputPath)
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

    // ── Native audio extraction via MediaExtractor + MediaMuxer ──────────────
    // Copies audio track from src MP4/webm into a new M4A container.
    // No re-encoding → very fast, lossless quality.
    // Supports any audio codec that can be muxed into MPEG-4 (AAC, Opus, MP3…).
    private fun extractAudioNative(srcPath: String, dstPath: String): Boolean {
        if (srcPath.isEmpty() || dstPath.isEmpty()) return false

        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null

        try {
            extractor.setDataSource(srcPath)

            // Find first audio track
            var audioTrackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    break
                }
            }

            if (audioTrackIndex < 0) return false

            extractor.selectTrack(audioTrackIndex)
            val audioFormat = extractor.getTrackFormat(audioTrackIndex)

            // Delete existing output file if any
            File(dstPath).takeIf { it.exists() }?.delete()

            muxer = MediaMuxer(dstPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val dstTrackIndex = muxer.addTrack(audioFormat)
            muxer.start()

            val buffer    = ByteBuffer.allocate(1 * 1024 * 1024) // 1MB buffer
            val bufferInfo = MediaCodec.BufferInfo()

            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size   = extractor.readSampleData(buffer, 0)
                if (bufferInfo.size < 0) break

                bufferInfo.presentationTimeUs = extractor.sampleTime
                bufferInfo.flags              = extractor.sampleFlags

                muxer.writeSampleData(dstTrackIndex, buffer, bufferInfo)
                extractor.advance()
            }

            muxer.stop()
            return true

        } catch (e: Exception) {
            // Clean up failed output file
            File(dstPath).takeIf { it.exists() }?.delete()
            throw e
        } finally {
            try { muxer?.release() } catch (_: Exception) {}
            extractor.release()
        }
    }
}