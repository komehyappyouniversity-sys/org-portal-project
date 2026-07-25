package jp.komehyappyo.member.next.feature.account

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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.model.AccountAccessState

@Composable
fun AccountRoot(model: AccountFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    when (state.screen) {
        AccountScreen.Overview -> AccountOverview(state, model)
        AccountScreen.Register -> AccountForm(true, state, model)
        AccountScreen.Login -> AccountForm(false, state, model)
        AccountScreen.ResetPassword -> ResetPasswordForm(state, model)
    }
}

@Composable
private fun AccountOverview(state: AccountUiState, model: AccountFeatureModel) {
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
                TextButton(onClick = { model.show(AccountScreen.ResetPassword) }) {
                    Text("パスワードを忘れた方")
                }
            }
            AccountAccessState.PendingApproval ->
                Text("コミュニティへの参加申請を確認中です。承認後に会員向け機能が追加されます。")
            AccountAccessState.Rejected -> {
                Text("コミュニティへの参加申請は承認されませんでした。申請先へご確認ください。")
                OutlinedButton(
                    onClick = { model.show(AccountScreen.Login) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("別のアカウントでログイン")
                }
            }
            AccountAccessState.Member ->
                Text("会員としてログインしています。参加中のコミュニティ機能を利用できます。")
        }
        StatusMessage(state)
    }
}

@Composable
private fun AccountForm(register: Boolean, state: AccountUiState, model: AccountFeatureModel) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(if (register) "会員登録" else "ログイン")
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
                if (register) model.register(email, password, confirmation)
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
