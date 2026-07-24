package jp.komehyappyo.member.next.core.data

import android.content.Context
import java.io.File
import java.util.UUID

interface DiaryPhotoStore {
    fun saveJpeg(data: ByteArray, diaryId: UUID): String
    fun load(reference: String): ByteArray
    fun delete(reference: String)
}

class LocalDiaryPhotoStore(
    context: Context? = null,
    rootDirectory: File? = null,
) : DiaryPhotoStore {
    private val root = rootDirectory
        ?: File(requireNotNull(context).filesDir, "DiaryPhotos")

    override fun saveJpeg(data: ByteArray, diaryId: UUID): String {
        require(data.isNotEmpty() && data.size <= MAXIMUM_PHOTO_BYTES) {
            "写真データが正しくありません。"
        }
        val directory = File(root, diaryId.toString()).apply { mkdirs() }
        val filename = "${UUID.randomUUID()}.jpg"
        File(directory, filename).writeBytes(data)
        return "${diaryId}/$filename"
    }

    override fun load(reference: String): ByteArray =
        validatedFile(reference).readBytes()

    override fun delete(reference: String) {
        val file = validatedFile(reference)
        if (file.exists()) file.delete()
    }

    private fun validatedFile(reference: String): File {
        require(reference.isNotBlank() && !reference.contains("..")) {
            "写真参照が正しくありません。"
        }
        val candidate = File(root, reference).canonicalFile
        val rootPath = root.canonicalFile.path + File.separator
        require(candidate.path.startsWith(rootPath)) {
            "写真参照が正しくありません。"
        }
        return candidate
    }

    companion object {
        const val MAXIMUM_PHOTO_BYTES = 10 * 1_024 * 1_024
    }
}
