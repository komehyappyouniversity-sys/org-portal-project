package jp.komehyappyo.member.next.feature.messages

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
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.ErrorState
import jp.komehyappyo.member.next.core.designsystem.FeatureCard
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.model.MemberPost
import jp.komehyappyo.member.next.core.model.PublicPost

@Composable
fun PostRoot(model: PostFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    val session by model.session.state.collectAsStateWithLifecycle()
    var section by remember { mutableIntStateOf(0) }
    LaunchedEffect(section, session.selectedCommunityId, session.authenticationToken) {
        if (section == 0) model.refreshPublic() else model.refreshMember()
    }
    state.selectedPublicPost?.let {
        PublicPostDetail(it, model::closeDetail)
        return
    }
    state.selectedMemberPost?.let {
        MemberPostDetail(it, state.replies.map { reply -> reply.body }, model)
        return
    }
    val editing = state.isEditing
    if (section == 1 && editing) {
        PostEditor(model)
        return
    }
    Column(modifier = Modifier.fillMaxSize()) {
        TabRow(selectedTabIndex = section) {
            listOf("公開投稿", "会員投稿").forEachIndexed { index, title ->
                Tab(
                    selected = section == index,
                    onClick = { section = index },
                    text = { Text(title) },
                )
            }
        }
        Column(
            modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            state.message?.let { message ->
                ErrorState(message) {
                    if (section == 0) model.refreshPublic() else model.refreshMember()
                }
            }
            if (state.isLoading) LoadingState()
            if (section == 0) {
                Text("公開投稿")
                Text("公開されている投稿は、会員登録前でも閲覧できます。")
                if (!state.isLoading && state.publicPosts.isEmpty()) {
                    EmptyState("公開投稿はありません", "新しい公開投稿が届くと表示されます。")
                }
                state.publicPosts.forEach { post ->
                    FeatureCard(
                        title = post.title.ifBlank { "公開投稿" },
                        description = post.body.take(120),
                        statusLabel = post.categoryId,
                        modifier = Modifier.clickable { model.open(post) },
                    )
                }
            } else if (model.approvedMembership == null) {
                EmptyState(
                    "承認済みコミュニティが必要です",
                    "参加が承認されたコミュニティを選択すると会員投稿を利用できます。",
                )
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text("自分の会員投稿")
                    Button(onClick = model::startCreate) { Text("新規投稿") }
                }
                if (!state.isLoading && state.memberPosts.isEmpty()) {
                    EmptyState("投稿はありません", "「新規投稿」から最初の投稿を作成できます。")
                }
                state.memberPosts.forEach { post ->
                    FeatureCard(
                        title = post.title,
                        description = post.body.take(120),
                        statusLabel = if (post.hasUnreadReply) "新しい返信" else null,
                        modifier = Modifier.clickable { model.open(post) },
                    )
                }
            }
        }
    }
}

@Composable
private fun PostEditor(model: PostFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(if (state.editorPost == null) "会員投稿を作成" else "会員投稿を編集")
        OutlinedTextField(
            value = state.editorTitle,
            onValueChange = model::updateTitle,
            label = { Text("タイトル") },
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = state.editorBody,
            onValueChange = model::updateBody,
            label = { Text("本文") },
            minLines = 8,
            modifier = Modifier.fillMaxWidth(),
        )
        Button(onClick = model::save, enabled = !state.isLoading) { Text("保存") }
        TextButton(onClick = model::cancelEditor) { Text("キャンセル") }
        state.message?.let { Text(it) }
    }
}

@Composable
private fun PublicPostDetail(post: PublicPost, onClose: () -> Unit) {
    val uriHandler = LocalUriHandler.current
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        TextButton(onClick = onClose) { Text("一覧へ戻る") }
        Text(post.title.ifBlank { "公開投稿" })
        Text(post.authorName)
        HorizontalDivider()
        Text(post.body)
        post.attachments.forEach {
            OutlinedButton(onClick = { uriHandler.openUri(it.url) }) { Text(it.name) }
        }
    }
}

@Composable
private fun MemberPostDetail(post: MemberPost, replies: List<String>, model: PostFeatureModel) {
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        TextButton(onClick = model::closeDetail) { Text("一覧へ戻る") }
        Text(post.title)
        HorizontalDivider()
        Text(post.body)
        if (post.adminReply.isNotBlank() || replies.isNotEmpty()) {
            Text("管理者からの返信")
            if (post.adminReply.isNotBlank()) Text(post.adminReply)
            replies.forEach { Text(it) }
        }
        Button(onClick = { model.startEdit(post) }) { Text("編集") }
        TextButton(onClick = { model.delete(post) }) { Text("削除") }
    }
}
