package jp.komehyappyo.member.next.feature.tools

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.PersonalVideoRepository
import jp.komehyappyo.member.next.core.model.PersonalVideo
import jp.komehyappyo.member.next.core.model.VideoMemo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.util.Locale
import java.util.UUID

data class PersonalVideoUiState(
    val videos: List<PersonalVideo> = emptyList(),
    val memosByVideo: Map<UUID, List<VideoMemo>> = emptyMap(),
    val isLoading: Boolean = true,
    val notice: String? = null,
    val errorMessage: String? = null,
)

class PersonalVideoFeatureModel(
    private val repository: PersonalVideoRepository,
) : ViewModel() {
    private val mutableState = MutableStateFlow(PersonalVideoUiState())
    val state: StateFlow<PersonalVideoUiState> = mutableState

    init {
        observeVideos()
    }

    private fun observeVideos() {
        viewModelScope.launch {
            repository.observeVideos()
                .catch { error ->
                    mutableState.update {
                        it.copy(
                            isLoading = false,
                            errorMessage = error.localizedMessage,
                        )
                    }
                }
                .collect { videos ->
                    mutableState.update {
                        it.copy(
                            videos = videos,
                            isLoading = false,
                            errorMessage = null,
                        )
                    }
                }
        }
    }

    fun loadMemos(videoId: UUID) {
        viewModelScope.launch {
            repository.observeMemos(videoId)
                .catch { error ->
                    mutableState.update {
                        it.copy(errorMessage = error.localizedMessage)
                    }
                }
                .collect { memos ->
                    mutableState.update { current ->
                        current.copy(
                            memosByVideo = current.memosByVideo + (videoId to memos),
                            errorMessage = null,
                        )
                    }
                }
        }
    }

    fun clearNotice() {
        mutableState.update { it.copy(notice = null) }
    }

    fun clearError() {
        mutableState.update { it.copy(errorMessage = null) }
    }

    fun saveVideo(
        existing: PersonalVideo?,
        title: String,
        urlOrId: String,
        note: String,
        savedPositionSeconds: Int,
        category: String,
        secondaryCategory: String,
        tertiaryCategory: String,
        onComplete: (Boolean) -> Unit,
    ) {
        viewModelScope.launch {
            val providerVideoId = parseVideoId(urlOrId)
            if (providerVideoId == null) {
                mutableState.update { it.copy(errorMessage = "YouTubeのURLまたは動画IDを確認してください。") }
                onComplete(false)
                return@launch
            }
            runCatching {
                PersonalVideo(
                    id = existing?.id ?: UUID.randomUUID(),
                    userId = existing?.userId ?: "guest-local",
                    providerVideoId = providerVideoId,
                    title = title,
                    originalUrl = normalizeYouTubeUrl(urlOrId),
                    note = note,
                    savedPositionSeconds = savedPositionSeconds,
                    category = category,
                    secondaryCategory = secondaryCategory,
                    tertiaryCategory = tertiaryCategory,
                    createdAt = existing?.createdAt ?: Instant.now(),
                    updatedAt = Instant.now(),
                ).validated().also { repository.saveVideo(it) }
            }.onSuccess {
                mutableState.update {
                    it.copy(
                        notice = if (existing == null) {
                            "動画を登録しました。"
                        } else {
                            "動画情報を更新しました。"
                        },
                    )
                }
                onComplete(true)
            }.onFailure { error ->
                mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                onComplete(false)
            }
        }
    }

    fun saveMemo(
        videoId: UUID,
        text: String,
        positionSeconds: Int,
        onComplete: (Boolean) -> Unit,
    ) {
        viewModelScope.launch {
            runCatching {
                VideoMemo(
                    id = UUID.randomUUID(),
                    userId = "guest-local",
                    videoId = videoId,
                    positionSeconds = positionSeconds,
                    memoText = text,
                    createdAt = Instant.now(),
                    updatedAt = Instant.now(),
                ).validated(now = Instant.now())
                    .also { repository.saveMemo(it) }
            }.onSuccess {
                mutableState.update { it.copy(notice = "メモを保存しました。") }
                loadMemos(videoId)
                onComplete(true)
            }.onFailure { error ->
                mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                onComplete(false)
            }
        }
    }

    fun deleteVideo(video: PersonalVideo) {
        viewModelScope.launch {
            runCatching {
                repository.deleteVideo(video.id)
            }.onSuccess {
                mutableState.update { current ->
                    current.copy(
                        notice = "動画を削除しました。",
                        memosByVideo = current.memosByVideo - video.id,
                    )
                }
            }.onFailure { error ->
                mutableState.update { it.copy(errorMessage = error.localizedMessage) }
            }
        }
    }

    fun deleteMemo(videoId: UUID, memoId: UUID) {
        viewModelScope.launch {
            runCatching {
                repository.deleteMemo(memoId)
            }.onSuccess {
                loadMemos(videoId)
                mutableState.update { it.copy(notice = "メモを削除しました。") }
            }.onFailure { error ->
                mutableState.update { it.copy(errorMessage = error.localizedMessage) }
            }
        }
    }

    class Factory(
        private val repository: PersonalVideoRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
            return PersonalVideoFeatureModel(repository) as T
        }
    }

    private fun normalizeYouTubeUrl(input: String): String {
        val id = parseVideoId(input) ?: return input
        return "https://www.youtube.com/watch?v=${id}"
    }

    private fun parseVideoId(input: String): String? {
        val value = input.trim()
        if (value.matches(YOUTUBE_ID_REGEX)) return value

        val uri = runCatching { Uri.parse(value) }.getOrNull() ?: return null
        val host = uri.host?.lowercase(Locale.getDefault()) ?: return null
        val normalizedHost = host.removePrefix("www.")

        if (normalizedHost == "youtu.be") {
            val candidate = uri.path?.trim('/')
            return if (candidate?.let { it.matches(YOUTUBE_ID_REGEX) } == true) candidate else null
        }

        if (normalizedHost == "youtube.com") {
            if (uri.path == "/watch") {
                return uri.getQueryParameter("v").takeIf { it?.matches(YOUTUBE_ID_REGEX) == true }
            }
            val pathParts = uri.path?.trim('/')?.split('/') ?: emptyList()
            if (pathParts.size >= 2 &&
                (pathParts[0] == "shorts" || pathParts[0] == "embed")
            ) {
                return pathParts[1].takeIf { it.matches(YOUTUBE_ID_REGEX) }
            }
        }
        return null
    }

    private companion object {
        val YOUTUBE_ID_REGEX = "[A-Za-z0-9_-]{11}".toRegex()
    }
}

