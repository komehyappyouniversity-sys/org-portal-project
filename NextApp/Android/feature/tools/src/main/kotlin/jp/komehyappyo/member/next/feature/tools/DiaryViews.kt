package jp.komehyappyo.member.next.feature.tools

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.ErrorState
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.designsystem.PrimaryActionButton
import jp.komehyappyo.member.next.core.model.Diary
import jp.komehyappyo.member.next.core.model.DiaryMood
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

private sealed interface DiaryScreen {
    data object List : DiaryScreen
    data class Detail(val diary: Diary) : DiaryScreen
    data class Editor(val diary: Diary?) : DiaryScreen
}

@Composable
fun DiaryRoot(model: DiaryFeatureModel) {
    var screen: DiaryScreen by remember { mutableStateOf(DiaryScreen.List) }
    when (val current = screen) {
        DiaryScreen.List -> DiaryListView(
            model = model,
            onOpen = { screen = DiaryScreen.Detail(it) },
            onAdd = { screen = DiaryScreen.Editor(null) },
        )
        is DiaryScreen.Detail -> DiaryDetailView(
            model = model,
            diary = current.diary,
            onBack = { screen = DiaryScreen.List },
            onEdit = { screen = DiaryScreen.Editor(current.diary) },
        )
        is DiaryScreen.Editor -> DiaryEditorView(
            model = model,
            editing = current.diary,
            onClose = { screen = DiaryScreen.List },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DiaryListView(
    model: DiaryFeatureModel,
    onOpen: (Diary) -> Unit,
    onAdd: () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var backupMessage by remember { mutableStateOf<String?>(null) }

    val createBackup = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri ->
        if (uri != null) {
            model.exportBackup { result ->
                result.fold(
                    onSuccess = { data ->
                        runCatching {
                            context.contentResolver.openOutputStream(uri)?.use {
                                output -> output.write(data)
                            } ?: error("保存先を開けません。")
                        }.fold(
                            onSuccess = { backupMessage = "バックアップを書き出しました。" },
                            onFailure = { backupMessage = "バックアップを書き出せませんでした。" },
                        )
                    },
                    onFailure = { backupMessage = "バックアップを書き出せませんでした。" },
                )
            }
        }
    }
    val openBackup = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) {
            runCatching {
                context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: error("ファイルを開けません。")
            }.fold(
                onSuccess = { data ->
                    model.importBackup(data) { result ->
                        result.fold(
                            onSuccess = {
                                backupMessage = "${it}件の日記を復元しました。"
                            },
                            onFailure = {
                                backupMessage = "バックアップを読み込めませんでした。"
                            },
                        )
                    }
                },
                onFailure = {
                    backupMessage = "バックアップを読み込めませんでした。"
                },
            )
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("日記・写真日記") },
                actions = {
                    IconButton(
                        enabled = state.diaries.isNotEmpty(),
                        onClick = {
                            createBackup.launch("日記バックアップ.json")
                        },
                    ) {
                        Icon(Icons.Outlined.FileUpload, contentDescription = "バックアップを書き出す")
                    }
                    IconButton(
                        onClick = { openBackup.launch(arrayOf("application/json")) },
                    ) {
                        Icon(Icons.Outlined.FileDownload, contentDescription = "バックアップを読み込む")
                    }
                },
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onAdd,
                icon = { Icon(Icons.Outlined.Add, contentDescription = null) },
                text = { Text("日記を追加") },
            )
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when {
                state.isLoading -> LoadingState()
                state.errorMessage != null -> ErrorState(
                    message = state.errorMessage.orEmpty(),
                    onRetry = model::reload,
                )
                state.diaries.isEmpty() -> EmptyState(
                    title = "日記はまだありません",
                    message = "「日記を追加」から最初の日記を登録できます。",
                )
                else -> LazyColumn {
                    items(state.diaries, key = { it.id }) { diary ->
                        DiaryRow(model, diary, onClick = { onOpen(diary) })
                    }
                }
            }
        }
    }

    backupMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { backupMessage = null },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = { backupMessage = null }) { Text("OK") }
            },
        )
    }
}

@Composable
private fun DiaryRow(model: DiaryFeatureModel, diary: Diary, onClick: () -> Unit) {
    ListItem(
        leadingContent = {
            diary.photoUrls.firstOrNull()?.let { reference ->
                StoredDiaryPhoto(
                    model = model,
                    reference = reference,
                    modifier = Modifier
                        .size(64.dp)
                        .clip(RoundedCornerShape(10.dp)),
                )
            } ?: Icon(Icons.Outlined.Photo, contentDescription = null)
        },
        headlineContent = { Text(diary.title) },
        supportingContent = {
            Column {
                Text(formatDiaryDate(diary.createdAt))
                Text(diaryMoodLabel(diary.mood))
            }
        },
        modifier = Modifier.clickable(onClick = onClick),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DiaryDetailView(
    model: DiaryFeatureModel,
    diary: Diary,
    onBack: () -> Unit,
    onEdit: () -> Unit,
) {
    var confirmDelete by remember { mutableStateOf(false) }
    var selectedPhotoIndex by remember { mutableStateOf<Int?>(null) }
    val photoData by produceState<List<ByteArray>>(
        initialValue = emptyList(),
        key1 = diary.photoUrls,
    ) {
        value = diary.photoUrls.mapNotNull { reference ->
            runCatching { model.photoData(reference) }.getOrNull()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(diary.title) },
                navigationIcon = { TextButton(onClick = onBack) { Text("戻る") } },
                actions = {
                    IconButton(onClick = onEdit) {
                        Icon(Icons.Outlined.Edit, contentDescription = "編集")
                    }
                    IconButton(onClick = { confirmDelete = true }) {
                        Icon(Icons.Outlined.Delete, contentDescription = "削除")
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item { DetailValue("日付", formatDiaryDate(diary.createdAt)) }
            item { DetailValue("気分", diaryMoodLabel(diary.mood)) }
            if (diary.body.isNotBlank()) {
                item { DetailValue("本文", diary.body) }
            }
            if (photoData.isNotEmpty()) {
                item {
                    Text("写真", style = MaterialTheme.typography.labelLarge)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        photoData.forEachIndexed { index, data ->
                            ByteArrayDiaryPhoto(
                                data = data,
                                modifier = Modifier
                                    .size(150.dp)
                                    .clip(RoundedCornerShape(10.dp))
                                    .clickable { selectedPhotoIndex = index },
                            )
                        }
                    }
                    Text(
                        "写真をタップすると拡大できます。",
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("この日記を削除しますか？") },
            text = { Text("削除した日記と写真は元に戻せません。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        model.delete(diary) { if (it.isSuccess) onBack() }
                        confirmDelete = false
                    },
                ) { Text("削除") }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("キャンセル") }
            },
        )
    }

    selectedPhotoIndex?.let { index ->
        DiaryPhotoGallery(
            photos = photoData,
            initialIndex = index,
            onDismiss = { selectedPhotoIndex = null },
        )
    }
}

@Composable
private fun DetailValue(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium)
        Text(value)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DiaryEditorView(
    model: DiaryFeatureModel,
    editing: Diary?,
    onClose: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var title by rememberSaveable { mutableStateOf(editing?.title.orEmpty()) }
    var body by rememberSaveable { mutableStateOf(editing?.body.orEmpty()) }
    var mood by rememberSaveable { mutableStateOf(editing?.mood ?: DiaryMood.Neutral) }
    val newPhotos = remember { mutableStateListOf<ByteArray>() }
    val removedReferences = remember { mutableStateListOf<String>() }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val visibleReferences = editing?.photoUrls.orEmpty().filterNot(removedReferences::contains)
    val remainingCount =
        (Diary.MAXIMUM_PHOTO_COUNT - visibleReferences.size - newPhotos.size).coerceAtLeast(0)
    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(Diary.MAXIMUM_PHOTO_COUNT),
    ) { uris ->
        scope.launch {
            val compressed = withContext(Dispatchers.IO) {
                uris.take(remainingCount).mapNotNull {
                    DiaryPhotoProcessor.compressedJpeg(context, it)
                }
            }
            newPhotos.addAll(compressed)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (editing == null) "日記の登録" else "日記の編集") },
                navigationIcon = { TextButton(onClick = onClose) { Text("閉じる") } },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("タイトル（必須）") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = body,
                    onValueChange = { body = it },
                    label = { Text("本文") },
                    minLines = 5,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                Text("気分")
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    DiaryMood.entries.forEach { option ->
                        FilterChip(
                            selected = mood == option,
                            onClick = { mood = option },
                            label = { Text(diaryMoodLabel(option)) },
                        )
                    }
                }
            }
            item {
                Text("写真（最大${Diary.MAXIMUM_PHOTO_COUNT}枚）")
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    visibleReferences.forEach { reference ->
                        RemovablePhoto(
                            onRemove = { removedReferences.add(reference) },
                        ) {
                            StoredDiaryPhoto(
                                model = model,
                                reference = reference,
                                modifier = Modifier.fillMaxSize(),
                            )
                        }
                    }
                    newPhotos.forEachIndexed { index, data ->
                        RemovablePhoto(
                            onRemove = { newPhotos.removeAt(index) },
                        ) {
                            ByteArrayDiaryPhoto(data, Modifier.fillMaxSize())
                        }
                    }
                }
                Button(
                    enabled = remainingCount > 0,
                    onClick = {
                        picker.launch(
                            PickVisualMediaRequest(
                                ActivityResultContracts.PickVisualMedia.ImageOnly,
                            ),
                        )
                    },
                ) {
                    Icon(Icons.Outlined.Photo, contentDescription = null)
                    Text("写真を選ぶ（残り${remainingCount}枚）")
                }
            }
            errorMessage?.let { message ->
                item { Text(message, color = MaterialTheme.colorScheme.error) }
            }
            item {
                PrimaryActionButton(
                    label = "保存",
                    enabled = title.isNotBlank(),
                    onClick = {
                        val now = Instant.now()
                        model.save(
                            diary = Diary(
                                id = editing?.id ?: UUID.randomUUID(),
                                userId = editing?.userId ?: "guest",
                                title = title,
                                body = body,
                                mood = mood,
                                photoUrls = editing?.photoUrls.orEmpty(),
                                createdAt = editing?.createdAt ?: now,
                                updatedAt = now,
                            ),
                            newPhotoData = newPhotos.toList(),
                            removedPhotoReferences = removedReferences.toSet(),
                        ) { result ->
                            result.fold(
                                onSuccess = { onClose() },
                                onFailure = { errorMessage = it.message },
                            )
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun RemovablePhoto(
    onRemove: () -> Unit,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(120.dp)
            .clip(RoundedCornerShape(10.dp)),
    ) {
        content()
        IconButton(
            modifier = Modifier.align(Alignment.TopEnd),
            onClick = onRemove,
        ) {
            Icon(Icons.Outlined.Close, contentDescription = "写真を外す")
        }
    }
}

@Composable
private fun StoredDiaryPhoto(
    model: DiaryFeatureModel,
    reference: String,
    modifier: Modifier = Modifier,
) {
    val bitmap by produceState<Bitmap?>(
        initialValue = null,
        key1 = reference,
    ) {
        value = runCatching {
            val data = model.photoData(reference)
            BitmapFactory.decodeByteArray(
                data,
                0,
                data.size,
            )
        }.getOrNull()
    }
    if (bitmap != null) {
        Image(
            bitmap = bitmap!!.asImageBitmap(),
            contentDescription = "日記の写真",
            modifier = modifier,
            contentScale = ContentScale.Crop,
        )
    } else {
        Box(modifier, contentAlignment = Alignment.Center) {
            Icon(Icons.Outlined.Photo, contentDescription = null)
        }
    }
}

@Composable
private fun ByteArrayDiaryPhoto(data: ByteArray, modifier: Modifier = Modifier) {
    val bitmap = remember(data) { BitmapFactory.decodeByteArray(data, 0, data.size) }
    if (bitmap != null) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = "日記の写真",
            modifier = modifier,
            contentScale = ContentScale.Crop,
        )
    }
}

@Composable
private fun DiaryPhotoGallery(
    photos: List<ByteArray>,
    initialIndex: Int,
    onDismiss: () -> Unit,
) {
    var index by remember { mutableStateOf(initialIndex.coerceIn(photos.indices)) }
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${index + 1} / ${photos.size}",
                    color = Color.White,
                )
                IconButton(onClick = onDismiss) {
                    Icon(
                        Icons.Outlined.Close,
                        contentDescription = "閉じる",
                        tint = Color.White,
                    )
                }
            }
            ZoomableDiaryPhoto(
                data = photos[index],
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            )
            if (photos.size > 1) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    TextButton(
                        enabled = index > 0,
                        onClick = { index -= 1 },
                    ) { Text("前の写真", color = Color.White) }
                    TextButton(
                        enabled = index < photos.lastIndex,
                        onClick = { index += 1 },
                    ) { Text("次の写真", color = Color.White) }
                }
            }
        }
    }
}

@Composable
private fun ZoomableDiaryPhoto(data: ByteArray, modifier: Modifier = Modifier) {
    val bitmap = remember(data) { BitmapFactory.decodeByteArray(data, 0, data.size) }
    var scale by remember { mutableStateOf(1f) }
    var offsetX by remember { mutableStateOf(0f) }
    var offsetY by remember { mutableStateOf(0f) }

    LaunchedEffect(data) {
        scale = 1f
        offsetX = 0f
        offsetY = 0f
    }

    if (bitmap != null) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = "拡大表示中の日記写真",
            contentScale = ContentScale.Fit,
            modifier = modifier
                .graphicsLayer(
                    scaleX = scale,
                    scaleY = scale,
                    translationX = offsetX,
                    translationY = offsetY,
                )
                .pointerInput(Unit) {
                    detectTransformGestures { _, pan, zoom, _ ->
                        scale = (scale * zoom).coerceIn(1f, 5f)
                        if (scale > 1f) {
                            offsetX += pan.x
                            offsetY += pan.y
                        } else {
                            offsetX = 0f
                            offsetY = 0f
                        }
                    }
                }
                .pointerInput(Unit) {
                    detectTapGestures(
                        onDoubleTap = {
                            scale = if (scale > 1f) 1f else 2f
                            if (scale == 1f) {
                                offsetX = 0f
                                offsetY = 0f
                            }
                        },
                    )
                },
        )
    }
}

private fun diaryMoodLabel(mood: DiaryMood): String = when (mood) {
    DiaryMood.VeryGood -> "とても良い"
    DiaryMood.Good -> "良い"
    DiaryMood.Neutral -> "普通"
    DiaryMood.SlightlyBad -> "少し悪い"
    DiaryMood.Bad -> "悪い"
}

private fun formatDiaryDate(instant: Instant): String =
    instant.atZone(ZoneId.systemDefault()).format(
        DateTimeFormatter.ofPattern("yyyy年M月d日"),
    )
