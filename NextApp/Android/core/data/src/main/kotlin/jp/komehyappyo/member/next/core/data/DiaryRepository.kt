package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.Diary
import kotlinx.coroutines.flow.Flow
import java.util.UUID

interface DiaryRepository {
    fun observeAll(): Flow<List<Diary>>
    suspend fun save(diary: Diary)
    suspend fun delete(id: UUID)
}
