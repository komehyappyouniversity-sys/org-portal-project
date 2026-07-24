package jp.komehyappyo.member.next.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.CashDistribution
import jp.komehyappyo.member.next.core.model.CashDistributionEntry
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.time.Instant

@RunWith(RobolectricTestRunner::class)
class CashDistributionBackupServiceTest {
    private val databases = mutableListOf<OrgPortalDatabase>()

    @After
    fun tearDown() {
        databases.forEach(OrgPortalDatabase::close)
    }

    @Test
    fun backupRestoresDistributionAndKeepsExistingRecord() = runTest {
        val source = repository()
        val sourceItem = CashDistribution(
            title = "講師謝礼",
            entries = listOf(
                CashDistributionEntry(
                    recipientName1 = "講師A",
                    amount1 = 12_000,
                    receivedDate = Instant.ofEpochSecond(100),
                    receiverName = "担当者",
                ),
            ),
            createdAt = Instant.ofEpochSecond(200),
            updatedAt = Instant.ofEpochSecond(300),
        )
        source.save(sourceItem)
        val backup = CashDistributionBackupService(source)
            .exportData(Instant.ofEpochSecond(400))

        val destination = repository()
        destination.save(
            CashDistribution(
                title = "端末に残す記録",
                entries = listOf(
                    CashDistributionEntry(
                        recipientName1 = "既存",
                        amount1 = 1_000,
                    ),
                ),
            ),
        )
        val restoredCount = CashDistributionBackupService(destination)
            .importData(backup)

        assertEquals(1, restoredCount)
        val restored = destination.observeAll().first()
        assertEquals(
            setOf("講師謝礼", "端末に残す記録"),
            restored.map { it.title }.toSet(),
        )
        val restoredItem = restored.single { it.id == sourceItem.id }
        assertEquals(12_000L, restoredItem.entries.first().amount1)
        assertEquals("担当者", restoredItem.entries.first().receiverName)
    }

    @Test
    fun invalidBackupFormatIsRejected() = runTest {
        try {
            CashDistributionBackupService(repository())
                .importData("{}".toByteArray())
            fail("Invalid format must be rejected")
        } catch (error: CashDistributionBackupException.InvalidFormat) {
            // Expected.
        }
    }

    private fun repository(): RoomCashDistributionRepository {
        val database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        databases += database
        return RoomCashDistributionRepository(database.cashDistributionDao())
    }
}
