package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.AppBackupException
import jp.komehyappyo.member.next.core.data.AppBackupService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class AppBackupUiState(
    val isWorking: Boolean = false,
    val pendingExport: ByteArray? = null,
    val skippedMeetingMinutes: Int = 0,
    val message: String? = null,
)

class AppBackupFeatureModel(
    private val service: AppBackupService,
) : ViewModel() {
    private val mutableState = MutableStateFlow(AppBackupUiState())
    val state: StateFlow<AppBackupUiState> = mutableState

    fun prepareExport() {
        if (mutableState.value.isWorking) return
        mutableState.update { it.copy(isWorking = true, message = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) { service.exportData() }
            }.onSuccess { result ->
                mutableState.update {
                    it.copy(
                        isWorking = false,
                        pendingExport = result.data,
                        skippedMeetingMinutes = result.skippedMeetingMinutes,
                    )
                }
            }.onFailure { error ->
                mutableState.update {
                    it.copy(isWorking = false, message = error.userMessage())
                }
            }
        }
    }

    fun exportCompleted(success: Boolean) {
        mutableState.update {
            it.copy(
                pendingExport = null,
                message = if (success) {
                    if (it.skippedMeetingMinutes > 0) {
                        "バックアップを書き出しました。録音ファイルが見つからない議事録" +
                            "${it.skippedMeetingMinutes}件は除外しました。その他のデータは保存されています。"
                    } else {
                        "バックアップを書き出しました。大切に保管してください。"
                    }
                } else {
                    "バックアップの保存をキャンセルしました。"
                },
            )
        }
    }

    fun importBackup(data: ByteArray) {
        if (mutableState.value.isWorking) return
        mutableState.update { it.copy(isWorking = true, message = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) { service.importData(data) }
            }.onSuccess { summary ->
                mutableState.update {
                    it.copy(
                        isWorking = false,
                        message = "${summary.total}件の端末内データを読み込みました。",
                    )
                }
            }.onFailure { error ->
                mutableState.update {
                    it.copy(isWorking = false, message = error.userMessage())
                }
            }
        }
    }

    private fun Throwable.userMessage(): String = when (this) {
        AppBackupException.InvalidFormat -> "このファイルはアプリの一括バックアップではありません。"
        AppBackupException.UnsupportedVersion -> "このバックアップ形式にはまだ対応していません。"
        AppBackupException.MissingRecording -> "録音ファイルが見つからない議事録があります。"
        AppBackupException.InvalidAttachment -> "写真・録音・PDFの内容を確認できませんでした。"
        else -> localizedMessage ?: "バックアップ処理に失敗しました。"
    }

    class Factory(
        private val service: AppBackupService,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            AppBackupFeatureModel(service) as T
    }
}
