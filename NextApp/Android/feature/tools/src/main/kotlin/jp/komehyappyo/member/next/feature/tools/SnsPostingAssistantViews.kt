package jp.komehyappyo.member.next.feature.tools

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Facebook
import androidx.compose.material.icons.outlined.IosShare
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.QuestionAnswer
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
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
import jp.komehyappyo.member.next.core.model.SnsCustomLink

@Composable
fun SnsPostingAssistantRoot(model: SnsPostingAssistantFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var message by remember { mutableStateOf("") }
    var editingLink by remember { mutableStateOf<SnsCustomLink?>(null) }
    var showsNewLink by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("SNS投稿補助", style = MaterialTheme.typography.headlineSmall)
        OutlinedTextField(
            value = message,
            onValueChange = { message = it },
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 160.dp),
            label = { Text("投稿文章") },
            supportingText = {
                Text("文章は自動投稿されません。移動先のSNSで内容を確認してください。")
            },
        )
        Button(
            onClick = {
                copyMessage(context, message)
                model.showNotice("投稿文章をコピーしました。")
            },
            enabled = message.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(Icons.Outlined.ContentCopy, contentDescription = null)
            Text("文章をコピー")
        }
        Button(
            onClick = { openShareMenu(context, message) },
            enabled = message.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(Icons.Outlined.IosShare, contentDescription = null)
            Text("共有メニューを開く")
        }

        Text("SNSを開く", style = MaterialTheme.typography.titleMedium)
        SnsDestinationButton(
            title = "Facebook",
            icon = { Icon(Icons.Outlined.Facebook, contentDescription = null) },
            enabled = message.isNotBlank(),
        ) {
            copyAndOpen(
                context,
                message,
                "fb://",
                "https://www.facebook.com/",
            )
        }
        SnsDestinationButton(
            title = "Instagram",
            icon = { Icon(Icons.Outlined.PhotoCamera, contentDescription = null) },
            enabled = message.isNotBlank(),
        ) {
            copyAndOpen(
                context,
                message,
                "instagram://app",
                "https://www.instagram.com/",
            )
        }
        SnsDestinationButton(
            title = "X",
            icon = { Icon(Icons.Outlined.QuestionAnswer, contentDescription = null) },
            enabled = message.isNotBlank(),
        ) {
            val encoded = Uri.encode(message.trim())
            copyAndOpen(
                context,
                message,
                "twitter://post?message=$encoded",
                "https://x.com/intent/post?text=$encoded",
            )
        }

        HorizontalDivider()
        Text("独自リンク", style = MaterialTheme.typography.titleMedium)
        state.customLinks.forEach { link ->
            Row(modifier = Modifier.fillMaxWidth()) {
                TextButton(
                    onClick = {
                        copyAndOpen(context, message, null, link.url)
                    },
                    enabled = message.isNotBlank(),
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Outlined.Link, contentDescription = null)
                    Column(modifier = Modifier.padding(start = 8.dp)) {
                        Text(link.title)
                        Text(
                            link.url,
                            style = MaterialTheme.typography.bodySmall,
                            maxLines = 1,
                        )
                    }
                }
                IconButton(onClick = { editingLink = link }) {
                    Icon(Icons.Outlined.Edit, contentDescription = "${link.title}を編集")
                }
            }
        }
        if (state.customLinks.size < SnsCustomLink.MAXIMUM_CUSTOM_LINKS) {
            TextButton(onClick = { showsNewLink = true }) {
                Icon(Icons.Outlined.Add, contentDescription = null)
                Text("独自リンクを追加")
            }
        }
        Text(
            "よく使う投稿先を2件まで登録できます。",
            style = MaterialTheme.typography.bodySmall,
        )
    }

    if (showsNewLink || editingLink != null) {
        SnsCustomLinkDialog(
            existing = editingLink,
            onDismiss = {
                showsNewLink = false
                editingLink = null
            },
            onSave = { title, url ->
                model.save(editingLink, title, url) { success ->
                    if (success) {
                        showsNewLink = false
                        editingLink = null
                    }
                }
            },
            onDelete = editingLink?.let { link ->
                {
                    model.delete(link)
                    editingLink = null
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
    state.errorMessage?.let { error ->
        AlertDialog(
            onDismissRequest = model::clearError,
            confirmButton = {
                TextButton(onClick = model::clearError) { Text("閉じる") }
            },
            title = { Text("処理できませんでした") },
            text = { Text(error) },
        )
    }
}

@Composable
private fun SnsDestinationButton(
    title: String,
    icon: @Composable () -> Unit,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
    ) {
        icon()
        Text("コピーして${title}を開く")
    }
}

@Composable
private fun SnsCustomLinkDialog(
    existing: SnsCustomLink?,
    onDismiss: () -> Unit,
    onSave: (String, String) -> Unit,
    onDelete: (() -> Unit)?,
) {
    var title by remember(existing?.id) { mutableStateOf(existing?.title.orEmpty()) }
    var url by remember(existing?.id) { mutableStateOf(existing?.url ?: "https://") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (existing == null) "独自リンクを追加" else "独自リンクを編集") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("リンク名") },
                )
                OutlinedTextField(
                    value = url,
                    onValueChange = { url = it },
                    label = { Text("URL") },
                )
                if (onDelete != null) {
                    TextButton(onClick = onDelete) { Text("独自リンクを削除") }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(title, url) }) { Text("保存") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("キャンセル") }
        },
    )
}

private fun copyMessage(context: Context, message: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("SNS投稿文章", message.trim()))
}

private fun copyAndOpen(
    context: Context,
    message: String,
    appUrl: String?,
    webUrl: String,
) {
    copyMessage(context, message)
    val appIntent = appUrl?.let {
        Intent(Intent.ACTION_VIEW, Uri.parse(it)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    val openedApp = appIntent?.let {
        runCatching {
            context.startActivity(it)
            true
        }.getOrDefault(false)
    } ?: false
    if (!openedApp) {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(webUrl))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}

private fun openShareMenu(context: Context, message: String) {
    val shareIntent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, message.trim())
    }
    context.startActivity(
        Intent.createChooser(shareIntent, "投稿文章を共有")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
    )
}
