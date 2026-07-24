package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.SnsCustomLinkRepository
import jp.komehyappyo.member.next.core.model.SnsCustomLink
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class SnsPostingAssistantUiState(
    val customLinks: List<SnsCustomLink> = emptyList(),
    val notice: String? = null,
    val errorMessage: String? = null,
)

class SnsPostingAssistantFeatureModel(
    private val repository: SnsCustomLinkRepository,
) : ViewModel() {
    private val mutableState = MutableStateFlow(SnsPostingAssistantUiState())
    val state: StateFlow<SnsPostingAssistantUiState> = mutableState

    init {
        viewModelScope.launch {
            repository.observeAll()
                .catch { error ->
                    mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                }
                .collect { links ->
                    mutableState.update { it.copy(customLinks = links) }
                }
        }
    }

    fun save(
        existing: SnsCustomLink?,
        title: String,
        url: String,
        onComplete: (Boolean) -> Unit,
    ) {
        viewModelScope.launch {
            runCatching {
                if (
                    existing == null &&
                    mutableState.value.customLinks.size >= SnsCustomLink.MAXIMUM_CUSTOM_LINKS
                ) {
                    error("独自リンクは2件まで登録できます。")
                }
                val value = SnsCustomLink(
                    id = existing?.id ?: java.util.UUID.randomUUID(),
                    userId = existing?.userId ?: "guest-local",
                    title = title,
                    url = url,
                    sortOrder = existing?.sortOrder ?: mutableState.value.customLinks.size,
                ).validated()
                repository.save(value)
            }.onSuccess {
                mutableState.update {
                    it.copy(
                        notice = if (existing == null) {
                            "独自リンクを追加しました。"
                        } else {
                            "独自リンクを更新しました。"
                        },
                        errorMessage = null,
                    )
                }
                onComplete(true)
            }.onFailure { error ->
                mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                onComplete(false)
            }
        }
    }

    fun delete(link: SnsCustomLink) {
        viewModelScope.launch {
            runCatching { repository.delete(link.id) }
                .onSuccess {
                    mutableState.update { it.copy(notice = "独自リンクを削除しました。") }
                }
                .onFailure { error ->
                    mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                }
        }
    }

    fun showNotice(message: String) {
        mutableState.update { it.copy(notice = message) }
    }

    fun clearNotice() {
        mutableState.update { it.copy(notice = null) }
    }

    fun clearError() {
        mutableState.update { it.copy(errorMessage = null) }
    }

    class Factory(
        private val repository: SnsCustomLinkRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            SnsPostingAssistantFeatureModel(repository) as T
    }
}
