package jp.komehyappyo.member.next.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.Diary
import jp.komehyappyo.member.next.core.model.DiaryMood
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File
import java.time.Instant
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
class DiaryBackupServiceTest {
    private val databases = mutableListOf<OrgPortalDatabase>()
    private val directories = mutableListOf<File>()

    @Before
    fun setUp() {
        databases.clear()
        directories.clear()
    }

    @After
    fun tearDown() {
        databases.forEach(OrgPortalDatabase::close)
        directories.forEach(File::deleteRecursively)
    }

    @Test
    fun backupRestoresDiaryAndPhoto() = runTest {
        val sourceRepository = repository()
        val sourcePhotos = photoStore()
        val id = UUID.randomUUID()
        val photoData = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xD9.toByte())
        val reference = sourcePhotos.saveJpeg(photoData, id)
        sourceRepository.save(
            Diary(
                id = id,
                userId = "guest",
                title = "バックアップ対象",
                body = "写真を含みます",
                mood = DiaryMood.VeryGood,
                photoUrls = listOf(reference),
                createdAt = Instant.ofEpochSecond(100),
                updatedAt = Instant.ofEpochSecond(200),
            ),
        )
        val backup = DiaryBackupService(sourceRepository, sourcePhotos)
            .exportData(Instant.ofEpochSecond(300))

        val destinationRepository = repository()
        val destinationPhotos = photoStore()
        val restoredCount = DiaryBackupService(destinationRepository, destinationPhotos)
            .importData(backup)

        assertEquals(1, restoredCount)
        val restored = destinationRepository.observeAll().first().single()
        assertEquals(id, restored.id)
        assertEquals("バックアップ対象", restored.title)
        assertEquals(DiaryMood.VeryGood, restored.mood)
        assertEquals(1, restored.photoUrls.size)
        assertArrayEquals(photoData, destinationPhotos.load(restored.photoUrls.single()))
    }

    @Test
    fun importKeepsUnrelatedLocalDiary() = runTest {
        val sourceRepository = repository()
        val sourcePhotos = photoStore()
        sourceRepository.save(Diary(userId = "guest", title = "バックアップ内の日記"))
        val backup = DiaryBackupService(sourceRepository, sourcePhotos).exportData()

        val destinationRepository = repository()
        val destinationPhotos = photoStore()
        destinationRepository.save(Diary(userId = "guest", title = "端末に残す日記"))

        DiaryBackupService(destinationRepository, destinationPhotos).importData(backup)

        assertEquals(
            setOf("バックアップ内の日記", "端末に残す日記"),
            destinationRepository.observeAll().first().map { it.title }.toSet(),
        )
    }

    @Test
    fun invalidPhotoHashIsRejected() = runTest {
        val repository = repository()
        val photos = photoStore()
        val invalidJson = """
            {
              "format": "org-portal-diary-backup",
              "version": 1,
              "exportedAtEpochMillis": 0,
              "diaries": [{
                "id": "${UUID.randomUUID()}",
                "userId": "guest",
                "title": "改ざんデータ",
                "body": "",
                "mood": "neutral",
                "createdAtEpochMillis": 0,
                "updatedAtEpochMillis": 0,
                "photos": [{
                  "dataBase64": "/9j/2Q==",
                  "sha256": "incorrect"
                }]
              }]
            }
        """.trimIndent()

        try {
            DiaryBackupService(repository, photos)
                .importData(invalidJson.toByteArray())
            fail("Invalid photo hash must be rejected")
        } catch (error: DiaryBackupException.InvalidPhoto) {
            // Expected.
        }
    }

    private fun repository(): RoomDiaryRepository {
        val database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        databases += database
        return RoomDiaryRepository(database.diaryDao())
    }

    private fun photoStore(): LocalDiaryPhotoStore {
        val directory = File(
            ApplicationProvider.getApplicationContext<android.content.Context>().cacheDir,
            "DiaryBackupTests-${UUID.randomUUID()}",
        )
        directories += directory
        return LocalDiaryPhotoStore(rootDirectory = directory)
    }
}
