package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.FavoriteBookmark
import kotlinx.coroutines.flow.Flow
import java.util.UUID

interface FavoriteBookmarkRepository {
    fun observeAll(): Flow<List<FavoriteBookmark>>
    suspend fun save(favorite: FavoriteBookmark)
    suspend fun delete(id: UUID)
}
