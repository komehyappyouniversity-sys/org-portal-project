package jp.komehyappyo.member.next.feature.tools

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.media.MediaPlayer
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.model.MeetingMinutes
import java.io.File
import java.io.FileOutputStream
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private enum class MeetingDestination {
    Recorder,
    Detail,
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MeetingMinutesRoot(model: MeetingMinutesFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    var destination by rememberSaveable { mutableStateOf<MeetingDestination?>(null) }
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    var showRecovery by rememberSaveable { mutableStateOf(state.draft != null) }

    when (destination) {
        MeetingDestination.Recorder -> MeetingRecorderScreen(
            model = model,
            onBack = { destination = null },
        )
        MeetingDestination.Detail -> state.minutes.firstOrNull {
            it.id.toString() == selectedId
        }?.let { value ->
            MeetingMinutesDetailScreen(
                model = model,
                initial = value,
                onBack = { destination = null },
            )
        }
        null -> Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("会議録音・議事録") },
                    actions = {
                        TextButton(onClick = { destination = MeetingDestination.Recorder }) {
                            Text("録音")
                        }
                    },
                )
            },
        ) { padding ->
            if (state.minutes.isEmpty()) {
                Box(Modifier.padding(padding)) {
                    EmptyState(
                        title = "会議録音はまだありません",
                        message = "録音を開始すると、音声と議事録がこの端末に保存されます。",
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.minutes, key = { it.id }) { value ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp),
                            onClick = {
                                selectedId = value.id.toString()
                                destination = MeetingDestination.Detail
                            },
                        ) {
                            Column(Modifier.padding(16.dp)) {
                                Text(value.title, style = MaterialTheme.typography.titleMedium)
                                Text(
                                    DateTimeFormatter.ofPattern("yyyy年M月d日 H:mm")
                                        .withZone(ZoneId.systemDefault())
                                        .format(value.recordingStartAt),
                                    style = MaterialTheme.typography.bodySmall,
                                )
                                Text("録音 ${duration(value.recordingDurationSeconds)}")
                            }
                        }
                    }
                }
            }
        }
    }

    if (showRecovery && state.draft != null && destination == null) {
        AlertDialog(
            onDismissRequest = {},
            title = { Text("未保存の録音があります") },
            text = { Text("前回中断された録音を再生し、名前を付けて保存できます。") },
            confirmButton = {
                Button(onClick = {
                    showRecovery = false
                    destination = MeetingDestination.Recorder
                }) { Text("復旧する") }
            },
            dismissButton = {
                TextButton(onClick = {
                    model.discardDraft()
                    showRecovery = false
                }) { Text("削除") }
            },
        )
    }

    state.errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = model::clearError,
            title = { Text("処理できません") },
            text = { Text(message) },
            confirmButton = {
                Button(onClick = model::clearError) { Text("OK") }
            },
        )
    }
}

@Composable
private fun MeetingRecorderScreen(
    model: MeetingMinutesFeatureModel,
    onBack: () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var title by rememberSaveable { mutableStateOf("") }
    var transcript by rememberSaveable(state.draft?.id) {
        mutableStateOf(state.draft?.transcriptText.orEmpty())
    }
    var showExplanation by rememberSaveable { mutableStateOf(false) }
    var player by remember { mutableStateOf<MediaPlayer?>(null) }
    DisposableEffect(Unit) { onDispose { player?.release() } }
    LaunchedEffect(state.liveTranscript, state.isTranscribing) {
        if (state.isTranscribing || state.liveTranscript.isNotBlank()) {
            transcript = state.liveTranscript
        }
    }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            model.startRecording()
        } else {
            model.reportError(
                "録音にはマイクの許可が必要です。設定アプリから許可してください。",
            )
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            TextButton(onClick = onBack, enabled = !state.isRecording) { Text("戻る") }
            Text(
                when {
                    state.isRecording -> "● 録音中 ${duration(state.elapsedSeconds)}"
                    state.isTranscribing -> "文字起こし中"
                    else -> "停止中"
                },
                color = if (state.isRecording) MaterialTheme.colorScheme.error
                else MaterialTheme.colorScheme.onSurface,
            )
        }
        if (state.isRecording) {
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = {
                    model.stopRecording()
                    transcript = model.state.value.liveTranscript
                },
            ) { Text("録音を停止") }
        } else if (state.draft == null) {
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = { showExplanation = true },
            ) { Text("録音を開始") }
        }
        if (state.draft != null) {
            val draftAudioPath = state.draft?.audioFileLocalPath
            if (!state.isRecording) {
                Button(
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !state.isTranscribing,
                    onClick = {
                        val audioPath = draftAudioPath ?: return@Button
                        player?.release()
                        player = MediaPlayer().apply {
                            setDataSource(audioPath)
                            prepare()
                            start()
                        }
                    },
                ) { Text("未保存の録音を再生") }
            }
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("会議名（必須）") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = if (state.isRecording) state.liveTranscript else transcript,
                onValueChange = { transcript = it },
                label = { Text("議事録（編集できます）") },
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                enabled = !state.isRecording && !state.isTranscribing,
            )
            if (state.isTranscribing) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    CircularProgressIndicator()
                    Text("録音停止後の音声を端末内で文字起こししています…")
                }
            }
            Text(
                "文字起こしには誤りが含まれる場合があります。保存前に確認・編集してください。",
                style = MaterialTheme.typography.bodySmall,
            )
            state.notice?.let {
                Text(it, color = MaterialTheme.colorScheme.tertiary)
            }
            if (!state.isRecording && !state.isTranscribing) {
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        transcript = ""
                        model.retryTranscription()
                    },
                ) { Text("文字起こしを再実行") }
            }
            Button(
                modifier = Modifier.fillMaxWidth(),
                enabled =
                    title.isNotBlank() && !state.isRecording && !state.isTranscribing,
                onClick = {
                    model.saveDraft(title, transcript) { result ->
                        if (result.isSuccess) onBack()
                    }
                },
            ) { Text("名前を付けて保存") }
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                enabled = !state.isRecording && !state.isTranscribing,
                onClick = {
                    model.discardDraft()
                    onBack()
                },
            ) { Text("未保存の録音を削除") }
        }
    }

    if (showExplanation) {
        AlertDialog(
            onDismissRequest = { showExplanation = false },
            title = { Text("マイクを使用します") },
            text = {
                Text("会議音声を端末内へ保存し、対応端末では端末内だけで文字起こしします。外部へ送信しません。")
            },
            confirmButton = {
                Button(onClick = {
                    showExplanation = false
                    if (ContextCompat.checkSelfPermission(
                            context,
                            Manifest.permission.RECORD_AUDIO,
                        ) == PackageManager.PERMISSION_GRANTED
                    ) {
                        model.startRecording()
                    } else {
                        permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                    }
                }) { Text("続ける") }
            },
            dismissButton = {
                TextButton(onClick = { showExplanation = false }) { Text("キャンセル") }
            },
        )
    }
}

@Composable
private fun MeetingMinutesDetailScreen(
    model: MeetingMinutesFeatureModel,
    initial: MeetingMinutes,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    var value by remember(initial.id) { mutableStateOf(initial) }
    var player by remember { mutableStateOf<MediaPlayer?>(null) }
    DisposableEffect(Unit) { onDispose { player?.release() } }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            TextButton(onClick = onBack) { Text("戻る") }
            Button(onClick = {
                model.update(value) { if (it.isSuccess) onBack() }
            }) { Text("保存") }
        }
        OutlinedTextField(
            value = value.title,
            onValueChange = { value = value.copy(title = it) },
            label = { Text("会議名") },
            modifier = Modifier.fillMaxWidth(),
        )
        Button(onClick = {
            player?.release()
            player = MediaPlayer().apply {
                setDataSource(value.audioFileLocalPath)
                prepare()
                start()
            }
        }) { Text("録音を再生") }
        HorizontalDivider()
        OutlinedTextField(
            value = value.transcriptText,
            onValueChange = { value = value.copy(transcriptText = it) },
            label = { Text("議事録") },
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
        )
        Text(
            "文字起こしには誤りが含まれる場合があります。",
            style = MaterialTheme.typography.bodySmall,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { shareText(context, value) }) { Text("文字を共有") }
            Button(onClick = {
                runCatching { createPdf(context, value) }
                    .onSuccess { output ->
                        value = value.copy(pdfFileLocalPath = output.absolutePath)
                        model.update(value) {}
                        previewPdf(context, output)
                    }
                    .onFailure { model.reportError(it.localizedMessage ?: "PDFを作成できません。") }
            }) { Text("PDFを表示") }
            Button(onClick = {
                runCatching { createPdf(context, value) }
                    .onSuccess { output ->
                        value = value.copy(pdfFileLocalPath = output.absolutePath)
                        model.update(value) {}
                        sharePdf(context, output)
                    }
                    .onFailure { model.reportError(it.localizedMessage ?: "PDFを作成できません。") }
            }) { Text("PDFを共有") }
        }
        TextButton(onClick = {
            model.delete(value)
            onBack()
        }) { Text("削除") }
    }
}

private fun duration(seconds: Int): String =
    "%02d:%02d".format(seconds / 60, seconds % 60)

private fun shareText(context: Context, minutes: MeetingMinutes) {
    context.startActivity(
        Intent.createChooser(
            Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_SUBJECT, minutes.title)
                putExtra(Intent.EXTRA_TEXT, minutes.transcriptText)
            },
            "議事録を共有",
        ),
    )
}

private fun sharePdf(context: Context, output: File) {
    val uri = FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        output,
    )
    context.startActivity(
        Intent.createChooser(
            Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
            "PDFを共有",
        ),
    )
}

private fun previewPdf(context: Context, output: File) {
    val uri = FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        output,
    )
    context.startActivity(
        Intent.createChooser(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
            "PDFを表示",
        ),
    )
}

private fun createPdf(context: Context, minutes: MeetingMinutes): File {
    val outputDirectory = File(context.filesDir, "meeting_minutes_pdfs").apply { mkdirs() }
    val output = File(outputDirectory, "議事録-${minutes.id}.pdf")
    val document = PdfDocument()
    val paint = Paint().apply { textSize = 13f }
    val date = DateTimeFormatter.ofPattern("yyyy年M月d日 H:mm")
        .withZone(ZoneId.systemDefault())
        .format(minutes.recordingStartAt)
    val text = listOf(
        minutes.title,
        "",
        "録音日時: $date",
        "録音時間: ${duration(minutes.recordingDurationSeconds)}",
        "",
        "議事録",
        minutes.transcriptText,
        "",
        "※文字起こしには誤りが含まれる場合があります。",
    ).joinToString("\n")
    val lines = wrapPdfText(text, paint, maxWidth = 507f)
    val linesPerPage = 43
    lines.chunked(linesPerPage).forEachIndexed { pageIndex, pageLines ->
        val page = document.startPage(
            PdfDocument.PageInfo.Builder(595, 842, pageIndex + 1).create(),
        )
        var y = 48f
        pageLines.forEach { line ->
            page.canvas.drawText(line, 44f, y, paint)
            y += 17f
        }
        document.finishPage(page)
    }
    FileOutputStream(output).use(document::writeTo)
    document.close()
    return output
}

private fun wrapPdfText(text: String, paint: Paint, maxWidth: Float): List<String> =
    buildList {
        text.split("\n").forEach { paragraph ->
            if (paragraph.isEmpty()) {
                add("")
            } else {
                var remaining = paragraph
                while (remaining.isNotEmpty()) {
                    val count = paint.breakText(remaining, true, maxWidth, null)
                        .coerceAtLeast(1)
                    add(remaining.take(count))
                    remaining = remaining.drop(count)
                }
            }
        }
    }
