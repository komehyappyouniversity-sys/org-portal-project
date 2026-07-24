package jp.komehyappyo.member.next.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.FavoriteBookmark
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class RoomFavoriteBookmarkRepositoryTest {
    private lateinit var database: OrgPortalDatabase
    private lateinit var repository: RoomFavoriteBookmarkRepository

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = RoomFavoriteBookmarkRepository(database.favoriteBookmarkDao())
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun `save update fetch and delete`() = runTest {
        var favorite = FavoriteBookmark(
            title = "公式ブログ",
            url = "https://example.com",
            category = "仕事",
        )

        repository.save(favorite)
        assertEquals(listOf("公式ブログ"), repository.observeAll().first().map { it.title })

        favorite = favorite.copy(title = "公式サイト", note = "更新済み")
        repository.save(favorite)
        val updated = repository.observeAll().first()
        assertEquals(listOf("公式サイト"), updated.map { it.title })
        assertEquals("更新済み", updated.first().note)

        repository.delete(favorite.id)
        assertTrue(repository.observeAll().first().isEmpty())
    }
}
