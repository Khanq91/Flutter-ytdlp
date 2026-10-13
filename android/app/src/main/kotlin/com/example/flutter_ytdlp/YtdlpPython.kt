package com.example.flutter_ytdlp

import android.content.Context
import com.chaquo.python.PyObject
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform

object YtdlpPython {
    private val initializerLock = Any()

    @Volatile
    private var cachedModule: PyObject? = null

    fun module(context: Context): PyObject {
        cachedModule?.let { return it }
        return synchronized(initializerLock) {
            cachedModule ?: run {
                if (!Python.isStarted()) {
                    Python.start(AndroidPlatform(context.applicationContext))
                }
                Python.getInstance().getModule("ytdlp_bridge").also {
                    cachedModule = it
                }
            }
        }
    }
}
