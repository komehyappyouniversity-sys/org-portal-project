package jp.komehyappyo.member.next.feature.tools

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.Calculate
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import jp.komehyappyo.member.next.core.designsystem.FeatureCard

private enum class ToolsDestination {
    Schedule,
    Diary,
    Denomination,
    MeetingMinutes,
}

@Composable
fun ToolsHubRoot(
    scheduleModel: ScheduleFeatureModel,
    diaryModel: DiaryFeatureModel,
    cashDistributionModel: CashDistributionFeatureModel,
    meetingMinutesModel: MeetingMinutesFeatureModel,
) {
    var destination by remember { mutableStateOf<ToolsDestination?>(null) }
    when (destination) {
        ToolsDestination.Schedule -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            ScheduleRoot(scheduleModel)
        }
        ToolsDestination.Diary -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            DiaryRoot(diaryModel)
        }
        ToolsDestination.Denomination -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            DenominationToolRoot(cashDistributionModel)
        }
        ToolsDestination.MeetingMinutes -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            MeetingMinutesRoot(meetingMinutesModel)
        }
        null -> Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("便利", style = MaterialTheme.typography.headlineSmall)
            Button(onClick = { destination = ToolsDestination.Schedule }) {
                FeatureCard(
                    title = "予定",
                    description = "予定の登録・編集・確認ができます。",
                    icon = Icons.Outlined.CalendarToday,
                )
            }
            Button(onClick = { destination = ToolsDestination.Diary }) {
                FeatureCard(
                    title = "日記・写真日記",
                    description = "できごとや写真を自分専用に残します。",
                    icon = Icons.AutoMirrored.Outlined.MenuBook,
                )
            }
            Button(onClick = { destination = ToolsDestination.Denomination }) {
                FeatureCard(
                    title = "金種計算",
                    description = "配布額から必要な金種を計算し、現金の集計もできます。",
                    icon = Icons.Outlined.Calculate,
                )
            }
            Button(onClick = { destination = ToolsDestination.MeetingMinutes }) {
                FeatureCard(
                    title = "会議録音・議事録",
                    description = "録音と文字起こしを端末内に保存します。",
                    icon = Icons.Outlined.Mic,
                )
            }
        }
    }
}

@Composable
private fun ToolDestinationContainer(
    onBack: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.fillMaxSize()) {
        TextButton(onClick = onBack) { Text("便利に戻る") }
        Box(modifier = Modifier.weight(1f)) { content() }
    }
}
