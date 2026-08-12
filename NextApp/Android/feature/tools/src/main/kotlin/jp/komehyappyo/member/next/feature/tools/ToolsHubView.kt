package jp.komehyappyo.member.next.feature.tools

import android.annotation.SuppressLint
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
import androidx.compose.material3.MaterialTheme
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
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.model.DistributedVideo
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
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
            )
        }
        is ToolsDestination.DistributedVideoPlayer -> ToolDestinationContainer(
            onBack = { destination = ToolsDestination.DistributedVideos },
        ) {
            DistributedVideoPlayer(
                model = distributedVideoModel,
                video = current.video,
            )
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
) {
    val state by model.state.collectAsStateWithLifecycle()
    val errorMessage = state.errorMessage

    LaunchedEffect(Unit) {
        model.load()
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

internal fun videoPlayerSource(video: DistributedVideo): VideoPlayerSource {
    return when {
        video.embedHtml.isNotBlank() -> VideoPlayerSource.Html(video.embedHtml)
        video.vimeoUrl.isNotBlank() -> VideoPlayerSource.Url(video.vimeoUrl)
        video.videoUrl.isNotBlank() -> VideoPlayerSource.Url(video.videoUrl)
        else -> VideoPlayerSource.Empty
    }
}

@Composable
private fun DistributedVideoPlayer(
    model: DistributedVideoFeatureModel,
    video: DistributedVideo,
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
    val scope = rememberCoroutineScope()

    LaunchedEffect(video.id) {
        model.load()
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
                onPlaybackTimeChanged = { playbackSeconds = it },
            )

            Button(onClick = { sendPlaybackCommand(VimeoPlaybackAction.ReportCurrentTime) }) {
                Text("現在の再生位置を取得")
            }

            Text("再生位置: ${playbackTimeLabel(playbackSeconds)}")

            Divider()

            Text("メモ")
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
                Text("まだメモはありません。", color = Color.Gray)
            } else {
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

            Text("質問")
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
                    )
                    questionText = ""
                }
            }) {
                Text("質問を送信")
            }

            val questions = model.questionsFor(video)
            if (questions.isEmpty()) {
                Text("まだ質問はありません。", color = Color.Gray)
            } else {
                questions.forEach { question ->
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text("質問: ${question.questionText}")
                        if (question.answerText.trim().isBlank()) {
                            Text("回答待ち", color = Color(0xFFFF9800))
                        } else {
                            Text("回答: ${question.answerText}", color = Color(0xFF4CAF50))
                        }
                    }
                    Divider()
                }
            }
        }
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
                webViewClient = WebViewClient()
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
                webView.loadDataWithBaseURL(
                    "https://player.vimeo.com",
                    distributedVimeoPlayerHTML(videoId, initialPlaybackSeconds),
                    "text/html",
                    "UTF-8",
                    null,
                )
                return@AndroidView
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
