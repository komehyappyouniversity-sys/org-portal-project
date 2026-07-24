package jp.komehyappyo.member.next.feature.tools

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.Calculate
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.designsystem.FeatureCard
import jp.komehyappyo.member.next.core.designsystem.StatusBadge

enum class GuestHomeTool(
    val title: String,
    val description: String,
    val icon: ImageVector,
    val isAvailable: Boolean,
) {
    Schedule(
        title = "今日の予定",
        description = "今日することを確認できます。",
        icon = Icons.Outlined.CalendarToday,
        isAvailable = true,
    ),
    Diary(
        title = "日記・写真日記",
        description = "できごとや写真を自分専用に残します。",
        icon = Icons.AutoMirrored.Outlined.MenuBook,
        isAvailable = true,
    ),
    Denomination(
        title = "金種計算",
        description = "紙幣・硬貨の枚数から合計金額を計算します。",
        icon = Icons.Outlined.Calculate,
        isAvailable = false,
    ),
    MeetingMinutes(
        title = "会議録音・議事録",
        description = "録音と文字起こしを端末内に保存します。",
        icon = Icons.Outlined.Mic,
        isAvailable = false,
    ),
    ;

    companion object {
        val ordered: List<GuestHomeTool> = entries
    }
}

private enum class GuestHomeDestination {
    TodaySchedule,
    Diary,
}

@Composable
fun GuestHomeView(
    scheduleModel: ScheduleFeatureModel,
    diaryModel: DiaryFeatureModel,
) {
    var destination by rememberSaveable { mutableStateOf<GuestHomeDestination?>(null) }

    if (destination != null) {
        Column(modifier = Modifier.fillMaxSize()) {
            TextButton(onClick = { destination = null }) {
                Text("ホームに戻る")
            }
            Box(modifier = Modifier.weight(1f)) {
                when (destination) {
                    GuestHomeDestination.TodaySchedule -> TodayScheduleView(model = scheduleModel)
                    GuestHomeDestination.Diary -> DiaryRoot(model = diaryModel)
                    null -> Unit
                }
            }
        }
        return
    }

    val scheduleState by scheduleModel.state.collectAsStateWithLifecycle()
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("便利な一日を始めましょう", style = MaterialTheme.typography.headlineSmall)
                    StatusBadge("Guest")
                }
                Text(
                    "会員登録なしで、毎日の便利ツールを利用できます。",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }

        items(GuestHomeTool.ordered, key = { it.name }) { tool ->
            FeatureCard(
                title = tool.title,
                description = tool.description,
                icon = tool.icon,
                statusLabel = if (tool.isAvailable) null else "準備中",
            ) {
                when (tool) {
                    GuestHomeTool.Schedule -> {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "今日 ${scheduleState.todaySchedules.size}件",
                            style = MaterialTheme.typography.labelLarge,
                        )
                        TextButton(
                            onClick = { destination = GuestHomeDestination.TodaySchedule },
                        ) {
                            Text("確認する")
                        }
                    }
                    }
                    GuestHomeTool.Diary -> {
                        TextButton(
                            modifier = Modifier.fillMaxWidth(),
                            onClick = { destination = GuestHomeDestination.Diary },
                        ) {
                            Text("日記を開く")
                        }
                    }
                    else -> Unit
                }
            }
        }
    }
}
