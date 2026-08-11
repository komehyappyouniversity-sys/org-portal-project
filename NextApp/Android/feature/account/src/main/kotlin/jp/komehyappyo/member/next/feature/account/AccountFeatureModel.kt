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
    val canUseBiometricLogin: Boolean = false,
    val message: String? = null,
)

class AccountFeatureModel(
    private val repository: AccountAuthRepository,
    private val biometricStore: BiometricCredentialStore,
    private val session: AppSession,
) : ViewModel() {
    private val mutableState = MutableStateFlow(
        AccountUiState(canUseBiometricLogin = biometricStore.hasCredential),
    )
    val state: StateFlow<AccountUiState> = mutableState.asStateFlow()

    fun show(screen: AccountScreen) {
        mutableState.value = mutableState.value.copy(screen = screen, message = null)
    }

    fun register(
        name: String,
        furigana: String,
        email: String,
        password: String,
        confirmation: String,
    ) {
        val credentials = AccountCredentials(
            email = email,
            password = password,
            passwordConfirmation = confirmation,
            name = name,
            furigana = furigana,
        )
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

    fun biometricLogin() {
        runAuth {
            runCatching { biometricStore.load() }
                .fold(
                    onSuccess = { repository.refresh(it) },
                    onFailure = { Result.failure(it) },
                )
        }
    }

    fun biometricError(message: String) {
        mutableState.value = mutableState.value.copy(
            isLoading = false,
            message = message,
        )
    }

    fun logout() {
        session.logout()
        mutableState.value = AccountUiState(
            accessState = AccountAccessState.Guest,
            canUseBiometricLogin = biometricStore.hasCredential,
            message = "ログアウトしました。",
        )
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
                    runCatching { biometricStore.save(account.refreshToken) }
                    if (account.emailVerified) {
                        session.updateAuthenticatedUser(account.userId, account.idToken)
                        session.updateStage(UserStage.Guest, account.userId)
                        mutableState.value = AccountUiState(
                            accessState = AccountAccessState.Registered,
                            canUseBiometricLogin = biometricStore.hasCredential,
                            message = "ログインしました。「つながる」からコミュニティへ参加できます。",
                        )
                    } else {
                        session.updateAuthenticatedUser(account.userId, account.idToken)
                        session.updateStage(UserStage.Guest, account.userId)
                        mutableState.value = AccountUiState(
                            accessState = AccountAccessState.Guest,
                            canUseBiometricLogin = biometricStore.hasCredential,
                            message = "確認メールを送信しました。メール内のリンクで確認後、ログインしてください。",
                        )
                    }
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
        private val biometricStore: BiometricCredentialStore,
        private val session: AppSession,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            AccountFeatureModel(repository, biometricStore, session) as T
    }
}
