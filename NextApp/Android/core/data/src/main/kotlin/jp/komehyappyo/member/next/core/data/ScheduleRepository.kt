package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.Schedule
import kotlinx.coroutines.flow.Flow
import java.time.LocalDate
import java.util.UUID

interface ScheduleRepository {
    fun observeAll(): Flow<List<Schedule>>
    fun observe(date: LocalDate): Flow<List<Schedule>>
    suspend fun save(schedule: Schedule)
    suspend fun delete(id: UUID)
}
