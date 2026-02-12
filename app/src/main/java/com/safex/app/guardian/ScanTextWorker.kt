package com.safex.app.guardian

import android.content.ContentUris
import android.content.Context
import android.provider.MediaStore
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlin.math.min

class ScanTextWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences("safex_scan", Context.MODE_PRIVATE)
        val lastScanSeconds = prefs.getLong("last_scan_seconds", 0L)

        try {
            val projection = arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.DATE_ADDED
            )

            // DATE_ADDED is in seconds
            val selection = "${MediaStore.Images.Media.DATE_ADDED} > ?"
            val selectionArgs = arrayOf(lastScanSeconds.toString())

            val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"

            val resolver = applicationContext.contentResolver
            val uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI

            var newestSeen = lastScanSeconds
            var scannedCount = 0

            resolver.query(uri, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)

                // Don’t scan infinite images in one run (keep it safe)
                val maxToScan = 10

                while (cursor.moveToNext() && scannedCount < maxToScan) {
                    val id = cursor.getLong(idCol)
                    val dateAdded = cursor.getLong(dateCol)
                    if (dateAdded > newestSeen) newestSeen = dateAdded

                    val imageUri = ContentUris.withAppendedId(uri, id)

                    val text = GalleryTextExtractor.extractText(applicationContext, imageUri).trim()
                    scannedCount++

                    if (text.isNotBlank()) {
                        val preview = text.replace("\n", " ")
                        val shortPreview = preview.substring(0, min(preview.length, 120))
                        Log.d("SafeX-Gallery", "OCR text: $shortPreview")
                    } else {
                        Log.d("SafeX-Gallery", "OCR empty (imageUri=$imageUri)")
                    }
                }
            }

            // Update last scan time so we don’t re-scan the same images
            prefs.edit().putLong("last_scan_seconds", newestSeen).apply()

            Log.d("SafeX-Gallery", "Worker done. scanned=$scannedCount lastScan=$newestSeen")
            return Result.success()

        } catch (se: SecurityException) {
            // This means READ_MEDIA_IMAGES (or old READ_EXTERNAL_STORAGE) is not granted.
            Log.e("SafeX-Gallery", "No permission to read images. Grant gallery permission.", se)
            return Result.failure()

        } catch (e: Exception) {
            Log.e("SafeX-Gallery", "Worker error", e)
            return Result.retry()
        }
    }
}