package jp.komehyappyo.member.next.feature.tools

import android.view.ViewGroup
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsStateWithLifecycle
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import coil.compose.AsyncImage
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.ErrorState
import jp.komehyappyo.member.next.core.designsystem.FeatureCard
import jp.komehyappyo.member.next.core.designsystem.LoadingState

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
            DistributedVideoPlayer(video = current.video)
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

    LaunchedEffect(Unit) {
        model.load()
    }

    when {
        state.isLoading && state.videos.isEmpty() -> {
            LoadingState()
        }

        state.errorMessage != null && state.videos.isEmpty() -> {
            ErrorState(
                message = state.errorMessage,
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
private fun DistributedVideoPlayer(video: DistributedVideo) {
    when (val source = videoPlayerSource(video)) {
        is VideoPlayerSource.Html -> DistributedVideoHtmlPlayer(source.html)
        is VideoPlayerSource.Url -> DistributedVideoUrlPlayer(source.url)
        VideoPlayerSource.Empty -> {
            EmptyState(
                title = "再生できません",
                message = "この動画に再生情報がありません。",
            )
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

private sealed interface VideoPlayerSource {
    data class Html(val html: String) : VideoPlayerSource
    data class Url(val url: String) : VideoPlayerSource
    data object Empty : VideoPlayerSource
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
