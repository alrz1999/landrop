package dev.landrop.landrop

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Android share target (share_target.dart): turns an ACTION_SEND or
 * ACTION_SEND_MULTIPLE intent into a list of cached files plus optional text.
 *
 * Streams are copied (off the UI thread) to `cacheDir/shared/<random>/<name>`
 * because the content URI grants end with the sending app's task and the Dart
 * side needs real paths. Only `content:` URIs are read: a `file:` URI could
 * point into this app's private directory.
 *
 * Channel payload: `{files: [path], text: String?, error: String?}` where
 * error is `tooMany`, `tooBig`, `unreadable` or `failed`. `tooMany` and
 * `tooBig` discard every copy.
 */
class ShareIntentHandler(private val context: Context) {
    /** Set by the EventChannel while Dart listens. */
    var sink: EventChannel.EventSink? = null

    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val root = File(context.cacheDir, "shared")

    // Main thread only.
    private var pending: Map<String, Any?>? = null
    private var waiting: MethodChannel.Result? = null
    private var processing = 0

    @Volatile
    private var destroyed = false

    /** Deletes copies older than a day (app start). */
    fun cleanOld() {
        executor.execute {
            try {
                val limit = System.currentTimeMillis() - MAX_AGE_MS
                root.listFiles()?.forEach {
                    if (it.lastModified() < limit) it.deleteRecursively()
                }
            } catch (e: Exception) {
                // Best effort.
            }
        }
    }

    /** Handles [intent] when it is a share; call on the main thread. */
    fun handle(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return
        val uris = streams(intent)
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        val subject = intent.getCharSequenceExtra(Intent.EXTRA_SUBJECT)?.toString()
        // The subject is only used when there is nothing else to send.
        val body = when {
            !text.isNullOrBlank() -> text
            uris.isEmpty() && !subject.isNullOrBlank() -> subject
            else -> null
        }
        processing++
        try {
            executor.execute {
                val payload = try {
                    copyAll(uris, body)
                } catch (e: Exception) {
                    mapOf("files" to emptyList<String>(), "text" to body, "error" to "failed")
                }
                main.post { deliver(payload) }
            }
        } catch (e: Exception) {
            // Executor shut down (activity destroyed).
            processing--
        }
    }

    /** `getInitial`: the pending share, or the one being copied, or null. */
    fun getInitial(result: MethodChannel.Result) {
        val p = pending
        when {
            p != null -> {
                pending = null
                result.success(p)
            }
            processing > 0 -> {
                // A previous waiter cannot be answered twice; the newest wins.
                waiting?.success(null)
                waiting = result
            }
            else -> result.success(null)
        }
    }

    /**
     * `clear`: forgets the pending share and deletes the copies at [paths]
     * (their `shared/<random>` folders). Paths outside the cache are ignored.
     */
    fun clear(paths: List<String>) {
        pending = null
        if (paths.isEmpty()) return
        executor.execute {
            try {
                val base = root.canonicalFile
                for (p in paths) {
                    var f: File? = File(p).canonicalFile
                    while (f != null && f.parentFile != base) f = f.parentFile
                    if (f != null && f.parentFile == base) f.deleteRecursively()
                }
            } catch (e: Exception) {
                // Best effort; cleanOld removes the rest.
            }
        }
    }

    fun destroy() {
        destroyed = true
        sink = null
        waiting = null
        executor.shutdown()
    }

    private fun deliver(payload: Map<String, Any?>) {
        processing--
        if (destroyed) return
        val w = waiting
        val s = sink
        when {
            w != null -> {
                waiting = null
                w.success(payload)
            }
            s != null -> s.success(payload)
            else -> pending = payload
        }
    }

    @Suppress("DEPRECATION")
    private fun streams(intent: Intent): List<Uri> {
        val out = ArrayList<Uri>()
        if (intent.action == Intent.ACTION_SEND) {
            val one: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            if (one != null) out.add(one)
        } else {
            val many: List<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }
            if (many != null) out.addAll(many)
        }
        if (out.isEmpty()) {
            val clip: ClipData? = intent.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) {
                    clip.getItemAt(i).uri?.let { out.add(it) }
                }
            }
        }
        return out
    }

    /** Runs on the executor. */
    private fun copyAll(uris: List<Uri>, text: String?): Map<String, Any?> {
        if (uris.size > MAX_FILES) return reply(emptyList(), text, "tooMany")
        if (uris.isEmpty()) return reply(emptyList(), text, null)
        val dir = File(root, UUID.randomUUID().toString())
        if (!dir.mkdirs() && !dir.isDirectory) return reply(emptyList(), text, "failed")
        val files = ArrayList<String>()
        var total = 0L
        var error: String? = null
        try {
            for (uri in uris) {
                if (destroyed) {
                    dir.deleteRecursively()
                    return reply(emptyList(), text, "failed")
                }
                if (uri.scheme != "content") {
                    error = "unreadable"
                    continue
                }
                try {
                    val (name, size) = describe(uri)
                    if (size != null && total + size > MAX_TOTAL_BYTES) {
                        dir.deleteRecursively()
                        return reply(emptyList(), text, "tooBig")
                    }
                    val target = uniqueFile(dir, name)
                    val copied = copyOne(uri, target, MAX_TOTAL_BYTES - total)
                    if (copied < 0) {
                        dir.deleteRecursively()
                        return reply(emptyList(), text, "tooBig")
                    }
                    total += copied
                    files.add(target.absolutePath)
                } catch (e: SecurityException) {
                    error = "unreadable"
                } catch (e: IOException) {
                    // Includes FileNotFoundException.
                    error = "unreadable"
                } catch (e: IllegalArgumentException) {
                    error = "unreadable"
                }
            }
        } catch (e: Exception) {
            dir.deleteRecursively()
            return reply(emptyList(), text, "failed")
        }
        if (files.isEmpty()) dir.deleteRecursively()
        return reply(files, text, error)
    }

    private fun reply(files: List<String>, text: String?, error: String?): Map<String, Any?> =
        mapOf("files" to files, "text" to text, "error" to error)

    /** Display name (sanitised) and size, when the provider tells. */
    private fun describe(uri: Uri): Pair<String, Long?> {
        var name: String? = null
        var size: Long? = null
        try {
            context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null, null, null
            )?.use { c ->
                if (c.moveToFirst()) {
                    val n = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val s = c.getColumnIndex(OpenableColumns.SIZE)
                    if (n >= 0 && !c.isNull(n)) name = c.getString(n)
                    if (s >= 0 && !c.isNull(s)) size = c.getLong(s)
                }
            }
        } catch (e: RuntimeException) {
            // Provider without the columns; use the fallbacks below.
        }
        var clean = sanitize(name ?: uri.lastPathSegment ?: "")
        if (!clean.contains('.')) {
            val type = try {
                context.contentResolver.getType(uri)
            } catch (e: RuntimeException) {
                null
            }
            val ext = if (type != null) MimeTypeMap.getSingleton().getExtensionFromMimeType(type) else null
            if (!ext.isNullOrEmpty()) clean = "$clean.$ext"
        }
        return Pair(clean, size)
    }

    private fun sanitize(raw: String): String {
        var n = raw.substringAfterLast('/').substringAfterLast('\\')
        n = n.map { ch -> if (ch.code < 32 || "\\/:*?\"<>|".indexOf(ch) >= 0) '_' else ch }
            .joinToString("")
        n = n.trim().trimStart('.')
        if (n.length > MAX_NAME) {
            val dot = n.lastIndexOf('.')
            val ext = if (dot > 0 && n.length - dot <= 16) n.substring(dot) else ""
            n = n.substring(0, MAX_NAME - ext.length) + ext
        }
        return if (n.isEmpty()) "file" else n
    }

    private fun uniqueFile(dir: File, name: String): File {
        var f = File(dir, name)
        if (!f.exists()) return f
        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var i = 1
        while (f.exists()) {
            f = File(dir, "$stem ($i)$ext")
            i++
        }
        return f
    }

    /** Copies [uri] to [target]; returns the bytes, or -1 when over [limit]. */
    private fun copyOne(uri: Uri, target: File, limit: Long): Long {
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IOException("no stream")
        var copied = 0L
        input.use { src ->
            target.outputStream().use { dst ->
                val buf = ByteArray(64 * 1024)
                while (true) {
                    if (destroyed) throw IOException("cancelled")
                    val n = src.read(buf)
                    if (n < 0) break
                    copied += n
                    if (copied > limit) {
                        target.delete()
                        return -1L
                    }
                    dst.write(buf, 0, n)
                }
            }
        }
        return copied
    }

    companion object {
        const val MAX_FILES = 200
        const val MAX_TOTAL_BYTES = 4L * 1024 * 1024 * 1024
        const val MAX_AGE_MS = 24L * 60 * 60 * 1000
        const val MAX_NAME = 120
    }
}
