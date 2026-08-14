package jp.komehyappyo.member.next.feature.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import jp.komehyappyo.member.next.core.data.BudgetRemoteAuth
import jp.komehyappyo.member.next.core.data.BudgetMigrationResult
import jp.komehyappyo.member.next.core.data.BudgetReceiptStore
import jp.komehyappyo.member.next.core.data.BudgetSettlementMigrationService
import jp.komehyappyo.member.next.core.data.BudgetSettlementRemoteRepository
import jp.komehyappyo.member.next.core.data.BudgetSettlementRepository
import jp.komehyappyo.member.next.core.model.BudgetEntry
import jp.komehyappyo.member.next.core.model.BudgetSettlementReport
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.util.UUID

data class BudgetSettlementUiState(
    val reports: List<BudgetSettlementReport> = emptyList(),
    val entries: List<BudgetEntry> = emptyList(),
    val selectedReportId: UUID? = null,
    val isLoading: Boolean = true,
    val isMigrating: Boolean = false,
    val migrationCandidateCount: Int = 0,
    val migrationResult: BudgetMigrationResult? = null,
    val errorMessage: String? = null,
)

class BudgetSettlementFeatureModel(
    private val localRepository: BudgetSettlementRepository,
    private val localReceiptStore: BudgetReceiptStore,
    private val remoteRepository: BudgetSettlementRemoteRepository,
    private val migrationService: BudgetSettlementMigrationService,
    private val session: AppSession,
) : ViewModel() {
    private val mutableState = MutableStateFlow(BudgetSettlementUiState())
    val state: StateFlow<BudgetSettlementUiState> = mutableState.asStateFlow()
    private var reportCollection: Job? = null
    private var entryCollection: Job? = null

    init {
        viewModelScope.launch {
            session.state.collect { reload() }
        }
    }

    fun reload() {
        reportCollection?.cancel()
        val auth = auth()
        if (auth == null) {
            reportCollection = viewModelScope.launch {
                mutableState.update { it.copy(isLoading = true, errorMessage = null) }
                localRepository.observeReports()
                    .catch { showError(it) }
                    .collect { reports ->
                        mutableState.update {
                            it.copy(reports = reports, isLoading = false, migrationCandidateCount = 0)
                        }
                    }
            }
        } else {
            viewModelScope.launch {
                mutableState.update { it.copy(isLoading = true, errorMessage = null) }
                runCatching {
                    remoteRepository.fetchReports(auth) to migrationService.candidateCount(auth)
                }.onSuccess { (reports, count) ->
                    mutableState.update {
                        it.copy(
                            reports = reports,
                            isLoading = false,
                            migrationCandidateCount = count,
                        )
                    }
                }.onFailure(::showError)
            }
        }
    }

    fun loadEntries(reportId: UUID) {
        mutableState.update { it.copy(selectedReportId = reportId, isLoading = true, errorMessage = null) }
        entryCollection?.cancel()
        val auth = auth()
        if (auth == null) {
            entryCollection = viewModelScope.launch {
                localRepository.observeEntries(reportId)
                    .catch { showError(it) }
                    .collect { entries ->
                        mutableState.update { it.copy(entries = entries, isLoading = false) }
                    }
            }
        } else {
            viewModelScope.launch {
                runCatching { remoteRepository.fetchEntries(auth, reportId) }
                    .onSuccess { entries ->
                        mutableState.update { it.copy(entries = entries, isLoading = false) }
                    }
                    .onFailure(::showError)
            }
        }
    }

    fun saveReport(report: BudgetSettlementReport, onComplete: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            val result = runCatching {
                val auth = auth()
                if (auth == null) localRepository.saveReport(report)
                else remoteRepository.saveReport(auth, report.copy(userId = auth.userId))
                reload()
            }
            result.onFailure(::showError)
            onComplete(result)
        }
    }

    fun saveEntry(
        entry: BudgetEntry,
        receiptJpeg: ByteArray?,
        onComplete: (Result<Unit>) -> Unit,
    ) {
        viewModelScope.launch {
            val result = runCatching {
                val auth = auth()
                val receiptReference = when {
                    receiptJpeg == null -> entry.receiptImageUrl
                    auth == null -> localReceiptStore.saveJpeg(entry.reportId, entry.id, receiptJpeg)
                    else -> remoteRepository.uploadReceipt(
                        auth,
                        entry.reportId,
                        entry.id,
                        receiptJpeg,
                    )
                }
                val value = entry.copy(receiptImageUrl = receiptReference, updatedAt = Instant.now())
                if (auth == null) localRepository.saveEntry(value)
                else remoteRepository.saveEntry(auth, value)
                loadEntries(entry.reportId)
                reload()
            }
            result.onFailure(::showError)
            onComplete(result)
        }
    }

    fun deleteEntry(entry: BudgetEntry, onComplete: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            val result = runCatching {
                val auth = auth()
                if (auth == null) localRepository.deleteEntry(entry.id)
                else remoteRepository.deleteEntry(auth, entry.reportId, entry.id)
                loadEntries(entry.reportId)
                reload()
            }
            result.onFailure(::showError)
            onComplete(result)
        }
    }

    fun deleteReport(report: BudgetSettlementReport, onComplete: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            val result = runCatching {
                val auth = auth()
                if (auth == null) localRepository.deleteReport(report.id)
                else remoteRepository.deleteReport(auth, report.id)
                mutableState.update { it.copy(entries = emptyList(), selectedReportId = null) }
                reload()
            }
            result.onFailure(::showError)
            onComplete(result)
        }
    }

    fun migrate(onComplete: (Result<BudgetMigrationResult>) -> Unit) {
        val auth = auth() ?: return onComplete(Result.failure(IllegalStateException("ログインが必要です。")))
        viewModelScope.launch {
            mutableState.update { it.copy(isMigrating = true, errorMessage = null) }
            val result = runCatching { migrationService.migrate(auth) }
            result.onSuccess { migrationResult ->
                mutableState.update {
                    it.copy(
                        isMigrating = false,
                        migrationCandidateCount = 0,
                        migrationResult = migrationResult,
                    )
                }
                reload()
            }.onFailure {
                mutableState.update { state -> state.copy(isMigrating = false) }
                showError(it)
            }
            onComplete(result)
        }
    }

    private fun auth(): BudgetRemoteAuth? {
        val state = session.state.value
        val token = state.authenticationToken ?: return null
        return BudgetRemoteAuth(state.userId, token)
    }

    private fun showError(error: Throwable) {
        mutableState.update {
            it.copy(isLoading = false, isMigrating = false, errorMessage = error.message ?: "処理に失敗しました。")
        }
    }

    class Factory(
        private val localRepository: BudgetSettlementRepository,
        private val localReceiptStore: BudgetReceiptStore,
        private val remoteRepository: BudgetSettlementRemoteRepository,
        private val migrationService: BudgetSettlementMigrationService,
        private val session: AppSession,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            BudgetSettlementFeatureModel(
                localRepository,
                localReceiptStore,
                remoteRepository,
                migrationService,
                session,
            ) as T
    }
}
