package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.MeetingMinutes
import jp.komehyappyo.member.next.core.model.MeetingRecordingDraft
import kotlinx.coroutines.flow.Flow
import java.util.UUID

interface MeetingMinutesRepository {
    fun observeAll(): Flow<List<MeetingMinutes>>
    suspend fun save(minutes: MeetingMinutes)
    suspend fun delete(id: UUID)
}

interface MeetingRecordingDraftStore {
    fun load(): MeetingRecordingDraft?
    fun save(draft: MeetingRecordingDraft)
    fun delete()
}
