package jp.komehyappyo.member.next.feature.tools

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

object DiaryPhotoProcessor {
    fun compressedJpeg(
        context: Context,
        uri: Uri,
        maximumDimension: Int = 1_600,
        quality: Int = 80,
    ): ByteArray? {
        val bitmap = context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it)
        } ?: return null
        val longestSide = max(bitmap.width, bitmap.height)
        val resized = if (longestSide > maximumDimension) {
            val scale = maximumDimension.toFloat() / longestSide
            Bitmap.createScaledBitmap(
                bitmap,
                (bitmap.width * scale).roundToInt().coerceAtLeast(1),
                (bitmap.height * scale).roundToInt().coerceAtLeast(1),
                true,
            )
        } else {
            bitmap
        }
        return ByteArrayOutputStream().use { output ->
            resized.compress(Bitmap.CompressFormat.JPEG, quality, output)
            if (resized !== bitmap) resized.recycle()
            bitmap.recycle()
            output.toByteArray()
        }
    }
}
