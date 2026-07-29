package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.FriendContact
import jp.komehyappyo.member.next.core.model.FriendInteractionHistory
import kotlinx.coroutines.flow.Flow
import java.util.UUID

interface FriendExchangeRepository {
    fun observeContacts(): Flow<List<FriendContact>>
    fun observeHistories(friendId: UUID): Flow<List<FriendInteractionHistory>>
    suspend fun save(contact: FriendContact)
    suspend fun save(history: FriendInteractionHistory)
    suspend fun deleteContact(id: UUID)
    suspend fun deleteHistory(id: UUID)
}
