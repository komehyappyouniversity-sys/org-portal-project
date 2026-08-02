package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.PersonalVideo
import jp.komehyappyo.member.next.core.model.VideoMemo
import kotlinx.coroutines.flow.Flow
import java.util.UUID

interface PersonalVideoRepository {
    fun observeVideos(): Flow<List<PersonalVideo>>
    fun observeMemos(videoId: UUID): Flow<List<VideoMemo>>

    suspend fun saveVideo(video: PersonalVideo)
    suspend fun saveMemo(memo: VideoMemo)
    suspend fun deleteVideo(id: UUID)
    suspend fun deleteMemo(id: UUID)
}

