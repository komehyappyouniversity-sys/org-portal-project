package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class DiaryTest {
    @Test
    fun `blank title is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            Diary(userId = "guest", title = "  ").validated()
        }
    }

    @Test
    fun `maximum photo count is five`() {
        val photos = (0 until Diary.MAXIMUM_PHOTO_COUNT).map { "photo-$it.jpg" }
        assertEquals(photos, Diary(userId = "guest", title = "写真", photoUrls = photos).validated().photoUrls)
        assertFailsWith<IllegalArgumentException> {
            Diary(
                userId = "guest",
                title = "写真",
                photoUrls = photos + "extra.jpg",
            ).validated()
        }
    }

    @Test
    fun `mood has five shared cases`() {
        assertEquals(
            listOf("VeryGood", "Good", "Neutral", "SlightlyBad", "Bad"),
            DiaryMood.entries.map { it.name },
        )
    }
}
