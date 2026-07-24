package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class SnsCustomLinkTest {
    @Test
    fun `validation trims title and url`() {
        val link = SnsCustomLink(
            title = "  公式ブログ  ",
            url = "  https://example.com/post  ",
        ).validated()

        assertEquals("公式ブログ", link.title)
        assertEquals("https://example.com/post", link.url)
    }

    @Test
    fun `validation rejects missing title and unsafe url`() {
        assertFailsWith<IllegalArgumentException> {
            SnsCustomLink(title = " ", url = "https://example.com").validated()
        }
        assertFailsWith<IllegalArgumentException> {
            SnsCustomLink(title = "危険", url = "javascript:alert(1)").validated()
        }
    }
}
