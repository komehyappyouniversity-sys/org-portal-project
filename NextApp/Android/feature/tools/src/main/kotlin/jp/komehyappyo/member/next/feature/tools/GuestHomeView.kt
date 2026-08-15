package jp.komehyappyo.member.next.feature.tools

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.Calculate
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.SettingsBackupRestore
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
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
        description = "配布額から必要な金種を計算し、現金の集計もできます。",
        icon = Icons.Outlined.Calculate,
        isAvailable = true,
    ),
    MeetingMinutes(
        title = "会議録音・議事録",
        description = "録音と文字起こしを端末内に保存します。",
        icon = Icons.Outlined.Mic,
        isAvailable = true,
    ),
    Favorites(
        title = "お気に入り",
        description = "よく見るWebページを自分専用に保存します。",
        icon = Icons.Outlined.Bookmark,
        isAvailable = true,
    ),
    Manual(
        title = "使い方マニュアル",
        description = "アプリの使い方を一覧で確認できます。",
        icon = Icons.AutoMirrored.Outlined.MenuBook,
        isAvailable = true,
    ),
    ;

    companion object {
        val ordered: List<GuestHomeTool> = entries
    }
}

private enum class GuestHomeDestination {
    TodaySchedule,
    Diary,
    Denomination,
    MeetingMinutes,
    Favorites,
    Manual,
    AppBackup,
}

@Composable
fun GuestHomeView(
    scheduleModel: ScheduleFeatureModel,
    diaryModel: DiaryFeatureModel,
    cashDistributionModel: CashDistributionFeatureModel,
    meetingMinutesModel: MeetingMinutesFeatureModel,
    favoriteBookmarkModel: FavoriteBookmarkFeatureModel,
    appBackupModel: AppBackupFeatureModel,
    manualModel: ManualFeatureModel,
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
                    GuestHomeDestination.Denomination ->
                        DenominationToolRoot(cashDistributionModel)
                    GuestHomeDestination.MeetingMinutes ->
                        MeetingMinutesRoot(meetingMinutesModel)
                    GuestHomeDestination.Favorites ->
                        FavoriteBookmarksRoot(favoriteBookmarkModel)
                    GuestHomeDestination.Manual ->
                        ManualListRoot(manualModel)
                    GuestHomeDestination.AppBackup ->
                        AppBackupRoot(appBackupModel)
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
                    GuestHomeTool.Denomination -> {
                        TextButton(
                            modifier = Modifier.fillMaxWidth(),
                            onClick = { destination = GuestHomeDestination.Denomination },
                        ) {
                            Text("金種計算を開く")
                        }
                    }
                    GuestHomeTool.MeetingMinutes -> {
                        TextButton(
                            modifier = Modifier.fillMaxWidth(),
                            onClick = { destination = GuestHomeDestination.MeetingMinutes },
                        ) {
                            Text("会議録音を開く")
                        }
                    }
                    GuestHomeTool.Favorites -> {
                        TextButton(
                            modifier = Modifier.fillMaxWidth(),
                            onClick = { destination = GuestHomeDestination.Favorites },
                        ) {
                            Text("お気に入りを開く")
                        }
                    }
                    GuestHomeTool.Manual -> {
                        TextButton(
                            modifier = Modifier.fillMaxWidth(),
                            onClick = { destination = GuestHomeDestination.Manual },
                        ) {
                            Text("アプリ説明を見る")
                        }
                    }
                }
            }
        }

        item {
            FeatureCard(
                title = "アプリ削除前のバックアップ",
                description = "予定・日記と写真・金種計算・会議録音と議事録・SNSリンク・お気に入りを、1つのファイルにまとめます。",
                icon = Icons.Outlined.SettingsBackupRestore,
            ) {
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { destination = GuestHomeDestination.AppBackup },
                ) {
                    Text("バックアップ操作を開く")
                }
            }
        }
    }
}

@Composable
private fun AppBackupRoot(model: AppBackupFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var exportData by remember { mutableStateOf<ByteArray?>(null) }
    val createDocument = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri ->
        val data = exportData
        if (uri == null || data == null) {
            model.exportCompleted(false)
        } else {
            val succeeded = runCatching {
                context.contentResolver.openOutputStream(uri)?.use { it.write(data) }
                    ?: error("ファイルを開けませんでした。")
            }.isSuccess
            model.exportCompleted(succeeded)
        }
        exportData = null
    }
    val openDocument = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) {
            runCatching {
                context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: error("ファイルを開けませんでした。")
            }.onSuccess(model::importBackup)
        }
    }

    LaunchedEffect(state.pendingExport) {
        state.pendingExport?.let { data ->
            exportData = data
            createDocument.launch("OrgPortalBackup.json")
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("アプリ削除前のバックアップ", style = MaterialTheme.typography.headlineSmall)
        Text(
            "この端末にだけ保存されている内容を、まとめて1つのファイルへ保存します。",
            style = MaterialTheme.typography.bodyLarge,
        )
        FeatureCard(
            title = "バックアップされる内容",
            description = "予定、日記・写真、金種計算、会議録音・議事録・PDF、SNSリンク、お気に入りURL・メモ・3段階カテゴリ、友達情報・交流履歴",
            icon = Icons.Outlined.SettingsBackupRestore,
        )
        Text(
            "会員情報、参加コミュニティ、お知らせなどFirebaseに保存される内容は、ログイン後に再取得されるため、このファイルには含みません。",
            style = MaterialTheme.typography.bodyMedium,
        )
        Button(
            modifier = Modifier.fillMaxWidth(),
            enabled = !state.isWorking && state.pendingExport == null,
            onClick = model::prepareExport,
        ) {
            Text("バックアップを書き出す")
        }
        Button(
            modifier = Modifier.fillMaxWidth(),
            enabled = !state.isWorking,
            onClick = {
                openDocument.launch(
                    arrayOf("application/json", "text/json", "application/octet-stream"),
                )
            },
        ) {
            Text("バックアップを読み込む")
        }
        if (state.isWorking) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator()
                Text("処理しています…")
            }
        }
        state.message?.let {
            Text(it, style = MaterialTheme.typography.bodyMedium)
        }
        Text(
            "アプリを削除する前に書き出し、端末外の安全な場所へ保存してください。復元すると同じIDのデータはバックアップ内容で更新されます。",
            style = MaterialTheme.typography.bodySmall,
        )
    }
}
