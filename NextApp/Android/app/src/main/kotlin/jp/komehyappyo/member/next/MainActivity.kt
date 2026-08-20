package jp.komehyappyo.member.next

import android.Manifest
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.fragment.app.FragmentActivity
import jp.komehyappyo.member.next.core.data.FirebaseEnvironmentGuard
import jp.komehyappyo.member.next.core.data.FirebaseRestAnnouncementRepository
import jp.komehyappyo.member.next.core.data.FirebaseRestPostRepository
import jp.komehyappyo.member.next.core.data.FirebaseRestAccountAuthRepository
import jp.komehyappyo.member.next.core.data.FirebaseRestCommunityRepository
import jp.komehyappyo.member.next.core.data.FirebaseRestManualRepository
import jp.komehyappyo.member.next.core.data.AppBackupService
import jp.komehyappyo.member.next.core.data.LocalDiaryPhotoStore
import jp.komehyappyo.member.next.core.data.OrgPortalDatabase
import jp.komehyappyo.member.next.core.data.RoomDiaryRepository
import jp.komehyappyo.member.next.core.data.RoomCashDistributionRepository
import jp.komehyappyo.member.next.core.data.RoomScheduleRepository
import jp.komehyappyo.member.next.core.data.LocalMeetingRecordingStore
import jp.komehyappyo.member.next.core.data.RoomMeetingMinutesRepository
import jp.komehyappyo.member.next.core.data.RoomSnsCustomLinkRepository
import jp.komehyappyo.member.next.core.data.RoomFavoriteBookmarkRepository
import jp.komehyappyo.member.next.core.data.RoomFriendExchangeRepository
import jp.komehyappyo.member.next.core.data.RoomVideoRepeatSettingRepository
import jp.komehyappyo.member.next.core.data.AndroidKeystoreGuestUserIdProvider
import jp.komehyappyo.member.next.core.data.BudgetSettlementMigrationService
import jp.komehyappyo.member.next.core.data.FirebaseRestBudgetSettlementRepository
import jp.komehyappyo.member.next.core.data.LocalBudgetReceiptStore
import jp.komehyappyo.member.next.core.data.RoomBudgetSettlementRepository
import jp.komehyappyo.member.next.core.data.DataStoreBudgetMigrationStateStore
import jp.komehyappyo.member.next.core.model.CommunityMembershipStatus
import jp.komehyappyo.member.next.core.designsystem.OrgPortalTheme
import jp.komehyappyo.member.next.core.navigation.AppShell
import jp.komehyappyo.member.next.core.navigation.AppTab
import jp.komehyappyo.member.next.core.notifications.FcmTokenRefreshBus
import jp.komehyappyo.member.next.core.notifications.FcmTokenRegistrationManager
import jp.komehyappyo.member.next.core.notifications.FirebaseRegistrationTokenProvider
import jp.komehyappyo.member.next.core.notifications.FirestoreFcmTokenStore
import jp.komehyappyo.member.next.core.notifications.NotificationNavigationDecision
import jp.komehyappyo.member.next.core.notifications.NotificationRoute
import jp.komehyappyo.member.next.core.notifications.NotificationRouteParser
import jp.komehyappyo.member.next.core.notifications.NotificationType
import jp.komehyappyo.member.next.core.notifications.NotificationService
import jp.komehyappyo.member.next.feature.tools.DiaryFeatureModel
import jp.komehyappyo.member.next.feature.tools.AppBackupFeatureModel
import jp.komehyappyo.member.next.feature.tools.CashDistributionFeatureModel
import jp.komehyappyo.member.next.feature.tools.GuestHomeView
import jp.komehyappyo.member.next.feature.tools.ScheduleFeatureModel
import jp.komehyappyo.member.next.feature.tools.DistributedVideoFeatureModel
import jp.komehyappyo.member.next.feature.tools.ToolsHubRoot
import jp.komehyappyo.member.next.feature.tools.MeetingMinutesFeatureModel
import jp.komehyappyo.member.next.feature.tools.ManualFeatureModel
import jp.komehyappyo.member.next.feature.tools.MeetingRecordingService
import jp.komehyappyo.member.next.feature.tools.SnsPostingAssistantFeatureModel
import jp.komehyappyo.member.next.feature.tools.FavoriteBookmarkFeatureModel
import jp.komehyappyo.member.next.feature.tools.FriendExchangeFeatureModel
import jp.komehyappyo.member.next.feature.tools.BudgetSettlementFeatureModel
import jp.komehyappyo.member.next.core.session.AppSession
import jp.komehyappyo.member.next.feature.account.AccountFeatureModel
import jp.komehyappyo.member.next.feature.account.AccountRoot
import jp.komehyappyo.member.next.feature.account.BiometricCredentialStore
import jp.komehyappyo.member.next.feature.community.CommunityFeatureModel
import jp.komehyappyo.member.next.feature.community.CommunityRoot
import jp.komehyappyo.member.next.feature.community.VimeoMemoStore
import jp.komehyappyo.member.next.feature.tools.VimeoMemoStore as ToolsVimeoMemoStore
import jp.komehyappyo.member.next.feature.tools.VideoQuestionDraftStore
import jp.komehyappyo.member.next.feature.messages.AnnouncementFeatureModel
import jp.komehyappyo.member.next.feature.messages.AnnouncementRoot
import jp.komehyappyo.member.next.feature.messages.MemberPostReplySection
import jp.komehyappyo.member.next.feature.messages.PostFeatureModel
import jp.komehyappyo.member.next.feature.messages.PostRoot
import kotlinx.coroutines.launch

class MainActivity : FragmentActivity() {
    private data class NavigationTarget(val route: NotificationRoute, val requestId: Long)
    private val notificationTarget = mutableStateOf<NavigationTarget?>(null)
    private var notificationSequence = 0L
    private val notificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        updateNotificationTarget(intent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        setContent {
            OrgPortalTheme {
                NextApp()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        updateNotificationTarget(intent)
    }

    private fun updateNotificationTarget(intent: Intent?) {
        val route = NotificationRouteParser.route(intent) ?: return
        notificationSequence += 1
        notificationTarget.value = NavigationTarget(route, notificationSequence)
    }

    @Composable
    private fun NextApp() {
        val appSession = remember { AppSession() }
        val target = notificationTarget.value
        var navigableTarget by remember { mutableStateOf<NavigationTarget?>(null) }
        LaunchedEffect(target?.requestId) {
            val current = target
            if (current == null) {
                navigableTarget = null
                return@LaunchedEffect
            }
            val route = current.route
            NotificationNavigationDecision.resolve(
                route,
                appSession.state.value.selectedCommunityId,
            ).communityIdToSelect?.let(appSession::selectCommunity)
            navigableTarget = current
        }
        val fcmManager = remember {
            FcmTokenRegistrationManager(
                store = FirestoreFcmTokenStore(BuildConfig.FIREBASE_PROJECT_ID),
                tokenProvider = FirebaseRegistrationTokenProvider(),
                environment = if (
                    BuildConfig.FIREBASE_PROJECT_ID == FirebaseEnvironmentGuard.PRODUCTION_PROJECT_ID
                ) "production" else "development",
            )
        }
        val tokenScope = rememberCoroutineScope()
        val refreshListener: (String) -> Unit = remember(fcmManager) {
            { token -> tokenScope.launch { runCatching { fcmManager.tokenRefreshed(token) } } }
        }
        DisposableEffect(fcmManager) {
            FcmTokenRefreshBus.add(refreshListener)
            onDispose { FcmTokenRefreshBus.remove(refreshListener) }
        }
        val accountFactory = remember {
            AccountFeatureModel.Factory(
                FirebaseRestAccountAuthRepository(
                    apiKey = BuildConfig.FIREBASE_WEB_API_KEY,
                    projectId = BuildConfig.FIREBASE_PROJECT_ID,
                ),
                BiometricCredentialStore(applicationContext),
                appSession,
            )
        }
        val accountModel: AccountFeatureModel = viewModel(factory = accountFactory)
        val communityRepository = remember {
            FirebaseRestCommunityRepository(BuildConfig.FIREBASE_PROJECT_ID)
        }
        val communityFactory = remember {
            CommunityFeatureModel.Factory(
                communityRepository,
                appSession,
                VimeoMemoStore(applicationContext),
            )
        }
        val communityModel: CommunityFeatureModel = viewModel(factory = communityFactory)
        val manualFactory = remember {
            ManualFeatureModel.Factory(
                FirebaseRestManualRepository(BuildConfig.FIREBASE_PROJECT_ID),
                appSession,
            )
        }
        val manualModel: ManualFeatureModel = viewModel(factory = manualFactory)
        val database = remember { OrgPortalDatabase.create(applicationContext) }
        val distributedVideoFactory = remember {
            DistributedVideoFeatureModel.Factory(
                communityRepository,
                appSession,
                canViewMembersOnlyVideo = { communityId ->
                    communityModel.state.value.memberships.any {
                        it.first.status == CommunityMembershipStatus.Approved && it.second.id == communityId
                    }
                },
                memoStore = ToolsVimeoMemoStore(applicationContext),
                questionStore = VideoQuestionDraftStore(applicationContext),
                repeatSettingRepository = RoomVideoRepeatSettingRepository(
                    database.videoRepeatSettingDao(),
                ),
                guestUserIdProvider = AndroidKeystoreGuestUserIdProvider(applicationContext),
            )
        }
        val distributedVideoModel: DistributedVideoFeatureModel = viewModel(
            factory = distributedVideoFactory,
        )
        val sessionState by appSession.state.collectAsStateWithLifecycle()
        LaunchedEffect(sessionState.userId, sessionState.authenticationToken) {
            runCatching {
                fcmManager.synchronize(sessionState.userId, sessionState.authenticationToken)
            }
        }
        LaunchedEffect(
            sessionState.userId,
            sessionState.selectedCommunityId,
            sessionState.authenticationToken,
        ) {
            distributedVideoModel.load()
            manualModel.load()
        }
        val announcementFactory = remember {
            AnnouncementFeatureModel.Factory(
                FirebaseRestAnnouncementRepository(BuildConfig.FIREBASE_PROJECT_ID),
                appSession,
                memberships = {
                    communityModel.state.value.memberships.map { it.first }
                },
            )
        }
        val announcementModel: AnnouncementFeatureModel = viewModel(
            factory = announcementFactory,
        )
        val postFactory = remember {
            PostFeatureModel.Factory(
                FirebaseRestPostRepository(BuildConfig.FIREBASE_PROJECT_ID),
                appSession,
                memberships = { communityModel.state.value.memberships.map { it.first } },
            )
        }
        val postModel: PostFeatureModel = viewModel(factory = postFactory)
        val scheduleRepository = remember { RoomScheduleRepository(database.scheduleDao()) }
        val scheduleFactory = remember {
            ScheduleFeatureModel.Factory(
                scheduleRepository,
                NotificationService(applicationContext),
            )
        }
        val scheduleModel: ScheduleFeatureModel = viewModel(factory = scheduleFactory)
        val diaryRepository = remember { RoomDiaryRepository(database.diaryDao()) }
        val diaryPhotoStore = remember { LocalDiaryPhotoStore(applicationContext) }
        val diaryFactory = remember {
            DiaryFeatureModel.Factory(
                diaryRepository,
                diaryPhotoStore,
            )
        }
        val diaryModel: DiaryFeatureModel = viewModel(factory = diaryFactory)
        val cashDistributionRepository = remember {
            RoomCashDistributionRepository(database.cashDistributionDao())
        }
        val cashDistributionFactory = remember {
            CashDistributionFeatureModel.Factory(cashDistributionRepository)
        }
        val cashDistributionModel: CashDistributionFeatureModel = viewModel(
            factory = cashDistributionFactory,
        )
        val meetingRecordingStore = remember {
            LocalMeetingRecordingStore(applicationContext)
        }
        val meetingMinutesRepository = remember {
            RoomMeetingMinutesRepository(database.meetingMinutesDao())
        }
        val meetingMinutesFactory = remember {
            MeetingMinutesFeatureModel.Factory(
                meetingMinutesRepository,
                meetingRecordingStore,
                MeetingRecordingService(applicationContext),
            )
        }
        val meetingMinutesModel: MeetingMinutesFeatureModel = viewModel(
            factory = meetingMinutesFactory,
        )
        val snsCustomLinkRepository = remember {
            RoomSnsCustomLinkRepository(database.snsCustomLinkDao())
        }
        val snsPostingAssistantFactory = remember {
            SnsPostingAssistantFeatureModel.Factory(snsCustomLinkRepository)
        }
        val snsPostingAssistantModel: SnsPostingAssistantFeatureModel = viewModel(
            factory = snsPostingAssistantFactory,
        )
        val favoriteBookmarkRepository = remember {
            RoomFavoriteBookmarkRepository(database.favoriteBookmarkDao())
        }
        val favoriteBookmarkFactory = remember {
            FavoriteBookmarkFeatureModel.Factory(favoriteBookmarkRepository)
        }
        val favoriteBookmarkModel: FavoriteBookmarkFeatureModel = viewModel(
            factory = favoriteBookmarkFactory,
        )
        val friendExchangeRepository = remember {
            RoomFriendExchangeRepository(
                database.friendContactDao(),
                database.friendInteractionHistoryDao(),
            )
        }
        val friendExchangeFactory = remember {
            FriendExchangeFeatureModel.Factory(friendExchangeRepository)
        }
        val friendExchangeModel: FriendExchangeFeatureModel = viewModel(
            factory = friendExchangeFactory,
        )
        val budgetReceiptStore = remember { LocalBudgetReceiptStore(applicationContext) }
        val budgetLocalRepository = remember {
            RoomBudgetSettlementRepository(database) { budgetReceiptStore.delete(it) }
        }
        val budgetRemoteRepository = remember {
            FirebaseRestBudgetSettlementRepository(
                projectId = BuildConfig.FIREBASE_PROJECT_ID,
                storageBucket = "${BuildConfig.FIREBASE_PROJECT_ID}.firebasestorage.app",
            )
        }
        val budgetMigrationService = remember {
            BudgetSettlementMigrationService(
                budgetLocalRepository,
                budgetReceiptStore,
                budgetRemoteRepository,
                DataStoreBudgetMigrationStateStore(applicationContext),
            )
        }
        val budgetSettlementFactory = remember {
            BudgetSettlementFeatureModel.Factory(
                budgetLocalRepository,
                budgetReceiptStore,
                budgetRemoteRepository,
                budgetMigrationService,
                appSession,
            )
        }
        val budgetSettlementModel: BudgetSettlementFeatureModel = viewModel(
            factory = budgetSettlementFactory,
        )
        val appBackupFactory = remember {
            AppBackupFeatureModel.Factory(
                AppBackupService(
                    scheduleRepository = scheduleRepository,
                    diaryRepository = diaryRepository,
                    photoStore = diaryPhotoStore,
                    cashDistributionRepository = cashDistributionRepository,
                    meetingMinutesRepository = meetingMinutesRepository,
                    recordingStore = meetingRecordingStore,
                    snsCustomLinkRepository = snsCustomLinkRepository,
                    favoriteBookmarkRepository = favoriteBookmarkRepository,
                    friendExchangeRepository = friendExchangeRepository,
                ),
            )
        }
        val appBackupModel: AppBackupFeatureModel = viewModel(factory = appBackupFactory)

        AppShell(
            requestedTab = when (navigableTarget?.route?.type) {
                NotificationType.VideoQuestionAnswer -> AppTab.Tools
                NotificationType.SupportMessage -> AppTab.MyPage
                NotificationType.Announcement,
                NotificationType.AdminReply,
                NotificationType.Event -> AppTab.Connect
                null -> null
            },
            navigationRequestKey = target?.requestId ?: 0,
            home = {
                GuestHomeView(
                    scheduleModel,
                    diaryModel,
                    cashDistributionModel,
                    meetingMinutesModel,
                    favoriteBookmarkModel,
                    appBackupModel,
                    manualModel,
                )
            },
            tools = {
                ToolsHubRoot(
                    scheduleModel,
                    diaryModel,
                    cashDistributionModel,
                    meetingMinutesModel,
                    snsPostingAssistantModel,
                    favoriteBookmarkModel,
                    friendExchangeModel,
                    distributedVideoModel,
                    budgetSettlementModel,
                    manualModel,
                    notificationQuestionId = navigableTarget?.route
                        ?.takeIf { it.type == NotificationType.VideoQuestionAnswer }
                        ?.targetId,
                    navigationRequestKey = navigableTarget?.requestId ?: 0,
                )
            },
            connect = {
                ConnectedRoot(
                    communityModel,
                    postModel,
                    announcementModel,
                    navigableTarget?.route,
                    navigableTarget?.requestId ?: 0,
                )
            },
            myPage = {
                val communityState by communityModel.state.collectAsStateWithLifecycle()
                AccountRoot(
                    model = accountModel,
                    activity = this@MainActivity,
                    canEnterManagementMode = communityState.adminAccess?.canReviewMembers == true,
                    managementContent = {
                        CommunityRoot(
                            model = communityModel,
                            onRefreshManagementPosts = postModel::refreshManagementMemberPosts,
                            memberPostReplyContent = { MemberPostReplySection(postModel) },
                        )
                    },
                )
            },
        )
    }

    @Composable
    private fun ConnectedRoot(
        communityModel: CommunityFeatureModel,
        postModel: PostFeatureModel,
        announcementModel: AnnouncementFeatureModel,
        notificationRoute: NotificationRoute?,
        navigationRequestKey: Long,
    ) {
        var selectedSection by rememberSaveable { mutableIntStateOf(0) }
        LaunchedEffect(navigationRequestKey) {
            when (notificationRoute?.type) {
                NotificationType.Announcement -> {
                    selectedSection = 2
                    announcementModel.openFromNotification(notificationRoute.targetId)
                }
                NotificationType.AdminReply -> {
                    selectedSection = 1
                    postModel.openFromNotification(notificationRoute.targetId)
                }
                NotificationType.Event -> selectedSection = 0
                else -> Unit
            }
        }
        val isLandscape = LocalConfiguration.current.orientation == Configuration.ORIENTATION_LANDSCAPE
        Column(modifier = Modifier.fillMaxSize()) {
            if (!isLandscape) {
                TabRow(selectedTabIndex = selectedSection) {
                    listOf("コミュニティ", "投稿", "お知らせ").forEachIndexed { index, title ->
                        Tab(
                            selected = selectedSection == index,
                            onClick = { selectedSection = index },
                            text = { Text(title) },
                        )
                    }
                }
            }
            when (selectedSection) {
                0 -> CommunityRoot(
                    model = communityModel,
                    onRefreshManagementPosts = postModel::refreshManagementMemberPosts,
                    memberPostReplyContent = { MemberPostReplySection(postModel) },
                    notificationEventId = notificationRoute
                        ?.takeIf { it.type == NotificationType.Event }
                        ?.targetId,
                    navigationRequestKey = navigationRequestKey,
                )
                1 -> PostRoot(postModel)
                else -> AnnouncementRoot(announcementModel)
            }
        }
    }
}
