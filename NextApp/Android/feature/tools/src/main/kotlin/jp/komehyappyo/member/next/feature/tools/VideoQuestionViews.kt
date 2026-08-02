package jp.komehyappyo.member.next.feature.tools

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.QuestionAnswer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.material3.Card
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.FeatureCard
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.model.VideoQuestion
import jp.komehyappyo.member.next.core.model.VideoQuestionStatus
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun VideoQuestionRoot(model: VideoQuestionFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    var videoId by rememberSaveable { mutableStateOf("") }
    var videoTitle by rememberSaveable { mutableStateOf("") }
    var note by rememberSaveable { mutableStateOf("") }
    var questionText by rememberSaveable { mutableStateOf("") }
    var playbackSeconds by rememberSaveable { mutableStateOf("0") }

    LaunchedEffect(Unit) {
        model.refresh()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("動画質問", style = MaterialTheme.typography.headlineSmall)
        state.currentCommunityId.ifBlank { null }?.let {
            Text(
                "コミュニティ: $it",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        state.message?.let {
            Text(it, color = MaterialTheme.colorScheme.primary)
        }

        OutlinedTextField(
            value = videoId,
            onValueChange = { videoId = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("動画ID（YouTube ID など）") },
            singleLine = true,
        )
        OutlinedTextField(
            value = videoTitle,
            onValueChange = { videoTitle = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("タイトル") },
            singleLine = true,
        )
        OutlinedTextField(
            value = note,
            onValueChange = { note = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("メモ（任意）") },
            minLines = 2,
        )
        OutlinedTextField(
            value = playbackSeconds,
            onValueChange = { playbackSeconds = it.filter { c -> c.isDigit() } },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("再生位置（秒）") },
            singleLine = true,
        )
        OutlinedTextField(
            value = questionText,
            onValueChange = { questionText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("質問内容") },
            minLines = 3,
        )

        Button(
            onClick = {
                model.updateDraft(
                    videoId = videoId,
                    videoTitle = videoTitle,
                    noteText = note,
                    questionText = questionText,
                    playbackSecondsText = playbackSeconds,
                )
                model.sendQuestion()
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = model.canSendQuestion,
        ) {
            Text("送信")
        }

        HorizontalDivider()

        when {
            state.isLoading -> LoadingState()
            state.questions.isEmpty() -> EmptyState(
                title = "まだ質問はありません",
                message = "動画IDと質問内容を入力して送信してください。",
            )
            else -> {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    contentPadding = PaddingValues(bottom = 24.dp),
                ) {
                    itemsIndexed(state.questions) { _, question ->
                        VideoQuestionItem(question)
                    }
                }
            }
        }
    }
}

@Composable
private fun VideoQuestionItem(question: VideoQuestion) {
    val status = when (question.status) {
        VideoQuestionStatus.Unanswered -> "未回答"
        VideoQuestionStatus.Answered -> "回答済"
    }
    Card(shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        FeatureCard(
            title = "${question.videoTitle.ifBlank { "(タイトル未設定)" }}",
            description = "#${status} / ${formatVideoQuestionDate(question.createdAt)}",
            icon = Icons.Outlined.QuestionAnswer,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    "質問: ${question.questionText}",
                    style = MaterialTheme.typography.bodyMedium,
                )
                if (question.noteText.isNotBlank()) {
                    Text(
                        "メモ: ${question.noteText}",
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
                Text(
                    "回答: ${if (question.answerText.isBlank()) "（まだなし）" else question.answerText}",
                    style = MaterialTheme.typography.bodyMedium,
                )
                if (question.seconds > 0) {
                    Text("再生位置: ${question.seconds}秒", style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

private fun formatVideoQuestionDate(instant: Instant): String {
    val formatter = DateTimeFormatter
        .ofPattern("yyyy/MM/dd HH:mm")
        .withZone(ZoneId.systemDefault())
    return formatter.format(instant)
}
