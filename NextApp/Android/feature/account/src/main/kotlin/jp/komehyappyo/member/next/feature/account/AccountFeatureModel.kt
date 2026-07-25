package jp.komehyappyo.member.next.feature.account

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.AccountAuthRepository
import jp.komehyappyo.member.next.core.model.AccountAccessState
import jp.komehyappyo.member.next.core.model.AccountCredentials
import jp.komehyappyo.member.next.core.model.UserStage
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class AccountScreen { Overview, Register, Login, ResetPassword }

data class AccountUiState(
    val screen: AccountScreen = AccountScreen.Overview,
    val accessState: AccountAccessState = AccountAccessState.Guest,
    val isLoading: Boolean = false,
    val message: String? = null,
)

class AccountFeatureModel(
    private val repository: AccountAuthRepository,
    private val session: AppSession,
) : ViewModel() {
    private val mutableState = MutableStateFlow(AccountUiState())
    val state: StateFlow<AccountUiState> = mutableState.asStateFlow()

    fun show(screen: AccountScreen) {
        mutableState.value = mutableState.value.copy(screen = screen, message = null)
    }

    fun register(email: String, password: String, confirmation: String) {
        val credentials = AccountCredentials(email, password, confirmation)
        credentials.validationError()?.let {
            mutableState.value = mutableState.value.copy(message = it)
            return
        }
        runAuth { repository.register(credentials) }
    }

    fun login(email: String, password: String) {
        val credentials = AccountCredentials(email, password)
        credentials.validationError()?.let {
            mutableState.value = mutableState.value.copy(message = it)
            return
        }
        runAuth { repository.login(credentials) }
    }

    fun resetPassword(email: String) {
        val credentials = AccountCredentials(email, "password")
        credentials.validationError()?.let {
            mutableState.value = mutableState.value.copy(message = it)
            return
        }
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch {
            repository.sendPasswordReset(email.trim())
                .onSuccess {
                    mutableState.value = mutableState.value.copy(
                        isLoading = false,
                        message = "パスワード再設定メールを送信しました。",
                    )
                }
                .onFailure { showError(it) }
        }
    }

    private fun runAuth(block: suspend () -> Result<jp.komehyappyo.member.next.core.data.AuthenticatedAccount>) {
        mutableState.value = mutableState.value.copy(isLoading = true, message = null)
        viewModelScope.launch {
            block()
                .onSuccess { account ->
                    session.updateStage(UserStage.Member, account.userId)
                    mutableState.value = AccountUiState(
                        accessState = AccountAccessState.Member,
                        message = "ログインしました。",
                    )
                }
                .onFailure { showError(it) }
        }
    }

    private fun showError(error: Throwable) {
        mutableState.value = mutableState.value.copy(
            isLoading = false,
            message = error.message ?: "処理に失敗しました。",
        )
    }

    class Factory(
        private val repository: AccountAuthRepository,
        private val session: AppSession,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            AccountFeatureModel(repository, session) as T
    }
}
