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
import jp.komehyappyo.member.next.core.data.ScheduleRepositories
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.OrgPortalTheme
import jp.komehyappyo.member.next.core.navigation.AppShell
import jp.komehyappyo.member.next.core.notifications.NotificationService
import jp.komehyappyo.member.next.feature.tools.ScheduleFeatureModel
import jp.komehyappyo.member.next.feature.tools.ScheduleRoot
import jp.komehyappyo.member.next.feature.tools.TodayScheduleView

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
        val repository = remember { ScheduleRepositories.createLocal(applicationContext) }
        val factory = remember {
            ScheduleFeatureModel.Factory(
                repository,
                NotificationService(applicationContext),
            )
        }
        val scheduleModel: ScheduleFeatureModel = viewModel(factory = factory)

        AppShell(
            home = { TodayScheduleView(scheduleModel) },
            tools = { ScheduleRoot(scheduleModel) },
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
