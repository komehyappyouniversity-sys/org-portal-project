package jp.komehyappyo.member.next.feature.community

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.CommunityRepository
import jp.komehyappyo.member.next.core.model.Community
import jp.komehyappyo.member.next.core.model.CommunityAdminAccess
import jp.komehyappyo.member.next.core.model.CommunityCodeParser
import jp.komehyappyo.member.next.core.model.CommunityMembership
import jp.komehyappyo.member.next.core.model.CommunityMembershipStatus
import jp.komehyappyo.member.next.core.model.UserStage
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class CommunityUiState(
    val code: String = "",
    val publicQuery: String = "",
    val publicCommunities: List<Community> = emptyList(),
    val candidate: Community? = null,
    val memberships: List<Pair<CommunityMembership, Community>> = emptyList(),
    val adminAccess: CommunityAdminAccess? = null,
    val pendingApplications: List<CommunityMembership> = emptyList(),
    val reviewingUserId: String? = null,
    val isLoading: Boolean = false,
    val message: String? = null,
)

class CommunityFeatureModel(
    private val repository: CommunityRepository,
    val session: AppSession,
) : ViewModel() {
    private val mutableState = MutableStateFlow(CommunityUiState())
    val state: StateFlow<CommunityUiState> = mutableState.asStateFlow()

    fun updateCode(value: String) {
        mutableState.value = mutableState.value.copy(code = value, message = null)
    }

    fun updatePublicQuery(value: String) {
        mutableState.value = mutableState.value.copy(publicQuery = value, message = null)
    }

    fun refreshPublicCommunities() {
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch {
            repository.publicCommunities(mutableState.value.publicQuery)
                .onSuccess {
                    mutableState.value = mutableState.value.copy(
                        publicCommunities = it,
                        isLoading = false,
                    )
                }
                .onFailure { showError(it, clearCandidate = false) }
        }
    }

    fun prepareApplication(community: Community) {
        if (session.state.value.authenticationToken == null) {
            mutableState.value = mutableState.value.copy(
                message = "参加申請には、マイページから会員登録またはログインが必要です。",
            )
            return
        }
        mutableState.value = mutableState.value.copy(
            code = community.code,
            candidate = community,
            message = if (community.joinEnabled) {
                "参加先を確認し、下の「参加申請」を押してください。"
            } else {
                "このコミュニティは現在、参加申請を受け付けていません。"
            },
        )
    }

    fun receiveScan(value: String) {
        updateCode(CommunityCodeParser.parse(value) ?: value)
        search()
    }

    fun search() {
        val token = session.state.value.authenticationToken
        if (token == null) {
            mutableState.value = mutableState.value.copy(
                message = "先にマイページからログインしてください。",
            )
            return
        }
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch {
            repository.findCommunity(mutableState.value.code, token)
                .onSuccess {
                    mutableState.value = mutableState.value.copy(
                        candidate = it,
                        isLoading = false,
                    )
                }
                .onFailure { showError(it) }
        }
    }

    fun apply() {
        val community = mutableState.value.candidate ?: return
        val current = session.state.value
        val token = current.authenticationToken ?: return
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch {
            repository.apply(community, current.userId, token)
                .onSuccess {
                    mutableState.value = mutableState.value.copy(
                        candidate = null,
                        message = "参加申請を送信しました。承認されるまでお待ちください。",
                    )
                    refresh()
                }
                .onFailure { showError(it) }
        }
    }

    fun refresh() {
        val current = session.state.value
        val token = current.authenticationToken ?: run {
            mutableState.value = mutableState.value.copy(
                candidate = null,
                memberships = emptyList(),
                adminAccess = null,
                pendingApplications = emptyList(),
                reviewingUserId = null,
                isLoading = false,
            )
            return
        }
        mutableState.value = mutableState.value.copy(isLoading = true)
        viewModelScope.launch {
            repository.memberships(current.userId, token)
                .onSuccess { items ->
                    mutableState.value = mutableState.value.copy(
                        memberships = items,
                        isLoading = false,
                    )
                    val approved = items.filter {
                        it.first.status == CommunityMembershipStatus.Approved
                    }
                    if (session.state.value.selectedCommunityId == null) {
                        approved.firstOrNull()?.let { session.selectCommunity(it.second.id) }
                    }
                    session.updateStage(
                        if (approved.isEmpty()) UserStage.Guest else UserStage.Member,
                        current.userId,
                    )
                    refreshManagement()
                }
                .onFailure { showError(it) }
        }
    }

    fun selectCommunity(communityId: String) {
        session.selectCommunity(communityId)
        refreshManagement()
    }

    fun review(
        application: CommunityMembership,
        status: CommunityMembershipStatus,
    ) {
        if (status == CommunityMembershipStatus.Pending) return
        val current = session.state.value
        val communityId = current.selectedCommunityId ?: return
        val token = current.authenticationToken ?: return
        mutableState.value = mutableState.value.copy(
            reviewingUserId = application.userId,
            message = null,
        )
        viewModelScope.launch {
            repository.reviewApplication(
                communityId = communityId,
                applicantUserId = application.userId,
                reviewerUserId = current.userId,
                status = status,
                idToken = token,
            ).onSuccess {
                mutableState.value = mutableState.value.copy(
                    message = if (status == CommunityMembershipStatus.Approved) {
                        "参加申請を承認しました。"
                    } else {
                        "参加申請を却下しました。"
                    },
                )
                refreshManagement()
            }.onFailure(::showError)
            mutableState.value = mutableState.value.copy(reviewingUserId = null)
        }
    }

    private fun refreshManagement() {
        val current = session.state.value
        val communityId = current.selectedCommunityId
        val token = current.authenticationToken
        if (communityId == null || token == null) {
            mutableState.value = mutableState.value.copy(
                adminAccess = null,
                pendingApplications = emptyList(),
            )
            return
        }
        viewModelScope.launch {
            repository.adminAccess(communityId, current.userId, token)
                .onSuccess { access ->
                    mutableState.value = mutableState.value.copy(adminAccess = access)
                    if (access?.canReviewMembers == true) {
                        repository.pendingApplications(communityId, token)
                            .onSuccess { applications ->
                                mutableState.value = mutableState.value.copy(
                                    pendingApplications = applications,
                                )
                            }
                            .onFailure(::showError)
                    } else {
                        mutableState.value = mutableState.value.copy(
                            pendingApplications = emptyList(),
                        )
                    }
                }
                .onFailure(::showError)
        }
    }

    private fun showError(error: Throwable, clearCandidate: Boolean = true) {
        mutableState.value = mutableState.value.copy(
            candidate = if (clearCandidate) null else mutableState.value.candidate,
            isLoading = false,
            message = error.message ?: "処理に失敗しました。",
        )
    }

    class Factory(
        private val repository: CommunityRepository,
        private val session: AppSession,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            CommunityFeatureModel(repository, session) as T
    }
}
