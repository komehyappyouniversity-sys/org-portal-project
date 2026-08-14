package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.CommunityRepository
import jp.komehyappyo.member.next.core.model.DistributedVideo
import jp.komehyappyo.member.next.core.model.VideoQuestion
import jp.komehyappyo.member.next.core.model.VimeoVideoMemoSyncStatus
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
    val hasPendingVideoMemoSync: Boolean = false,
)

class DistributedVideoFeatureModel(
    private val repository: CommunityRepository,
    private val session: AppSession,
    private val canViewMembersOnlyVideo: (String) -> Boolean,
    private val memoStore: VimeoMemoStoreProtocol,
) : ViewModel() {
    private val mutableState = MutableStateFlow(DistributedVideosUiState())
    val state: StateFlow<DistributedVideosUiState> = mutableState.asStateFlow()

    fun load() {
        val current = session.state.value
        val communityId = current.selectedCommunityId
        val token = current.authenticationToken
        val userId = current.userId

        if (communityId == null || token == null) {
            mutableState.value = DistributedVideosUiState()
            return
        }

        mutableState.update {
            it.copy(isLoading = true, errorMessage = null)
        }

        viewModelScope.launch {
            runCatching {
                Triple(
                    repository.communityVideos(communityId, token).getOrThrow(),
                    repository.videoQuestions(communityId, userId, token).getOrThrow(),
                    repository.videoMemos(userId, token).getOrDefault(emptyMap()),
                )
            }.onSuccess { (videos, questions, memoPayloads) ->
                val canViewMembersOnly = canViewMembersOnlyVideo(communityId)
                memoStore.saveAll(
                    mergeMemoEntries(
                        local = memoStore.allEntries(),
                        remote = memoPayloads,
                    ).mapValues { (_, value) ->
                        memoStore.serialized(value)
                    },
                )
                synchronizePendingVideoMemos(userId, token)

                mutableState.update {
                    it.copy(
                        videos = filterDistributedVideos(videos, canViewMembersOnly),
                        videoQuestions = questions,
                        isLoading = false,
                        errorMessage = null,
                        hasPendingVideoMemoSync = memoStore.pendingEntries().isNotEmpty(),
                    )
                }
            }.onFailure {
                mutableState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = "動画を取得できませんでした。",
                        hasPendingVideoMemoSync = memoStore.pendingEntries().isNotEmpty(),
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
            syncStatus = VimeoVideoMemoSyncStatus.Synced,
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
            it.copy(
                errorMessage = successMessage,
                hasPendingVideoMemoSync = memoStore.pendingEntries().isNotEmpty(),
            )
        }

        val current = session.state.value
        val token = current.authenticationToken ?: return

        viewModelScope.launch {
            syncVideoMemos(
                video = video,
                entries = entries,
                userId = current.userId,
                token = token,
                successMessage = successMessage,
                reportSuccess = true,
            )
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
        if (normalizedQuestion.isBlank()) {
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

    private suspend fun syncVideoMemos(
        video: DistributedVideo,
        entries: List<VimeoVideoMemo>,
        userId: String,
        token: String,
        successMessage: String,
        reportSuccess: Boolean,
    ) {
        runCatching {
            repository.saveVideoMemo(
                userId = userId,
                communityId = video.communityId,
                videoId = video.id,
                memo = memoStore.serialized(entries),
                idToken = token,
            ).getOrThrow()
            memoStore.save(
                communityId = video.communityId,
                videoId = video.id,
                entries = entries.map { it.copy(syncStatus = VimeoVideoMemoSyncStatus.Synced) },
            )
            if (reportSuccess) {
                mutableState.update { it.copy(errorMessage = successMessage, hasPendingVideoMemoSync = false) }
            }
        }.onFailure {
            memoStore.save(
                communityId = video.communityId,
                videoId = video.id,
                entries = entries.map { it.copy(syncStatus = VimeoVideoMemoSyncStatus.PendingSync) },
            )
            if (reportSuccess) {
                mutableState.update { it.copy(errorMessage = "オフライン時は動画メモを保留しました。") }
            }
        }
        mutableState.update {
            it.copy(hasPendingVideoMemoSync = memoStore.pendingEntries().isNotEmpty())
        }
    }

    private fun synchronizePendingVideoMemos(userId: String, token: String) {
        val pending = memoStore.pendingEntries()
        if (pending.isEmpty()) {
            mutableState.update { it.copy(hasPendingVideoMemoSync = false) }
            return
        }
        val allEntries = memoStore.allEntries()
        viewModelScope.launch {
            pending.forEach { (key, entries) ->
                val components = key.split(":", limit = 2)
                if (components.size != 2) return@forEach
                // Sync the full entry list for this video, not just the pending subset —
                // syncVideoMemos overwrites the store for this key, so passing only the
                // pending entries would silently drop any already-synced memos.
                syncVideoMemos(
                    video = memoVideo(components[0], components[1]),
                    entries = allEntries[key] ?: entries,
                    userId = userId,
                    token = token,
                    successMessage = "",
                    reportSuccess = false,
                )
            }
        }
    }

    private fun memoVideo(communityId: String, videoId: String) = DistributedVideo(
        id = videoId,
        communityId = communityId,
        videoTitle = "",
        description = "",
        embedHtml = "",
        videoUrl = "",
        vimeoUrl = "",
        providerVideoId = "",
        videoType = "distributed_vimeo",
        thumbnailUrl = "",
        isPremium = false,
        createdAt = null,
        updatedAt = null,
        isPublished = true,
        isMembersOnly = false,
        sortOrder = 0,
    )

    private fun mergeMemoEntries(
        local: Map<String, List<VimeoVideoMemo>>,
        remote: Map<String, String>,
    ): Map<String, List<VimeoVideoMemo>> {
        return local.toMutableMap().also { merged ->
            remote.forEach { (key, payload) ->
                val localEntries = local[key] ?: emptyList()
                val remoteEntries = memoStore.entries(fromRaw = payload)
                val localById = localEntries.associateBy { it.id }
                val remoteIds = remoteEntries.map { it.id }.toSet()
                val entries = buildList {
                    remoteEntries.forEach { remoteEntry ->
                        val localEntry = localById[remoteEntry.id]
                        if (localEntry?.syncStatus == VimeoVideoMemoSyncStatus.PendingSync) {
                            add(localEntry)
                        } else {
                            add(remoteEntry)
                        }
                    }
                    localEntries
                        .filter {
                            it.syncStatus == VimeoVideoMemoSyncStatus.PendingSync && it.id !in remoteIds
                        }
                        .forEach(::add)
                }
                merged[key] = entries.sortedByDescending { it.createdAtMillis }
            }
        }
    }

    class Factory(
        private val repository: CommunityRepository,
        private val session: AppSession,
        private val canViewMembersOnlyVideo: (String) -> Boolean,
        private val memoStore: VimeoMemoStoreProtocol,
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
