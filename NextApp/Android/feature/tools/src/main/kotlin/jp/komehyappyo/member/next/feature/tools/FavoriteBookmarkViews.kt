package jp.komehyappyo.member.next.feature.tools

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Launch
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.IosShare
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.ErrorState
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.model.FavoriteBookmark

@Composable
fun FavoriteBookmarksRoot(model: FavoriteBookmarkFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var editingFavorite by remember { mutableStateOf<FavoriteBookmark?>(null) }
    var showsNewFavorite by remember { mutableStateOf(false) }
    var backupMessage by remember { mutableStateOf<String?>(null) }
    val createBackup = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri ->
        if (uri != null) {
            model.exportBackup { result ->
                result.fold(
                    onSuccess = { data ->
                        runCatching {
                            context.contentResolver.openOutputStream(uri)?.use { output ->
                                output.write(data)
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
                                backupMessage = "${it}件のお気に入りを復元しました。"
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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("お気に入り", style = MaterialTheme.typography.headlineSmall)
            Button(onClick = { showsNewFavorite = true }) {
                Icon(Icons.Outlined.Add, contentDescription = null)
                Text("追加")
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TextButton(
                enabled = state.favorites.isNotEmpty(),
                onClick = { createBackup.launch("お気に入りバックアップ.json") },
            ) {
                Icon(Icons.Outlined.FileUpload, contentDescription = null)
                Text("書き出す")
            }
            TextButton(
                onClick = { openBackup.launch(arrayOf("application/json")) },
            ) {
                Icon(Icons.Outlined.FileDownload, contentDescription = null)
                Text("読み込む")
            }
        }

        when {
            state.isLoading -> LoadingState()
            state.errorMessage != null && state.favorites.isEmpty() -> ErrorState(
                message = state.errorMessage.orEmpty(),
                onRetry = model::clearError,
            )
            state.favorites.isEmpty() -> EmptyState(
                title = "お気に入りはまだありません",
                message = "よく見るWebページを登録できます。",
            )
            else -> LazyColumn(
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(state.favorites, key = { it.id }) { favorite ->
                    FavoriteBookmarkCard(
                        favorite = favorite,
                        onOpen = { openUrl(context, favorite.url) },
                        onShare = { shareFavorite(context, favorite) },
                        onEdit = { editingFavorite = favorite },
                        onDelete = { model.delete(favorite) },
                    )
                }
            }
        }
    }

    if (showsNewFavorite || editingFavorite != null) {
        FavoriteBookmarkDialog(
            existing = editingFavorite,
            onDismiss = {
                showsNewFavorite = false
                editingFavorite = null
            },
            onSave = { title, url, note, category ->
                model.save(editingFavorite, title, url, note, category) { success ->
                    if (success) {
                        showsNewFavorite = false
                        editingFavorite = null
                    }
                }
            },
            onDelete = editingFavorite?.let { favorite ->
                {
                    model.delete(favorite)
                    editingFavorite = null
                }
            },
        )
    }

    state.notice?.let { notice ->
        AlertDialog(
            onDismissRequest = model::clearNotice,
            confirmButton = {
                TextButton(onClick = model::clearNotice) { Text("閉じる") }
            },
            title = { Text("お知らせ") },
            text = { Text(notice) },
        )
    }
    if (state.errorMessage != null && state.favorites.isNotEmpty()) {
        AlertDialog(
            onDismissRequest = model::clearError,
            confirmButton = {
                TextButton(onClick = model::clearError) { Text("閉じる") }
            },
            title = { Text("処理できませんでした") },
            text = { Text(state.errorMessage.orEmpty()) },
        )
    }
    backupMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { backupMessage = null },
            confirmButton = {
                TextButton(onClick = { backupMessage = null }) { Text("OK") }
            },
            text = { Text(message) },
        )
    }
}

@Composable
private fun FavoriteBookmarkCard(
    favorite: FavoriteBookmark,
    onOpen: () -> Unit,
    onShare: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(favorite.title, style = MaterialTheme.typography.titleMedium)
                    Text(
                        favorite.category,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
                IconButton(onClick = onEdit) {
                    Icon(Icons.Outlined.Edit, contentDescription = "${favorite.title}を編集")
                }
                IconButton(onClick = onDelete) {
                    Icon(Icons.Outlined.Delete, contentDescription = "${favorite.title}を削除")
                }
            }
            Text(
                favorite.url,
                style = MaterialTheme.typography.bodySmall,
                maxLines = 1,
            )
            if (favorite.note.isNotEmpty()) {
                Text(favorite.note, style = MaterialTheme.typography.bodyMedium)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = onOpen) {
                    Icon(Icons.AutoMirrored.Outlined.Launch, contentDescription = null)
                    Text("リンクを開く")
                }
                TextButton(onClick = onShare) {
                    Icon(Icons.Outlined.IosShare, contentDescription = null)
                    Text("共有")
                }
            }
        }
    }
}

@Composable
private fun FavoriteBookmarkDialog(
    existing: FavoriteBookmark?,
    onDismiss: () -> Unit,
    onSave: (String, String, String, String) -> Unit,
    onDelete: (() -> Unit)?,
) {
    var title by remember(existing?.id) { mutableStateOf(existing?.title.orEmpty()) }
    var url by remember(existing?.id) { mutableStateOf(existing?.url ?: "https://") }
    var note by remember(existing?.id) { mutableStateOf(existing?.note.orEmpty()) }
    var category by remember(existing?.id) {
        mutableStateOf(existing?.category ?: FavoriteBookmark.UNCATEGORIZED)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (existing == null) "お気に入りを追加" else "お気に入りを編集") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("タイトル（必須）") },
                )
                OutlinedTextField(
                    value = url,
                    onValueChange = { url = it },
                    label = { Text("URL（必須）") },
                )
                OutlinedTextField(
                    value = category,
                    onValueChange = { category = it },
                    label = { Text("カテゴリ") },
                )
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("メモ") },
                    minLines = 3,
                )
                if (onDelete != null) {
                    TextButton(onClick = onDelete) { Text("このお気に入りを削除") }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(title, url, note, category) }) { Text("保存") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("キャンセル") }
        },
    )
}

private fun openUrl(context: Context, url: String) {
    context.startActivity(
        Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
    )
}

private fun shareFavorite(context: Context, favorite: FavoriteBookmark) {
    val text = listOf(favorite.title, favorite.url, favorite.note)
        .filter(String::isNotBlank)
        .joinToString(separator = "\n")
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }
    context.startActivity(
        Intent.createChooser(intent, "お気に入りを共有")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
    )
}
