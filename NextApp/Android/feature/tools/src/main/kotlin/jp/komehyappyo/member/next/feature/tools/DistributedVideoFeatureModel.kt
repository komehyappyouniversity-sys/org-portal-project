package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.CommunityRepository
import jp.komehyappyo.member.next.core.model.DistributedVideo
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class DistributedVideosUiState(
    val videos: List<DistributedVideo> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

class DistributedVideoFeatureModel(
    private val repository: CommunityRepository,
    private val session: AppSession,
    private val canViewMembersOnlyVideo: (String) -> Boolean,
) : ViewModel() {
    private val mutableState = MutableStateFlow(DistributedVideosUiState())
    val state: StateFlow<DistributedVideosUiState> = mutableState.asStateFlow()

    fun load() {
        val current = session.state.value
        val communityId = current.selectedCommunityId
        val token = current.authenticationToken
        if (communityId == null || token == null) {
            mutableState.value = DistributedVideosUiState()
            return
        }
        mutableState.update {
            it.copy(isLoading = true, errorMessage = null)
        }
        viewModelScope.launch {
            repository.communityVideos(communityId, token)
                .onSuccess { videos ->
                    val canViewMembersOnly = canViewMembersOnlyVideo(communityId)
                    mutableState.update {
                        it.copy(
                            videos = filterDistributedVideos(
                                videos,
                                canViewMembersOnly,
                            ),
                            isLoading = false,
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error ->
                    mutableState.update {
                        it.copy(
                            isLoading = false,
                            errorMessage = "動画を取得できませんでした。",
                        )
                    }
                }
        }
    }

    fun clearError() {
        mutableState.update { it.copy(errorMessage = null) }
    }

    class Factory(
        private val repository: CommunityRepository,
        private val session: AppSession,
        private val canViewMembersOnlyVideo: (String) -> Boolean,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
            return DistributedVideoFeatureModel(
                repository,
                session,
                canViewMembersOnlyVideo,
            ) as T
        }
    }
}

internal fun filterDistributedVideos(
    videos: List<DistributedVideo>,
    canViewMembersOnlyVideo: Boolean,
): List<DistributedVideo> {
    return videos
        .filter { video ->
            !video.isPremium &&
                (!video.isMembersOnly || canViewMembersOnlyVideo)
        }
        .sortedWith(
            compareBy<DistributedVideo> { it.sortOrder }
                .thenBy { it.title },
        )
}
