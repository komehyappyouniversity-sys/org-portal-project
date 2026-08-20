package jp.komehyappyo.member.next.core.notifications

import java.time.Instant
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class FcmTokenRegistrationManagerTest {
    @Test
    fun registersOnLoginUpdatesOnRefreshAndDeletesOnLogout() = runTest {
        val store = RecordingStore()
        val manager = FcmTokenRegistrationManager(
            store = store,
            tokenProvider = FcmRegistrationTokenProvider { "token-1" },
            environment = "development",
            now = { Instant.parse("2026-08-15T00:00:00Z") },
        )

        manager.synchronize("user-1", "id-token")
        val first = store.saved.single()
        assertEquals("user-1", first.userId)
        assertEquals("next", first.appVariant)
        assertEquals("Android", first.os)
        assertEquals("development", first.environment)
        assertEquals(FcmToken.idFor("token-1"), first.id)

        manager.tokenRefreshed("token-2")
        assertEquals(2, store.saved.size)
        assertNotEquals(store.saved[0].id, store.saved[1].id)
        assertEquals(listOf("user-1" to first.id), store.deleted)

        manager.synchronize(null, null)
        assertEquals(
            listOf("user-1" to first.id, "user-1" to FcmToken.idFor("token-2")),
            store.deleted,
        )
    }

    private class RecordingStore : FcmTokenStore {
        val saved = mutableListOf<FcmToken>()
        val deleted = mutableListOf<Pair<String, String>>()

        override suspend fun save(token: FcmToken, idToken: String) {
            saved += token
        }

        override suspend fun delete(userId: String, tokenId: String, idToken: String) {
            deleted += userId to tokenId
        }
    }
}
