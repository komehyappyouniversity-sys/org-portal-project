package jp.komehyappyo.member.next.core.data

import android.content.Context
import java.io.File
import java.util.UUID

interface BudgetReceiptStore {
    suspend fun saveJpeg(reportId: UUID, entryId: UUID, data: ByteArray): String
    suspend fun load(reference: String): ByteArray
    suspend fun delete(reference: String)
}

class LocalBudgetReceiptStore(context: Context) : BudgetReceiptStore {
    private val directory = File(context.filesDir, "budget-receipts")

    override suspend fun saveJpeg(reportId: UUID, entryId: UUID, data: ByteArray): String {
        require(data.isNotEmpty()) { "領収書画像が空です。" }
        require(data.size <= MAXIMUM_RECEIPT_BYTES) { "領収書画像は10MB以下にしてください。" }
        val reportDirectory = File(directory, reportId.toString()).apply { mkdirs() }
        val file = File(reportDirectory, "$entryId.jpg")
        file.writeBytes(data)
        return file.absolutePath
    }

    override suspend fun load(reference: String): ByteArray = File(reference).readBytes()

    override suspend fun delete(reference: String) {
        val file = File(reference)
        if (file.exists() && file.canonicalPath.startsWith(directory.canonicalPath)) {
            file.delete()
            file.parentFile?.takeIf { it.list().isNullOrEmpty() }?.delete()
        }
    }

    companion object {
        const val MAXIMUM_RECEIPT_BYTES = 10 * 1_024 * 1_024
    }
}
