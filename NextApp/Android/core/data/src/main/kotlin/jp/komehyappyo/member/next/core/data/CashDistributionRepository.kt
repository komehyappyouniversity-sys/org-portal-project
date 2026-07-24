package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.CashDistribution
import kotlinx.coroutines.flow.Flow
import java.util.UUID

interface CashDistributionRepository {
    fun observeAll(): Flow<List<CashDistribution>>
    suspend fun save(distribution: CashDistribution)
    suspend fun delete(id: UUID)
}
