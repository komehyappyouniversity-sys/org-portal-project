package jp.komehyappyo.member.next.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.FriendContact
import jp.komehyappyo.member.next.core.model.FriendInteractionHistory
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
class RoomFriendExchangeRepositoryTest {
    private lateinit var database: OrgPortalDatabase
    private lateinit var repository: RoomFriendExchangeRepository

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = RoomFriendExchangeRepository(
            contactDao = database.friendContactDao(),
            historyDao = database.friendInteractionHistoryDao(),
        )
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun `save update fetch and cascade delete`() = runTest {
        var contact = FriendContact(
            userId = "guest",
            name = "山田 花子",
            phoneNumber = "090-1234-5678",
        )
        repository.save(contact)
        assertEquals(listOf("山田 花子"), repository.observeContacts().first().map { it.name })

        contact = contact.copy(name = "山田 花子（更新）")
        repository.save(contact)
        assertEquals("山田 花子（更新）", repository.observeContacts().first().single().name)

        val history = FriendInteractionHistory(
            friendId = contact.id,
            memo = "喫茶店で交流",
            photoUrls = listOf("file:///photo.jpg"),
        )
        repository.save(history)
        assertEquals(
            "喫茶店で交流",
            repository.observeHistories(contact.id).first().single().memo,
        )

        repository.deleteContact(contact.id)
        assertTrue(repository.observeContacts().first().isEmpty())
        assertTrue(repository.observeHistories(contact.id).first().isEmpty())
    }
}
