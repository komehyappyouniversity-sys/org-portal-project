package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.UsageLog
import jp.komehyappyo.member.next.core.model.UsageLogEventType
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.time.Instant

@RunWith(RobolectricTestRunner::class)
class UsageLogDataTest {
    @Test
    fun conversionAddsNinetyDayExpirationWithoutContentFields() {
        val occurredAt = Instant.parse("2026-08-15T00:00:00Z")
        val fields = usageLogFirestoreFields(
            UsageLog(
                id = "log-1",
                userId = "member-1",
                eventType = UsageLogEventType.VideoCompleted,
                targetId = "video-1",
                positionSeconds = 120.0,
                occurredAt = occurredAt,
            ),
        )

        assertEquals("video_completed", fields.getJSONObject("eventType").getString("stringValue"))
        assertEquals(120.0, fields.getJSONObject("positionSeconds").getDouble("doubleValue"), 0.0)
        assertEquals("2026-11-13T00:00:00Z", fields.getJSONObject("expiresAt").getString("timestampValue"))
        assertNull(fields.optJSONObject("body"))
        assertNull(fields.optJSONObject("memo"))
    }

    @Test
    fun recorderDoesNotSendWhenOptedOut() = runBlocking {
        val remote = UsageLogRemoteSpy()
        val recorder = UsageLogRecorder(
            remoteRepository = remote,
            preferenceStore = FixedUsagePreferenceStore(true),
            idProvider = { "log-1" },
            now = { Instant.parse("2026-08-15T00:00:00Z") },
        )

        val sent = recorder.record(
            userId = "member-1",
            idToken = "token",
            eventType = UsageLogEventType.RadioPlayed,
            targetId = "radio-1",
        )

        assertFalse(sent)
        assertEquals(0, remote.savedLogs.size)
    }

    @Test
    fun recorderSendsAllowedMetadataWhenEnabled() = runBlocking {
        val remote = UsageLogRemoteSpy()
        val recorder = UsageLogRecorder(
            remoteRepository = remote,
            preferenceStore = FixedUsagePreferenceStore(false),
            idProvider = { "log-1" },
            now = { Instant.parse("2026-08-15T00:00:00Z") },
        )

        assertTrue(recorder.record(
            userId = "member-1",
            idToken = "token",
            eventType = UsageLogEventType.VideoPlaybackStarted,
            targetId = "video-1",
            positionSeconds = 12.0,
        ))
        assertEquals(1, remote.savedLogs.size)
        assertEquals("video-1", remote.savedLogs.single().targetId)
    }
}

private class FixedUsagePreferenceStore(initial: Boolean) : UsageAnalyticsPreferenceStore {
    private var optedOut = initial
    override val optOutFlow: Flow<Boolean> get() = flowOf(optedOut)
    override suspend fun isOptedOut(): Boolean = optedOut
    override suspend fun setOptedOut(optedOut: Boolean) {
        this.optedOut = optedOut
    }
}

private class UsageLogRemoteSpy : UsageLogRemoteRepository {
    val savedLogs = mutableListOf<UsageLog>()
    override suspend fun saveUsageLog(log: UsageLog, idToken: String): Result<Unit> = runCatching {
        savedLogs += log
    }
}
