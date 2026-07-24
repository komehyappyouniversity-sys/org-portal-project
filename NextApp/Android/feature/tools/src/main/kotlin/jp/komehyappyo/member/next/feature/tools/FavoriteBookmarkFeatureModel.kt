package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.FavoriteBookmarkRepository
import jp.komehyappyo.member.next.core.data.FavoriteBookmarkBackupService
import jp.komehyappyo.member.next.core.model.FavoriteBookmark
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant
import java.util.UUID

data class FavoriteBookmarkUiState(
    val favorites: List<FavoriteBookmark> = emptyList(),
    val isLoading: Boolean = true,
    val notice: String? = null,
    val errorMessage: String? = null,
)

class FavoriteBookmarkFeatureModel(
    private val repository: FavoriteBookmarkRepository,
    private val backupService: FavoriteBookmarkBackupService =
        FavoriteBookmarkBackupService(repository),
) : ViewModel() {
    private val mutableState = MutableStateFlow(FavoriteBookmarkUiState())
    val state: StateFlow<FavoriteBookmarkUiState> = mutableState

    init {
        observeFavorites()
    }

    private fun observeFavorites() {
        viewModelScope.launch {
            repository.observeAll()
                .catch { error ->
                    mutableState.update {
                        it.copy(
                            isLoading = false,
                            errorMessage = error.localizedMessage,
                        )
                    }
                }
                .collect { favorites ->
                    mutableState.update {
                        it.copy(
                            favorites = favorites,
                            isLoading = false,
                            errorMessage = null,
                        )
                    }
                }
        }
    }

    fun save(
        existing: FavoriteBookmark?,
        title: String,
        url: String,
        note: String,
        category: String,
        onComplete: (Boolean) -> Unit,
    ) {
        viewModelScope.launch {
            runCatching {
                val now = Instant.now()
                FavoriteBookmark(
                    id = existing?.id ?: UUID.randomUUID(),
                    userId = existing?.userId ?: "guest-local",
                    title = title,
                    url = url,
                    note = note,
                    category = category,
                    createdAt = existing?.createdAt ?: now,
                    updatedAt = now,
                ).validated().also { repository.save(it) }
            }.onSuccess {
                mutableState.update {
                    it.copy(
                        notice = if (existing == null) {
                            "お気に入りを追加しました。"
                        } else {
                            "お気に入りを更新しました。"
                        },
                    )
                }
                onComplete(true)
            }.onFailure { error ->
                mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                onComplete(false)
            }
        }
    }

    fun delete(favorite: FavoriteBookmark) {
        viewModelScope.launch {
            runCatching { repository.delete(favorite.id) }
                .onSuccess {
                    mutableState.update { it.copy(notice = "お気に入りを削除しました。") }
                }
                .onFailure { error ->
                    mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                }
        }
    }

    fun clearNotice() {
        mutableState.update { it.copy(notice = null) }
    }

    fun clearError() {
        mutableState.update { it.copy(errorMessage = null) }
    }

    fun exportBackup(onComplete: (Result<ByteArray>) -> Unit) {
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) { backupService.exportData() }
            }.also(onComplete)
        }
    }

    fun importBackup(data: ByteArray, onComplete: (Result<Int>) -> Unit) {
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) { backupService.importData(data) }
            }.also(onComplete)
        }
    }

    class Factory(
        private val repository: FavoriteBookmarkRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            FavoriteBookmarkFeatureModel(repository) as T
    }
}
