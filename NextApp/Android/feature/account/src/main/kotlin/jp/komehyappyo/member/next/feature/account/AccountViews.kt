package jp.komehyappyo.member.next.feature.account

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Divider
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.model.AccountAccessState

// `feature:account` must not depend on `feature:community` directly (see
// docs/Codex実装指示書_タスク1-3.md の共通制約). The App layer decides whether
// management mode is available and supplies the management screen content.
@Composable
fun AccountRoot(
    model: AccountFeatureModel,
    activity: FragmentActivity,
    canEnterManagementMode: Boolean,
    usageAnalyticsOptOut: Boolean,
    onUsageAnalyticsOptOutChange: (Boolean) -> Unit,
    managementContent: @Composable () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    when (state.screen) {
        AccountScreen.Overview -> AccountOverview(
            state,
            model,
            activity,
            canEnterManagementMode,
            usageAnalyticsOptOut,
            onUsageAnalyticsOptOutChange,
        )
        AccountScreen.Management -> ManagementModeRoot(managementContent) { model.show(AccountScreen.Overview) }
        AccountScreen.Register -> AccountForm(true, state, model)
        AccountScreen.Login -> AccountForm(false, state, model)
        AccountScreen.ResetPassword -> ResetPasswordForm(state, model)
    }
}

@Composable
private fun AccountOverview(
    state: AccountUiState,
    model: AccountFeatureModel,
    activity: FragmentActivity,
    canEnterManagementMode: Boolean,
    usageAnalyticsOptOut: Boolean,
    onUsageAnalyticsOptOutChange: (Boolean) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("マイページ")
        when (state.accessState) {
            AccountAccessState.Guest -> {
                Text("現在はGuestとして利用しています。会員登録は便利機能を引き続き利用したまま行えます。")
                Button(
                    onClick = { model.show(AccountScreen.Register) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("会員登録")
                }
                OutlinedButton(
                    onClick = { model.show(AccountScreen.Login) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("ログイン")
                }
                if (state.canUseBiometricLogin) {
                    OutlinedButton(
                        onClick = {
                            requestBiometricAuthentication(
                                activity = activity,
                                onSuccess = model::biometricLogin,
                                onError = model::biometricError,
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("顔・指紋などの生体認証でログイン")
                    }
                }
                TextButton(onClick = { model.show(AccountScreen.ResetPassword) }) {
                    Text("パスワードを忘れた方")
                }
            }
            AccountAccessState.PendingApproval ->
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("コミュニティへの参加申請を確認中です。承認後に会員向け機能が追加されます。")
                    OutlinedButton(onClick = model::logout) { Text("ログアウト") }
                }
            AccountAccessState.Registered ->
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("ログイン済みです。「つながる」からコミュニティコードまたはQRコードで参加申請できます。")
                    if (canEnterManagementMode) {
                        OutlinedButton(
                            onClick = { model.show(AccountScreen.Management) },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("運営モードへ入る")
                        }
                    }
                    OutlinedButton(onClick = model::logout) { Text("ログアウト") }
                }
            AccountAccessState.Rejected -> {
                Text("コミュニティへの参加申請は承認されませんでした。申請先へご確認ください。")
                OutlinedButton(
                    onClick = { model.show(AccountScreen.Login) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("別のアカウントでログイン")
                }
                OutlinedButton(onClick = model::logout) { Text("ログアウト") }
            }
            AccountAccessState.Member ->
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("会員としてログインしています。参加中のコミュニティ機能を利用できます。")
                    if (canEnterManagementMode) {
                        OutlinedButton(
                            onClick = { model.show(AccountScreen.Management) },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("運営モードへ入る")
                        }
                    }
                    OutlinedButton(onClick = model::logout) { Text("ログアウト") }
                }
        }
        Divider()
        Text("アプリ設定")
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("任意の利用状況記録を停止")
                Text("ONにすると、機能改善のための動画・ラジオ利用イベントを送信しません。")
            }
            Switch(
                checked = usageAnalyticsOptOut,
                onCheckedChange = onUsageAnalyticsOptOutChange,
            )
        }
        StatusMessage(state)
    }
}

@Composable
private fun ManagementModeRoot(
    managementContent: @Composable () -> Unit,
    onBack: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("運営モード")
        Divider()
        Button(onClick = onBack) { Text("マイページへ戻る") }
        managementContent()
    }
}

private fun requestBiometricAuthentication(
    activity: FragmentActivity,
    onSuccess: () -> Unit,
    onError: (String) -> Unit,
) {
    val authenticators = BiometricManager.Authenticators.BIOMETRIC_WEAK
    val biometricManager = BiometricManager.from(activity)
    when (biometricManager.canAuthenticate(authenticators)) {
        BiometricManager.BIOMETRIC_SUCCESS -> Unit
        BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> {
            onError("この端末は指紋・顔認証に対応していません。")
            return
        }
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> {
            onError("端末の設定で指紋または顔認証を登録してください。")
            return
        }
        else -> {
            onError("指紋・顔認証を利用できません。端末のロック設定を確認してください。")
            return
        }
    }
    val prompt = BiometricPrompt(
        activity,
        ContextCompat.getMainExecutor(activity),
        object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(
                result: BiometricPrompt.AuthenticationResult,
            ) {
                onSuccess()
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                if (errorCode != BiometricPrompt.ERROR_NEGATIVE_BUTTON &&
                    errorCode != BiometricPrompt.ERROR_USER_CANCELED
                ) {
                    onError(errString.toString().ifBlank { "生体認証に失敗しました。" })
                }
            }

            override fun onAuthenticationFailed() {
                onError("指紋または顔を認識できませんでした。もう一度お試しください。")
            }
        },
    )
    prompt.authenticate(
        BiometricPrompt.PromptInfo.Builder()
            .setTitle("生体認証でログイン")
            .setSubtitle("本人確認後、会員アプリへログインします")
            .setAllowedAuthenticators(authenticators)
            .setNegativeButtonText("キャンセル")
            .build(),
    )
}

@Composable
private fun AccountForm(register: Boolean, state: AccountUiState, model: AccountFeatureModel) {
    var name by remember { mutableStateOf("") }
    var furigana by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(if (register) "会員登録" else "ログイン")
        if (register) {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("名前") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = furigana,
                onValueChange = { furigana = it },
                label = { Text("ふりがな") },
                modifier = Modifier.fillMaxWidth(),
            )
        }
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("メールアドレス") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("パスワード（8文字以上）") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
        )
        if (register) {
            OutlinedTextField(
                value = confirmation,
                onValueChange = { confirmation = it },
                label = { Text("確認用パスワード") },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        Button(
            onClick = {
                if (register) {
                    model.register(name, furigana, email, password, confirmation)
                }
                else model.login(email, password)
            },
            enabled = !state.isLoading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (register) "登録する" else "ログイン")
        }
        OutlinedButton(onClick = { model.show(AccountScreen.Overview) }) { Text("戻る") }
        StatusMessage(state)
    }
}

@Composable
private fun ResetPasswordForm(state: AccountUiState, model: AccountFeatureModel) {
    var email by remember { mutableStateOf("") }
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("パスワード再設定")
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("メールアドレス") },
            modifier = Modifier.fillMaxWidth(),
        )
        Button(
            onClick = { model.resetPassword(email) },
            enabled = !state.isLoading,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("再設定メールを送信") }
        OutlinedButton(onClick = { model.show(AccountScreen.Overview) }) { Text("戻る") }
        StatusMessage(state)
    }
}

@Composable
private fun StatusMessage(state: AccountUiState) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (state.isLoading) CircularProgressIndicator()
        state.message?.let { Text(it) }
    }
}
