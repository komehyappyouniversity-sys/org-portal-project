package jp.komehyappyo.member.next.feature.community

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import android.media.MediaPlayer
import android.media.MediaPlayer.OnCompletionListener
import jp.komehyappyo.member.next.core.data.CommunityRepository
import jp.komehyappyo.member.next.core.data.VimeoConfiguration
import jp.komehyappyo.member.next.core.data.VimeoFolder
import jp.komehyappyo.member.next.core.data.UsageLogRecorder
import jp.komehyappyo.member.next.core.model.Community
import jp.komehyappyo.member.next.core.model.CommunityAdminAccess
import jp.komehyappyo.member.next.core.model.CommunityAdmin
import jp.komehyappyo.member.next.core.model.CommunityAuditLog
import jp.komehyappyo.member.next.core.model.BookingEvent
import jp.komehyappyo.member.next.core.model.BookingSlot
import jp.komehyappyo.member.next.core.model.BookingReservation
import jp.komehyappyo.member.next.core.model.DistributedVideo
import jp.komehyappyo.member.next.core.model.VideoQuestion
import jp.komehyappyo.member.next.core.model.CommunityCodeParser
import jp.komehyappyo.member.next.core.model.CommunityMembership
import jp.komehyappyo.member.next.core.model.CommunityMembershipStatus
import jp.komehyappyo.member.next.core.model.VimeoVideoMemoSyncStatus
import jp.komehyappyo.member.next.core.model.UserStage
import jp.komehyappyo.member.next.core.model.RadioPlaybackRecord
import jp.komehyappyo.member.next.core.model.RadioProgram
import jp.komehyappyo.member.next.core.model.RadioPlaybackPolicy
import jp.komehyappyo.member.next.core.model.UsageLogEventType
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.Instant
import java.util.UUID


data class CommunityUiState(
    val code: String = "",
    val publicQuery: String = "",
    val publicCommunities: List<Community> = emptyList(),
    val candidate: Community? = null,
    val memberships: List<Pair<CommunityMembership, Community>> = emptyList(),
    val adminAccess: CommunityAdminAccess? = null,
    val pendingApplications: List<CommunityMembership> = emptyList(),
    val administrators: List<CommunityAdmin> = emptyList(),
    val communityMembers: List<CommunityMembership> = emptyList(),
    val auditLogs: List<CommunityAuditLog> = emptyList(),
    val distributedVideos: List<DistributedVideo> = emptyList(),
    val managedVideos: List<DistributedVideo> = emptyList(),
    val managedBookingEvents: List<BookingEvent> = emptyList(),
    val selectedManagedBookingEventId: String? = null,
    val managedBookingSlots: List<BookingSlot> = emptyList(),
    val managedBookingReservations: List<BookingReservation> = emptyList(),
    val vimeoLibraryVideos: List<DistributedVideo> = emptyList(),
    val vimeoFolders: List<VimeoFolder> = emptyList(),
    val vimeoConfiguration: VimeoConfiguration = VimeoConfiguration(),
    val videoQuestions: List<VideoQuestion> = emptyList(),
    val adminVideoQuestions: List<VideoQuestion> = emptyList(),
    val bookingEvents: List<BookingEvent> = emptyList(),
    val selectedBookingEventId: String? = null,
    val bookingSlots: List<BookingSlot> = emptyList(),
    val bookedSlotIds: Set<String> = emptySet(),
    val myBookingReservations: List<BookingReservation> = emptyList(),
    val myBookingSlots: Map<String, BookingSlot> = emptyMap(),
    val bookingProcessingSlotId: String? = null,
    val adminQuery: String = "",
    val editingAdministratorUserId: String? = null,
    val editingAdministratorRole: String = "admin",
    val administratorPermissionSelection: Set<String> = emptySet(),
    val reviewingUserId: String? = null,
    val isLoading: Boolean = false,
    val message: String? = null,
    val radioPrograms: List<RadioProgram> = emptyList(),
    val radioPlaybackRecords: List<RadioPlaybackRecord> = emptyList(),
    val radioPlayingProgramId: String? = null,
    val radioIsLoading: Boolean = false,
    val hasPendingVideoMemoSync: Boolean = false,
)

class CommunityFeatureModel(
    private val repository: CommunityRepository,
    val session: AppSession,
    private val memoStore: VimeoMemoStore,
    private val usageLogRecorder: UsageLogRecorder? = null,
) : ViewModel() {
    private val mutableState = MutableStateFlow(CommunityUiState())
    val state: StateFlow<CommunityUiState> = mutableState.asStateFlow()
    private var mediaPlayer: MediaPlayer? = null
    private var membershipsUserId: String? = null
    private val lastRecordedVideoPositionBucket = mutableMapOf<String, Int>()
    private val currentUserId: String
        get() = session.state.value.userId

    init {
        refreshRadioPrograms()
    }

    fun recordVideoDetailOpened(video: DistributedVideo) {
        recordUsage(UsageLogEventType.VideoDetailOpened, video.id)
    }

    fun recordVideoPlaybackStarted(video: DistributedVideo, positionSeconds: Double) {
        recordUsage(UsageLogEventType.VideoPlaybackStarted, video.id, positionSeconds)
    }

    fun recordVideoPosition(video: DistributedVideo, positionSeconds: Double) {
        if (!positionSeconds.isFinite() || positionSeconds < 30.0) return
        val bucket = (positionSeconds / 30.0).toInt()
        if (bucket <= 0 || lastRecordedVideoPositionBucket[video.id] == bucket) return
        lastRecordedVideoPositionBucket[video.id] = bucket
        recordUsage(UsageLogEventType.VideoPosition, video.id, positionSeconds)
    }

    fun recordVideoCompleted(video: DistributedVideo, positionSeconds: Double) {
        lastRecordedVideoPositionBucket.remove(video.id)
        recordUsage(UsageLogEventType.VideoCompleted, video.id, positionSeconds)
    }

    private fun recordUsage(
        eventType: UsageLogEventType,
        targetId: String,
        positionSeconds: Double = 0.0,
    ) {
        val recorder = usageLogRecorder ?: return
        val current = session.state.value
        val idToken = current.authenticationToken ?: return
        viewModelScope.launch {
            runCatching {
                recorder.record(
                    userId = current.userId,
                    idToken = idToken,
                    eventType = eventType,
                    targetId = targetId,
                    positionSeconds = positionSeconds,
                )
            }
        }
    }

    fun updateCode(value: String) {
        mutableState.value = mutableState.value.copy(code = value, message = null)
    }

    fun updatePublicQuery(value: String) {
        mutableState.value = mutableState.value.copy(publicQuery = value, message = null)
    }

    fun updateAdminQuery(value: String) {
        mutableState.value = mutableState.value.copy(adminQuery = value, message = null)
    }

    fun administratorCandidates(): List<CommunityMembership> {
        val query = state.value.adminQuery.trim()
        val activeAdminIds = state.value.administrators
            .filter { it.isActive }
            .map { it.userId }
            .toSet()
        return state.value.communityMembers
            .filter { member ->
                member.status == CommunityMembershipStatus.Approved &&
                    member.userId !in activeAdminIds &&
                    (query.isEmpty() || listOfNotNull(
                        member.userId,
                        member.applicantName,
                        member.applicantFurigana,
                        member.applicantEmail,
                    ).any { it.contains(query, ignoreCase = true) })
            }
            .sortedBy { it.applicantName ?: it.userId }
    }

    fun refreshPublicCommunities() {
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch {
            repository.publicCommunities(mutableState.value.publicQuery)
                .onSuccess {
                    mutableState.value = mutableState.value.copy(
                        publicCommunities = it,
                        isLoading = false,
                    )
                }
                .onFailure { showError(it, clearCandidate = false) }
        }
    }

    fun refreshRadioPrograms() {
        val current = session.state.value
        val communityId = current.selectedCommunityId
        val token = current.authenticationToken
        val hasApprovedMembership = membershipsUserId == current.userId &&
            communityId != null && state.value.memberships.any {
            it.second.id == communityId && it.first.status == CommunityMembershipStatus.Approved
        }
        if (communityId == null || token == null || !hasApprovedMembership) {
            stopRadioPlayback()
            mutableState.value = mutableState.value.copy(
                radioPrograms = emptyList(),
                radioPlaybackRecords = emptyList(),
                radioPlayingProgramId = null,
                radioIsLoading = false,
            )
            return
        }
        mutableState.value = mutableState.value.copy(
            radioIsLoading = true,
        )
        viewModelScope.launch {
            repository.radioPrograms(communityId, token)
                .onSuccess { programs ->
                    val stillAuthorized = session.state.value.selectedCommunityId == communityId &&
                        canAccessRadio()
                    if (!stillAuthorized) return@onSuccess
                    if (state.value.radioPlayingProgramId != null && programs.none {
                            it.id == state.value.radioPlayingProgramId
                        }
                    ) {
                        stopRadioPlayback()
                    }
                    mutableState.value = mutableState.value.copy(
                        radioPrograms = programs,
                        radioIsLoading = false,
                    )
                }
                .onFailure {
                    if (session.state.value.selectedCommunityId != communityId || !canAccessRadio()) {
                        return@onFailure
                    }
                    mutableState.value = mutableState.value.copy(
                        radioPrograms = emptyList(),
                        radioIsLoading = false,
                    )
                    showError(it, clearCandidate = false)
                }
        }
    }

    fun canAccessRadio(): Boolean {
        val communityId = session.state.value.selectedCommunityId ?: return false
        if (session.state.value.authenticationToken == null) return false
        if (membershipsUserId != session.state.value.userId) return false
        return state.value.memberships.any {
            it.second.id == communityId && it.first.status == CommunityMembershipStatus.Approved
        }
    }

    fun videoMemosFor(video: DistributedVideo): List<VimeoVideoMemo> {
        return memoStore.entries(video.communityId, video.id)
    }

    fun addVideoMemo(video: DistributedVideo, memo: String, playbackSeconds: Double) {
        val normalized = memo.trim()
        if (normalized.isEmpty()) {
            mutableState.value = mutableState.value.copy(message = "メモを入力してください。")
            return
        }
        val now = System.currentTimeMillis()
        persistVideoMemos(
            video,
            videoMemosFor(video) + VimeoVideoMemo(
                id = UUID.randomUUID().toString(),
                text = normalized,
                playbackSeconds = playbackSeconds,
                createdAtMillis = now,
                updatedAtMillis = now,
                syncStatus = VimeoVideoMemoSyncStatus.Synced,
            ),
            "動画メモを追加しました。",
        )
    }

    fun updateVideoMemo(video: DistributedVideo, entry: VimeoVideoMemo, text: String) {
        val normalized = text.trim()
        if (normalized.isEmpty()) {
            mutableState.value = mutableState.value.copy(message = "メモを入力してください。")
            return
        }
        persistVideoMemos(
            video,
            videoMemosFor(video).map { item ->
                if (item.id == entry.id) {
                    item.copy(
                        text = normalized,
                        updatedAtMillis = System.currentTimeMillis(),
                        syncStatus = if (item.syncStatus == VimeoVideoMemoSyncStatus.PendingSync) {
                            VimeoVideoMemoSyncStatus.PendingSync
                        } else {
                            VimeoVideoMemoSyncStatus.Synced
                        },
                    )
                } else {
                    item
                }
            },
            "動画メモを更新しました。",
        )
    }

    fun deleteVideoMemo(video: DistributedVideo, entry: VimeoVideoMemo) {
        persistVideoMemos(
            video,
            videoMemosFor(video).filterNot { it.id == entry.id },
            "動画メモを削除しました。",
        )
    }

    private fun persistVideoMemos(
        video: DistributedVideo,
        entries: List<VimeoVideoMemo>,
        successMessage: String,
    ) {
        val current = session.state.value
        val token = current.authenticationToken
        memoStore.save(video.communityId, video.id, entries)
        if (token == null) {
            mutableState.value = mutableState.value.copy(
                message = successMessage,
                hasPendingVideoMemoSync = memoStore.pendingEntries().isNotEmpty(),
            )
            return
        }
        viewModelScope.launch {
            syncVideoMemos(
                video,
                entries,
                current.userId,
                token,
                successMessage,
                reportSuccess = true,
            )
        }
    }

    fun questionsFor(video: DistributedVideo): List<VideoQuestion> =
        state.value.videoQuestions.filter { it.videoId == video.id }

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
                video.communityId,
                video.id,
                entries.map { it.copy(syncStatus = VimeoVideoMemoSyncStatus.Synced) },
            )
            if (reportSuccess) {
                mutableState.value = mutableState.value.copy(
                    message = successMessage,
                    hasPendingVideoMemoSync = false,
                )
            }
        }.onFailure {
            memoStore.save(
                video.communityId,
                video.id,
                entries.map { it.copy(syncStatus = VimeoVideoMemoSyncStatus.PendingSync) },
            )
            if (reportSuccess) {
                mutableState.value = mutableState.value.copy(
                    message = "オフライン時は動画メモを保留しました。",
                )
            }
        }
        updatePendingVideoMemoSyncState()
    }

    private fun synchronizePendingVideoMemos(userId: String, token: String) {
        val pending = memoStore.pendingEntries()
        if (pending.isEmpty()) {
            updatePendingVideoMemoSyncState()
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
                    memoVideo(components[0], components[1]),
                    allEntries[key] ?: entries,
                    userId,
                    token,
                    successMessage = "",
                    reportSuccess = false,
                )
            }
        }
    }

    private fun memoVideo(communityId: String, videoId: String): DistributedVideo =
        DistributedVideo(
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
                val mergedEntries = buildList {
                    remoteEntries.forEach { remoteEntry ->
                        val localEntry = localById[remoteEntry.id]
                        if (localEntry?.syncStatus == VimeoVideoMemoSyncStatus.PendingSync) {
                            add(localEntry)
                        } else {
                            add(remoteEntry)
                        }
                    }
                    localEntries
                        .filter { it.syncStatus == VimeoVideoMemoSyncStatus.PendingSync && it.id !in remoteIds }
                        .forEach(::add)
                }
                merged[key] = mergedEntries
            }
        }
    }

    private fun updatePendingVideoMemoSyncState() {
        mutableState.value = mutableState.value.copy(
            hasPendingVideoMemoSync = memoStore.pendingEntries().isNotEmpty(),
        )
    }

    fun submitVideoQuestion(
        video: DistributedVideo,
        memo: String,
        question: String,
        playbackSeconds: Double,
    ) {
        val current = session.state.value
        val token = current.authenticationToken ?: return
        viewModelScope.launch {
            repository.saveVideoQuestion(
                current.selectedCommunityId ?: video.communityId,
                current.userId,
                video,
                memo,
                question,
                playbackSeconds,
                java.util.UUID.randomUUID().toString(),
                token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(message = "質問を送信しました。")
                refreshVideos()
            }.onFailure { showError(it, clearCandidate = false) }
        }
    }

    fun answerVideoQuestion(questionId: String, answerText: String) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        if (state.value.adminAccess?.canReviewMembers != true) return
        viewModelScope.launch {
            repository.answerVideoQuestion(
                communityId = communityId,
                questionId = questionId,
                answerText = answerText.trim(),
                idToken = token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(message = "回答を保存しました。")
                refreshManagement()
            }.onFailure { showError(it, clearCandidate = false) }
        }
    }

    fun isRadioPlayable(program: RadioProgram): Boolean =
        RadioPlaybackPolicy.isPlayable(program, Instant.now())

    fun playbackRecord(forProgramId: String): RadioPlaybackRecord? =
        state.value.radioPlaybackRecords.firstOrNull {
            it.userId == currentUserId && it.programId == forProgramId
        }

    fun toggleRadioPlayback(program: RadioProgram) {
        if (!isRadioPlayable(program)) {
            mutableState.value = mutableState.value.copy(
                message = "この番組は配信開始前です。"
            )
            return
        }

        if (state.value.radioPlayingProgramId == program.id) {
            stopRadioPlayback()
            return
        }

        stopRadioPlayback()
        mutableState.value = mutableState.value.copy(
            radioPlayingProgramId = program.id,
            message = null,
        )

        val player = MediaPlayer()
        mediaPlayer = player
        viewModelScope.launch {
            try {
                player.setDataSource(program.audioUrl)
                player.setOnCompletionListener(OnCompletionListener {
                    mutableState.value = mutableState.value.copy(radioPlayingProgramId = null)
                })
                player.prepare()
                player.start()
                recordRadioPlayback(program.id)
                recordUsage(UsageLogEventType.RadioPlayed, program.id)
            } catch (_: Throwable) {
                stopRadioPlayback()
                mutableState.value = mutableState.value.copy(
                    message = "再生できませんでした。ネットワーク接続と音声URLをご確認ください。"
                )
            }
        }
    }

    private fun stopRadioPlayback() {
        mediaPlayer?.setOnCompletionListener(null)
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        mutableState.value = mutableState.value.copy(radioPlayingProgramId = null)
    }

    private fun recordRadioPlayback(programId: String) {
        val now = Instant.now()
        val records = state.value.radioPlaybackRecords.toMutableList()
        val index = records.indexOfFirst {
            it.userId == currentUserId && it.programId == programId
        }
        if (index >= 0) {
            val old = records[index]
            records[index] = old.copy(
                playCount = old.playCount + 1,
                lastPlayedAt = now,
            )
        } else {
            records.add(
                RadioPlaybackRecord(
                    userId = currentUserId,
                    programId = programId,
                    playCount = 1,
                    lastPlayedAt = now,
                ),
            )
        }
        mutableState.value = mutableState.value.copy(radioPlaybackRecords = records)
    }

    fun prepareApplication(community: Community) {
        if (session.state.value.authenticationToken == null) {
            mutableState.value = mutableState.value.copy(
                message = "参加申請には、マイページから会員登録またはログインが必要です。",
            )
            return
        }
        mutableState.value = mutableState.value.copy(
            code = community.code,
            candidate = community,
            message = if (community.joinEnabled) {
                "参加先を確認し、下の「参加申請」を押してください。"
            } else {
                "このコミュニティは現在、参加申請を受け付けていません。"
            },
        )
    }

    fun applyTo(community: Community) {
        if (session.state.value.authenticationToken == null) {
            mutableState.value = mutableState.value.copy(
                message = "参加申請には、マイページから会員登録またはログインが必要です。",
            )
            return
        }
        if (!community.joinEnabled) {
            mutableState.value = mutableState.value.copy(
                message = "このコミュニティは現在、参加申請を受け付けていません。",
            )
            return
        }
        if (state.value.memberships.any { it.second.id == community.id }) {
            mutableState.value = mutableState.value.copy(
                message = "このコミュニティには既に参加申請済みです。状態を確認してください。",
            )
            return
        }
        mutableState.value = mutableState.value.copy(
            code = community.code,
            candidate = community,
        )
        apply()
    }

    fun receiveScan(value: String) {
        updateCode(CommunityCodeParser.parse(value) ?: value)
        search()
    }

    fun search() {
        val token = session.state.value.authenticationToken
        if (token == null) {
            mutableState.value = mutableState.value.copy(
                message = "先にマイページからログインしてください。",
            )
            return
        }
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch {
            repository.findCommunity(mutableState.value.code, token)
                .onSuccess {
                    mutableState.value = mutableState.value.copy(
                        candidate = it,
                        isLoading = false,
                    )
                }
                .onFailure { showError(it) }
        }
    }

    fun apply() {
        val community = mutableState.value.candidate ?: return
        val current = session.state.value
        val token = current.authenticationToken ?: return
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch {
            repository.apply(community, current.userId, token)
                .onSuccess {
                    mutableState.value = mutableState.value.copy(
                        candidate = null,
                        message = "参加申請を送信しました。承認されるまでお待ちください。",
                    )
                    refresh()
                }
                .onFailure { showError(it) }
        }
    }

    fun refresh() {
        val current = session.state.value
        val token = current.authenticationToken ?: run {
            membershipsUserId = null
            mutableState.value = mutableState.value.copy(
                candidate = null,
                memberships = emptyList(),
                adminAccess = null,
                pendingApplications = emptyList(),
                administrators = emptyList(),
                communityMembers = emptyList(),
                distributedVideos = emptyList(),
                bookingEvents = emptyList(),
                selectedBookingEventId = null,
                bookingSlots = emptyList(),
                bookedSlotIds = emptySet(),
                myBookingReservations = emptyList(),
                myBookingSlots = emptyMap(),
                bookingProcessingSlotId = null,
                reviewingUserId = null,
                hasPendingVideoMemoSync = false,
                isLoading = false,
            )
            return
        }
        if (membershipsUserId != current.userId) {
            membershipsUserId = null
            mutableState.value = mutableState.value.copy(memberships = emptyList())
            refreshRadioPrograms()
        }
        mutableState.value = mutableState.value.copy(isLoading = true)
        viewModelScope.launch {
            repository.memberships(current.userId, token)
                .onSuccess { items ->
                    membershipsUserId = current.userId
                    mutableState.value = mutableState.value.copy(
                        memberships = items,
                        isLoading = false,
                    )
                    val approved = items.filter {
                        it.first.status == CommunityMembershipStatus.Approved
                    }
                    if (session.state.value.selectedCommunityId == null) {
                        approved.firstOrNull()?.let { session.selectCommunity(it.second.id) }
                    }
                    session.updateStage(
                        if (approved.isEmpty()) UserStage.Guest else UserStage.Member,
                        current.userId,
                    )
                    refreshManagement()
                    refreshVideos()
                    refreshBookingEvents()
                    refreshRadioPrograms()
                }
                .onFailure { showError(it) }
        }
    }

    fun selectCommunity(communityId: String) {
        session.selectCommunity(communityId)
        refreshManagement()
        refreshVideos()
        refreshBookingEvents()
        refreshRadioPrograms()
    }

    fun refreshBookingStatus() {
        refreshBookingEvents()
        mutableState.value.selectedManagedBookingEventId?.let(::selectManagedBookingEvent)
    }

    private fun refreshBookingEvents() {
        val current = session.state.value
        val communityId = current.selectedCommunityId
        val token = current.authenticationToken
        if (communityId == null || token == null) {
            mutableState.value = mutableState.value.copy(
                bookingEvents = emptyList(),
                selectedBookingEventId = null,
                bookingSlots = emptyList(),
                bookedSlotIds = emptySet(),
                myBookingReservations = emptyList(),
                myBookingSlots = emptyMap(),
                bookingProcessingSlotId = null,
            )
            return
        }
        viewModelScope.launch {
            repository.bookingEvents(communityId, token)
                .onSuccess { events ->
                    val selectedEventId = mutableState.value.selectedBookingEventId
                        ?.takeIf { id -> events.any { it.id == id } }
                    val reservations = repository.myBookingReservations(
                        communityId,
                        current.userId,
                        token,
                    ).getOrDefault(emptyList())
                    val slots = reservations
                        .map { it.eventId }
                        .distinct()
                        .flatMap { eventId ->
                            repository.bookingSlots(communityId, eventId, token)
                                .getOrDefault(emptyList())
                        }
                        .associateBy { "${it.eventId}:${it.id}" }
                    mutableState.value = mutableState.value.copy(
                        bookingEvents = events,
                        selectedBookingEventId = selectedEventId,
                        bookingSlots = if (selectedEventId == null) emptyList() else mutableState.value.bookingSlots,
                        bookedSlotIds = if (selectedEventId == null) emptySet() else mutableState.value.bookedSlotIds,
                        myBookingReservations = reservations,
                        myBookingSlots = slots,
                    )
                    selectedEventId?.let(::refreshBookingDetails)
                }
                .onFailure { showError(it, clearCandidate = false) }
        }
    }

    fun selectBookingEvent(eventId: String) {
        mutableState.value = mutableState.value.copy(
            selectedBookingEventId = eventId,
            bookingSlots = emptyList(),
            bookedSlotIds = emptySet(),
            message = null,
        )
        refreshBookingDetails(eventId)
    }

    fun reserveBooking(event: BookingEvent, slot: BookingSlot) {
        updateBooking(event, slot, reserve = true)
    }

    fun cancelBooking(event: BookingEvent, slot: BookingSlot) {
        updateBooking(event, slot, reserve = false)
    }

    private fun refreshBookingDetails(eventId: String) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        viewModelScope.launch {
            val slots = repository.bookingSlots(communityId, eventId, token).getOrDefault(emptyList())
            val booked = repository.bookedSlotIds(
                communityId,
                eventId,
                current.userId,
                token,
            ).getOrDefault(emptySet())
            if (mutableState.value.selectedBookingEventId == eventId) {
                mutableState.value = mutableState.value.copy(
                    bookingSlots = slots,
                    bookedSlotIds = booked,
                )
            }
        }
    }

    private fun updateBooking(event: BookingEvent, slot: BookingSlot, reserve: Boolean) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        mutableState.value = mutableState.value.copy(
            bookingProcessingSlotId = slot.id,
            message = null,
        )
        viewModelScope.launch {
            val result = if (reserve) {
                repository.reserveBookingSlot(communityId, event.id, slot.id, token)
            } else {
                repository.cancelBookingSlot(communityId, event.id, slot.id, token)
            }
            result.onSuccess {
                mutableState.value = mutableState.value.copy(
                    message = if (reserve) "イベントを予約しました。" else "イベント予約をキャンセルしました。",
                )
                refreshBookingDetails(event.id)
            }.onFailure { showError(it, clearCandidate = false) }
            mutableState.value = mutableState.value.copy(bookingProcessingSlotId = null)
        }
    }

    private fun refreshVideos() {
        val current = session.state.value
        val communityId = current.selectedCommunityId
        val token = current.authenticationToken
        if (communityId == null || token == null) {
            mutableState.value = mutableState.value.copy(
                distributedVideos = emptyList(),
                videoQuestions = emptyList(),
                hasPendingVideoMemoSync = false,
            )
            return
        }
        viewModelScope.launch {
            repository.communityVideos(communityId, token)
                .onSuccess { videos ->
                    val questions = repository.videoQuestions(communityId, current.userId, token)
                        .getOrDefault(emptyList())
                    val remoteMemos = runCatching {
                        repository.videoMemos(current.userId, token).getOrThrow()
                    }.getOrNull()
                    if (remoteMemos != null) {
                        memoStore.saveAll(
                            mergeMemoEntries(
                                local = memoStore.allEntries(),
                                remote = remoteMemos,
                            ).mapValues { (_, value) ->
                                memoStore.serialized(value)
                            },
                        )
                    }
                    synchronizePendingVideoMemos(current.userId, token)
                    mutableState.value = mutableState.value.copy(
                        distributedVideos = videos,
                        videoQuestions = questions,
                    )
                    updatePendingVideoMemoSyncState()
                }
                .onFailure {
                    showError(it, clearCandidate = false)
                    updatePendingVideoMemoSyncState()
                    }
        }
    }

    fun review(
        application: CommunityMembership,
        status: CommunityMembershipStatus,
        auditAction: String? = null,
        successMessage: String? = null,
    ) {
        if (status == CommunityMembershipStatus.Pending) return
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        mutableState.value = mutableState.value.copy(
            reviewingUserId = application.userId,
            message = null,
        )
        viewModelScope.launch {
            repository.reviewApplication(
                communityId = communityId,
                applicantUserId = application.userId,
                reviewerUserId = current.userId,
                status = status,
                auditAction = auditAction,
                idToken = token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(
                    message = successMessage ?: if (status == CommunityMembershipStatus.Approved) {
                        "参加申請を承認しました。"
                    } else {
                        "参加申請を却下しました。"
                    },
                )
                refreshManagement()
            }.onFailure(::showError)
            mutableState.value = mutableState.value.copy(reviewingUserId = null)
        }
    }

    private fun refreshManagement() {
        val current = session.state.value
        val communityId = current.selectedCommunityId
        val token = current.authenticationToken
        if (communityId == null || token == null) {
            mutableState.value = mutableState.value.copy(
                adminAccess = null,
                adminVideoQuestions = emptyList(),
                pendingApplications = emptyList(),
                auditLogs = emptyList(),
                managedVideos = emptyList(),
                managedBookingEvents = emptyList(),
                selectedManagedBookingEventId = null,
                managedBookingSlots = emptyList(),
                managedBookingReservations = emptyList(),
                vimeoLibraryVideos = emptyList(),
                vimeoConfiguration = VimeoConfiguration(),
            )
            return
        }
        viewModelScope.launch {
            repository.adminAccess(communityId, current.userId, token)
                .onSuccess { access ->
                    mutableState.value = mutableState.value.copy(adminAccess = access)
                    if (access?.canReviewMembers == true) {
                        repository.pendingApplications(communityId, token).onSuccess { applications ->
                            mutableState.value = mutableState.value.copy(pendingApplications = applications)
                        }.onFailure(::showError)
                        repository.administrators(communityId, token).onSuccess { administrators ->
                            mutableState.value = mutableState.value.copy(administrators = administrators)
                        }.onFailure(::showError)
                        repository.communityMembers(communityId, token).onSuccess { members ->
                            mutableState.value = mutableState.value.copy(communityMembers = members)
                        }.onFailure(::showError)
                        repository.adminCommunityVideos(communityId, token).onSuccess { videos ->
                            mutableState.value = mutableState.value.copy(managedVideos = videos)
                        }.onFailure(::showError)
                        repository.adminBookingEvents(communityId, token).onSuccess { events ->
                            mutableState.value = mutableState.value.copy(managedBookingEvents = events)
                        }.onFailure(::showError)
                        repository.adminVideoQuestions(communityId, token).onSuccess { questions ->
                            mutableState.value = mutableState.value.copy(adminVideoQuestions = questions)
                        }.onFailure(::showError)
                        repository.auditLogs(communityId, token).onSuccess { logs ->
                            mutableState.value = mutableState.value.copy(auditLogs = logs)
                        }.onFailure(::showError)
                        mutableState.value = mutableState.value.copy(vimeoLibraryVideos = emptyList())
                        repository.vimeoConfiguration(communityId, token).onSuccess { configuration ->
                            mutableState.value = mutableState.value.copy(vimeoConfiguration = configuration)
                        }.onFailure(::showError)
                    } else {
                        mutableState.value = mutableState.value.copy(
                            pendingApplications = emptyList(),
                            administrators = emptyList(),
                            communityMembers = emptyList(),
                            auditLogs = emptyList(),
                            managedVideos = emptyList(),
                            managedBookingEvents = emptyList(),
                            selectedManagedBookingEventId = null,
                            managedBookingSlots = emptyList(),
                            managedBookingReservations = emptyList(),
                            vimeoLibraryVideos = emptyList(),
                            vimeoConfiguration = VimeoConfiguration(),
                            adminVideoQuestions = emptyList(),
                        )
                    }
                }
                .onFailure(::showError)
        }
    }

    fun saveVimeoConfiguration(accessToken: String, userId: String, query: String) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        viewModelScope.launch {
            repository.saveVimeoConfiguration(communityId, accessToken, userId, query, token)
                .onSuccess {
                    mutableState.value = mutableState.value.copy(message = "Vimeo接続設定を保存しました。")
                    refreshManagement()
                }
                .onFailure(::showError)
        }
    }

    fun refreshVimeoLibrary() {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        if (state.value.adminAccess?.canReviewMembers != true) return
        viewModelScope.launch {
            repository.vimeoLibraryVideos(communityId, token).onSuccess { videos ->
                mutableState.value = mutableState.value.copy(
                    vimeoLibraryVideos = videos,
                    message = "Vimeoから${videos.size}件の動画を取得しました。",
                )
            }.onFailure(::showError)
        }
    }

    fun clearVimeoLibrary() {
        mutableState.value = mutableState.value.copy(vimeoLibraryVideos = emptyList())
    }

    fun saveBookingEvent(
        eventId: String,
        title: String,
        description: String,
        eventDate: String?,
        feeAmount: Int,
        paymentRequired: Boolean,
        zoomUrl: String,
        isPublished: Boolean,
    ) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        if (state.value.adminAccess?.canReviewMembers != true) return
        viewModelScope.launch {
            repository.saveBookingEvent(
                communityId,
                eventId,
                title,
                description,
                eventDate,
                feeAmount,
                paymentRequired,
                zoomUrl,
                isPublished,
                token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(message = "イベントを保存しました。")
                refreshManagement()
                refreshBookingEvents()
            }.onFailure(::showError)
        }
    }

    fun saveBookingSlot(
        eventId: String,
        slotId: String,
        startAt: String?,
        endAt: String?,
        capacity: Int,
        isOpen: Boolean,
    ) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        if (state.value.adminAccess?.canReviewMembers != true) return
        viewModelScope.launch {
            repository.saveBookingSlot(
                communityId,
                eventId,
                slotId,
                startAt,
                endAt,
                capacity,
                isOpen,
                token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(message = "予約枠を保存しました。")
                refreshBookingDetails(eventId)
            }.onFailure(::showError)
        }
    }

    fun selectManagedBookingEvent(eventId: String) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        if (state.value.adminAccess?.canReviewMembers != true) return
        mutableState.value = mutableState.value.copy(
            selectedManagedBookingEventId = eventId,
            managedBookingSlots = emptyList(),
            managedBookingReservations = emptyList(),
        )
        viewModelScope.launch {
            val slots = repository.bookingSlots(communityId, eventId, token).getOrDefault(emptyList())
            val reservations = repository.bookingReservations(communityId, eventId, token)
                .getOrDefault(emptyList())
            if (mutableState.value.selectedManagedBookingEventId == eventId) {
                mutableState.value = mutableState.value.copy(
                    managedBookingSlots = slots,
                    managedBookingReservations = reservations,
                )
            }
        }
    }

    fun saveCommunityVideos(videos: List<DistributedVideo>, isPublished: Boolean) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        if (videos.isEmpty()) return
        viewModelScope.launch {
            try {
                videos.forEach { video ->
                    repository.saveCommunityVideo(
                        communityId = communityId,
                        videoId = video.vimeoVideoId,
                        title = video.title,
                        description = video.description,
                        vimeoVideoId = video.vimeoVideoId,
                        vimeoUrl = video.videoUrl.orEmpty(),
                        thumbnailUrl = video.thumbnailUrl.orEmpty(),
                        isPublished = isPublished,
                        idToken = token,
                    ).getOrThrow()
                }
                mutableState.value = mutableState.value.copy(
                    message = "${videos.size}件の動画を${if (isPublished) "公開" else "下書き保存"}しました。",
                )
                refreshManagement()
            } catch (error: Throwable) {
                showError(error)
            }
        }
    }

    fun refreshVimeoFolders() {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        if (state.value.adminAccess?.canReviewMembers != true) return
        viewModelScope.launch {
            repository.vimeoFolders(communityId, token).onSuccess { folders ->
                mutableState.value = mutableState.value.copy(
                    vimeoFolders = folders,
                    message = "Vimeoから${folders.size}件のフォルダを取得しました。",
                )
            }.onFailure(::showError)
        }
    }

    fun refreshVimeoFolderVideos(folder: VimeoFolder) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        if (state.value.adminAccess?.canReviewMembers != true) return
        viewModelScope.launch {
            repository.vimeoLibraryVideos(communityId, token, folder.id).onSuccess { videos ->
                mutableState.value = mutableState.value.copy(
                    vimeoLibraryVideos = videos,
                    message = "「${folder.name}」から${videos.size}件の動画を取得しました。",
                )
            }.onFailure(::showError)
        }
    }

    fun saveCommunityVideo(
        videoId: String,
        title: String,
        description: String,
        vimeoVideoId: String,
        vimeoUrl: String,
        thumbnailUrl: String,
        isPublished: Boolean,
    ) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        viewModelScope.launch {
            repository.saveCommunityVideo(
                communityId,
                videoId,
                title,
                description,
                vimeoVideoId,
                vimeoUrl,
                thumbnailUrl,
                isPublished,
                token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(message = "動画を保存しました。")
                refreshManagement()
                refreshVideos()
            }.onFailure(::showError)
        }
    }

    fun beginAdministratorAdd(adminUserId: String) {
        if (state.value.adminAccess?.role != "owner") return
        mutableState.value = mutableState.value.copy(
            editingAdministratorUserId = adminUserId,
            editingAdministratorRole = "admin",
            administratorPermissionSelection = setOf(CommunityAdminAccess.MEMBER_REVIEW_PERMISSION),
            message = null,
        )
    }

    fun beginAdministratorEdit(admin: CommunityAdmin) {
        if (state.value.adminAccess?.role != "owner") return
        mutableState.value = mutableState.value.copy(
            editingAdministratorUserId = admin.userId,
            editingAdministratorRole = admin.role,
            administratorPermissionSelection = CommunityAdminAccess.editablePermissions(admin.permissions),
            message = null,
        )
    }

    fun toggleAdministratorPermission(permissionKey: String) {
        if (CommunityAdminAccess.DELEGABLE_PERMISSIONS.none { it.key == permissionKey }) return
        val selected = state.value.administratorPermissionSelection.toMutableSet()
        if (!selected.add(permissionKey)) selected.remove(permissionKey)
        mutableState.value = mutableState.value.copy(administratorPermissionSelection = selected)
    }

    fun cancelAdministratorEdit() {
        mutableState.value = mutableState.value.copy(
            editingAdministratorUserId = null,
            editingAdministratorRole = "admin",
            administratorPermissionSelection = emptySet(),
        )
    }

    fun saveAdministrator() {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        if (state.value.adminAccess?.role != "owner") {
            mutableState.value = mutableState.value.copy(message = "管理者の追加・編集はOwnerのみが操作できます。")
            return
        }
        val adminUserId = state.value.editingAdministratorUserId ?: return
        val role = state.value.editingAdministratorRole
        val permissions = state.value.administratorPermissionSelection
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch {
            repository.saveAdministrator(
                communityId = communityId,
                adminUserId = adminUserId,
                role = role,
                permissions = permissions,
                isActive = true,
                actorUserId = current.userId,
                idToken = token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(
                    editingAdministratorUserId = null,
                    editingAdministratorRole = "admin",
                    administratorPermissionSelection = emptySet(),
                    isLoading = false,
                    message = "管理者権限を保存しました。",
                )
                refreshManagement()
            }.onFailure(::showError)
        }
    }

    fun deactivateAdministrator(admin: CommunityAdmin) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        if (admin.userId == current.userId) {
            mutableState.value = mutableState.value.copy(message = "自分自身の管理者権限はこの画面から無効化できません。")
            return
        }
        viewModelScope.launch {
            repository.saveAdministrator(
                communityId = communityId,
                adminUserId = admin.userId,
                role = admin.role,
                permissions = admin.permissions,
                isActive = false,
                actorUserId = current.userId,
                idToken = token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(message = "管理者を無効化しました。")
                refreshManagement()
            }.onFailure(::showError)
        }
    }

    fun suspendMember(member: CommunityMembership) {
        review(
            member,
            CommunityMembershipStatus.Rejected,
            auditAction = "membership.suspended",
            successMessage = "会員を利用停止しました。",
        )
    }

    override fun onCleared() {
        stopRadioPlayback()
        super.onCleared()
    }

    private fun showError(error: Throwable, clearCandidate: Boolean = true) {
        mutableState.value = mutableState.value.copy(
            candidate = if (clearCandidate) null else mutableState.value.candidate,
            isLoading = false,
            message = error.message ?: "処理に失敗しました。",
        )
    }

    class Factory(
        private val repository: CommunityRepository,
        private val session: AppSession,
        private val memoStore: VimeoMemoStore,
        private val usageLogRecorder: UsageLogRecorder? = null,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            CommunityFeatureModel(repository, session, memoStore, usageLogRecorder) as T
    }
}
