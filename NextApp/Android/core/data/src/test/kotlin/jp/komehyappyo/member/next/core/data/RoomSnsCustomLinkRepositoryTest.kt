package jp.komehyappyo.member.next.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.SnsCustomLink
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
class RoomSnsCustomLinkRepositoryTest {
    private lateinit var database: OrgPortalDatabase
    private lateinit var repository: RoomSnsCustomLinkRepository

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = RoomSnsCustomLinkRepository(database.snsCustomLinkDao())
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun `save update fetch and delete`() = runTest {
        var link = SnsCustomLink(
            title = "公式ブログ",
            url = "https://example.com",
        )

        repository.save(link)
        assertEquals(listOf("公式ブログ"), repository.observeAll().first().map { it.title })

        link = link.copy(title = "公式サイト")
        repository.save(link)
        assertEquals(listOf("公式サイト"), repository.observeAll().first().map { it.title })

        repository.delete(link.id)
        assertTrue(repository.observeAll().first().isEmpty())
    }
}
