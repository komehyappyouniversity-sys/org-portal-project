package jp.komehyappyo.member.next.feature.messages

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.AnnouncementRepository
import jp.komehyappyo.member.next.core.model.Announcement
import jp.komehyappyo.member.next.core.model.CommunityMembership
import jp.komehyappyo.member.next.core.model.CommunityMembershipStatus
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AnnouncementUiState(
    val announcements: List<Announcement> = emptyList(),
    val readIds: Set<String> = emptySet(),
    val selected: Announcement? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

class AnnouncementFeatureModel(
    private val repository: AnnouncementRepository,
    val session: AppSession,
    private val memberships: () -> List<CommunityMembership>,
) : ViewModel() {
    private val mutableState = MutableStateFlow(AnnouncementUiState())
    val state: StateFlow<AnnouncementUiState> = mutableState.asStateFlow()

    fun refresh() {
        val current = session.state.value
        val membership = memberships().firstOrNull {
            it.communityId == current.selectedCommunityId &&
                it.status == CommunityMembershipStatus.Approved
        }
        mutableState.value = mutableState.value.copy(isLoading = true, errorMessage = null)
        viewModelScope.launch {
            repository.announcements(
                communityId = current.selectedCommunityId,
                membership = membership,
                userId = current.userId.takeUnless { it == "guest" },
                idToken = current.authenticationToken,
            ).onSuccess { announcements ->
                mutableState.value = mutableState.value.copy(
                    announcements = announcements,
                    isLoading = false,
                )
            }.onFailure(::showError)
            val userId = current.userId.takeUnless { it == "guest" }
            val token = current.authenticationToken
            if (userId != null && token != null) {
                repository.readAnnouncementIds(userId, token).onSuccess {
                    mutableState.value = mutableState.value.copy(readIds = it)
                }
            }
        }
    }

    fun open(announcement: Announcement) {
        mutableState.value = mutableState.value.copy(selected = announcement)
        val current = session.state.value
        val token = current.authenticationToken ?: return
        if (current.userId == "guest" || announcement.id in mutableState.value.readIds) return
        viewModelScope.launch {
            repository.markRead(current.userId, announcement.id, token).onSuccess {
                mutableState.value = mutableState.value.copy(
                    readIds = mutableState.value.readIds + announcement.id,
                )
            }
        }
    }

    fun closeDetail() {
        mutableState.value = mutableState.value.copy(selected = null)
    }

    private fun showError(error: Throwable) {
        mutableState.value = mutableState.value.copy(
            isLoading = false,
            errorMessage = error.message ?: "お知らせを読み込めませんでした。",
        )
    }

    class Factory(
        private val repository: AnnouncementRepository,
        private val session: AppSession,
        private val memberships: () -> List<CommunityMembership>,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            AnnouncementFeatureModel(repository, session, memberships) as T
    }
}
