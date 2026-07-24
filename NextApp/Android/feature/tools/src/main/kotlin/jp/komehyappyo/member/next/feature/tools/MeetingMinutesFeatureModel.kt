package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.LocalMeetingRecordingStore
import jp.komehyappyo.member.next.core.data.MeetingMinutesRepository
import jp.komehyappyo.member.next.core.model.MeetingMinutes
import jp.komehyappyo.member.next.core.model.MeetingRecordingDraft
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import java.time.Instant
import java.util.UUID

data class MeetingMinutesUiState(
    val minutes: List<MeetingMinutes> = emptyList(),
    val draft: MeetingRecordingDraft? = null,
    val isRecording: Boolean = false,
    val isTranscribing: Boolean = false,
    val elapsedSeconds: Int = 0,
    val liveTranscript: String = "",
    val notice: String? = null,
    val errorMessage: String? = null,
)

class MeetingMinutesFeatureModel(
    private val repository: MeetingMinutesRepository,
    private val recordingStore: LocalMeetingRecordingStore,
    private val recorder: MeetingRecordingService,
) : ViewModel() {
    private val mutableState = MutableStateFlow(
        runCatching { recordingStore.load() }.getOrNull().let { draft ->
            MeetingMinutesUiState(
                draft = draft,
                elapsedSeconds = draft?.recordingDurationSeconds ?: 0,
                liveTranscript = draft?.transcriptText.orEmpty(),
            )
        },
    )
    val state: StateFlow<MeetingMinutesUiState> = mutableState
    private var timerJob: Job? = null

    init {
        recorder.onTranscriptChanged = { value ->
            mutableState.update { it.copy(liveTranscript = value) }
        }
        recorder.onTranscriptionStateChanged = { value ->
            mutableState.update {
                it.copy(
                    isTranscribing = value,
                    liveTranscript = recorder.transcript,
                    notice = recorder.transcriptionNotice,
                )
            }
            if (!value) persistDraft()
        }
        recorder.onInterrupted = {
            stopRecording(interrupted = true)
        }
        viewModelScope.launch {
            repository.observeAll()
                .catch { error ->
                    mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                }
                .collect { values -> mutableState.update { it.copy(minutes = values) } }
        }
    }

    fun startRecording(): Result<Unit> = runCatching {
        val id = UUID.randomUUID()
        val file = recordingStore.newTemporaryAudioFile(id)
        val draft = MeetingRecordingDraft(id = id, audioFileLocalPath = file.absolutePath)
        recordingStore.save(draft)
        recorder.start(file)
        mutableState.update {
            it.copy(
                draft = draft,
                isRecording = true,
                elapsedSeconds = 0,
                liveTranscript = "",
                notice = recorder.transcriptionNotice,
                errorMessage = null,
            )
        }
        timerJob = viewModelScope.launch {
            while (isActive) {
                delay(1_000)
                mutableState.update { current ->
                    current.copy(
                        elapsedSeconds = current.elapsedSeconds + 1,
                        liveTranscript = recorder.transcript,
                        notice = recorder.transcriptionNotice,
                    )
                }
                if (mutableState.value.elapsedSeconds % 10 == 0) persistDraft()
            }
        }
    }.onFailure { error ->
        mutableState.update { it.copy(errorMessage = error.localizedMessage) }
    }

    fun stopRecording(interrupted: Boolean = false) {
        val text = recorder.stopAndTranscribe()
        timerJob?.cancel()
        timerJob = null
        mutableState.update {
            it.copy(
                isRecording = false,
                isTranscribing = recorder.isTranscribing,
                liveTranscript = text,
                notice = if (interrupted) {
                    "録音が中断されました。録音を保存し、文字起こしを試みています。"
                } else {
                    recorder.transcriptionNotice
                },
            )
        }
        persistDraft()
    }

    fun retryTranscription() {
        val draft = mutableState.value.draft ?: return
        val file = File(draft.audioFileLocalPath)
        if (!file.exists()) {
            reportError("文字起こしする録音ファイルが見つかりません。")
            return
        }
        mutableState.update {
            it.copy(
                isTranscribing = true,
                liveTranscript = "",
                notice = "保存した録音の文字起こしを再実行します。",
                errorMessage = null,
            )
        }
        recorder.transcribe(file)
    }

    fun saveDraft(title: String, transcript: String, onComplete: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            runCatching {
                val draft = requireNotNull(mutableState.value.draft)
                val now = Instant.now()
                val duration = maxOf(
                    draft.recordingDurationSeconds,
                    mutableState.value.elapsedSeconds,
                )
                val destination = recordingStore.moveAudio(
                    File(draft.audioFileLocalPath),
                    draft.id,
                )
                repository.save(
                    MeetingMinutes(
                        id = draft.id,
                        userId = draft.userId,
                        title = title,
                        recordingStartAt = draft.startedAt,
                        recordingEndAt = draft.startedAt.plusSeconds(duration.toLong()),
                        recordingDurationSeconds = duration,
                        audioFileLocalPath = destination.absolutePath,
                        transcriptText = transcript,
                        createdAt = draft.startedAt,
                        updatedAt = now,
                    ).validated(now),
                )
                recordingStore.delete()
                mutableState.update {
                    it.copy(
                        draft = null,
                        isTranscribing = false,
                        liveTranscript = "",
                        elapsedSeconds = 0,
                    )
                }
            }.also(onComplete)
        }
    }

    fun update(minutes: MeetingMinutes, onComplete: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            runCatching { repository.save(minutes.copy(updatedAt = Instant.now())) }
                .also(onComplete)
        }
    }

    fun delete(minutes: MeetingMinutes) {
        viewModelScope.launch {
            runCatching { repository.delete(minutes.id) }
                .onFailure { error ->
                    mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                }
        }
    }

    fun discardDraft() {
        mutableState.value.draft?.let(recordingStore::discard)
        mutableState.update {
            it.copy(
                draft = null,
                isTranscribing = false,
                liveTranscript = "",
                elapsedSeconds = 0,
            )
        }
    }

    fun clearError() {
        mutableState.update { it.copy(errorMessage = null) }
    }

    fun reportError(message: String) {
        mutableState.update { it.copy(errorMessage = message) }
    }

    private fun persistDraft() {
        val current = mutableState.value
        val draft = current.draft ?: return
        val updated = draft.copy(
            transcriptText = current.liveTranscript,
            recordingDurationSeconds = current.elapsedSeconds,
            updatedAt = Instant.now(),
        )
        runCatching { recordingStore.save(updated) }
            .onSuccess { mutableState.update { it.copy(draft = updated) } }
            .onFailure { error ->
                mutableState.update { it.copy(errorMessage = error.localizedMessage) }
            }
    }

    override fun onCleared() {
        if (recorder.isRecording) {
            timerJob?.cancel()
            persistDraft()
        }
        recorder.release()
    }

    class Factory(
        private val repository: MeetingMinutesRepository,
        private val recordingStore: LocalMeetingRecordingStore,
        private val recorder: MeetingRecordingService,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            MeetingMinutesFeatureModel(repository, recordingStore, recorder) as T
    }
}
