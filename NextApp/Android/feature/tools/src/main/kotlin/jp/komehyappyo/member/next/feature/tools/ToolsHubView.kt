package jp.komehyappyo.member.next.feature.tools

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.Calculate
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.VideoLibrary
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.ErrorState
import jp.komehyappyo.member.next.core.designsystem.FeatureCard
import jp.komehyappyo.member.next.core.designsystem.OfflineBanner
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.model.DistributedVideo
import jp.komehyappyo.member.next.core.model.VideoQuestion
import jp.komehyappyo.member.next.core.model.VideoQuestionSyncStatus
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.time.Instant
import java.util.Date
import java.util.Locale

private sealed class ToolsDestination {
    data object Schedule : ToolsDestination()
    data object Diary : ToolsDestination()
    data object Denomination : ToolsDestination()
    data object MeetingMinutes : ToolsDestination()
    data object SnsPostingAssistant : ToolsDestination()
    data object Favorites : ToolsDestination()
    data object Friends : ToolsDestination()
    data object Manual : ToolsDestination()
    data object DistributedVideos : ToolsDestination()
    data class DistributedVideoPlayer(val video: DistributedVideo) : ToolsDestination()
    data object VideoQuestions : ToolsDestination()
    data class VideoQuestionDetail(val question: VideoQuestion) : ToolsDestination()

    val id: String
        get() = when (this) {
            is Schedule -> "schedule"
            is Diary -> "diary"
            is Denomination -> "denomination"
            is MeetingMinutes -> "meetingMinutes"
            is SnsPostingAssistant -> "snsPostingAssistant"
            is Favorites -> "favorites"
            is Friends -> "friends"
            is Manual -> "manual"
            is DistributedVideos -> "distributedVideos"
            is DistributedVideoPlayer -> "distributedVideoPlayer:${video.id}"
            is VideoQuestions -> "videoQuestions"
            is VideoQuestionDetail -> "videoQuestionDetail:${question.id}"
        }
}

@Composable
fun ToolsHubRoot(
    scheduleModel: ScheduleFeatureModel,
    diaryModel: DiaryFeatureModel,
    cashDistributionModel: CashDistributionFeatureModel,
    meetingMinutesModel: MeetingMinutesFeatureModel,
    snsPostingAssistantModel: SnsPostingAssistantFeatureModel,
    favoriteBookmarkModel: FavoriteBookmarkFeatureModel,
    friendExchangeModel: FriendExchangeFeatureModel,
    distributedVideoModel: DistributedVideoFeatureModel,
) {
    var destination by remember { mutableStateOf<ToolsDestination?>(null) }
    when (val current = destination) {
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
        ToolsDestination.SnsPostingAssistant -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            SnsPostingAssistantRoot(snsPostingAssistantModel)
        }
        ToolsDestination.Favorites -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            FavoriteBookmarksRoot(favoriteBookmarkModel)
        }
        ToolsDestination.Friends -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            FriendExchangeRoot(friendExchangeModel)
        }
        ToolsDestination.Manual -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            ManualListRoot()
        }
        ToolsDestination.DistributedVideos -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            DistributedVideoListRoot(
                model = distributedVideoModel,
                onSelect = { selected ->
                    destination = ToolsDestination.DistributedVideoPlayer(selected)
                },
                onOpenQuestions = { destination = ToolsDestination.VideoQuestions },
            )
        }
        is ToolsDestination.DistributedVideoPlayer -> ToolDestinationContainer(
            onBack = { destination = ToolsDestination.DistributedVideos },
        ) {
            DistributedVideoPlayer(
                model = distributedVideoModel,
                video = current.video,
                onOpenQuestions = { destination = ToolsDestination.VideoQuestions },
            )
        }
        ToolsDestination.VideoQuestions -> ToolDestinationContainer(
            onBack = { destination = ToolsDestination.DistributedVideos },
        ) {
            VideoQuestionList(
                model = distributedVideoModel,
                onSelect = { destination = ToolsDestination.VideoQuestionDetail(it) },
            )
        }
        is ToolsDestination.VideoQuestionDetail -> ToolDestinationContainer(
            onBack = { destination = ToolsDestination.VideoQuestions },
        ) {
            VideoQuestionDetail(current.question)
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
            Button(onClick = { destination = ToolsDestination.DistributedVideos }) {
                FeatureCard(
                    title = "配信動画",
                    description = "配信動画の一覧を開いて再生できます。",
                    icon = Icons.Outlined.VideoLibrary,
                )
            }
            Button(onClick = { destination = ToolsDestination.VideoQuestions }) {
                FeatureCard(
                    title = "動画の質問・回答",
                    description = "送信した質問と管理者からの回答を確認できます。",
                    icon = Icons.Outlined.VideoLibrary,
                )
            }
            Button(onClick = { destination = ToolsDestination.MeetingMinutes }) {
                FeatureCard(
                    title = "会議録音・議事録",
                    description = "録音と文字起こしを端末内に保存します。",
                    icon = Icons.Outlined.Mic,
                )
            }
            Button(onClick = { destination = ToolsDestination.SnsPostingAssistant }) {
                FeatureCard(
                    title = "SNS投稿補助",
                    description = "文章をコピーして外部SNSを開きます。",
                    icon = Icons.Outlined.Share,
                )
            }
            Button(onClick = { destination = ToolsDestination.Favorites }) {
                FeatureCard(
                    title = "お気に入り",
                    description = "よく見るWebページを自分専用に保存します。",
                    icon = Icons.Outlined.Bookmark,
                )
            }
            Button(onClick = { destination = ToolsDestination.Manual }) {
                FeatureCard(
                    title = "使い方マニュアル",
                    description = "アプリの主要機能をすばやく確認できます。",
                    icon = Icons.AutoMirrored.Outlined.MenuBook,
                )
            }
            Button(onClick = { destination = ToolsDestination.Friends }) {
                FeatureCard(
                    title = "友達情報・交流履歴帳",
                    description = "本人専用の友達情報と交流履歴を非公開で記録します。",
                    icon = Icons.Outlined.People,
                )
            }
        }
    }
}

@Composable
private fun DistributedVideoListRoot(
    model: DistributedVideoFeatureModel,
    onSelect: (DistributedVideo) -> Unit,
    onOpenQuestions: () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val errorMessage = state.errorMessage

    LaunchedEffect(Unit) {
        model.load()
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Button(onClick = onOpenQuestions) {
            Text("自分の質問・回答")
        }

        if (state.hasPendingVideoMemoSync || state.hasPendingVideoQuestionSync) {
            OfflineBanner()
        }

        when {
            state.isLoading && state.videos.isEmpty() -> {
                LoadingState()
            }

            errorMessage != null && state.videos.isEmpty() -> {
                ErrorState(
                    message = errorMessage,
                    onRetry = { model.load() },
                )
            }

            state.videos.isEmpty() -> {
                EmptyState(
                    title = "配信動画",
                    message = "配信動画はまだありません",
                )
            }

            else -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(state.videos) { video ->
                        Button(
                            onClick = { onSelect(video) },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            DistributedVideoCard(video)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DistributedVideoCard(video: DistributedVideo) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .wrapContentHeight(),
        shape = RoundedCornerShape(12.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (video.thumbnailUrl.isNotBlank()) {
                AsyncImage(
                    model = video.thumbnailUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(84.dp)
                        .background(Color(0xFFE5E7EB)),
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(84.dp)
                        .background(Color(0xFFE5E7EB)),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        imageVector = Icons.Outlined.VideoLibrary,
                        contentDescription = null,
                        modifier = Modifier.size(36.dp),
                    )
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(video.videoTitle, style = MaterialTheme.typography.titleSmall)
                Spacer(modifier = Modifier.size(4.dp))
                Text(video.description, style = MaterialTheme.typography.bodySmall)
                if (video.isMembersOnly) {
                    Text(
                        "メンバー限定",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }
    }
}

@Composable
private fun VideoQuestionList(
    model: DistributedVideoFeatureModel,
    onSelect: (VideoQuestion) -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var showsCsvEmptyState by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        model.load()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("動画質問・回答一覧", style = MaterialTheme.typography.titleLarge)
            Button(onClick = {
                if (state.videoQuestions.isEmpty()) {
                    showsCsvEmptyState = true
                } else {
                    showsCsvEmptyState = false
                    shareCsv(
                        context = context,
                        subject = "video-questions.csv",
                        csv = VideoQuestionCsvExporter.export(
                            questions = state.videoQuestions,
                            videos = state.videos,
                        ),
                    )
                }
            }) {
                Text("CSV共有")
            }
        }

        if (state.hasPendingVideoQuestionSync) {
            OfflineBanner()
        }

        when {
            state.isLoading && state.videoQuestions.isEmpty() -> LoadingState()
            state.errorMessage != null && state.videoQuestions.isEmpty() -> ErrorState(
                message = state.errorMessage ?: "質問を取得できませんでした。",
                onRetry = { model.load() },
            )
            state.videoQuestions.isEmpty() -> EmptyState(
                title = if (showsCsvEmptyState) {
                    "CSV共有対象の質問がありません"
                } else {
                    "送信済みの質問はありません"
                },
                message = "質問を送信すると、ここで回答状況を確認できます。",
            )
            else -> {
                val unanswered = model.unansweredQuestions()
                val answered = model.answeredQuestions()
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item {
                        Text(
                            "未回答（${unanswered.size}件）",
                            style = MaterialTheme.typography.titleMedium,
                        )
                    }
                    if (unanswered.isEmpty()) {
                        item { Text("未回答の質問はありません。", color = Color.Gray) }
                    } else {
                        items(unanswered, key = { it.id }) { question ->
                            VideoQuestionRow(question = question, onSelect = { onSelect(question) })
                        }
                    }

                    item {
                        Text(
                            "回答済み（${answered.size}件）",
                            style = MaterialTheme.typography.titleMedium,
                            modifier = Modifier.padding(top = 12.dp),
                        )
                    }
                    if (answered.isEmpty()) {
                        item { Text("回答済みの質問はありません。", color = Color.Gray) }
                    } else {
                        items(answered, key = { it.id }) { question ->
                            VideoQuestionRow(question = question, onSelect = { onSelect(question) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun VideoQuestionRow(
    question: VideoQuestion,
    onSelect: () -> Unit,
) {
    Button(
        onClick = onSelect,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.Start,
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                question.videoTitle.ifEmpty { "配信動画" },
                style = MaterialTheme.typography.titleSmall,
            )
            Text(question.questionText, maxLines = 2)
            Text(
                videoQuestionStatusLabel(question),
                color = when {
                    question.syncStatus == VideoQuestionSyncStatus.Failed -> Color.Red
                    question.syncStatus == VideoQuestionSyncStatus.Synced && question.isAnswered -> Color(0xFF2E7D32)
                    else -> Color(0xFFFF9800)
                },
                style = MaterialTheme.typography.labelMedium,
            )
        }
    }
}

@Composable
private fun VideoQuestionDetail(question: VideoQuestion) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("質問詳細", style = MaterialTheme.typography.titleLarge)

        QuestionDetailCard(title = "対象動画") {
            Text(question.videoTitle.ifEmpty { "配信動画" })
        }
        QuestionDetailCard(title = "質問本文") {
            Text(question.questionText)
        }
        QuestionDetailCard(title = "管理者回答") {
            if (question.isAnswered) {
                Text(question.answerText)
                Spacer(modifier = Modifier.size(8.dp))
                Text(
                    "回答日時: ${question.answeredAt?.let(::questionDateLabel) ?: "日時情報なし"}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                Text("回答待ち", color = Color(0xFFFF9800))
            }
        }
    }
}

@Composable
private fun QuestionDetailCard(
    title: String,
    content: @Composable () -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            content()
        }
    }
}

private fun questionDateLabel(value: String): String {
    val instant = runCatching { Instant.parse(value) }.getOrNull() ?: return value
    return SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.JAPAN).format(Date.from(instant))
}

internal fun videoPlayerSource(video: DistributedVideo): VideoPlayerSource {
    return when {
        video.embedHtml.isNotBlank() -> VideoPlayerSource.Html(video.embedHtml)
        video.vimeoUrl.isNotBlank() -> VideoPlayerSource.Url(video.vimeoUrl)
        video.videoUrl.isNotBlank() -> VideoPlayerSource.Url(video.videoUrl)
        else -> VideoPlayerSource.Empty
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun DistributedVideoPlayer(
    model: DistributedVideoFeatureModel,
    video: DistributedVideo,
    onOpenQuestions: () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val source = videoPlayerSource(video)
    val videoId = distributedVimeoVideoId(video)
    val memoDateFormatter = remember { SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.JAPAN) }

    var memoText by remember { mutableStateOf("") }
    var editingMemoId by remember { mutableStateOf<String?>(null) }
    var editingMemoText by remember { mutableStateOf("") }
    var questionText by remember { mutableStateOf("") }
    var playbackSeconds by remember { mutableStateOf(0.0) }
    var playbackCommand by remember { mutableStateOf<VimeoPlaybackCommand?>(null) }
    var playbackCommandId by remember { mutableStateOf(0) }
    var showMemoCsvEmptyState by remember { mutableStateOf(false) }
    var showRepeatSettingPanel by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    LaunchedEffect(video.id) {
        model.load()
        model.loadRepeatSetting(video.id)
    }

    fun sendPlaybackCommand(action: VimeoPlaybackAction) {
        playbackCommandId += 1
        playbackCommand = VimeoPlaybackCommand(action, playbackCommandId)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 12.dp)
            .padding(bottom = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        state.errorMessage?.let { message ->
            Text(
                message,
                color = MaterialTheme.colorScheme.error,
            )
        }
        if (state.hasPendingVideoMemoSync || state.hasPendingVideoQuestionSync) {
            OfflineBanner()
        }

        if (videoId == null) {
            when (source) {
                is VideoPlayerSource.Html -> DistributedVideoHtmlPlayer(source.html)
                is VideoPlayerSource.Url -> DistributedVideoUrlPlayer(source.url)
                VideoPlayerSource.Empty -> {
                    EmptyState(
                        title = "再生できません",
                        message = "この動画に再生情報がありません。",
                    )
                }
            }
        } else {
            DistributedVimeoVideoPlayerView(
                videoId = videoId,
                initialPlaybackSeconds = playbackSeconds,
                command = playbackCommand,
                isRepeatEnabled = model.isRepeatEnabled(video.id),
                onPlaybackTimeChanged = { playbackSeconds = it },
            )

            Button(onClick = { showRepeatSettingPanel = true }) {
                Text("リピート再生設定")
            }

            if (model.isRepeatEnabled(video.id)) {
                Text(
                    "動画全体のリピート再生: ON",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Button(onClick = { sendPlaybackCommand(VimeoPlaybackAction.ReportCurrentTime) }) {
                Text("現在の再生位置を取得")
            }

            Text("再生位置: ${playbackTimeLabel(playbackSeconds)}")

            Divider()

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("メモ")
                Button(onClick = {
                    val memos = model.videoMemosFor(video)
                    if (memos.isEmpty()) {
                        showMemoCsvEmptyState = true
                    } else {
                        showMemoCsvEmptyState = false
                        shareCsv(
                            context,
                            subject = "video-memos-${video.id}.csv",
                            csv = VideoMemoCsvExporter.export(
                                memos = memos,
                                video = video,
                            ),
                        )
                    }
                }) {
                    Text("CSV共有")
                }
            }
            TextField(
                value = memoText,
                onValueChange = { memoText = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("動画メモ") },
            )
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Button(onClick = {
                    model.addVideoMemo(
                        video = video,
                        memo = memoText,
                        playbackSeconds = playbackSeconds,
                    )
                    memoText = ""
                }) {
                    Text("メモを追加")
                }
                Button(onClick = { memoText = "" }) {
                    Text("クリア")
                }
            }

            val memos = model.videoMemosFor(video)
            if (memos.isEmpty()) {
                if (showMemoCsvEmptyState) {
                    EmptyState(
                        title = "CSV共有対象のメモがありません",
                        message = "CSV共有するにはメモが必要です。",
                    )
                } else {
                    Text("まだメモはありません。", color = Color.Gray)
                }
            } else {
                if (showMemoCsvEmptyState) {
                    showMemoCsvEmptyState = false
                }
                memos.forEach { item ->
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            memoDateText(item = item, formatter = memoDateFormatter),
                            style = MaterialTheme.typography.labelSmall,
                        )
                        if (editingMemoId == item.id) {
                            TextField(
                                value = editingMemoText,
                                onValueChange = { editingMemoText = it },
                                modifier = Modifier.fillMaxWidth(),
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(onClick = {
                                    model.updateVideoMemo(video, item, editingMemoText)
                                    editingMemoId = null
                                }) {
                                    Text("更新")
                                }
                                Button(onClick = { editingMemoId = null }) {
                                    Text("取消")
                                }
                            }
                        } else {
                            Text(item.text)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(onClick = {
                                    sendPlaybackCommand(VimeoPlaybackAction.SeekAndPlay(item.playbackSeconds))
                                }) {
                                    Text("この位置から再生")
                                }
                                Button(onClick = {
                                    editingMemoId = item.id
                                    editingMemoText = item.text
                                }) {
                                    Text("編集")
                                }
                                Button(
                                    onClick = {
                                        model.deleteVideoMemo(video, item)
                                    },
                                ) {
                                    Text("削除")
                                }
                            }
                        }
                    }
                    Divider()
                }
            }

            Divider()

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("質問")
                Button(onClick = onOpenQuestions) {
                    Text("自分の質問・回答一覧")
                }
            }
            TextField(
                value = questionText,
                onValueChange = { questionText = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("動画について質問") },
            )
            Button(onClick = {
                scope.launch {
                    model.submitVideoQuestion(
                        video = video,
                        memo = memoText,
                        question = questionText,
                        playbackSeconds = playbackSeconds,
                        onSubmitted = {
                            questionText = ""
                            onOpenQuestions()
                        },
                    )
                }
            }) {
                Text("質問を送信")
            }
        }
    }

    if (showRepeatSettingPanel) {
        ModalBottomSheet(
            onDismissRequest = { showRepeatSettingPanel = false },
        ) {
            VideoRepeatSettingPanel(
                isEnabled = model.isRepeatEnabled(video.id),
                onEnabledChange = { model.setRepeatEnabled(video.id, it) },
            )
        }
    }
}

private fun videoQuestionStatusLabel(question: VideoQuestion): String = when (question.syncStatus) {
    VideoQuestionSyncStatus.Draft -> "下書き"
    VideoQuestionSyncStatus.Sending -> "送信中"
    VideoQuestionSyncStatus.Failed -> "送信失敗（オフライン保持中）"
    VideoQuestionSyncStatus.Synced -> if (question.isAnswered) "回答済み" else "送信済み・回答待ち"
}

@Composable
private fun VideoRepeatSettingPanel(
    isEnabled: Boolean,
    onEnabledChange: (Boolean) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("リピート再生設定", style = MaterialTheme.typography.titleLarge)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("動画全体をリピート再生")
            Switch(
                checked = isEnabled,
                onCheckedChange = onEnabledChange,
            )
        }
        Text(
            "ONにすると、動画の再生終了後に最初から再生を再開します。",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.size(16.dp))
    }
}

@Composable
private fun DistributedVideoHtmlPlayer(html: String) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            WebView(context).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                )
                webViewClient = WebViewClient()
                webChromeClient = WebChromeClient()
                settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    mediaPlaybackRequiresUserGesture = false
                    loadWithOverviewMode = true
                    useWideViewPort = true
                    setSupportZoom(false)
                }
            }
        },
        update = { webView ->
            webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
        },
    )
}

@Composable
private fun DistributedVideoUrlPlayer(url: String) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            WebView(context).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                )
                webViewClient = WebViewClient()
                webChromeClient = WebChromeClient()
                settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    mediaPlaybackRequiresUserGesture = false
                    loadWithOverviewMode = true
                    useWideViewPort = true
                    setSupportZoom(false)
                }
            }
        },
        update = { webView ->
            webView.loadUrl(url)
        },
    )
}

internal sealed interface VideoPlayerSource {
    data class Html(val html: String) : VideoPlayerSource
    data class Url(val url: String) : VideoPlayerSource
    data object Empty : VideoPlayerSource
}

@Composable
private fun DistributedVimeoVideoPlayerView(
    videoId: String,
    initialPlaybackSeconds: Double,
    command: VimeoPlaybackCommand?,
    isRepeatEnabled: Boolean,
    onPlaybackTimeChanged: (Double) -> Unit,
) {
    val state = remember {
        DistributedVimeoPlayerState()
    }
    val bridge: DistributedVimeoPlayerBridge = remember {
        DistributedVimeoPlayerBridge(onPlaybackTimeChanged)
    }

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    AndroidView(
        modifier = Modifier
            .fillMaxWidth()
            .fillMaxHeight(0.4f),
        factory = { context ->
            WebView(context).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                )
                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView, url: String?) {
                        view.evaluateJavascript(
                            "window.vimeoSetRepeatEnabled(${state.isRepeatEnabled});",
                            null,
                        )
                    }
                }
                webChromeClient = WebChromeClient()
                addJavascriptInterface(bridge, "VimeoPlayerBridge")
                settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    mediaPlaybackRequiresUserGesture = false
                    loadWithOverviewMode = true
                    useWideViewPort = true
                    setSupportZoom(false)
                }
            }
        },
        update = { webView ->
            if (state.videoId != videoId) {
                state.videoId = videoId
                state.lastCommandId = null
                state.isRepeatEnabled = isRepeatEnabled
                webView.loadDataWithBaseURL(
                    "https://player.vimeo.com",
                    distributedVimeoPlayerHTML(
                        videoId,
                        initialPlaybackSeconds,
                        isRepeatEnabled,
                    ),
                    "text/html",
                    "UTF-8",
                    null,
                )
                return@AndroidView
            }

            if (state.isRepeatEnabled != isRepeatEnabled) {
                state.isRepeatEnabled = isRepeatEnabled
                webView.evaluateJavascript(
                    "window.vimeoSetRepeatEnabled(${isRepeatEnabled.toString()});",
                    null,
                )
            }

            val commandToExecute = command ?: return@AndroidView
            if (commandToExecute.requestId == state.lastCommandId) return@AndroidView

            state.lastCommandId = commandToExecute.requestId
            when (commandToExecute.action) {
                VimeoPlaybackAction.ReportCurrentTime -> {
                    webView.evaluateJavascript("window.vimeoReportTime();", null)
                }
                is VimeoPlaybackAction.Seek -> {
                    webView.evaluateJavascript(
                        "window.vimeoSeek(${commandToExecute.action.seconds});",
                        null,
                    )
                }
                is VimeoPlaybackAction.SeekAndPlay -> {
                    webView.evaluateJavascript(
                        "window.vimeoSeekAndPlay(${commandToExecute.action.seconds});",
                        null,
                    )
                }
            }
        },
    )
}

private fun distributedVimeoPlayerHTML(
    videoId: String,
    initialSeconds: Double,
    isRepeatEnabled: Boolean,
): String {
    return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        html, body, #player { margin: 0; width: 100%; height: 100%; background: #000; }
        </style>
        <script src=\"https://player.vimeo.com/api/player.js\"></script>
        </head>
        <body>
        <div id="player"></div>
        <script>
        const initialSeconds = $initialSeconds;
        let repeatEnabled = $isRepeatEnabled;
        const targetId = $videoId;
        const bridge = window.VimeoPlayerBridge;

        const postError = function(message) {
            if (!bridge || !bridge.onError) return;
            bridge.onError(message || '');
        };

        const postTime = function(seconds) {
            if (!bridge || !bridge.onCurrentTime) return;
            bridge.onCurrentTime(seconds || 0);
        };

        const player = new Vimeo.Player('player', {
            id: targetId,
            autoplay: false,
            controls: true,
            dnt: true,
            playsinline: true,
            responsive: true,
        });

        player.ready().then(function() {
            if (initialSeconds > 0) {
                player.setCurrentTime(initialSeconds).catch(function() {});
            }
        }).catch(function(error) {
            postError(error && error.message ? error.message : 'Vimeoプレーヤーを準備できませんでした。');
        });

        player.on('ended', function() {
            if (!repeatEnabled) return;
            player.setCurrentTime(0).then(function() {
                return player.play();
            }).catch(function(error) {
                postError(error && error.message ? error.message : 'リピート再生に失敗しました。');
            });
        });

        window.vimeoSetRepeatEnabled = function(isEnabled) {
            repeatEnabled = !!isEnabled;
        };

        window.vimeoReportTime = function() {
            player.getCurrentTime().then(function(value) {
                postTime(value || 0);
            }).catch(function(error) {
                postError(error && error.message ? error.message : '再生位置を取得できませんでした。');
                postTime(0);
            });
        };

        window.vimeoSeekAndPlay = function(seconds) {
            player.setCurrentTime(seconds).then(function() {
                return player.play();
            }).catch(function(error) {
                postError(error && error.message ? error.message : '再生に失敗しました。');
            });
        };

        window.vimeoSeek = function(seconds) {
            player.setCurrentTime(seconds).catch(function(error) {
                postError(error && error.message ? error.message : 'シークに失敗しました。');
            });
        };
        </script>
        </body>
        </html>
    """
}

@Composable
private fun ToolDestinationContainer(
    onBack: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.fillMaxSize()) {
        TextButton(onClick = onBack) {
            Text("便利に戻る")
        }
        Box(modifier = Modifier.weight(1f)) {
            content()
        }
    }
}

private class DistributedVimeoPlayerState {
    var videoId: String? = null
    var lastCommandId: Int? = null
    var isRepeatEnabled: Boolean = false
}

private class DistributedVimeoPlayerBridge(
    private var onPlaybackTimeChanged: (Double) -> Unit,
) {
    @JavascriptInterface
    fun onCurrentTime(value: Double) {
        onPlaybackTimeChanged(value)
    }

    @JavascriptInterface
    fun onError(value: String?) {
        // Keep callback behavior close to iOS by avoiding UI side effects directly from WebView bridge.
    }
}

private fun shareCsv(context: Context, subject: String, csv: String) {
    val sendIntent = Intent(Intent.ACTION_SEND).apply {
        type = "text/csv"
        putExtra(Intent.EXTRA_SUBJECT, subject)
        putExtra(Intent.EXTRA_TEXT, "\uFEFF$csv")
    }
    context.startActivity(Intent.createChooser(sendIntent, "CSVを共有"))
}

private fun distributedVimeoVideoId(video: DistributedVideo): String? {
    val candidates = listOf(video.vimeoVideoId, video.vimeoUrl, video.videoUrl)
        .map(String::trim)
        .filter(String::isNotBlank)

    candidates.forEach { value ->
        val numeric = value.replace(Regex("\\D"), "")
        if (numeric.isNotBlank()) {
            return numeric
        }
    }
    return null
}

private fun playbackTimeLabel(value: Double): String {
    val seconds = kotlin.math.max(0, value.toInt())
    val minutes = seconds / 60
    return "$minutes:" + String.format(Locale.JAPAN, "%02d", seconds % 60)
}

private fun memoDateText(item: VimeoVideoMemo, formatter: SimpleDateFormat): String {
    if (item.createdAtMillis == 0L) return "以前のメモ"
    val date = Date(item.createdAtMillis)
    return "${formatter.format(date)} / 再生位置 ${playbackTimeLabel(item.playbackSeconds)}"
}

private sealed interface VimeoPlaybackAction {
    data object ReportCurrentTime : VimeoPlaybackAction
    data class Seek(val seconds: Double) : VimeoPlaybackAction
    data class SeekAndPlay(val seconds: Double) : VimeoPlaybackAction
}

private data class VimeoPlaybackCommand(
    val action: VimeoPlaybackAction,
    val requestId: Int,
)
