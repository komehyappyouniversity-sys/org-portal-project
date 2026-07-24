package jp.komehyappyo.member.next.core.data

import android.content.Context
import jp.komehyappyo.member.next.core.model.MeetingRecordingDraft
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.util.UUID

class LocalMeetingRecordingStore(context: Context) : MeetingRecordingDraftStore {
    private val root = File(context.filesDir, "meeting_recordings").apply { mkdirs() }
    private val draftMetadata = File(root, "recording-draft.json")

    fun newTemporaryAudioFile(id: UUID = UUID.randomUUID()): File =
        File(root, "draft-$id.aac")

    fun permanentAudioFile(id: UUID): File = File(root, "$id.aac")

    fun moveAudio(source: File, minutesId: UUID): File {
        val destination = permanentAudioFile(minutesId)
        if (source.canonicalPath != destination.canonicalPath) {
            if (destination.exists()) destination.delete()
            check(source.renameTo(destination)) { "録音ファイルを保存できませんでした。" }
        }
        return destination
    }

    override fun load(): MeetingRecordingDraft? {
        if (!draftMetadata.exists()) return null
        val value = JSONObject(draftMetadata.readText())
        return MeetingRecordingDraft(
            id = UUID.fromString(value.getString("id")),
            userId = value.optString("userId", "guest"),
            startedAt = Instant.ofEpochMilli(value.getLong("startedAtEpochMillis")),
            audioFileLocalPath = value.getString("audioFileLocalPath"),
            transcriptText = value.optString("transcriptText"),
            recordingDurationSeconds = value.optInt("recordingDurationSeconds", 0),
            updatedAt = Instant.ofEpochMilli(value.getLong("updatedAtEpochMillis")),
        )
    }

    override fun save(draft: MeetingRecordingDraft) {
        root.mkdirs()
        val value = JSONObject()
            .put("id", draft.id.toString())
            .put("userId", draft.userId)
            .put("startedAtEpochMillis", draft.startedAt.toEpochMilli())
            .put("audioFileLocalPath", draft.audioFileLocalPath)
            .put("transcriptText", draft.transcriptText)
            .put("recordingDurationSeconds", draft.recordingDurationSeconds)
            .put("updatedAtEpochMillis", draft.updatedAt.toEpochMilli())
        val temporary = File(root, "recording-draft.tmp")
        temporary.writeText(value.toString())
        if (draftMetadata.exists()) draftMetadata.delete()
        check(temporary.renameTo(draftMetadata)) { "録音の復旧情報を保存できませんでした。" }
    }

    override fun delete() {
        draftMetadata.delete()
    }

    fun discard(draft: MeetingRecordingDraft) {
        File(draft.audioFileLocalPath).delete()
        delete()
    }
}
