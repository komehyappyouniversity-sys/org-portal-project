package jp.komehyappyo.member.next.feature.messages

import android.content.Intent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.ErrorState
import jp.komehyappyo.member.next.core.designsystem.FeatureCard
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.model.Announcement

@Composable
fun AnnouncementRoot(model: AnnouncementFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    val session by model.session.state.collectAsStateWithLifecycle()
    LaunchedEffect(session.selectedCommunityId, session.authenticationToken) {
        model.refresh()
    }
    state.selected?.let {
        AnnouncementDetail(it, model::closeDetail)
        return
    }
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Column {
                Text("お知らせ")
                Text(if (session.authenticationToken == null) "公開のお知らせ" else "参加コミュニティのお知らせ")
            }
            TextButton(onClick = model::refresh) { Text("更新") }
        }
        when {
            state.isLoading -> LoadingState()
            state.errorMessage != null -> ErrorState(state.errorMessage!!, model::refresh)
            state.announcements.isEmpty() -> EmptyState(
                "お知らせはありません",
                "新しいお知らせが届くとここに表示されます。",
            )
            else -> {
                val unread = state.announcements.filterNot { it.id in state.readIds }
                val read = state.announcements.filter { it.id in state.readIds }
                if (unread.isNotEmpty()) {
                    Text("未読 ${unread.size}件")
                    unread.forEach { AnnouncementRow(it, false) { model.open(it) } }
                }
                if (read.isNotEmpty()) {
                    Text("既読")
                    read.forEach { AnnouncementRow(it, true) { model.open(it) } }
                }
            }
        }
    }
}

@Composable
private fun AnnouncementRow(item: Announcement, isRead: Boolean, onClick: () -> Unit) {
    FeatureCard(
        title = item.title,
        description = item.body.take(100),
        statusLabel = if (isRead) "既読" else "未読",
        modifier = Modifier.clickable(onClick = onClick),
    )
}

@Composable
private fun AnnouncementDetail(item: Announcement, onClose: () -> Unit) {
    val context = LocalContext.current
    val uriHandler = LocalUriHandler.current
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        TextButton(onClick = onClose) { Text("一覧へ戻る") }
        Text(item.title)
        item.createdAt?.let { Text(it) }
        HorizontalDivider()
        Text(item.body)
        item.attachments.forEach { attachment ->
            OutlinedButton(onClick = { uriHandler.openUri(attachment.url) }) {
                Text(attachment.name)
            }
        }
        item.zoomUrl?.let { url ->
            OutlinedButton(onClick = { uriHandler.openUri(url) }) { Text("Zoomを開く") }
        }
        item.videoUrl?.let { url ->
            OutlinedButton(onClick = { uriHandler.openUri(url) }) { Text("動画を開く") }
        }
        Button(
            onClick = {
                context.startActivity(
                    Intent.createChooser(
                        Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_SUBJECT, item.title)
                            putExtra(Intent.EXTRA_TEXT, "${item.title}\n\n${item.body}")
                        },
                        "お知らせを共有",
                    ),
                )
            },
        ) {
            Text("共有")
        }
    }
}
