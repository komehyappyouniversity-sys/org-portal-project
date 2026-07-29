package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.FriendExchangeRepository
import jp.komehyappyo.member.next.core.model.FriendContact
import jp.komehyappyo.member.next.core.model.FriendInteractionHistory
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class FriendExchangeUiState(
    val contacts: List<FriendContact> = emptyList(),
    val histories: Map<UUID, List<FriendInteractionHistory>> = emptyMap(),
    val isLoading: Boolean = true,
    val notice: String? = null,
    val errorMessage: String? = null,
)

class FriendExchangeFeatureModel(
    private val repository: FriendExchangeRepository,
) : ViewModel() {
    private val mutableState = MutableStateFlow(FriendExchangeUiState())
    val state: StateFlow<FriendExchangeUiState> = mutableState
    private val historyJobs = mutableMapOf<UUID, Job>()

    init {
        viewModelScope.launch {
            repository.observeContacts()
                .catch { error ->
                    mutableState.update {
                        it.copy(isLoading = false, errorMessage = error.localizedMessage)
                    }
                }
                .collect { contacts ->
                    mutableState.update {
                        it.copy(contacts = contacts, isLoading = false, errorMessage = null)
                    }
                }
        }
    }

    fun observeHistories(friendId: UUID) {
        if (historyJobs[friendId]?.isActive == true) return
        historyJobs[friendId] = viewModelScope.launch {
            repository.observeHistories(friendId)
                .catch { error ->
                    mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                }
                .collect { histories ->
                    mutableState.update {
                        it.copy(histories = it.histories + (friendId to histories))
                    }
                }
        }
    }

    fun saveContact(
        existing: FriendContact?,
        name: String,
        postalCode: String,
        prefecture: String,
        city: String,
        addressLine: String,
        birthDate: LocalDate?,
        phoneNumber: String,
        email: String,
        onComplete: (Boolean) -> Unit,
    ) {
        viewModelScope.launch {
            runCatching {
                val now = Instant.now()
                FriendContact(
                    id = existing?.id ?: UUID.randomUUID(),
                    userId = existing?.userId ?: "guest-local",
                    name = name,
                    postalCode = postalCode,
                    prefecture = prefecture,
                    city = city,
                    addressLine = addressLine,
                    birthDate = birthDate,
                    phoneNumber = phoneNumber,
                    email = email,
                    createdAt = existing?.createdAt ?: now,
                    updatedAt = now,
                ).validated().also { repository.save(it) }
            }.onSuccess {
                mutableState.update {
                    it.copy(notice = if (existing == null) "友達情報を追加しました。" else "友達情報を更新しました。")
                }
                onComplete(true)
            }.onFailure { error ->
                mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                onComplete(false)
            }
        }
    }

    fun saveHistory(
        existing: FriendInteractionHistory?,
        friendId: UUID,
        interactionDate: Instant,
        memo: String,
        photoUrls: List<String>,
        isPhoneCall: Boolean,
        phoneNumber: String,
        onComplete: (Boolean) -> Unit,
    ) {
        viewModelScope.launch {
            runCatching {
                val now = Instant.now()
                FriendInteractionHistory(
                    id = existing?.id ?: UUID.randomUUID(),
                    friendId = friendId,
                    interactionDate = interactionDate,
                    memo = memo,
                    photoUrls = photoUrls.filter(String::isNotBlank),
                    isPhoneCall = isPhoneCall,
                    phoneNumber = phoneNumber,
                    createdAt = existing?.createdAt ?: now,
                    updatedAt = now,
                ).validated().also { repository.save(it) }
            }.onSuccess {
                mutableState.update {
                    it.copy(notice = if (existing == null) "交流履歴を追加しました。" else "交流履歴を更新しました。")
                }
                onComplete(true)
            }.onFailure { error ->
                mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                onComplete(false)
            }
        }
    }

    fun deleteContact(contact: FriendContact) {
        viewModelScope.launch {
            runCatching { repository.deleteContact(contact.id) }
                .onSuccess {
                    historyJobs.remove(contact.id)?.cancel()
                    mutableState.update {
                        it.copy(
                            histories = it.histories - contact.id,
                            notice = "友達情報を削除しました。",
                        )
                    }
                }
                .onFailure { error ->
                    mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                }
        }
    }

    fun deleteHistory(history: FriendInteractionHistory) {
        viewModelScope.launch {
            runCatching { repository.deleteHistory(history.id) }
                .onSuccess {
                    mutableState.update { it.copy(notice = "交流履歴を削除しました。") }
                }
                .onFailure { error ->
                    mutableState.update { it.copy(errorMessage = error.localizedMessage) }
                }
        }
    }

    fun clearNotice() = mutableState.update { it.copy(notice = null) }
    fun clearError() = mutableState.update { it.copy(errorMessage = null) }

    class Factory(
        private val repository: FriendExchangeRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            FriendExchangeFeatureModel(repository) as T
    }
}
