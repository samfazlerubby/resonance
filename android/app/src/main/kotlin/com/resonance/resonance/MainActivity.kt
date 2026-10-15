package com.resonance.resonance

import android.content.ContentUris
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Talks to Android's MediaStore (the phone's built-in index of every song on it).
 * Flutter calls this through the "resonance/media" channel:
 *   getSongs            -> list of every music file with its tags
 *   getArtwork(id,size) -> JPEG bytes of the cover embedded in that song, or null
 *
 * Extends AudioServiceActivity so background playback keeps working.
 */
class MainActivity : AudioServiceActivity() {
    private val worker = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "resonance/media")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSongs" -> worker.execute {
                        try {
                            val songs = querySongs()
                            main.post { result.success(songs) }
                        } catch (e: Exception) {
                            main.post { result.error("QUERY_FAILED", e.message, null) }
                        }
                    }
                    "getArtwork" -> {
                        val id = (call.argument<Number>("id") ?: 0).toLong()
                        val size = call.argument<Int>("size") ?: 512
                        worker.execute {
                            val bytes = loadArtwork(id, size)
                            main.post { result.success(bytes) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun querySongs(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.YEAR,
            MediaStore.Audio.Media.DATE_ADDED,
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection, selection, null,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
        )?.use { c ->
            val iId = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val iTitle = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val iArtist = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val iAlbum = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val iAlbumId = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val iDur = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val iTrack = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
            val iYear = c.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
            val iAdded = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            while (c.moveToNext()) {
                val id = c.getLong(iId)
                out.add(
                    mapOf(
                        "id" to id,
                        "title" to c.getString(iTitle),
                        "artist" to c.getString(iArtist),
                        "album" to c.getString(iAlbum),
                        "albumId" to c.getLong(iAlbumId),
                        "duration" to c.getLong(iDur),
                        "track" to c.getInt(iTrack),
                        "year" to c.getInt(iYear),
                        "dateAdded" to c.getLong(iAdded),
                        "uri" to ContentUris.withAppendedId(
                            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id
                        ).toString(),
                    )
                )
            }
        }
        return out
    }

    private fun loadArtwork(songId: Long, size: Int): ByteArray? {
        val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, songId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val bmp = contentResolver.loadThumbnail(uri, Size(size, size), null)
                val stream = ByteArrayOutputStream()
                bmp.compress(Bitmap.CompressFormat.JPEG, 90, stream)
                return stream.toByteArray()
            } catch (e: Exception) {
                // no thumbnail; fall through to the embedded picture
            }
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(this, uri)
            retriever.embeddedPicture
        } catch (e: Exception) {
            null
        } finally {
            try { retriever.release() } catch (e: Exception) {}
        }
    }
}
