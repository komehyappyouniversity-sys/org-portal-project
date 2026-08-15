package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.ManualRepository
import jp.komehyappyo.member.next.core.model.Manual
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ManualUiState(
    val manuals: List<Manual> = emptyList(),
    val isLoading: Boolean = false,
    val hasLoaded: Boolean = false,
    val errorMessage: String? = null,
)

class ManualFeatureModel(
    private val repository: ManualRepository,
    private val session: AppSession,
) : ViewModel() {
    private val mutableState = MutableStateFlow(ManualUiState())
    val state: StateFlow<ManualUiState> = mutableState.asStateFlow()
    private var loadJob: Job? = null

    fun load() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            mutableState.value = mutableState.value.copy(
                isLoading = true,
                errorMessage = null,
            )
            val sessionState = session.state.value
            repository.manuals(
                communityId = sessionState.selectedCommunityId,
                idToken = sessionState.authenticationToken,
            ).fold(
                onSuccess = {
                    mutableState.value = ManualUiState(
                        manuals = it,
                        hasLoaded = true,
                    )
                },
                onFailure = {
                    mutableState.value = ManualUiState(
                        hasLoaded = true,
                        errorMessage = "マニュアルを読み込めませんでした。",
                    )
                },
            )
        }
    }

    class Factory(
        private val repository: ManualRepository,
        private val session: AppSession,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            ManualFeatureModel(repository, session) as T
    }
}
