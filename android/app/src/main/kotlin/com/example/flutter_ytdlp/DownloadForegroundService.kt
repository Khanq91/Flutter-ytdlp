package com.example.flutter_ytdlp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.IBinder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class DownloadForegroundService : Service() {
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val activeJobs = ConcurrentHashMap<String, Job>()
    private val retryJobs = ConcurrentHashMap<String, Job>()
    private val records = linkedMapOf<String, JSONObject>()
    private val recordsLock = Any()
    private val queueLock = Any()

    private val ytdlpModule get() = YtdlpPython.module(applicationContext)

    override fun onCreate() {
        super.onCreate()
        activeInstance = this
        createNotificationChannel()
        loadRecords()
        restoreInterruptedTasks()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_ENQUEUE -> enqueueFromIntent(intent)
            ACTION_CANCEL -> cancelFromIntent(intent)
            else -> restoreInterruptedTasks()
        }
        resumeScheduledRetries()

        if (hasPendingWork()) {
            showForegroundNotification()
            processQueue()
            return START_STICKY
        }

        stopSelfIfIdle()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        serviceScope.cancel()
        if (activeInstance === this) activeInstance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun enqueueFromIntent(intent: Intent) {
        val taskId = intent.getStringExtra(EXTRA_TASK_ID).orEmpty()
        if (taskId.isEmpty()) return

        synchronized(recordsLock) {
            val existing = records[taskId]
            if (existing?.isPendingDownload() == true) return

            if (existing == null && records.values.none { it.isPendingDownload() }) {
                records.clear()
            }

            records[taskId] = JSONObject().apply {
                put("id", taskId)
                put("title", intent.getStringExtra(EXTRA_TITLE).orEmpty())
                put("url", intent.getStringExtra(EXTRA_URL).orEmpty())
                put("formatId", intent.getStringExtra(EXTRA_FORMAT_ID).orEmpty())
                put("ext", intent.getStringExtra(EXTRA_EXT).orEmpty())
                put("thumbnail", intent.getStringExtra(EXTRA_THUMBNAIL))
                put("outputDir", intent.getStringExtra(EXTRA_OUTPUT_DIR).orEmpty())
                put("status", STATUS_QUEUED)
                put("progress", 0.0)
                put("speed", "")
                put("eta", "")
                put("errorMessage", JSONObject.NULL)
                put("outputPath", JSONObject.NULL)
                put("startedAt", JSONObject.NULL)
                put("completedAt", JSONObject.NULL)
                put("retryCount", 0)
            }
            persistRecordsLocked()
        }
        updateNotification()
    }

    private fun cancelFromIntent(intent: Intent) {
        val taskId = intent.getStringExtra(EXTRA_TASK_ID).orEmpty()
        if (taskId.isEmpty()) return

        val status = synchronized(recordsLock) {
            records[taskId]?.optString("status")
        }
        if (status == STATUS_QUEUED || status == STATUS_WAITING_TO_RETRY) {
            retryJobs.remove(taskId)?.cancel()
            updateRecord(taskId) {
                put("status", STATUS_CANCELLED)
                put("completedAt", System.currentTimeMillis())
            }
            processQueue()
            stopSelfIfIdle()
            return
        }
        if (status != STATUS_PREPARING && status != STATUS_DOWNLOADING) return

        serviceScope.launch {
            try {
                ytdlpModule.callAttr("cancel_download", taskId)
            } catch (_: Exception) {
                // The task remains active unless the download call confirms cancellation.
            }
        }
    }

    private fun restoreInterruptedTasks() {
        synchronized(recordsLock) {
            var changed = false
            records.values.forEach { record ->
                val status = record.optString("status")
                if (status == STATUS_PREPARING || status == STATUS_DOWNLOADING) {
                    record.put("status", STATUS_QUEUED)
                    changed = true
                }
            }
            if (changed) persistRecordsLocked()
        }
    }

    private fun processQueue() {
        synchronized(queueLock) {
            val available = MAX_CONCURRENT_DOWNLOADS - activeJobs.size
            if (available <= 0) return

            val queuedIds = synchronized(recordsLock) {
                records.values
                    .filter { it.optString("status") == STATUS_QUEUED }
                    .take(available)
                    .map { it.getString("id") }
            }
            queuedIds.forEach(::startDownload)
        }
    }

    private fun startDownload(taskId: String) {
        if (activeJobs.containsKey(taskId)) return

        val task = synchronized(recordsLock) {
            records[taskId]?.let { JSONObject(it.toString()) }
        } ?: return
        if (task.optString("status") != STATUS_QUEUED) return

        updateRecord(taskId) {
            put("status", STATUS_PREPARING)
            put("startedAt", System.currentTimeMillis())
            put("errorMessage", JSONObject.NULL)
        }

        val job = serviceScope.launch(start = CoroutineStart.LAZY) {
            updateRecord(taskId) { put("status", STATUS_DOWNLOADING) }
            try {
                val rawResult = ytdlpModule.callAttr(
                    "download",
                    taskId,
                    task.getString("url"),
                    task.getString("formatId"),
                    task.getString("outputDir"),
                ).toString()
                applyDownloadResult(taskId, task, JSONObject(rawResult))
            } catch (error: Exception) {
                handleFailure(taskId, error.message ?: "Download failed")
            } finally {
                activeJobs.remove(taskId)
                processQueue()
                stopSelfIfIdle()
            }
        }
        activeJobs[taskId] = job
        job.start()
    }

    private fun applyDownloadResult(taskId: String, task: JSONObject, result: JSONObject) {
        if (result.optBoolean("cancelled")) {
            updateRecord(taskId) {
                put("status", STATUS_CANCELLED)
                put("completedAt", System.currentTimeMillis())
            }
            return
        }
        if (!result.optBoolean("success") || result.has("error")) {
            handleFailure(taskId, result.optString("error", "Download failed"))
            return
        }

        var outputPath = result.optString("path").takeIf { it.isNotEmpty() }
        if (needsAudioExtraction(task.optString("formatId")) && outputPath != null) {
            val extractedPath = outputPath.replaceAfterLast('.', "m4a")
            try {
                if (!AudioExtractor.extractToM4a(outputPath, extractedPath)) {
                    throw IllegalStateException("MediaExtractor did not find an audio track")
                }
                File(outputPath).takeIf { it.exists() }?.delete()
                outputPath = extractedPath
            } catch (error: Exception) {
                updateRecord(taskId) {
                    put("status", STATUS_ERROR)
                    put("errorMessage", error.message ?: "Audio extraction failed")
                    put("completedAt", System.currentTimeMillis())
                }
                return
            }
        }

        updateRecord(taskId) {
            put("status", STATUS_DONE)
            put("progress", 1.0)
            put("speed", "")
            put("eta", "")
            put("outputPath", outputPath ?: JSONObject.NULL)
            put("completedAt", System.currentTimeMillis())
        }
    }

    private fun needsAudioExtraction(formatId: String): Boolean =
        formatId == "__extract_audio__" ||
            formatId == "__extract_m4a__" ||
            formatId == "__extract_mp3__"

    private fun handleFailure(taskId: String, message: String) {
        val retryCount = synchronized(recordsLock) {
            records[taskId]?.optInt("retryCount", 0) ?: 0
        }
        if (retryCount < MAX_TRANSIENT_RETRIES &&
            (isTransientFailure(message) || !isNetworkAvailable())
        ) {
            val nextAttempt = retryCount + 1
            updateRecord(taskId) {
                put("status", STATUS_WAITING_TO_RETRY)
                put("retryCount", nextAttempt)
                put("errorMessage", "Lỗi tạm thời, sẽ thử lại ($nextAttempt/$MAX_TRANSIENT_RETRIES)")
            }
            scheduleRetry(taskId, nextAttempt)
            return
        }

        updateRecord(taskId) {
            put("status", STATUS_ERROR)
            put("errorMessage", message)
            put("completedAt", System.currentTimeMillis())
        }
    }

    private fun resumeScheduledRetries() {
        val waiting = synchronized(recordsLock) {
            records.values
                .filter { it.optString("status") == STATUS_WAITING_TO_RETRY }
                .map { it.getString("id") to it.optInt("retryCount", 1) }
        }
        waiting.forEach { (taskId, attempt) -> scheduleRetry(taskId, attempt) }
    }

    private fun scheduleRetry(taskId: String, attempt: Int) {
        if (retryJobs.containsKey(taskId)) return
        val job = serviceScope.launch(start = CoroutineStart.LAZY) {
            try {
                delay(RETRY_BASE_DELAY_MS * (1L shl (attempt - 1).coerceAtLeast(0)))
                while (!isNetworkAvailable()) delay(NETWORK_RECHECK_DELAY_MS)

                val stillWaiting = synchronized(recordsLock) {
                    records[taskId]?.optString("status") == STATUS_WAITING_TO_RETRY
                }
                if (stillWaiting) {
                    updateRecord(taskId) {
                        put("status", STATUS_QUEUED)
                        put("errorMessage", JSONObject.NULL)
                    }
                }
            } finally {
                retryJobs.remove(taskId)
                processQueue()
            }
        }
        retryJobs[taskId] = job
        job.start()
    }

    private fun isNetworkAvailable(): Boolean {
        val manager = getSystemService(ConnectivityManager::class.java)
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun isTransientFailure(message: String): Boolean {
        val normalized = message.lowercase()
        return TRANSIENT_ERROR_MARKERS.any(normalized::contains) ||
            Regex("http error 5\\d\\d").containsMatchIn(normalized)
    }

    private fun updateRecord(taskId: String, update: JSONObject.() -> Unit) {
        synchronized(recordsLock) {
            val record = records[taskId] ?: return
            record.update()
            persistRecordsLocked()
        }
        updateNotification()
    }

    private fun removeFinishedRecords(taskId: String? = null) {
        synchronized(recordsLock) {
            records.entries.removeAll { (id, record) ->
                (taskId == null || id == taskId) && !record.isPendingDownload()
            }
            persistRecordsLocked()
        }
        updateNotification(finalState = !hasPendingWork())
    }

    private fun hasPendingWork(): Boolean = synchronized(recordsLock) {
        records.values.any { it.isPendingDownload() }
    }

    private fun stopSelfIfIdle() {
        if (hasPendingWork() || activeJobs.isNotEmpty()) return
        updateNotification(finalState = true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_DETACH)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(false)
        }
        stopSelf()
    }

    private fun showForegroundNotification() {
        val notification = buildNotification(finalState = false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(finalState: Boolean = false) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(finalState))
    }

    private fun buildNotification(finalState: Boolean): Notification {
        val counts = synchronized(recordsLock) {
            val statuses = records.values.map { it.optString("status") }
            NotificationCounts(
                active = statuses.count {
                    it == STATUS_PREPARING || it == STATUS_DOWNLOADING
                },
                done = statuses.count { it == STATUS_DONE },
                queued = statuses.count {
                    it == STATUS_QUEUED || it == STATUS_WAITING_TO_RETRY
                },
                error = statuses.count { it == STATUS_ERROR },
            )
        }
        val openApp = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val text = "Đang tải ${counts.active} • Xong ${counts.done} • " +
            "Chờ ${counts.queued} • Lỗi ${counts.error}"

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(if (finalState) android.R.drawable.stat_sys_download_done else android.R.drawable.stat_sys_download)
            .setContentTitle(if (finalState) "Tải xuống đã kết thúc" else "Muzicz đang tải xuống")
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(pendingIntent)
            .setOngoing(!finalState)
            .setOnlyAlertOnce(true)
            .setAutoCancel(finalState)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Tiến trình tải xuống",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Hiển thị tiến trình tải nội dung của Muzicz"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun loadRecords() {
        val raw = getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
            .getString(PREFERENCES_KEY, null) ?: return
        synchronized(recordsLock) {
            records.clear()
            val array = JSONArray(raw)
            for (index in 0 until array.length()) {
                val record = array.getJSONObject(index)
                records[record.getString("id")] = record
            }
        }
    }

    private fun persistRecordsLocked() {
        val array = JSONArray()
        records.values.forEach(array::put)
        getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
            .edit()
            .putString(PREFERENCES_KEY, array.toString())
            .apply()
    }

    private data class NotificationCounts(
        val active: Int,
        val done: Int,
        val queued: Int,
        val error: Int,
    )

    companion object {
        private const val ACTION_ENQUEUE = "com.example.flutter_ytdlp.action.ENQUEUE_DOWNLOAD"
        private const val ACTION_CANCEL = "com.example.flutter_ytdlp.action.CANCEL_DOWNLOAD"
        private const val EXTRA_TASK_ID = "taskId"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_URL = "url"
        private const val EXTRA_FORMAT_ID = "formatId"
        private const val EXTRA_EXT = "ext"
        private const val EXTRA_THUMBNAIL = "thumbnail"
        private const val EXTRA_OUTPUT_DIR = "outputDir"
        private const val PREFERENCES_NAME = "download_foreground_service"
        private const val PREFERENCES_KEY = "tasks"
        private const val NOTIFICATION_CHANNEL_ID = "flutter_ytdlp_download_progress"
        private const val NOTIFICATION_ID = 2207
        private const val MAX_CONCURRENT_DOWNLOADS = 2
        private const val MAX_TRANSIENT_RETRIES = 2
        private const val RETRY_BASE_DELAY_MS = 2_000L
        private const val NETWORK_RECHECK_DELAY_MS = 1_000L

        private const val STATUS_QUEUED = "queued"
        private const val STATUS_PREPARING = "preparing"
        private const val STATUS_DOWNLOADING = "downloading"
        private const val STATUS_WAITING_TO_RETRY = "waitingToRetry"
        private const val STATUS_DONE = "done"
        private const val STATUS_ERROR = "error"
        private const val STATUS_CANCELLED = "cancelled"

        private val TRANSIENT_ERROR_MARKERS = listOf(
            "timed out",
            "timeout",
            "connection",
            "network",
            "temporary failure",
            "unable to download",
            "remote end closed",
            "name or service not known",
            "no route to host",
            "http error 429",
        )

        @Volatile
        private var activeInstance: DownloadForegroundService? = null

        fun enqueue(context: Context, arguments: Map<String, Any?>) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_ENQUEUE
                putExtra(EXTRA_TASK_ID, arguments[EXTRA_TASK_ID] as? String)
                putExtra(EXTRA_TITLE, arguments[EXTRA_TITLE] as? String)
                putExtra(EXTRA_URL, arguments[EXTRA_URL] as? String)
                putExtra(EXTRA_FORMAT_ID, arguments[EXTRA_FORMAT_ID] as? String)
                putExtra(EXTRA_EXT, arguments[EXTRA_EXT] as? String)
                putExtra(EXTRA_THUMBNAIL, arguments[EXTRA_THUMBNAIL] as? String)
                putExtra(EXTRA_OUTPUT_DIR, arguments[EXTRA_OUTPUT_DIR] as? String)
            }
            start(context, intent)
        }

        fun cancel(context: Context, taskId: String) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_CANCEL
                putExtra(EXTRA_TASK_ID, taskId)
            }
            start(context, intent)
        }

        fun readTask(context: Context, taskId: String): String? {
            val tasks = readTasksArray(context)
            for (index in 0 until tasks.length()) {
                val task = tasks.getJSONObject(index)
                if (task.optString("id") == taskId) return task.toString()
            }
            return null
        }

        fun readTasks(context: Context): String = readTasksArray(context).toString()

        fun removeFinished(context: Context, taskId: String) {
            val service = activeInstance
            if (service != null) {
                service.removeFinishedRecords(taskId)
            } else {
                updateStoredRecords(context) { record ->
                    record.optString("id") == taskId && !record.isPendingDownload()
                }
            }
        }

        fun clearFinished(context: Context) {
            val service = activeInstance
            if (service != null) {
                service.removeFinishedRecords()
            } else {
                updateStoredRecords(context) { record -> !record.isPendingDownload() }
                context.getSystemService(NotificationManager::class.java)
                    .cancel(NOTIFICATION_ID)
            }
        }

        private fun readTasksArray(context: Context): JSONArray {
            val raw = context.getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
                .getString(PREFERENCES_KEY, null)
            return if (raw == null) JSONArray() else JSONArray(raw)
        }

        private fun updateStoredRecords(
            context: Context,
            shouldRemove: (JSONObject) -> Boolean,
        ) {
            val source = readTasksArray(context)
            val updated = JSONArray()
            for (index in 0 until source.length()) {
                val record = source.getJSONObject(index)
                if (!shouldRemove(record)) updated.put(record)
            }
            context.getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
                .edit()
                .putString(PREFERENCES_KEY, updated.toString())
                .apply()
        }

        private fun start(context: Context, intent: Intent) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}

private fun JSONObject.isPendingDownload(): Boolean {
    val status = optString("status")
    return status == "queued" ||
        status == "preparing" ||
        status == "downloading" ||
        status == "waitingToRetry"
}
