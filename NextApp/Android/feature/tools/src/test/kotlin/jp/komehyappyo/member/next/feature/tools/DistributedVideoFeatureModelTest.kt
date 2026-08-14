package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.data.CommunityRepository
import jp.komehyappyo.member.next.core.data.GuestUserIdProvider
import jp.komehyappyo.member.next.core.data.VimeoConfiguration
import jp.komehyappyo.member.next.core.data.VimeoFolder
import jp.komehyappyo.member.next.core.data.VideoRepeatSettingRepository
import jp.komehyappyo.member.next.core.model.*
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.json.JSONArray
import org.json.JSONObject
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@OptIn(ExperimentalCoroutinesApi::class)
class DistributedVideoFeatureModelTest {
    @Test
    fun loadsSavedFullVideoRepeatSettingWhenVideoOpens() = runTest {
        val dispatcher = UnconfinedTestDispatcher(testScheduler)
        Dispatchers.setMain(dispatcher)

        try {
            val repeatRepository = InMemoryVideoRepeatSettingRepository()
            repeatRepository.save(
                VideoRepeatSetting(
                    userId = "guest-local",
                    videoId = "video-1",
                    isEnabled = true,
                ),
            )
            val model = DistributedVideoFeatureModel(
                repository = FakeCommunityRepository(),
                session = AppSession(),
                canViewMembersOnlyVideo = { false },
                memoStore = InMemoryVimeoMemoStore(),
                repeatSettingRepository = repeatRepository,
                guestUserIdProvider = GuestUserIdProvider { "unused" },
            )

            model.loadRepeatSetting("video-1")
            advanceUntilIdle()

            assertTrue(model.isRepeatEnabled("video-1"))
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test
    fun guestCanEnableAndDisableFullVideoRepeatSetting() = runTest {
        val dispatcher = UnconfinedTestDispatcher(testScheduler)
        Dispatchers.setMain(dispatcher)

        try {
            val repeatRepository = InMemoryVideoRepeatSettingRepository()
            val model = DistributedVideoFeatureModel(
                repository = FakeCommunityRepository(),
                session = AppSession(),
                canViewMembersOnlyVideo = { false },
                memoStore = InMemoryVimeoMemoStore(),
                repeatSettingRepository = repeatRepository,
                guestUserIdProvider = GuestUserIdProvider {
                    "813af24e-55fc-4d75-a61c-a8b453532ba6"
                },
            )

            model.loadRepeatSetting("video-1")
            advanceUntilIdle()
            assertFalse(model.isRepeatEnabled("video-1"))

            model.setRepeatEnabled("video-1", true)
            advanceUntilIdle()
            assertTrue(model.isRepeatEnabled("video-1"))
            assertEquals(
                "813af24e-55fc-4d75-a61c-a8b453532ba6",
                repeatRepository.savedSetting?.userId,
            )
            assertEquals(VideoRepeatMode.Full, repeatRepository.savedSetting?.mode)
            assertEquals(null, repeatRepository.savedSetting?.repeatStartSeconds)
            assertEquals(null, repeatRepository.savedSetting?.repeatEndSeconds)

            model.setRepeatEnabled("video-1", false)
            advanceUntilIdle()
            assertFalse(model.isRepeatEnabled("video-1"))
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test
    fun filtersOutMembersOnlyVideoWhenCommunityIsNotAllowed() {
        val sourceVideos = listOf(
            distributedVideo(id = "public", title = "公開動画", sortOrder = 1),
            distributedVideo(id = "member", title = "限定動画", isMembersOnly = true, sortOrder = 0),
            distributedVideo(id = "premium", title = "有料動画", isPremium = true, sortOrder = -1),
            distributedVideo(id = "another", title = "別公開動画", isMembersOnly = false, sortOrder = 2),
        )

        val result = filterDistributedVideos(sourceVideos, canViewMembersOnlyVideo = false)

        assertEquals(listOf("public", "another"), result.map { it.id })
    }

    @Test
    fun showsMembersOnlyVideoForAllowedCommunity() {
        val sourceVideos = listOf(
            distributedVideo(id = "public", title = "公開動画", sortOrder = 2),
            distributedVideo(id = "member", title = "限定動画", isMembersOnly = true, sortOrder = 1),
            distributedVideo(id = "premium", title = "有料動画", isPremium = true, sortOrder = 0),
            distributedVideo(id = "another", title = "別公開動画", sortOrder = 3),
        )

        val result = filterDistributedVideos(sourceVideos, canViewMembersOnlyVideo = true)

        assertEquals(listOf("member", "public", "another"), result.map { it.id })
    }

    @Test
    fun selectsVideoPlaybackSourceInEmbedThenVimeoThenUrlOrder() {
        val embedVideo = distributedVideo(
            id = "a",
            title = "embed",
            sortOrder = 0,
            embedHtml = "<iframe />",
            vimeoUrl = "https://example.com/vimeo",
            videoUrl = "https://example.com/video",
        )
        val vimeoOnlyVideo = distributedVideo(
            id = "b",
            title = "vimeo",
            sortOrder = 1,
            embedHtml = "",
            vimeoUrl = "https://example.com/vimeo",
            videoUrl = "https://example.com/video",
        )
        val urlOnlyVideo = distributedVideo(
            id = "c",
            title = "url",
            sortOrder = 2,
            embedHtml = "",
            vimeoUrl = "",
            videoUrl = "https://example.com/video",
        )
        val spaceVideo = distributedVideo(
            id = "d",
            title = "space",
            sortOrder = 3,
            embedHtml = "   ",
            vimeoUrl = "\n\t",
            videoUrl = "https://example.com/video",
        )

        assertEquals(VideoPlayerSource.Html("<iframe />"), videoPlayerSource(embedVideo))
        assertEquals(VideoPlayerSource.Url("https://example.com/vimeo"), videoPlayerSource(vimeoOnlyVideo))
        assertEquals(VideoPlayerSource.Url("https://example.com/video"), videoPlayerSource(urlOnlyVideo))
        assertEquals(VideoPlayerSource.Url("https://example.com/video"), videoPlayerSource(spaceVideo))
    }

    @Test
    fun addVideoMemoFailureKeepsPendingStatusAndSyncsOnLoad() = runTest {
        val dispatcher = UnconfinedTestDispatcher(testScheduler)
        Dispatchers.setMain(dispatcher)

        try {
            val session = AppSession().apply {
                selectCommunity("org-1")
                updateAuthenticatedUser(userId = "member", idToken = "token")
            }
            val repository = FakeCommunityRepository(
                videos = listOf(distributedVideo(id = "video-1", title = "配信動画", sortOrder = 1)),
                questions = emptyList(),
                shouldFailVideoMemoSave = true,
            )
            val memoStore = InMemoryVimeoMemoStore()
            val model = DistributedVideoFeatureModel(
                repository = repository,
                session = session,
                canViewMembersOnlyVideo = { _ -> false },
                memoStore = memoStore,
            )

            model.addVideoMemo(distributedVideo(id = "video-1", title = "配信動画", sortOrder = 1), memo = "メモ", playbackSeconds = 10.0)
            advanceUntilIdle()

            val pendingEntries = model.videoMemosFor(distributedVideo(id = "video-1", title = "配信動画", sortOrder = 1))
            assertEquals(1, pendingEntries.size)
            assertEquals(VimeoVideoMemoSyncStatus.PendingSync, pendingEntries[0].syncStatus)
            assertTrue(model.state.value.hasPendingVideoMemoSync)
            assertEquals(1, repository.saveVideoMemoCallCount)

            repository.shouldFailVideoMemoSave = false
            model.load()
            advanceUntilIdle()

            val syncedEntries = memoStore.entries("org-1", "video-1")
            assertEquals(VimeoVideoMemoSyncStatus.Synced, syncedEntries[0].syncStatus)
            assertEquals(2, repository.saveVideoMemoCallCount)
            assertFalse(model.state.value.hasPendingVideoMemoSync)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test
    fun loadSyncsExistingPendingMemos() = runTest {
        val dispatcher = UnconfinedTestDispatcher(testScheduler)
        Dispatchers.setMain(dispatcher)

        try {
            val session = AppSession().apply {
                selectCommunity("org-1")
                updateAuthenticatedUser(userId = "member", idToken = "token")
            }
            val memoStore = InMemoryVimeoMemoStore().apply {
                save(
                    communityId = "org-1",
                    videoId = "video-1",
                    entries = listOf(
                        VimeoVideoMemo(
                            id = "memo-1",
                            text = "保留メモ",
                            playbackSeconds = 10.0,
                            createdAtMillis = 1,
                            updatedAtMillis = 1,
                            syncStatus = VimeoVideoMemoSyncStatus.PendingSync,
                        ),
                    ),
                )
            }
            val repository = FakeCommunityRepository(
                videos = listOf(distributedVideo(id = "video-1", title = "配信動画", sortOrder = 1)),
                questions = emptyList(),
            )
            val model = DistributedVideoFeatureModel(
                repository = repository,
                session = session,
                canViewMembersOnlyVideo = { _ -> false },
                memoStore = memoStore,
            )

            model.load()
            advanceUntilIdle()

            val syncedEntries = memoStore.entries("org-1", "video-1")
            assertEquals(VimeoVideoMemoSyncStatus.Synced, syncedEntries[0].syncStatus)
            assertFalse(model.state.value.hasPendingVideoMemoSync)
            assertEquals(1, repository.saveVideoMemoCallCount)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test
    fun questionsAreClassifiedIntoUnansweredAndAnsweredSections() = runTest {
        val dispatcher = UnconfinedTestDispatcher(testScheduler)
        Dispatchers.setMain(dispatcher)

        try {
            val session = AppSession().apply {
                selectCommunity("org-1")
                updateAuthenticatedUser(userId = "member", idToken = "token")
            }
            val repository = FakeCommunityRepository(
                questions = listOf(
                    videoQuestion(id = "waiting", answerText = " \n "),
                    videoQuestion(id = "answered", answerText = "回答"),
                ),
            )
            val model = DistributedVideoFeatureModel(
                repository = repository,
                session = session,
                canViewMembersOnlyVideo = { false },
                memoStore = InMemoryVimeoMemoStore(),
            )

            model.load()
            advanceUntilIdle()

            assertEquals(listOf("waiting"), model.unansweredQuestions().map { it.id })
            assertEquals(listOf("answered"), model.answeredQuestions().map { it.id })
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test
    fun videoQuestionFailureKeepsDraftAndRetriesWithSameClientRequestIdOnLoad() = runTest {
        val dispatcher = UnconfinedTestDispatcher(testScheduler)
        Dispatchers.setMain(dispatcher)

        try {
            val session = AppSession().apply {
                selectCommunity("org-1")
                updateAuthenticatedUser(userId = "member", idToken = "token")
            }
            val repository = FakeCommunityRepository(
                videos = listOf(distributedVideo(id = "video-1", title = "配信動画", sortOrder = 1)),
                shouldFailVideoQuestionSave = true,
            )
            val questionStore = InMemoryVideoQuestionStore()
            val model = DistributedVideoFeatureModel(
                repository = repository,
                session = session,
                canViewMembersOnlyVideo = { true },
                memoStore = InMemoryVimeoMemoStore(),
                questionStore = questionStore,
            )
            var submittedCount = 0
            val video = distributedVideo(id = "video-1", title = "配信動画", sortOrder = 1)

            model.submitVideoQuestion(
                video = video,
                memo = "メモ",
                question = "オフライン質問",
                playbackSeconds = 12.0,
                onSubmitted = { submittedCount += 1 },
            )
            advanceUntilIdle()

            assertEquals(1, submittedCount)
            assertEquals(1, model.state.value.videoQuestions.size)
            assertEquals(VideoQuestionSyncStatus.Failed, model.state.value.videoQuestions[0].syncStatus)
            assertTrue(model.state.value.hasPendingVideoQuestionSync)
            assertEquals(1, repository.saveVideoQuestionCallCount)
            val clientRequestId = model.state.value.videoQuestions[0].clientRequestId

            repository.shouldFailVideoQuestionSave = false
            model.load()
            advanceUntilIdle()

            assertEquals(2, repository.saveVideoQuestionCallCount)
            assertEquals(listOf(clientRequestId, clientRequestId), repository.savedClientRequestIds)
            assertEquals(1, model.state.value.videoQuestions.size)
            assertEquals(VideoQuestionSyncStatus.Synced, model.state.value.videoQuestions[0].syncStatus)
            assertFalse(model.state.value.hasPendingVideoQuestionSync)
        } finally {
            Dispatchers.resetMain()
        }
    }

    private fun videoQuestion(id: String, answerText: String): VideoQuestion = VideoQuestion(
        id = id,
        communityId = "org-1",
        memberUid = "member",
        videoId = "video-1",
        videoTitle = "動画",
        questionText = "質問",
        answerText = answerText,
        createdAt = "2026-08-14T10:00:00Z",
    )

    private fun distributedVideo(
        id: String,
        title: String,
        sortOrder: Int,
        embedHtml: String = "",
        vimeoUrl: String = "",
        videoUrl: String = "",
        isMembersOnly: Boolean = false,
        isPremium: Boolean = false,
    ): DistributedVideo = DistributedVideo(
        id = id,
        communityId = "org-1",
        videoTitle = title,
        description = "",
        embedHtml = embedHtml,
        videoUrl = videoUrl,
        vimeoUrl = vimeoUrl,
        providerVideoId = "",
        videoType = "distributed_vimeo",
        thumbnailUrl = "",
        isPremium = isPremium,
        createdAt = null,
        updatedAt = null,
        isPublished = true,
        isMembersOnly = isMembersOnly,
        sortOrder = sortOrder,
    )
}

private class InMemoryVideoRepeatSettingRepository : VideoRepeatSettingRepository {
    var savedSetting: VideoRepeatSetting? = null

    override suspend fun setting(videoId: String): VideoRepeatSetting? =
        savedSetting?.takeIf { it.videoId == videoId }

    override suspend fun save(setting: VideoRepeatSetting) {
        savedSetting = setting
    }
}

private class FakeCommunityRepository(
    private val videos: List<DistributedVideo> = emptyList(),
    private val questions: List<VideoQuestion> = emptyList(),
    private val memoValues: Map<String, String> = emptyMap(),
    var shouldFailVideoMemoSave: Boolean = false,
    var shouldFailVideoQuestionSave: Boolean = false,
) : CommunityRepository {
    var saveVideoMemoCallCount = 0
    var saveVideoQuestionCallCount = 0
    val savedClientRequestIds = mutableListOf<String>()

    override suspend fun publicCommunities(query: String): Result<List<Community>> = Result.success(emptyList())

    override suspend fun findCommunity(code: String, idToken: String): Result<Community> =
        Result.success(
            Community(
                id = "org-1",
                code = code,
                name = "",
                description = "",
                isActive = true,
                joinEnabled = false,
                surfingVisible = true,
            ),
        )

    override suspend fun apply(community: Community, userId: String, idToken: String): Result<Unit> =
        Result.success(Unit)

    override suspend fun memberships(userId: String, idToken: String): Result<List<Pair<CommunityMembership, Community>>> =
        Result.success(emptyList())

    override suspend fun adminAccess(
        communityId: String,
        userId: String,
        idToken: String,
    ): Result<CommunityAdminAccess?> = Result.success(null)

    override suspend fun pendingApplications(communityId: String, idToken: String): Result<List<CommunityMembership>> =
        Result.success(emptyList())

    override suspend fun reviewApplication(
        communityId: String,
        applicantUserId: String,
        reviewerUserId: String,
        status: CommunityMembershipStatus,
        auditAction: String?,
        idToken: String,
    ): Result<Unit> = Result.success(Unit)

    override suspend fun administrators(communityId: String, idToken: String): Result<List<CommunityAdmin>> =
        Result.success(emptyList())

    override suspend fun saveAdministrator(
        communityId: String,
        adminUserId: String,
        role: String,
        permissions: Set<String>,
        isActive: Boolean,
        actorUserId: String,
        idToken: String,
    ): Result<Unit> = Result.success(Unit)

    override suspend fun communityMembers(
        communityId: String,
        idToken: String,
    ): Result<List<CommunityMembership>> = Result.success(emptyList())

    override suspend fun auditLogs(communityId: String, idToken: String): Result<List<CommunityAuditLog>> =
        Result.success(emptyList())

    override suspend fun bookingEvents(communityId: String, idToken: String): Result<List<BookingEvent>> =
        Result.success(emptyList())

    override suspend fun adminBookingEvents(communityId: String, idToken: String): Result<List<BookingEvent>> =
        Result.success(emptyList())

    override suspend fun saveBookingEvent(
        communityId: String,
        eventId: String,
        title: String,
        description: String,
        eventDate: String?,
        feeAmount: Int,
        paymentRequired: Boolean,
        zoomUrl: String,
        isPublished: Boolean,
        idToken: String,
    ): Result<Unit> = Result.success(Unit)

    override suspend fun bookingSlots(
        communityId: String,
        eventId: String,
        idToken: String,
    ): Result<List<BookingSlot>> = Result.success(emptyList())

    override suspend fun bookingReservations(
        communityId: String,
        eventId: String,
        idToken: String,
    ): Result<List<BookingReservation>> = Result.success(emptyList())

    override suspend fun saveBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        startAt: String?,
        endAt: String?,
        capacity: Int,
        isOpen: Boolean,
        idToken: String,
    ): Result<Unit> = Result.success(Unit)

    override suspend fun bookedSlotIds(
        communityId: String,
        eventId: String,
        userId: String,
        idToken: String,
    ): Result<Set<String>> = Result.success(emptySet())

    override suspend fun myBookingReservations(
        communityId: String,
        userId: String,
        idToken: String,
    ): Result<List<BookingReservation>> = Result.success(emptyList())

    override suspend fun reserveBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String,
    ): Result<Unit> = Result.success(Unit)

    override suspend fun cancelBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String,
    ): Result<Unit> = Result.success(Unit)

    override suspend fun communityVideos(
        communityId: String,
        idToken: String,
    ): Result<List<DistributedVideo>> = Result.success(videos)

    override suspend fun radioPrograms(
        communityId: String,
        idToken: String,
    ): Result<List<jp.komehyappyo.member.next.core.model.RadioProgram>> = Result.success(emptyList())

    override suspend fun videoMemos(userId: String, idToken: String): Result<Map<String, String>> =
        Result.success(memoValues)

    override suspend fun saveVideoMemo(
        userId: String,
        communityId: String,
        videoId: String,
        memo: String,
        idToken: String,
    ): Result<Unit> {
        saveVideoMemoCallCount += 1
        return if (shouldFailVideoMemoSave) {
            Result.failure(RuntimeException("offline"))
        } else {
            Result.success(Unit)
        }
    }

    override suspend fun videoQuestions(
        communityId: String,
        memberUid: String,
        idToken: String,
    ): Result<List<VideoQuestion>> = Result.success(questions)

    override suspend fun adminVideoQuestions(communityId: String, idToken: String): Result<List<VideoQuestion>> =
        Result.success(emptyList())

    override suspend fun saveVideoQuestion(
        communityId: String,
        memberUid: String,
        video: DistributedVideo,
        memoText: String,
        questionText: String,
        playbackSeconds: Double,
        clientRequestId: String,
        idToken: String,
    ): Result<Unit> {
        saveVideoQuestionCallCount += 1
        savedClientRequestIds += clientRequestId
        return if (shouldFailVideoQuestionSave) {
            Result.failure(RuntimeException("offline"))
        } else {
            Result.success(Unit)
        }
    }

    override suspend fun answerVideoQuestion(
        communityId: String,
        questionId: String,
        answerText: String,
        idToken: String,
    ): Result<Unit> = Result.success(Unit)

    override suspend fun adminCommunityVideos(
        communityId: String,
        idToken: String,
    ): Result<List<DistributedVideo>> = Result.success(emptyList())

    override suspend fun vimeoLibraryVideos(
        communityId: String,
        idToken: String,
        folderId: String?,
    ): Result<List<DistributedVideo>> = Result.success(emptyList())

    override suspend fun vimeoFolders(communityId: String, idToken: String): Result<List<VimeoFolder>> =
        Result.success(emptyList())

    override suspend fun vimeoConfiguration(communityId: String, idToken: String): Result<VimeoConfiguration> =
        Result.success(VimeoConfiguration())

    override suspend fun saveVimeoConfiguration(
        communityId: String,
        accessToken: String,
        userId: String,
        query: String,
        idToken: String,
    ): Result<Unit> = Result.success(Unit)

    override suspend fun saveCommunityVideo(
        communityId: String,
        videoId: String,
        title: String,
        description: String,
        vimeoVideoId: String,
        vimeoUrl: String,
        thumbnailUrl: String,
        isPublished: Boolean,
        idToken: String,
    ): Result<Unit> = Result.success(Unit)
}

private class InMemoryVimeoMemoStore : VimeoMemoStoreProtocol {
    private val values = mutableMapOf<String, List<VimeoVideoMemo>>()

    override fun entries(communityId: String, videoId: String): List<VimeoVideoMemo> {
        return values[key(communityId, videoId)]?.sortedByDescending { it.createdAtMillis } ?: emptyList()
    }

    override fun allEntries(): Map<String, List<VimeoVideoMemo>> = values.toMap()

    override fun pendingEntries(): Map<String, List<VimeoVideoMemo>> =
        values
            .mapValues { it.value.filter { memo -> memo.syncStatus == VimeoVideoMemoSyncStatus.PendingSync } }
            .filterValues { it.isNotEmpty() }

    override fun entries(fromRaw: String): List<VimeoVideoMemo> {
        if (fromRaw.isBlank()) return emptyList()

        val payload = runCatching { JSONArray(fromRaw) }.getOrNull() ?: return emptyList()
        return buildList {
            for (index in 0 until payload.length()) {
                val item = payload.optJSONObject(index) ?: continue
                val status = item.optString("syncStatus", "")
                add(
                    VimeoVideoMemo(
                        id = item.optString("id"),
                        text = item.optString("text", ""),
                        playbackSeconds = item.optDouble("playbackSeconds", 0.0),
                        createdAtMillis = item.optLong("createdAtMillis", 0),
                        updatedAtMillis = item.optLong("updatedAtMillis", 0),
                        syncStatus = VimeoVideoMemoSyncStatus.fromValue(status.ifBlank { null }),
                    ),
                )
            }
        }
    }

    override fun serialized(entries: List<VimeoVideoMemo>): String {
        if (entries.isEmpty()) return ""

        val payload = JSONArray()
        entries.forEach { memo ->
            payload.put(
                JSONObject()
                    .put("id", memo.id)
                    .put("text", memo.text)
                    .put("playbackSeconds", memo.playbackSeconds)
                    .put("createdAtMillis", memo.createdAtMillis)
                    .put("updatedAtMillis", memo.updatedAtMillis)
                    .put("syncStatus", memo.syncStatus.rawValue()),
            )
        }

        return payload.toString()
    }

    override fun save(communityId: String, videoId: String, entries: List<VimeoVideoMemo>) {
        val key = key(communityId, videoId)
        if (entries.isEmpty()) {
            values.remove(key)
            return
        }
        values[key] = entries
    }

    override fun saveAll(memos: Map<String, String>) {
        values.clear()
        memos.forEach { (key, raw) ->
            values[key] = entries(fromRaw = raw)
        }
    }

    private fun key(communityId: String, videoId: String): String = "$communityId:$videoId"
}
