package jp.komehyappyo.member.next.feature.tools

import android.content.Intent
import android.net.Uri

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.Calculate
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.QuestionAnswer
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import jp.komehyappyo.member.next.core.designsystem.FeatureCard

private enum class ToolsDestination {
    Schedule,
    Diary,
    Denomination,
    MeetingMinutes,
    SnsPostingAssistant,
    Favorites,
    Friends,
    Manual,
    YouTubeSearch,
    PersonalVideos,
    VideoQuestions,
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
    personalVideoFeatureModel: PersonalVideoFeatureModel,
    videoQuestionFeatureModel: VideoQuestionFeatureModel,
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
        ToolsDestination.YouTubeSearch -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            YoutubeSearchRoot()
        }
        ToolsDestination.PersonalVideos -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            YoutubeMenuRoot(model = personalVideoFeatureModel)
        }
        ToolsDestination.VideoQuestions -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            VideoQuestionRoot(videoQuestionFeatureModel)
        }
        ToolsDestination.Manual -> ToolDestinationContainer(
            onBack = { destination = null },
        ) {
            ManualListRoot()
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
            Button(onClick = { destination = ToolsDestination.YouTubeSearch }) {
                FeatureCard(
                    title = "YouTube検索・登録",
                    description = "キーワードでYouTubeを開きます。",
                    icon = Icons.Outlined.Search,
                )
            }
            Button(onClick = { destination = ToolsDestination.PersonalVideos }) {
                FeatureCard(
                    title = "YouTube動画メモ",
                    description = "保存済みYouTubeを開く/タイトル編集/3段階カテゴリ/時間メモができます。",
                    icon = Icons.Outlined.Bookmark,
                )
            }
            Button(onClick = { destination = ToolsDestination.VideoQuestions }) {
                FeatureCard(
                    title = "動画質問",
                    description = "自分の質問を送信し、回答を確認します。",
                    icon = Icons.Outlined.QuestionAnswer,
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
private fun ToolDestinationContainer(
    onBack: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.fillMaxSize()) {
        TextButton(onClick = onBack) { Text("便利に戻る") }
        Box(modifier = Modifier.weight(1f)) { content() }
    }
}

@Composable
fun YoutubeSearchRoot() {
    var keyword by remember { mutableStateOf("") }
    val context = androidx.compose.ui.platform.LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            "YouTube検索",
            style = MaterialTheme.typography.headlineSmall,
        )
        androidx.compose.material3.OutlinedTextField(
            value = keyword,
            onValueChange = { keyword = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("検索ワード") },
            singleLine = true,
        )
        Button(
            modifier = Modifier.fillMaxWidth(),
            enabled = keyword.isNotBlank(),
            onClick = {
                val query = Uri.encode(keyword)
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/results?search_query=${query}"))
                context.startActivity(intent)
            },
        ) {
            Text("YouTubeで検索")
        }
        Text(
            "検索結果から動画を開いて、\"お気に入り\"画面でURLを登録してください。",
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}
