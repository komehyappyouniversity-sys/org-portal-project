package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.ScheduleRepository
import jp.komehyappyo.member.next.core.model.Schedule
import jp.komehyappyo.member.next.core.notifications.NotificationService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.UUID

data class ScheduleUiState(
    val schedules: List<Schedule> = emptyList(),
    val todaySchedules: List<Schedule> = emptyList(),
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
)

class ScheduleFeatureModel(
    private val repository: ScheduleRepository,
    private val notificationService: NotificationService,
) : ViewModel() {
    private val mutableState = MutableStateFlow(ScheduleUiState())
    val state: StateFlow<ScheduleUiState> = mutableState

    init {
        reload()
    }

    fun reload() {
        viewModelScope.launch {
            mutableState.update { it.copy(isLoading = true, errorMessage = null) }
            launch {
                repository.observeAll()
                    .catch { error ->
                        mutableState.update {
                            it.copy(isLoading = false, errorMessage = error.localizedMessage)
                        }
                    }
                    .collect { schedules ->
                        mutableState.update { it.copy(schedules = schedules, isLoading = false) }
                    }
            }
            launch {
                repository.observe(LocalDate.now())
                    .catch { error ->
                        mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                    }
                    .collect { schedules ->
                        mutableState.update { it.copy(todaySchedules = schedules) }
                    }
            }
        }
    }

    fun save(schedule: Schedule, onComplete: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            runCatching {
                repository.save(schedule)
                notificationService.scheduleReminder(schedule)
            }.also(onComplete)
        }
    }

    fun delete(id: UUID, onComplete: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            runCatching { repository.delete(id) }.also(onComplete)
        }
    }

    class Factory(
        private val repository: ScheduleRepository,
        private val notificationService: NotificationService,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            ScheduleFeatureModel(repository, notificationService) as T
    }
}
