package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class FavoriteBookmarkTest {
    @Test
    fun `validation trims values and defaults category`() {
        val favorite = FavoriteBookmark(
            title = " 公式サイト ",
            url = " https://example.com ",
            note = " メモ ",
            category = " ",
        ).validated()

        assertEquals("公式サイト", favorite.title)
        assertEquals("https://example.com", favorite.url)
        assertEquals("メモ", favorite.note)
        assertEquals("未分類", favorite.category)
    }

    @Test
    fun `validation rejects missing title and unsafe url`() {
        assertFailsWith<IllegalArgumentException> {
            FavoriteBookmark(title = " ", url = "https://example.com").validated()
        }
        assertFailsWith<IllegalArgumentException> {
            FavoriteBookmark(title = "危険", url = "javascript:alert(1)").validated()
        }
    }
}
