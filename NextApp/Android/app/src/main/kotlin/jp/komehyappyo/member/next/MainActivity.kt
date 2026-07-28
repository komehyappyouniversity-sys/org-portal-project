package jp.komehyappyo.member.next

import android.Manifest
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.fragment.app.FragmentActivity
import jp.komehyappyo.member.next.core.data.FirebaseRestAnnouncementRepository
import jp.komehyappyo.member.next.core.data.FirebaseEnvironmentGuard
import jp.komehyappyo.member.next.core.data.FirebaseRestAccountAuthRepository
import jp.komehyappyo.member.next.core.data.FirebaseRestCommunityRepository
import jp.komehyappyo.member.next.core.data.LocalDiaryPhotoStore
import jp.komehyappyo.member.next.core.data.OrgPortalDatabase
import jp.komehyappyo.member.next.core.data.RoomDiaryRepository
import jp.komehyappyo.member.next.core.data.RoomCashDistributionRepository
import jp.komehyappyo.member.next.core.data.RoomScheduleRepository
import jp.komehyappyo.member.next.core.data.LocalMeetingRecordingStore
import jp.komehyappyo.member.next.core.data.RoomMeetingMinutesRepository
import jp.komehyappyo.member.next.core.data.RoomSnsCustomLinkRepository
import jp.komehyappyo.member.next.core.data.RoomFavoriteBookmarkRepository
import jp.komehyappyo.member.next.core.designsystem.OrgPortalTheme
import jp.komehyappyo.member.next.core.navigation.AppShell
import jp.komehyappyo.member.next.core.notifications.NotificationService
import jp.komehyappyo.member.next.feature.tools.DiaryFeatureModel
import jp.komehyappyo.member.next.feature.tools.CashDistributionFeatureModel
import jp.komehyappyo.member.next.feature.tools.GuestHomeView
import jp.komehyappyo.member.next.feature.tools.ScheduleFeatureModel
import jp.komehyappyo.member.next.feature.tools.ToolsHubRoot
import jp.komehyappyo.member.next.feature.tools.MeetingMinutesFeatureModel
import jp.komehyappyo.member.next.feature.tools.MeetingRecordingService
import jp.komehyappyo.member.next.feature.tools.SnsPostingAssistantFeatureModel
import jp.komehyappyo.member.next.feature.tools.FavoriteBookmarkFeatureModel
import jp.komehyappyo.member.next.core.session.AppSession
import jp.komehyappyo.member.next.feature.account.AccountFeatureModel
import jp.komehyappyo.member.next.feature.account.AccountRoot
import jp.komehyappyo.member.next.feature.account.BiometricCredentialStore
import jp.komehyappyo.member.next.feature.community.CommunityFeatureModel
import jp.komehyappyo.member.next.feature.community.CommunityRoot
import jp.komehyappyo.member.next.feature.messages.AnnouncementFeatureModel
import jp.komehyappyo.member.next.feature.messages.AnnouncementRoot

class MainActivity : FragmentActivity() {
    private val notificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FirebaseEnvironmentGuard.requireSafeDebugProject(
            isDebug = BuildConfig.DEBUG,
            configuredProjectId = BuildConfig.FIREBASE_PROJECT_ID,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        setContent {
            OrgPortalTheme {
                NextApp()
            }
        }
    }

    @Composable
    private fun NextApp() {
        val appSession = remember { AppSession() }
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
        val communityFactory = remember {
            CommunityFeatureModel.Factory(
                FirebaseRestCommunityRepository(BuildConfig.FIREBASE_PROJECT_ID),
                appSession,
            )
        }
        val communityModel: CommunityFeatureModel = viewModel(factory = communityFactory)
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
        val database = remember { OrgPortalDatabase.create(applicationContext) }
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
        val meetingMinutesFactory = remember {
            MeetingMinutesFeatureModel.Factory(
                RoomMeetingMinutesRepository(database.meetingMinutesDao()),
                meetingRecordingStore,
                MeetingRecordingService(applicationContext),
            )
        }
        val meetingMinutesModel: MeetingMinutesFeatureModel = viewModel(
            factory = meetingMinutesFactory,
        )
        val snsPostingAssistantFactory = remember {
            SnsPostingAssistantFeatureModel.Factory(
                RoomSnsCustomLinkRepository(database.snsCustomLinkDao()),
            )
        }
        val snsPostingAssistantModel: SnsPostingAssistantFeatureModel = viewModel(
            factory = snsPostingAssistantFactory,
        )
        val favoriteBookmarkFactory = remember {
            FavoriteBookmarkFeatureModel.Factory(
                RoomFavoriteBookmarkRepository(database.favoriteBookmarkDao()),
            )
        }
        val favoriteBookmarkModel: FavoriteBookmarkFeatureModel = viewModel(
            factory = favoriteBookmarkFactory,
        )

        AppShell(
            home = {
                GuestHomeView(
                    scheduleModel,
                    diaryModel,
                    cashDistributionModel,
                    meetingMinutesModel,
                    favoriteBookmarkModel,
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
                )
            },
            connect = {
                ConnectedRoot(communityModel, announcementModel)
            },
            myPage = {
                AccountRoot(accountModel, this@MainActivity)
            },
        )
    }

    @Composable
    private fun ConnectedRoot(
        communityModel: CommunityFeatureModel,
        announcementModel: AnnouncementFeatureModel,
    ) {
        var selectedSection by rememberSaveable { mutableIntStateOf(0) }
        Column(modifier = Modifier.fillMaxSize()) {
            TabRow(selectedTabIndex = selectedSection) {
                listOf("コミュニティ", "お知らせ").forEachIndexed { index, title ->
                    Tab(
                        selected = selectedSection == index,
                        onClick = { selectedSection = index },
                        text = { Text(title) },
                    )
                }
            }
            when (selectedSection) {
                0 -> CommunityRoot(communityModel)
                else -> AnnouncementRoot(announcementModel)
            }
        }
    }
}
