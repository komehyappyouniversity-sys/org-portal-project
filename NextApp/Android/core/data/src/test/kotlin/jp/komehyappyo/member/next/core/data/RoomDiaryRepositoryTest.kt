package jp.komehyappyo.member.next.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.Diary
import jp.komehyappyo.member.next.core.model.DiaryMood
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class RoomDiaryRepositoryTest {
    private lateinit var database: OrgPortalDatabase
    private lateinit var repository: RoomDiaryRepository

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = RoomDiaryRepository(database.diaryDao())
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun saveFetchAndDelete() = runTest {
        val diary = Diary(
            userId = "guest",
            title = "保存テスト",
            body = "端末内に保存します",
            mood = DiaryMood.Good,
        )

        repository.save(diary)
        val saved = repository.observeAll().first()
        assertEquals(listOf("保存テスト"), saved.map { it.title })
        assertEquals(DiaryMood.Good, saved.first().mood)

        repository.delete(diary.id)
        assertTrue(repository.observeAll().first().isEmpty())
    }
}
