package jp.komehyappyo.member.next.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.MeetingMinutes
import jp.komehyappyo.member.next.core.model.MeetingRecordingDraft
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File
import java.time.Instant
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
class RoomMeetingMinutesRepositoryTest {
    private lateinit var database: OrgPortalDatabase
    private lateinit var repository: RoomMeetingMinutesRepository

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = RoomMeetingMinutesRepository(database.meetingMinutesDao())
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun `save fetch and delete also removes audio`() = runTest {
        val audio = File.createTempFile("meeting-", ".m4a")
        val now = Instant.now()
        val minutes = MeetingMinutes(
            title = "保存テスト",
            recordingStartAt = now,
            recordingEndAt = now.plusSeconds(30),
            recordingDurationSeconds = 30,
            audioFileLocalPath = audio.absolutePath,
            transcriptText = "本文",
        )

        repository.save(minutes)
        assertEquals(listOf("保存テスト"), repository.observeAll().first().map { it.title })

        repository.delete(minutes.id)
        assertEquals(emptyList<MeetingMinutes>(), repository.observeAll().first())
        assertFalse(audio.exists())
    }

    @Test
    fun `interrupted draft can be restored`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val store = LocalMeetingRecordingStore(context)
        val draft = MeetingRecordingDraft(
            id = UUID.randomUUID(),
            startedAt = Instant.ofEpochSecond(1_000),
            audioFileLocalPath = File(context.filesDir, "draft-test.m4a").absolutePath,
            transcriptText = "復旧する文字起こし",
            updatedAt = Instant.ofEpochSecond(1_010),
        )

        store.save(draft)
        assertEquals(draft, store.load())
        store.delete()
        assertNull(store.load())
    }
}
