package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.VideoQuestionRepository
import jp.komehyappyo.member.next.core.model.VideoQuestion
import jp.komehyappyo.member.next.core.model.VideoQuestionStatus
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class VideoQuestionUiState(
    val questions: List<VideoQuestion> = emptyList(),
    val isLoading: Boolean = false,
    val currentCommunityId: String = "",
    val videoId: String = "",
    val videoTitle: String = "",
    val noteText: String = "",
    val questionText: String = "",
    val playbackSecondsText: String = "0",
    val message: String? = null,
)

class VideoQuestionFeatureModel(
    private val repository: VideoQuestionRepository,
    private val session: AppSession,
) : ViewModel() {
    private val mutableState = MutableStateFlow(VideoQuestionUiState())
    val state: StateFlow<VideoQuestionUiState> = mutableState

    init {
        refresh()
    }

    val canSendQuestion: Boolean
        get() {
            val current = session.state.value
            return current.selectedCommunityId != null && current.authenticationToken != null
        }

    fun refresh() {
        val current = session.state.value
        val communityId = current.selectedCommunityId?.trim()?.ifEmpty { null }
        val token = current.authenticationToken
        if (communityId == null || token == null) {
            mutableState.update {
                it.copy(
                    questions = emptyList(),
                    isLoading = false,
                    currentCommunityId = "",
                    message = if (current.selectedCommunityId == null) {
                        "コミュニティを選択すると質問一覧を確認できます。"
                    } else {
                        "質問一覧の取得にはログインが必要です。"
                    },
                )
            }
            return
        }
        mutableState.update { it.copy(isLoading = true, currentCommunityId = communityId, message = null) }
        viewModelScope.launch {
            repository.myQuestions(
                communityId = communityId,
                memberUid = current.userId,
                idToken = token,
            ).onSuccess { questions ->
                mutableState.update {
                    it.copy(
                        isLoading = false,
                        questions = questions.sortedWith(
                            compareByDescending<VideoQuestion> { it.updatedAt }
                                .thenByDescending { it.createdAt },
                        ),
                        message = null,
                    )
                }
            }.onFailure { error ->
                mutableState.update {
                    it.copy(
                        isLoading = false,
                        questions = emptyList(),
                        message = error.message ?: "質問一覧を取得できませんでした。",
                    )
                }
            }
        }
    }

    fun updateDraft(
        videoId: String,
        videoTitle: String,
        noteText: String,
        questionText: String,
        playbackSecondsText: String,
    ) {
        mutableState.update {
            it.copy(
                videoId = videoId,
                videoTitle = videoTitle,
                noteText = noteText,
                questionText = questionText,
                playbackSecondsText = playbackSecondsText,
                message = null,
            )
        }
    }

    fun clearDraft() {
        mutableState.update {
            it.copy(
                videoId = "",
                videoTitle = "",
                noteText = "",
                questionText = "",
                playbackSecondsText = "0",
                message = null,
            )
        }
    }

    fun sendQuestion() {
        val current = session.state.value
        val communityId = current.selectedCommunityId?.trim()?.ifEmpty { null }
        val token = current.authenticationToken
        val stateValue = mutableState.value
        if (communityId == null || token == null) {
            mutableState.update {
                it.copy(message = "先にログインしてコミュニティを選択してください。")
            }
            return
        }
        val question = stateValue.questionText.trim()
        if (question.isBlank()) {
            mutableState.update { it.copy(message = "質問内容を入力してください。") }
            return
        }
        val videoId = stateValue.videoId.trim()
        if (videoId.isBlank()) {
            mutableState.update { it.copy(message = "動画IDを入力してください。") }
            return
        }
        val seconds = stateValue.playbackSecondsText.toIntOrNull() ?: 0

        viewModelScope.launch {
            repository.createQuestion(
                communityId = communityId,
                videoId = videoId,
                videoType = "personal_youtube",
                videoTitle = stateValue.videoTitle.trim().ifEmpty { "動画" },
                memberUid = current.userId,
                memberName = current.userId.takeIf { it.isNotBlank() } ?: "会員",
                memberEmail = "",
                questionText = question,
                noteText = stateValue.noteText.trim(),
                seconds = seconds,
                idToken = token,
            ).onSuccess {
                refresh()
                mutableState.update {
                    it.copy(
                        message = "質問を送信しました。",
                        questionText = "",
                    )
                }
            }.onFailure { error ->
                mutableState.update { it.copy(message = error.message ?: "送信できませんでした。") }
            }
        }
    }

    fun resolveAnswerText(for question: VideoQuestion): String {
        return if (question.status == VideoQuestionStatus.Answered) {
            question.answerText.ifEmpty { "（回答はまだありません）" }
        } else {
            "（未回答）"
        }
    }

    class Factory(
        private val repository: VideoQuestionRepository,
        private val session: AppSession,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
            return VideoQuestionFeatureModel(repository, session) as T
        }
    }
}
