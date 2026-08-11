package jp.komehyappyo.member.next.feature.tools

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class ManualViewsTest {
    @Test
    fun manualCatalogHasExpectedOrderAndIds() {
        val expectedIds = listOf("quick-start", "tools-start", "sns-favorites", "troubleshoot")
        assertEquals(expectedIds, availableManuals.map { it.id })
    }

    @Test
    fun manualCatalogHasRequiredContent() {
        assertEquals(4, availableManuals.size)

        availableManuals.forEach {
            assertFalse(it.id.isBlank())
            assertFalse(it.title.isBlank())
            assertFalse(it.description.isBlank())
            assertFalse(it.detail.isBlank())
        }
    }
}
