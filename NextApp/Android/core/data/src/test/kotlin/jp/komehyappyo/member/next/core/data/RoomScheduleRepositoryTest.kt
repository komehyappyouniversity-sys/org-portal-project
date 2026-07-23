package jp.komehyappyo.member.next.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.Schedule
import jp.komehyappyo.member.next.core.model.ScheduleTimeOfDay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.time.Instant

@RunWith(RobolectricTestRunner::class)
class RoomScheduleRepositoryTest {
    private lateinit var database: OrgPortalDatabase
    private lateinit var repository: RoomScheduleRepository

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = RoomScheduleRepository(database.scheduleDao())
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun saveFetchAndDelete() = runTest {
        val schedule = Schedule(
            userId = "guest",
            title = "保存テスト",
            startDateTime = Instant.parse("2026-07-23T01:00:00Z"),
            endDateTime = Instant.parse("2026-07-23T02:00:00Z"),
            timeOfDay = ScheduleTimeOfDay.Specified,
        )

        repository.save(schedule)
        assertEquals(listOf("保存テスト"), repository.observeAll().first().map { it.title })

        repository.delete(schedule.id)
        assertTrue(repository.observeAll().first().isEmpty())
    }
}
