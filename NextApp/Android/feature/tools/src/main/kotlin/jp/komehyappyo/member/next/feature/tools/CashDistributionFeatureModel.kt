package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.CashDistributionBackupService
import jp.komehyappyo.member.next.core.data.CashDistributionRepository
import jp.komehyappyo.member.next.core.model.CashDistribution
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class CashDistributionUiState(
    val distributions: List<CashDistribution> = emptyList(),
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
)

class CashDistributionFeatureModel(
    private val repository: CashDistributionRepository,
    private val backupService: CashDistributionBackupService,
) : ViewModel() {
    private val mutableState = MutableStateFlow(CashDistributionUiState())
    val state: StateFlow<CashDistributionUiState> = mutableState

    init {
        reload()
    }

    fun reload() {
        viewModelScope.launch {
            mutableState.update { it.copy(isLoading = true, errorMessage = null) }
            repository.observeAll()
                .catch { error ->
                    mutableState.update {
                        it.copy(isLoading = false, errorMessage = error.localizedMessage)
                    }
                }
                .collect { values ->
                    mutableState.update { it.copy(distributions = values, isLoading = false) }
                }
        }
    }

    fun save(distribution: CashDistribution, onComplete: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            runCatching {
                repository.save(distribution.copy(updatedAt = java.time.Instant.now()))
            }.also(onComplete)
        }
    }

    fun delete(distribution: CashDistribution, onComplete: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            runCatching { repository.delete(distribution.id) }.also(onComplete)
        }
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
        private val repository: CashDistributionRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            CashDistributionFeatureModel(
                repository,
                CashDistributionBackupService(repository),
            ) as T
    }
}
