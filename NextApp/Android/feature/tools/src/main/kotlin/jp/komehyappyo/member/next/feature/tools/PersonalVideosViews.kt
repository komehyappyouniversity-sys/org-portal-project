package jp.komehyappyo.member.next.feature.tools

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.designsystem.FeatureCard
import jp.komehyappyo.member.next.core.model.PersonalVideo
import java.util.Locale

enum class VideoMenuDestination {
    List,
    Add,
}

@Composable
fun YoutubeMenuRoot(model: PersonalVideoFeatureModel) {
    var destination by rememberSaveable { mutableStateOf(VideoMenuDestination.List) }

    when (destination) {
        VideoMenuDestination.List -> PersonalVideosRoot(
            model,
            onOpenCreate = { destination = VideoMenuDestination.Add },
        )
        VideoMenuDestination.Add -> {
            PersonalVideoEditorScreen(
                model = model,
                existing = null,
                onBack = { destination = VideoMenuDestination.List },
            )
        }
    }
}

@Composable
private fun PersonalVideosRoot(
    model: PersonalVideoFeatureModel,
    onOpenCreate: () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    var selectedVideo by remember { mutableStateOf<PersonalVideo?>(null) }
    val context = LocalContext.current

    LaunchedEffect(selectedVideo?.id) {
        selectedVideo?.let { model.loadMemos(it.id) }
    }

    if (selectedVideo != null) {
        PersonalVideoDetailScreen(
            model,
            selectedVideo!!,
            onBack = { selectedVideo = null },
            openInBrowser = { video, seconds -> openYouTubeInBrowser(context, video, seconds) },
        )
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("YouTube動画機能", style = MaterialTheme.typography.headlineSmall)
        if (state.notice != null) {
            Text(state.notice!!, color = MaterialTheme.colorScheme.primary)
        }
        state.errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error)
        }
        Button(
            onClick = onOpenCreate,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("動画を登録")
        }

        Text(
            "検索結果から開いた動画のURLを使って登録できます。",
            style = MaterialTheme.typography.bodyMedium,
        )

        LazyColumn(
            contentPadding = PaddingValues(top = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(state.videos, key = { it.id }) { video ->
                FeatureCard(
                    title = video.title,
                    description = "カテゴリ: ${video.categoryPath}",
                    icon = Icons.Outlined.PlayArrow,
                ) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        TextButton(onClick = { selectedVideo = video }) {
                            Text("詳細")
                        }
                        Row {
                            Text(formatSeconds(video.savedPositionSeconds))
                            TextButton(onClick = {
                                openYouTubeInBrowser(context, video, video.savedPositionSeconds)
                            }) {
                                Text("再生")
                            }
                            TextButton(onClick = { model.deleteVideo(video) }) {
                                Text("削除", color = MaterialTheme.colorScheme.error)
                            }
                        }
                    }
                }
            }
            if (state.videos.isEmpty()) {
                item {
                    Text(
                        "まだ動画がありません。検索結果から開いて登録してください。",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }
    }
}

@Composable
private fun PersonalVideoDetailScreen(
    model: PersonalVideoFeatureModel,
    video: PersonalVideo,
    onBack: () -> Unit,
    openInBrowser: (PersonalVideo, Int) -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val memos = state.memosByVideo[video.id] ?: emptyList()
    var memoText by rememberSaveable { mutableStateOf("") }
    var memoPosition by rememberSaveable { mutableStateOf(formatSeconds(video.savedPositionSeconds)) }
    var memoInputError by rememberSaveable { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("動画詳細", style = MaterialTheme.typography.headlineSmall)
        Text("タイトル：${video.title}")
        Text("再生位置：${formatSeconds(video.savedPositionSeconds)}")
        Text("カテゴリ：${video.categoryPath}")
        Text("URL：${video.timestampedUrl}")

        Button(onClick = { openInBrowser(video, video.savedPositionSeconds) }) {
            Text("YouTubeで開く")
        }

        Text("メモ", style = MaterialTheme.typography.titleMedium)
        memos.forEach { memo ->
            FeatureCard(
                title = "${formatSeconds(memo.positionSeconds)}",
                description = memo.memoText,
                icon = Icons.Outlined.PlayArrow,
            ) {
                TextButton(onClick = { openInBrowser(video, memo.positionSeconds) }) {
                    Text("再生")
                }
                TextButton(onClick = { model.deleteMemo(video.id, memo.id) }) {
                    Text("削除")
                }
            }
        }

        OutlinedTextField(
            value = memoText,
            onValueChange = { memoText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("メモ内容") },
            minLines = 2,
        )

        OutlinedTextField(
            value = memoPosition,
            onValueChange = { memoPosition = it.filter { c -> c.isDigit() || c == ':' } },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("再生位置（mm:ss または h:mm:ss）") },
            singleLine = true,
        )

        memoInputError?.let {
            Text(it, color = MaterialTheme.colorScheme.error)
        }

        Button(
            onClick = {
                val seconds = parseMemoPositionSeconds(memoPosition)
                if (seconds == null) {
                    memoInputError = "再生位置は mm:ss か h:mm:ss で入力してください。"
                    return@Button
                }
                memoInputError = null
                model.saveMemo(
                    videoId = video.id,
                    text = memoText,
                    positionSeconds = seconds,
                ) { saved ->
                    if (saved) {
                        memoText = ""
                        memoPosition = "0"
                    }
                }
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("メモを保存")
        }

        TextButton(onClick = onBack) {
            Text("戻る")
        }
    }
}

@Composable
private fun PersonalVideoEditorScreen(
    model: PersonalVideoFeatureModel,
    existing: PersonalVideo?,
    onBack: () -> Unit,
) {
    var title by rememberSaveable { mutableStateOf(existing?.title.orEmpty()) }
    var url by rememberSaveable { mutableStateOf(existing?.originalUrl.orEmpty()) }
    var note by rememberSaveable { mutableStateOf(existing?.note.orEmpty()) }
    var startSeconds by rememberSaveable { mutableStateOf(existing?.savedPositionSeconds?.toString().orEmpty()) }
    var category by rememberSaveable { mutableStateOf(existing?.category.orEmpty()) }
    var secondaryCategory by rememberSaveable { mutableStateOf(existing?.secondaryCategory.orEmpty()) }
    var tertiaryCategory by rememberSaveable { mutableStateOf(existing?.tertiaryCategory.orEmpty()) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(if (existing == null) "動画登録" else "動画編集", style = MaterialTheme.typography.headlineSmall)
        OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("タイトル") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = url, onValueChange = { url = it }, label = { Text("YouTube URL / 動画ID") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = note, onValueChange = { note = it }, label = { Text("メモ") }, modifier = Modifier.fillMaxWidth(), minLines = 2)
        OutlinedTextField(
            value = startSeconds,
            onValueChange = { startSeconds = it.filter { c -> c.isDigit() || c == ':' } },
            label = { Text("登録位置（mm:ss または h:mm:ss）") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        OutlinedTextField(value = category, onValueChange = { category = it }, label = { Text("大カテゴリ") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = secondaryCategory, onValueChange = { secondaryCategory = it }, label = { Text("小カテゴリ") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = tertiaryCategory, onValueChange = { tertiaryCategory = it }, label = { Text("さらに分ける") }, modifier = Modifier.fillMaxWidth())

        Button(
            modifier = Modifier.fillMaxWidth(),
            onClick = {
                model.saveVideo(
                    existing = existing,
                    title = title,
                    urlOrId = url,
                    note = note,
                    savedPositionSeconds = parseMemoPositionSeconds(startSeconds) ?: 0,
                    category = category,
                    secondaryCategory = secondaryCategory,
                    tertiaryCategory = tertiaryCategory,
                ) { saved ->
                    if (saved) {
                        onBack()
                    }
                }
            },
        ) {
            Text("保存")
        }

        TextButton(onClick = onBack) {
            Text("キャンセル")
        }

        Text(
            "YouTubeのURLまたは動画IDを貼り付けて、タイトルを入力して保存してください。",
            style = MaterialTheme.typography.bodySmall,
        )
    }
}

private fun openYouTubeInBrowser(context: Context, video: PersonalVideo, positionSeconds: Int) {
    val baseUrl = video.canonicalUrl
    val target = if (positionSeconds > 0) {
        "${baseUrl}&t=${positionSeconds}s"
    } else {
        baseUrl
    }
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(target))
    context.startActivity(intent)
}

private fun formatSeconds(value: Int): String {
    val safe = value.coerceAtLeast(0)
    val totalMinutes = safe / 60
    val second = safe % 60
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60

    return if (hours > 0) {
        String.format(Locale.getDefault(), "%d:%02d:%02d", hours, minutes, second)
    } else {
        String.format(Locale.getDefault(), "%d:%02d", minutes, second)
    }
}

private fun parseMemoPositionSeconds(value: String): Int? {
    val trimmed = value.trim()
    if (trimmed.isBlank()) return 0

    val parts = trimmed.split(":")
    if (parts.isEmpty() || parts.any { it.isBlank() || !it.all(Char::isDigit) }) {
        return null
    }

    return when (parts.size) {
        1 -> parts[0].toIntOrNull()
        2 -> {
            val minutes = parts[0].toIntOrNull() ?: return null
            val seconds = parts[1].toIntOrNull() ?: return null
            if (seconds > 59) return null
            minutes * 60 + seconds
        }
        3 -> {
            val hours = parts[0].toIntOrNull() ?: return null
            val minutes = parts[1].toIntOrNull() ?: return null
            val seconds = parts[2].toIntOrNull() ?: return null
            if (minutes > 59 || seconds > 59) return null
            (hours * 60 + minutes) * 60 + seconds
        }
        else -> null
    }
}
