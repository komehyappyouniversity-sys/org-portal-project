package jp.komehyappyo.member.next.core.session

import jp.komehyappyo.member.next.core.model.UserStage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class SessionState(
    val userId: String = "guest",
    val stage: UserStage = UserStage.Guest,
    val selectedCommunityId: String? = null,
)

class AppSession {
    private val mutableState = MutableStateFlow(SessionState())
    val state: StateFlow<SessionState> = mutableState.asStateFlow()

    fun updateStage(stage: UserStage, userId: String) {
        mutableState.value = mutableState.value.copy(stage = stage, userId = userId)
    }

    fun selectCommunity(communityId: String?) {
        mutableState.value = mutableState.value.copy(selectedCommunityId = communityId)
    }
}
