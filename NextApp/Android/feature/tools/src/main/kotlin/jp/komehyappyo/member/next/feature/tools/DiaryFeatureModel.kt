package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.DiaryBackupService
import jp.komehyappyo.member.next.core.data.DiaryPhotoStore
import jp.komehyappyo.member.next.core.data.DiaryRepository
import jp.komehyappyo.member.next.core.model.Diary
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

data class DiaryUiState(
    val diaries: List<Diary> = emptyList(),
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
)

class DiaryFeatureModel(
    private val repository: DiaryRepository,
    private val photoStore: DiaryPhotoStore,
    private val backupService: DiaryBackupService,
) : ViewModel() {
    private val mutableState = MutableStateFlow(DiaryUiState())
    val state: StateFlow<DiaryUiState> = mutableState

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
                .collect { diaries ->
                    mutableState.update { it.copy(diaries = diaries, isLoading = false) }
                }
        }
    }

    fun save(
        diary: Diary,
        newPhotoData: List<ByteArray>,
        removedPhotoReferences: Set<String>,
        onComplete: (Result<Unit>) -> Unit,
    ) {
        viewModelScope.launch {
            runCatching {
                val remaining = diary.photoUrls.filterNot(removedPhotoReferences::contains)
                require(remaining.size + newPhotoData.size <= Diary.MAXIMUM_PHOTO_COUNT) {
                    "写真は${Diary.MAXIMUM_PHOTO_COUNT}枚まで登録できます。"
                }
                val createdReferences = mutableListOf<String>()
                try {
                    withContext(Dispatchers.IO) {
                        newPhotoData.forEach { data ->
                            createdReferences += photoStore.saveJpeg(data, diary.id)
                        }
                    }
                    repository.save(
                        diary.copy(
                            photoUrls = remaining + createdReferences,
                            updatedAt = java.time.Instant.now(),
                        ),
                    )
                    withContext(Dispatchers.IO) {
                        removedPhotoReferences.forEach {
                            runCatching { photoStore.delete(it) }
                        }
                    }
                } catch (error: Throwable) {
                    withContext(Dispatchers.IO) {
                        createdReferences.forEach { runCatching { photoStore.delete(it) } }
                    }
                    throw error
                }
            }.also(onComplete)
        }
    }

    fun delete(diary: Diary, onComplete: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            runCatching {
                repository.delete(diary.id)
                withContext(Dispatchers.IO) {
                    diary.photoUrls.forEach { runCatching { photoStore.delete(it) } }
                }
            }.also(onComplete)
        }
    }

    suspend fun photoData(reference: String): ByteArray =
        withContext(Dispatchers.IO) { photoStore.load(reference) }

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
        private val repository: DiaryRepository,
        private val photoStore: DiaryPhotoStore,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            DiaryFeatureModel(
                repository,
                photoStore,
                DiaryBackupService(repository, photoStore),
            ) as T
    }
}
