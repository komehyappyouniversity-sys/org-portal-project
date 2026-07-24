package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.SnsCustomLink
import kotlinx.coroutines.flow.Flow
import java.util.UUID

interface SnsCustomLinkRepository {
    fun observeAll(): Flow<List<SnsCustomLink>>
    suspend fun save(link: SnsCustomLink)
    suspend fun delete(id: UUID)
}
