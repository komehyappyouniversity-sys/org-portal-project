package jp.komehyappyo.member.next.feature.community

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import android.media.MediaPlayer
import android.media.MediaPlayer.OnCompletionListener
import jp.komehyappyo.member.next.core.data.CommunityRepository
import jp.komehyappyo.member.next.core.data.VimeoConfiguration
import jp.komehyappyo.member.next.core.data.VimeoFolder
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
import jp.komehyappyo.member.next.core.model.UserStage
import jp.komehyappyo.member.next.core.model.RadioPlaybackRecord
import jp.komehyappyo.member.next.core.model.RadioProgram
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
    val bookingEvents: List<BookingEvent> = emptyList(),
    val selectedBookingEventId: String? = null,
    val bookingSlots: List<BookingSlot> = emptyList(),
    val bookedSlotIds: Set<String> = emptySet(),
    val myBookingReservations: List<BookingReservation> = emptyList(),
    val myBookingSlots: Map<String, BookingSlot> = emptyMap(),
    val bookingProcessingSlotId: String? = null,
    val adminQuery: String = "",
    val reviewingUserId: String? = null,
    val isLoading: Boolean = false,
    val message: String? = null,
    val radioPrograms: List<RadioProgram> = emptyList(),
    val radioPlaybackRecords: List<RadioPlaybackRecord> = emptyList(),
    val radioPlayingProgramId: String? = null,
)

class CommunityFeatureModel(
    private val repository: CommunityRepository,
    val session: AppSession,
    private val memoStore: VimeoMemoStore,
) : ViewModel() {
    private val mutableState = MutableStateFlow(CommunityUiState())
    val state: StateFlow<CommunityUiState> = mutableState.asStateFlow()
    private var mediaPlayer: MediaPlayer? = null
    private val currentUserId: String
        get() = session.state.value.userId

    init {
        refreshRadioPrograms()
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
        val communityId = session.state.value.selectedCommunityId ?: run {
            mutableState.value = mutableState.value.copy(
                radioPrograms = emptyList(),
                radioPlaybackRecords = emptyList(),
                radioPlayingProgramId = null,
            )
            return
        }
        mutableState.value = mutableState.value.copy(
            radioPrograms = seededRadioPrograms(communityId),
        )
        if (state.value.radioPlayingProgramId != null) {
            val isCurrentProgramInCommunity = mutableState.value.radioPrograms.any {
                it.id == state.value.radioPlayingProgramId
            }
            if (!isCurrentProgramInCommunity) {
                stopRadioPlayback()
            }
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
                if (item.id == entry.id) item.copy(text = normalized, updatedAtMillis = System.currentTimeMillis()) else item
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
        val token = current.authenticationToken ?: return
        val payload = memoStore.serialized(entries)
        viewModelScope.launch {
            repository.saveVideoMemo(current.userId, video.communityId, video.id, payload, token)
                .onSuccess {
                    memoStore.save(video.communityId, video.id, entries)
                    mutableState.value = mutableState.value.copy(
                        message = successMessage,
                    )
                }
                .onFailure { showError(it, clearCandidate = false) }
        }
    }

    fun questionsFor(video: DistributedVideo): List<VideoQuestion> =
        state.value.videoQuestions.filter { it.videoId == video.id }

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
                token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(message = "質問を送信しました。")
                refreshVideos()
            }.onFailure { showError(it, clearCandidate = false) }
        }
    }

    fun isRadioPlayable(program: RadioProgram): Boolean =
        Instant.now() >= program.broadcastStartAt

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

    private fun seededRadioPrograms(communityId: String): List<RadioProgram> {
        val now = Instant.now()
        return listOf(
            RadioProgram(
                id = "radio-$communityId-1",
                communityId = communityId,
                title = "コミュニティラジオ いそぎわ",
                description = "最新のお知らせと短いトピックをお届け。",
                imageUrl = "https://picsum.photos/seed/radio1/400/200",
                audioUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
                broadcastStartAt = now.minusSeconds(24 * 60 * 60),
                broadcastEndAt = now.plusSeconds(10 * 24 * 60 * 60),
            ),
            RadioProgram(
                id = "radio-$communityId-2",
                communityId = communityId,
                title = "夜のニュースラジオ",
                description = "コミュニティイベント情報を中心に配信。",
                imageUrl = "https://picsum.photos/seed/radio2/400/200",
                audioUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
                broadcastStartAt = now.plusSeconds(12 * 60 * 60),
                broadcastEndAt = now.plusSeconds(13 * 60 * 60),
            ),
            RadioProgram(
                id = "radio-$communityId-3",
                communityId = communityId,
                title = "まちニュース定期放送",
                description = "週1回の告知番組。",
                imageUrl = "https://picsum.photos/seed/radio3/400/200",
                audioUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
                broadcastStartAt = now.minusSeconds(7 * 24 * 60 * 60),
                broadcastEndAt = now.minusSeconds(6 * 24 * 60 * 60),
            ),
        )
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
                isLoading = false,
            )
            return
        }
        mutableState.value = mutableState.value.copy(isLoading = true)
        viewModelScope.launch {
            repository.memberships(current.userId, token)
                .onSuccess { items ->
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
            )
            return
        }
        viewModelScope.launch {
            repository.communityVideos(communityId, token)
                .onSuccess { videos ->
                    val questions = repository.videoQuestions(communityId, current.userId, token)
                        .getOrDefault(emptyList())
                    mutableState.value = mutableState.value.copy(
                        distributedVideos = videos,
                        videoQuestions = questions,
                    )
                    repository.videoMemos(current.userId, token).onSuccess { memos ->
                        memoStore.saveAll(memos)
                    }
                }
                .onFailure { showError(it, clearCandidate = false) }
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

    fun saveAdministrator(adminUserId: String) {
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch {
            repository.saveAdministrator(
                communityId = communityId,
                adminUserId = adminUserId,
                role = "admin",
                permissions = setOf(CommunityAdminAccess.MEMBER_REVIEW_PERMISSION),
                isActive = true,
                actorUserId = current.userId,
                idToken = token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(message = "管理者を追加しました。")
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
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            CommunityFeatureModel(repository, session, memoStore) as T
    }
}
