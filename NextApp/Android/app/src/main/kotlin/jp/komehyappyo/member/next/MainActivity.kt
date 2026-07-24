package jp.komehyappyo.member.next

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.lifecycle.viewmodel.compose.viewModel
import jp.komehyappyo.member.next.core.data.FirebaseEnvironmentGuard
import jp.komehyappyo.member.next.core.data.LocalDiaryPhotoStore
import jp.komehyappyo.member.next.core.data.OrgPortalDatabase
import jp.komehyappyo.member.next.core.data.RoomDiaryRepository
import jp.komehyappyo.member.next.core.data.RoomCashDistributionRepository
import jp.komehyappyo.member.next.core.data.RoomScheduleRepository
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.OrgPortalTheme
import jp.komehyappyo.member.next.core.navigation.AppShell
import jp.komehyappyo.member.next.core.notifications.NotificationService
import jp.komehyappyo.member.next.feature.tools.DiaryFeatureModel
import jp.komehyappyo.member.next.feature.tools.CashDistributionFeatureModel
import jp.komehyappyo.member.next.feature.tools.GuestHomeView
import jp.komehyappyo.member.next.feature.tools.ScheduleFeatureModel
import jp.komehyappyo.member.next.feature.tools.ToolsHubRoot

class MainActivity : ComponentActivity() {
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

        AppShell(
            home = { GuestHomeView(scheduleModel, diaryModel, cashDistributionModel) },
            tools = { ToolsHubRoot(scheduleModel, diaryModel, cashDistributionModel) },
            connect = {
                EmptyState(
                    title = "つながる",
                    message = "コミュニティ機能は後続タスクで実装します。",
                )
            },
            myPage = {
                EmptyState(
                    title = "マイページ",
                    message = "現在はGuestとして利用しています。",
                )
            },
        )
    }
}
