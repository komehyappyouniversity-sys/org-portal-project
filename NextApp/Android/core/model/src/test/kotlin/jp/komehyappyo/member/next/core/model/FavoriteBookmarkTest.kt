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
            secondaryCategory = " 学習 ",
            tertiaryCategory = " Kotlin ",
        ).validated()

        assertEquals("公式サイト", favorite.title)
        assertEquals("https://example.com", favorite.url)
        assertEquals("メモ", favorite.note)
        assertEquals("未分類", favorite.category)
        assertEquals("学習", favorite.secondaryCategory)
        assertEquals("Kotlin", favorite.tertiaryCategory)
        assertEquals("未分類 / 学習 / Kotlin", favorite.categoryPath)
    }

    @Test
    fun `tertiary category is cleared without secondary category`() {
        val favorite = FavoriteBookmark(
            title = "公式サイト",
            url = "https://example.com",
            category = "仕事",
            tertiaryCategory = "資料",
        ).validated()

        assertEquals("仕事", favorite.categoryPath)
        assertEquals("", favorite.tertiaryCategory)
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
