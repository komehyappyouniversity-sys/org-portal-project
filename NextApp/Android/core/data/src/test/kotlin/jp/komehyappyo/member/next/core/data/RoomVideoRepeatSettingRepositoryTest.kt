package jp.komehyappyo.member.next.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.VideoRepeatMode
import jp.komehyappyo.member.next.core.model.VideoRepeatSetting
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class RoomVideoRepeatSettingRepositoryTest {
    private lateinit var database: OrgPortalDatabase
    private lateinit var repository: RoomVideoRepeatSettingRepository

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = RoomVideoRepeatSettingRepository(database.videoRepeatSettingDao())
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun saveUpdateAndFetchByVideoId() = runTest {
        assertNull(repository.setting("video-1"))

        repository.save(
            VideoRepeatSetting(
                userId = "guest-local",
                videoId = "video-1",
                isEnabled = true,
            ),
        )
        repository.save(
            VideoRepeatSetting(
                userId = "member-1",
                videoId = "video-2",
                isEnabled = true,
            ),
        )

        val saved = requireNotNull(repository.setting("video-1"))
        assertEquals("guest-local", saved.userId)
        assertTrue(saved.isEnabled)
        assertEquals(VideoRepeatMode.Full, saved.mode)
        assertNull(saved.repeatStartSeconds)
        assertNull(saved.repeatEndSeconds)

        repository.save(saved.copy(userId = "member-1", isEnabled = false))

        val updated = requireNotNull(repository.setting("video-1"))
        assertEquals("member-1", updated.userId)
        assertFalse(updated.isEnabled)
        assertTrue(requireNotNull(repository.setting("video-2")).isEnabled)
    }
}
