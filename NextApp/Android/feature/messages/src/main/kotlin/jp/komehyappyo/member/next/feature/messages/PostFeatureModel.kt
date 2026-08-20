package jp.komehyappyo.member.next.feature.messages

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.PostRepository
import jp.komehyappyo.member.next.core.model.AdminReply
import jp.komehyappyo.member.next.core.model.CommunityMembership
import jp.komehyappyo.member.next.core.model.CommunityMembershipStatus
import jp.komehyappyo.member.next.core.model.MemberPost
import jp.komehyappyo.member.next.core.model.PublicPost
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class PostUiState(
    val publicPosts: List<PublicPost> = emptyList(),
    val memberPosts: List<MemberPost> = emptyList(),
    val managementMemberPosts: List<MemberPost> = emptyList(),
    val selectedPublicPost: PublicPost? = null,
    val selectedMemberPost: MemberPost? = null,
    val selectedManagementMemberPost: MemberPost? = null,
    val managementReplyDraft: String = "",
    val replies: List<AdminReply> = emptyList(),
    val isEditing: Boolean = false,
    val editorPost: MemberPost? = null,
    val editorTitle: String = "",
    val editorBody: String = "",
    val isLoading: Boolean = false,
    val message: String? = null,
)

class PostFeatureModel(
    private val repository: PostRepository,
    val session: AppSession,
    private val memberships: () -> List<CommunityMembership>,
) : ViewModel() {
    private var pendingNotificationId: String? = null
    private val mutableState = MutableStateFlow(PostUiState())
    val state: StateFlow<PostUiState> = mutableState.asStateFlow()

    val approvedMembership: CommunityMembership?
        get() = memberships().firstOrNull {
            it.communityId == session.state.value.selectedCommunityId &&
                it.status == CommunityMembershipStatus.Approved
        }

    fun refreshPublic() = launchLoad {
        repository.publicPosts().onSuccess {
            mutableState.value = mutableState.value.copy(publicPosts = it, isLoading = false)
        }.onFailure(::showError)
    }

    fun refreshManagementMemberPosts() {
        val current = session.state.value
        val membership = approvedMembership
        val token = current.authenticationToken
        if (membership == null || token == null) {
            mutableState.value = mutableState.value.copy(
                managementMemberPosts = emptyList(),
                isLoading = false,
            )
            return
        }
        launchLoad {
            repository.allMemberPosts(
                membership.communityId,
                token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(
                    managementMemberPosts = it,
                    isLoading = false,
                )
            }.onFailure(::showError)
        }
    }

    fun refreshMember() {
        val current = session.state.value
        val membership = approvedMembership
        val token = current.authenticationToken
        if (membership == null || token == null) {
            mutableState.value = mutableState.value.copy(memberPosts = emptyList(), isLoading = false)
            return
        }
        launchLoad {
            repository.memberPosts(
                membership.communityId,
                current.userId,
                token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(memberPosts = it, isLoading = false)
                pendingNotificationId?.let { targetId ->
                    it.firstOrNull { post -> post.id == targetId }?.let { post ->
                        pendingNotificationId = null
                        open(post)
                    }
                }
            }.onFailure(::showError)
        }
    }

    fun open(post: PublicPost) {
        mutableState.value = mutableState.value.copy(selectedPublicPost = post)
    }

    fun open(post: MemberPost) {
        mutableState.value = mutableState.value.copy(selectedMemberPost = post, replies = emptyList())
        val token = session.state.value.authenticationToken ?: return
        viewModelScope.launch {
            repository.replies(post.communityId, post.id, token).onSuccess {
                mutableState.value = mutableState.value.copy(replies = it)
            }
            if (post.hasUnreadReply) repository.markReplyRead(post.communityId, post.id, token)
        }
    }

    fun openFromNotification(postId: String) {
        pendingNotificationId = postId
        mutableState.value.memberPosts.firstOrNull { it.id == postId }?.let {
            pendingNotificationId = null
            open(it)
        } ?: refreshMember()
    }

    fun closeDetail() {
        mutableState.value = mutableState.value.copy(
            selectedPublicPost = null,
            selectedMemberPost = null,
            replies = emptyList(),
        )
        refreshMember()
    }

    fun startCreate() {
        mutableState.value = mutableState.value.copy(
            isEditing = true,
            editorPost = null,
            editorTitle = "",
            editorBody = "",
            message = null,
        )
    }

    fun startEdit(post: MemberPost) {
        mutableState.value = mutableState.value.copy(
            isEditing = true,
            editorPost = post,
            editorTitle = post.title,
            editorBody = post.body,
            selectedMemberPost = null,
        )
    }

    fun updateTitle(value: String) {
        mutableState.value = mutableState.value.copy(editorTitle = value)
    }

    fun updateBody(value: String) {
        mutableState.value = mutableState.value.copy(editorBody = value)
    }

    fun save() {
        val current = session.state.value
        val membership = approvedMembership
        val title = mutableState.value.editorTitle.trim()
        val body = mutableState.value.editorBody.trim()
        val token = current.authenticationToken
        if (membership == null || token == null) {
            showError(IllegalStateException("承認済みコミュニティを選択してください。"))
            return
        }
        if (title.isBlank() || body.isBlank()) {
            showError(IllegalArgumentException("タイトルと本文を入力してください。"))
            return
        }
        launchLoad {
            val editing = mutableState.value.editorPost
            val result = if (editing == null) {
                repository.createMemberPost(
                    membership.communityId,
                    current.userId,
                    membership.applicantName ?: "会員",
                    title,
                    body,
                    token,
                )
            } else {
                repository.updateMemberPost(editing.communityId, editing.id, title, body, token)
            }
            result.onSuccess {
                mutableState.value = mutableState.value.copy(
                    isEditing = false,
                    editorPost = null,
                    editorTitle = "",
                    editorBody = "",
                    isLoading = false,
                    message = "投稿を保存しました。",
                )
                refreshMember()
            }.onFailure(::showError)
        }
    }

    fun delete(post: MemberPost) {
        val token = session.state.value.authenticationToken ?: return
        launchLoad {
            repository.deleteMemberPost(post.communityId, post.id, token).onSuccess {
                mutableState.value = mutableState.value.copy(
                    selectedMemberPost = null,
                    isLoading = false,
                    message = "投稿を削除しました。",
                )
                refreshMember()
            }.onFailure(::showError)
        }
    }

    fun cancelEditor() {
        mutableState.value = mutableState.value.copy(
            isEditing = false,
            editorPost = null,
            editorTitle = "",
            editorBody = "",
        )
    }

    fun startManagementReply(post: MemberPost) {
        mutableState.value = mutableState.value.copy(
            selectedManagementMemberPost = post,
            managementReplyDraft = post.adminReply,
            selectedMemberPost = null,
        )
    }

    fun updateManagementReplyDraft(value: String) {
        mutableState.value = mutableState.value.copy(managementReplyDraft = value)
    }

    fun closeManagementReply() {
        mutableState.value = mutableState.value.copy(
            selectedManagementMemberPost = null,
            managementReplyDraft = "",
        )
    }

    fun saveManagementReply() {
        val current = session.state.value
        val membership = approvedMembership
        val selected = mutableState.value.selectedManagementMemberPost
        val token = current.authenticationToken
        val draft = mutableState.value.managementReplyDraft.trim()
        if (selected == null || membership == null || token == null) {
            showError(IllegalStateException("承認済みコミュニティを選択してください。"))
            return
        }
        if (draft.isBlank()) {
            showError(IllegalArgumentException("返信内容を入力してください。"))
            return
        }
        launchLoad {
            repository.saveAdminReply(
                selected.communityId,
                selected.id,
                current.userId,
                membership.applicantName,
                draft,
                token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(
                    selectedManagementMemberPost = null,
                    managementReplyDraft = "",
                    isLoading = false,
                    message = "返信を保存しました。",
                )
                refreshManagementMemberPosts()
            }.onFailure(::showError)
        }
    }

    private fun launchLoad(block: suspend () -> Unit) {
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch { block() }
    }

    private fun showError(error: Throwable) {
        mutableState.value = mutableState.value.copy(
            isLoading = false,
            message = error.message ?: "投稿を処理できませんでした。",
        )
    }

    class Factory(
        private val repository: PostRepository,
        private val session: AppSession,
        private val memberships: () -> List<CommunityMembership>,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            PostFeatureModel(repository, session, memberships) as T
    }
}
