package jp.komehyappyo.member.next.core.session

import jp.komehyappyo.member.next.core.model.UserStage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class SessionState(
    val userId: String = "guest",
    val stage: UserStage = UserStage.Guest,
    val selectedCommunityId: String? = null,
    val previousCommunityId: String? = null,
    val authenticationToken: String? = null,
)

class AppSession {
    private val mutableState = MutableStateFlow(SessionState())
    val state: StateFlow<SessionState> = mutableState.asStateFlow()

    fun updateStage(stage: UserStage, userId: String) {
        mutableState.value = mutableState.value.copy(stage = stage, userId = userId)
    }

    fun updateAuthenticatedUser(userId: String, idToken: String) {
        mutableState.value = mutableState.value.copy(
            userId = userId,
            authenticationToken = idToken,
        )
    }

    fun logout() {
        mutableState.value = SessionState()
    }

    fun selectCommunity(communityId: String?) {
        if (communityId == mutableState.value.selectedCommunityId) return
        mutableState.value = mutableState.value.copy(
            selectedCommunityId = communityId,
            previousCommunityId = mutableState.value.selectedCommunityId,
        )
    }

    fun returnToPreviousCommunity() {
        val current = mutableState.value.selectedCommunityId
        mutableState.value = mutableState.value.copy(
            selectedCommunityId = mutableState.value.previousCommunityId,
            previousCommunityId = current,
        )
    }
}
