package jp.komehyappyo.member.next.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.FavoriteBookmark
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
class FavoriteBookmarkBackupServiceTest {
    private val databases = mutableListOf<OrgPortalDatabase>()

    @After
    fun tearDown() {
        databases.forEach(OrgPortalDatabase::close)
    }

    @Test
    fun `backup restores title url note and category and keeps existing favorite`() = runTest {
        val source = repository()
        val sourceFavorite = FavoriteBookmark(
            title = "公式サイト",
            url = "https://example.com/article",
            note = "後で読み返すメモ",
            category = "学習",
            createdAt = Instant.ofEpochSecond(100),
            updatedAt = Instant.ofEpochSecond(200),
        )
        source.save(sourceFavorite)
        val backup = FavoriteBookmarkBackupService(source)
            .exportData(Instant.ofEpochSecond(300))

        val destination = repository()
        destination.save(
            FavoriteBookmark(
                title = "端末に残すお気に入り",
                url = "https://example.org",
            ),
        )
        val restoredCount = FavoriteBookmarkBackupService(destination)
            .importData(backup)

        assertEquals(1, restoredCount)
        val restored = destination.observeAll().first()
        assertEquals(
            setOf("公式サイト", "端末に残すお気に入り"),
            restored.map { it.title }.toSet(),
        )
        val restoredFavorite = restored.single { it.id == sourceFavorite.id }
        assertEquals("https://example.com/article", restoredFavorite.url)
        assertEquals("後で読み返すメモ", restoredFavorite.note)
        assertEquals("学習", restoredFavorite.category)
    }

    @Test
    fun `invalid backup format is rejected`() = runTest {
        try {
            FavoriteBookmarkBackupService(repository())
                .importData("{}".toByteArray())
            fail("Invalid format must be rejected")
        } catch (error: FavoriteBookmarkBackupException.InvalidFormat) {
            // Expected.
        }
    }

    private fun repository(): RoomFavoriteBookmarkRepository {
        val database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        databases += database
        return RoomFavoriteBookmarkRepository(database.favoriteBookmarkDao())
    }
}
