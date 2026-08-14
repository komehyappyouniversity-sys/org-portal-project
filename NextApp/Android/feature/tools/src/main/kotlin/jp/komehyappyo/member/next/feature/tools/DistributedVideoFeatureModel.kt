package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.CommunityRepository
import jp.komehyappyo.member.next.core.data.GuestUserIdProvider
import jp.komehyappyo.member.next.core.data.VideoRepeatSettingRepository
import jp.komehyappyo.member.next.core.model.DistributedVideo
import jp.komehyappyo.member.next.core.model.VideoRepeatMode
import jp.komehyappyo.member.next.core.model.VideoRepeatSetting
import jp.komehyappyo.member.next.core.model.VideoQuestion
import jp.komehyappyo.member.next.core.model.VideoQuestionSyncStatus
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
    val hasPendingVideoQuestionSync: Boolean = false,
    val videoRepeatSettings: Map<String, VideoRepeatSetting> = emptyMap(),
)

class DistributedVideoFeatureModel(
    private val repository: CommunityRepository,
    private val session: AppSession,
    private val canViewMembersOnlyVideo: (String) -> Boolean,
    private val memoStore: VimeoMemoStoreProtocol,
    private val questionStore: VideoQuestionStoreProtocol = InMemoryVideoQuestionStore(),
    private val repeatSettingRepository: VideoRepeatSettingRepository? = null,
    private val guestUserIdProvider: GuestUserIdProvider? = null,
) : ViewModel() {
    private val mutableState = MutableStateFlow(DistributedVideosUiState())
    val state: StateFlow<DistributedVideosUiState> = mutableState.asStateFlow()
    private val syncingVideoQuestionRequestIds = mutableSetOf<String>()

    fun loadRepeatSetting(videoId: String) {
        val localRepository = repeatSettingRepository ?: return
        viewModelScope.launch {
            runCatching {
                localRepository.setting(videoId) ?: VideoRepeatSetting(
                    userId = localVideoSettingUserId(),
                    videoId = videoId,
                    isEnabled = false,
                )
            }
                .onSuccess { setting ->
                    mutableState.update {
                        it.copy(videoRepeatSettings = it.videoRepeatSettings + (videoId to setting))
                    }
                }
                .onFailure {
                    mutableState.update {
                        it.copy(errorMessage = "リピート再生設定を読み込めませんでした。")
                    }
                }
        }
    }

    fun isRepeatEnabled(videoId: String): Boolean =
        state.value.videoRepeatSettings[videoId]?.isEnabled ?: false

    fun setRepeatEnabled(videoId: String, isEnabled: Boolean) {
        val localRepository = repeatSettingRepository ?: return
        viewModelScope.launch {
            runCatching {
                VideoRepeatSetting(
                    userId = localVideoSettingUserId(),
                    videoId = videoId,
                    isEnabled = isEnabled,
                    mode = VideoRepeatMode.Full,
                    repeatStartSeconds = null,
                    repeatEndSeconds = null,
                ).also { localRepository.save(it) }
            }
                .onSuccess { setting ->
                    mutableState.update {
                        it.copy(videoRepeatSettings = it.videoRepeatSettings + (videoId to setting))
                    }
                }
                .onFailure {
                    mutableState.update {
                        it.copy(errorMessage = "リピート再生設定を保存できませんでした。")
                    }
                }
        }
    }

    private fun localVideoSettingUserId(): String {
        val current = session.state.value
        return if (current.authenticationToken == null) {
            guestUserIdProvider?.guestUserId() ?: "guest-local"
        } else {
            current.userId
        }
    }

    fun load() {
        val current = session.state.value
        val communityId = current.selectedCommunityId
        val token = current.authenticationToken
        val userId = current.userId

        if (communityId == null) {
            mutableState.value = DistributedVideosUiState()
            return
        }

        val localQuestions = questionStore.questions(communityId, userId)
        if (token == null) {
            mutableState.update {
                it.copy(
                    videos = emptyList(),
                    videoQuestions = localQuestions,
                    isLoading = false,
                    errorMessage = null,
                    hasPendingVideoQuestionSync = questionStore
                        .pendingQuestions(communityId, userId)
                        .isNotEmpty(),
                )
            }
            return
        }

        mutableState.update {
            it.copy(
                videoQuestions = localQuestions,
                isLoading = true,
                errorMessage = null,
                hasPendingVideoQuestionSync = questionStore
                    .pendingQuestions(communityId, userId)
                    .isNotEmpty(),
            )
        }

        viewModelScope.launch {
            synchronizePendingVideoQuestions(communityId, userId, token)
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
                val mergedQuestions = mergeVideoQuestions(
                    local = questionStore.questions(communityId, userId),
                    remote = questions,
                )
                questionStore.replaceQuestions(communityId, userId, mergedQuestions)

                mutableState.update {
                    it.copy(
                        videos = filterDistributedVideos(videos, canViewMembersOnly),
                        videoQuestions = mergedQuestions,
                        isLoading = false,
                        errorMessage = null,
                        hasPendingVideoMemoSync = memoStore.pendingEntries().isNotEmpty(),
                        hasPendingVideoQuestionSync = questionStore
                            .pendingQuestions(communityId, userId)
                            .isNotEmpty(),
                    )
                }
            }.onFailure {
                mutableState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = "動画を取得できませんでした。",
                        hasPendingVideoMemoSync = memoStore.pendingEntries().isNotEmpty(),
                        videoQuestions = questionStore.questions(communityId, userId),
                        hasPendingVideoQuestionSync = questionStore
                            .pendingQuestions(communityId, userId)
                            .isNotEmpty(),
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

    fun unansweredQuestions(): List<VideoQuestion> = state.value.videoQuestions
        .filterNot { it.isAnswered }

    fun answeredQuestions(): List<VideoQuestion> = state.value.videoQuestions
        .filter { it.isAnswered }

    fun submitVideoQuestion(
        video: DistributedVideo,
        memo: String,
        question: String,
        playbackSeconds: Double,
        onSubmitted: () -> Unit = {},
    ) {
        val normalizedQuestion = question.trim()
        if (normalizedQuestion.isBlank()) {
            mutableState.update { it.copy(errorMessage = "質問を入力してください。") }
            return
        }

        val current = session.state.value
        val communityId = current.selectedCommunityId
        if (communityId == null) {
            mutableState.update { it.copy(errorMessage = "動画情報を取得できませんでした。") }
            return
        }

        val clientRequestId = UUID.randomUUID().toString()
        val draft = VideoQuestion(
            id = clientRequestId,
            communityId = communityId,
            memberUid = current.userId,
            videoId = video.id,
            videoTitle = video.title,
            playbackSeconds = playbackSeconds,
            memoText = memo.trim(),
            questionText = normalizedQuestion,
            answerText = "",
            createdAt = Instant.now().toString(),
            answeredAt = null,
            syncStatus = VideoQuestionSyncStatus.Draft,
            clientRequestId = clientRequestId,
        )
        questionStore.save(draft)
        refreshLocalVideoQuestions(communityId, current.userId)
        onSubmitted()

        val token = current.authenticationToken
        if (token == null) {
            questionStore.save(draft.copy(syncStatus = VideoQuestionSyncStatus.Failed))
            refreshLocalVideoQuestions(communityId, current.userId)
            mutableState.update {
                it.copy(errorMessage = "オフラインのため質問を端末内に保存しました。")
            }
            return
        }

        viewModelScope.launch {
            val sent = syncVideoQuestion(draft, token)
            mutableState.update {
                it.copy(
                    errorMessage = if (sent) {
                        "質問を送信しました。"
                    } else {
                        "オフラインのため質問を端末内に保存しました。"
                    },
                )
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

    private suspend fun synchronizePendingVideoQuestions(
        communityId: String,
        memberUid: String,
        token: String,
    ) {
        questionStore.pendingQuestions(communityId, memberUid).forEach { question ->
            syncVideoQuestion(question, token)
        }
    }

    private suspend fun syncVideoQuestion(question: VideoQuestion, token: String): Boolean {
        val requestId = question.clientRequestId.ifBlank { question.id }
        if (!syncingVideoQuestionRequestIds.add(requestId)) return true
        try {
            val sending = question.copy(syncStatus = VideoQuestionSyncStatus.Sending)
            questionStore.save(sending)
            refreshLocalVideoQuestions(question.communityId, question.memberUid)
            return repository.saveVideoQuestion(
                communityId = question.communityId,
                memberUid = question.memberUid,
                video = questionVideo(question),
                memoText = question.memoText,
                questionText = question.questionText,
                playbackSeconds = question.playbackSeconds,
                clientRequestId = requestId,
                idToken = token,
            ).fold(
                onSuccess = {
                    questionStore.save(sending.copy(syncStatus = VideoQuestionSyncStatus.Synced))
                    refreshLocalVideoQuestions(question.communityId, question.memberUid)
                    true
                },
                onFailure = {
                    questionStore.save(sending.copy(syncStatus = VideoQuestionSyncStatus.Failed))
                    refreshLocalVideoQuestions(question.communityId, question.memberUid)
                    false
                },
            )
        } finally {
            syncingVideoQuestionRequestIds.remove(requestId)
        }
    }

    private fun refreshLocalVideoQuestions(communityId: String, memberUid: String) {
        mutableState.update {
            it.copy(
                videoQuestions = questionStore.questions(communityId, memberUid),
                hasPendingVideoQuestionSync = questionStore
                    .pendingQuestions(communityId, memberUid)
                    .isNotEmpty(),
            )
        }
    }

    private fun mergeVideoQuestions(
        local: List<VideoQuestion>,
        remote: List<VideoQuestion>,
    ): List<VideoQuestion> {
        val remoteIdentities = remote.map(::questionIdentity).toSet()
        return (remote + local.filter { questionIdentity(it) !in remoteIdentities })
            .sortedByDescending { parseQuestionCreatedAtMillis(it.createdAt) }
    }

    private fun questionIdentity(question: VideoQuestion): String =
        question.clientRequestId.ifBlank { question.id }

    private fun questionVideo(question: VideoQuestion) = DistributedVideo(
        id = question.videoId,
        communityId = question.communityId,
        videoTitle = question.videoTitle,
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
        private val questionStore: VideoQuestionStoreProtocol,
        private val repeatSettingRepository: VideoRepeatSettingRepository,
        private val guestUserIdProvider: GuestUserIdProvider,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
            return DistributedVideoFeatureModel(
                repository = repository,
                session = session,
                canViewMembersOnlyVideo = canViewMembersOnlyVideo,
                memoStore = memoStore,
                questionStore = questionStore,
                repeatSettingRepository = repeatSettingRepository,
                guestUserIdProvider = guestUserIdProvider,
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
