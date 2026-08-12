package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.CommunityRepository
import jp.komehyappyo.member.next.core.model.DistributedVideo
import jp.komehyappyo.member.next.core.model.VideoQuestion
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.util.UUID

internal fun parseQuestionCreatedAtMillis(value: String?): Long =
    runCatching { Instant.parse(value ?: "").toEpochMilli() }.getOrDefault(0L)

data class DistributedVideosUiState(
    val videos: List<DistributedVideo> = emptyList(),
    val videoQuestions: List<VideoQuestion> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

class DistributedVideoFeatureModel(
    private val repository: CommunityRepository,
    private val session: AppSession,
    private val canViewMembersOnlyVideo: (String) -> Boolean,
    private val memoStore: VimeoMemoStore,
) : ViewModel() {
    private val mutableState = MutableStateFlow(DistributedVideosUiState())
    val state: StateFlow<DistributedVideosUiState> = mutableState.asStateFlow()

    fun load() {
        val current = session.state.value
        val communityId = current.selectedCommunityId
        val token = current.authenticationToken
        if (communityId == null || token == null) {
            mutableState.value = DistributedVideosUiState()
            return
        }
        mutableState.update {
            it.copy(isLoading = true, errorMessage = null)
        }
        viewModelScope.launch {
            runCatching {
                repository.communityVideos(communityId, token).getOrThrow() to
                    repository.videoQuestions(communityId, current.userId, token).getOrThrow()
            }
                .onSuccess { (videos, questions) ->
                    val canViewMembersOnly = canViewMembersOnlyVideo(communityId)
                    mutableState.update {
                        it.copy(
                            videos = filterDistributedVideos(videos, canViewMembersOnly),
                            videoQuestions = questions,
                            isLoading = false,
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error ->
                    mutableState.update {
                        it.copy(
                            isLoading = false,
                            errorMessage = "動画を取得できませんでした。",
                        )
                    }
                }
        }
    }

    fun videoMemosFor(video: DistributedVideo): List<VimeoVideoMemo> {
        return memoStore.entries(communityId = video.communityId, videoId = video.id)
    }

    fun addVideoMemo(video: DistributedVideo, memo: String, playbackSeconds: Double) {
        val normalized = memo.trim()
        if (normalized.isBlank()) {
            mutableState.update { it.copy(errorMessage = "メモを入力してください。") }
            return
        }

        val now = System.currentTimeMillis()
        val entries = videoMemosFor(video) + VimeoVideoMemo(
            id = UUID.randomUUID().toString(),
            text = normalized,
            playbackSeconds = playbackSeconds,
            createdAtMillis = now,
            updatedAtMillis = now,
        )

        persistVideoMemos(
            video = video,
            entries = entries,
            successMessage = "動画メモを追加しました。",
        )
    }

    fun updateVideoMemo(video: DistributedVideo, memo: VimeoVideoMemo, text: String) {
        val normalized = text.trim()
        if (normalized.isBlank()) {
            mutableState.update { it.copy(errorMessage = "メモを入力してください。") }
            return
        }

        val now = System.currentTimeMillis()
        val updated = videoMemosFor(video).map { entry ->
            if (entry.id == memo.id) {
                entry.copy(
                    text = normalized,
                    updatedAtMillis = now,
                )
            } else {
                entry
            }
        }

        persistVideoMemos(
            video = video,
            entries = updated,
            successMessage = "動画メモを更新しました。",
        )
    }

    fun deleteVideoMemo(video: DistributedVideo, memo: VimeoVideoMemo) {
        val remaining = videoMemosFor(video).filter { it.id != memo.id }
        persistVideoMemos(
            video = video,
            entries = remaining,
            successMessage = "動画メモを削除しました。",
        )
    }

    private fun persistVideoMemos(
        video: DistributedVideo,
        entries: List<VimeoVideoMemo>,
        successMessage: String,
    ) {
        memoStore.save(
            communityId = video.communityId,
            videoId = video.id,
            entries = entries,
        )
        mutableState.update {
            it.copy(errorMessage = successMessage)
        }
    }

    fun questionsFor(video: DistributedVideo): List<VideoQuestion> = state.value.videoQuestions
        .filter { it.videoId == video.id }
        .sortedByDescending { parseQuestionCreatedAtMillis(it.createdAt) }

    fun submitVideoQuestion(
        video: DistributedVideo,
        memo: String,
        question: String,
        playbackSeconds: Double,
    ) {
        val normalizedQuestion = question.trim()
        if (normalizedQuestion.isEmpty()) {
            mutableState.update { it.copy(errorMessage = "質問を入力してください。") }
            return
        }

        val current = session.state.value
        val communityId = current.selectedCommunityId
        val token = current.authenticationToken
        if (communityId == null || token == null) {
            mutableState.update { it.copy(errorMessage = "動画情報を取得できませんでした。") }
            return
        }

        viewModelScope.launch {
            runCatching {
                repository.saveVideoQuestion(
                    communityId = communityId,
                    memberUid = current.userId,
                    video = video,
                    memoText = memo,
                    questionText = normalizedQuestion,
                    playbackSeconds = playbackSeconds,
                    idToken = token,
                ).getOrThrow()
                load()
            }.onSuccess {
                mutableState.update {
                    it.copy(errorMessage = "質問を送信しました。")
                }
            }.onFailure { error ->
                mutableState.update {
                    it.copy(errorMessage = error.localizedMessage)
                }
            }
        }
    }

    fun clearError() {
        mutableState.update { it.copy(errorMessage = null) }
    }

    class Factory(
        private val repository: CommunityRepository,
        private val session: AppSession,
        private val canViewMembersOnlyVideo: (String) -> Boolean,
        private val memoStore: VimeoMemoStore,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
            return DistributedVideoFeatureModel(
                repository,
                session,
                canViewMembersOnlyVideo,
                memoStore,
            ) as T
        }
    }
}

internal fun filterDistributedVideos(
    videos: List<DistributedVideo>,
    canViewMembersOnlyVideo: Boolean,
): List<DistributedVideo> {
    return videos
        .filter { video ->
            !video.isPremium &&
                (!video.isMembersOnly || canViewMembersOnlyVideo)
        }
        .sortedWith(
            compareBy<DistributedVideo> { it.sortOrder }
                .thenBy { it.title },
        )
}
