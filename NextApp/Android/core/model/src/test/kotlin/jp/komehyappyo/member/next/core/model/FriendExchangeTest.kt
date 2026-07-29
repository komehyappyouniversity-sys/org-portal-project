package jp.komehyappyo.member.next.core.model

import java.time.Instant
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class FriendExchangeTest {
    @Test
    fun `contact validation trims text and requires name`() {
        val now = Instant.parse("2026-07-29T00:00:00Z")
        val contact = FriendContact(
            userId = "guest",
            name = " 山田 花子 ",
            postalCode = " 100-0001 ",
            phoneNumber = " 090-1234-5678 ",
            email = " hanako@example.com ",
        ).validated(now)

        assertEquals("山田 花子", contact.name)
        assertEquals("100-0001", contact.postalCode)
        assertEquals("090-1234-5678", contact.phoneNumber)
        assertEquals("hanako@example.com", contact.email)
        assertEquals(now, contact.updatedAt)

        assertFailsWith<IllegalArgumentException> {
            FriendContact(userId = "guest", name = "  ").validated()
        }
    }

    @Test
    fun `history requires content and limits photos to two`() {
        val friendId = UUID.randomUUID()

        assertFailsWith<IllegalArgumentException> {
            FriendInteractionHistory(friendId = friendId).validated()
        }
        assertFailsWith<IllegalArgumentException> {
            FriendInteractionHistory(
                friendId = friendId,
                photoUrls = listOf("one", "two", "three"),
            ).validated()
        }

        val history = FriendInteractionHistory(
            friendId = friendId,
            memo = " 電話で近況確認 ",
            isPhoneCall = true,
            phoneNumber = " 090-0000-0000 ",
        ).validated()
        assertEquals("電話で近況確認", history.memo)
        assertEquals("090-0000-0000", history.phoneNumber)
    }
}
