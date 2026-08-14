package jp.komehyappyo.member.next.feature.tools

import android.content.Context
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.IosShare
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.ErrorState
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.model.BudgetEntry
import jp.komehyappyo.member.next.core.model.BudgetEntryType
import jp.komehyappyo.member.next.core.model.BudgetSettlementReport
import java.math.BigDecimal
import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import java.util.Locale
import java.io.File

private sealed interface BudgetScreen {
    data object Reports : BudgetScreen
    data class Detail(val reportId: java.util.UUID) : BudgetScreen
    data class Entries(val reportId: java.util.UUID) : BudgetScreen
    data class EntryEditor(val reportId: java.util.UUID, val entryId: java.util.UUID?) : BudgetScreen
}

@Composable
fun BudgetSettlementRoot(model: BudgetSettlementFeatureModel) {
    val state by model.state.collectAsState()
    var screen by remember { mutableStateOf<BudgetScreen>(BudgetScreen.Reports) }
    val reportFor: (java.util.UUID) -> BudgetSettlementReport? = { id ->
        state.reports.firstOrNull { it.id == id }
    }
    when (val current = screen) {
        BudgetScreen.Reports -> BudgetReportListView(
            model = model,
            onOpen = { screen = BudgetScreen.Detail(it.id) },
        )
        is BudgetScreen.Detail -> reportFor(current.reportId)?.let { report ->
            BudgetReportDetailView(
                model = model,
                report = report,
                onBack = { screen = BudgetScreen.Reports },
                onEntries = { screen = BudgetScreen.Entries(report.id) },
            )
        } ?: LaunchedEffect(current.reportId) { screen = BudgetScreen.Reports }
        is BudgetScreen.Entries -> reportFor(current.reportId)?.let { report ->
            BudgetEntryListView(
                model = model,
                report = report,
                onBack = { screen = BudgetScreen.Detail(report.id) },
                onAdd = { screen = BudgetScreen.EntryEditor(report.id, null) },
                onEdit = { screen = BudgetScreen.EntryEditor(report.id, it.id) },
            )
        } ?: LaunchedEffect(current.reportId) { screen = BudgetScreen.Reports }
        is BudgetScreen.EntryEditor -> reportFor(current.reportId)?.let { report ->
            BudgetEntryEditorView(
                model = model,
                report = report,
                editing = state.entries.firstOrNull { it.id == current.entryId },
                onClose = { screen = BudgetScreen.Entries(report.id) },
            )
        } ?: LaunchedEffect(current.reportId) { screen = BudgetScreen.Reports }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BudgetReportListView(
    model: BudgetSettlementFeatureModel,
    onOpen: (BudgetSettlementReport) -> Unit,
) {
    val state by model.state.collectAsState()
    var showEditor by remember { mutableStateOf(false) }
    var showMigration by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { model.reload() }
    LaunchedEffect(state.migrationCandidateCount) {
        if (state.migrationCandidateCount > 0) showMigration = true
    }
    Scaffold(
        topBar = { TopAppBar(title = { Text("予算・決算") }) },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { showEditor = true },
                icon = { Icon(Icons.Outlined.Add, contentDescription = null) },
                text = { Text("帳簿を追加") },
            )
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            when {
                state.isLoading -> LoadingState()
                state.errorMessage != null -> ErrorState(state.errorMessage!!) { model.reload() }
                state.reports.isEmpty() -> EmptyState("帳簿はまだありません", "右下のボタンから帳簿を追加できます。")
                else -> LazyColumn {
                    items(state.reports, key = { it.id }) { report ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 6.dp)
                                .clickable { onOpen(report) },
                        ) {
                            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(report.bookName, style = MaterialTheme.typography.titleMedium)
                                Text("${report.fiscalYearStart} ～ ${report.fiscalYearEnd}")
                                Text("残高 ${money(report.balance)}")
                            }
                        }
                    }
                }
            }
        }
    }
    if (showEditor) {
        BudgetReportEditorDialog(
            editing = null,
            onDismiss = { showEditor = false },
            onSave = { report ->
                model.saveReport(report) { if (it.isSuccess) showEditor = false }
            },
        )
    }
    if (showMigration) {
        AlertDialog(
            onDismissRequest = { showMigration = false },
            title = { Text("端末内の帳簿を移行") },
            text = {
                Text("${state.migrationCandidateCount}件の帳簿を、ログイン中の本人専用領域へ移行します。端末内データはバックアップとして残ります。")
            },
            confirmButton = {
                TextButton(
                    enabled = !state.isMigrating,
                    onClick = { model.migrate { if (it.isSuccess) showMigration = false } },
                ) { Text(if (state.isMigrating) "移行中…" else "移行する") }
            },
            dismissButton = { TextButton(onClick = { showMigration = false }) { Text("後で") } },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BudgetReportDetailView(
    model: BudgetSettlementFeatureModel,
    report: BudgetSettlementReport,
    onBack: () -> Unit,
    onEntries: () -> Unit,
) {
    val state by model.state.collectAsState()
    val context = LocalContext.current
    var showEditor by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    LaunchedEffect(report.id) { model.loadEntries(report.id) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(report.bookName) },
                navigationIcon = { TextButton(onClick = onBack) { Text("戻る") } },
                actions = {
                    IconButton(onClick = { showEditor = true }) {
                        Icon(Icons.Outlined.Edit, contentDescription = "帳簿を編集")
                    }
                    IconButton(
                        enabled = !state.isLoading,
                        onClick = { shareBudgetCsv(context, report, state.entries) },
                    ) { Icon(Icons.Outlined.IosShare, contentDescription = "CSV共有") }
                    IconButton(onClick = { confirmDelete = true }) {
                        Icon(Icons.Outlined.Delete, contentDescription = "帳簿を削除")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier.padding(padding).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("会計年度 ${report.fiscalYearStart} ～ ${report.fiscalYearEnd}")
            SummaryCard("収入合計", report.incomeTotal)
            SummaryCard("支出合計", report.expenseTotal)
            SummaryCard("残高", report.balance)
            Button(onClick = onEntries, modifier = Modifier.fillMaxWidth()) { Text("収支明細を見る") }
        }
    }
    if (showEditor) {
        BudgetReportEditorDialog(
            editing = report,
            onDismiss = { showEditor = false },
            onSave = { value ->
                model.saveReport(value) { if (it.isSuccess) showEditor = false }
            },
        )
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("帳簿を削除しますか？") },
            text = { Text("紐づく明細と領収書画像もすべて削除されます。この操作は取り消せません。") },
            confirmButton = {
                TextButton(onClick = {
                    model.deleteReport(report) { if (it.isSuccess) onBack() }
                    confirmDelete = false
                }) { Text("削除") }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("キャンセル") } },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BudgetEntryListView(
    model: BudgetSettlementFeatureModel,
    report: BudgetSettlementReport,
    onBack: () -> Unit,
    onAdd: () -> Unit,
    onEdit: (BudgetEntry) -> Unit,
) {
    val state by model.state.collectAsState()
    var deleting by remember { mutableStateOf<BudgetEntry?>(null) }
    LaunchedEffect(report.id) { model.loadEntries(report.id) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("${report.bookName}の明細") },
                navigationIcon = { TextButton(onClick = onBack) { Text("戻る") } },
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onAdd,
                icon = { Icon(Icons.Outlined.Add, contentDescription = null) },
                text = { Text("明細を追加") },
            )
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            when {
                state.isLoading -> LoadingState()
                state.errorMessage != null -> ErrorState(state.errorMessage!!) { model.loadEntries(report.id) }
                state.entries.isEmpty() -> EmptyState("明細はまだありません", "右下のボタンから収支明細を追加できます。")
                else -> LazyColumn {
                    items(state.entries, key = { it.id }) { entry ->
                        Card(
                            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
                        ) {
                            Row(Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Column(
                                    Modifier.weight(1f).clickable { onEdit(entry) },
                                    verticalArrangement = Arrangement.spacedBy(4.dp),
                                ) {
                                    Text(entry.accountItem, style = MaterialTheme.typography.titleMedium)
                                    Text("${entry.date}・${entryTypeLabel(entry.entryType)}")
                                    Text(money(entry.amount))
                                    if (entry.receiptImageUrl != null) Text("領収書画像あり")
                                }
                                IconButton(onClick = { deleting = entry }) {
                                    Icon(Icons.Outlined.Delete, contentDescription = "明細を削除")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    deleting?.let { entry ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            title = { Text("明細を削除しますか？") },
            text = { Text("添付した領収書画像も削除されます。") },
            confirmButton = {
                TextButton(onClick = {
                    model.deleteEntry(entry) { if (it.isSuccess) deleting = null }
                }) { Text("削除") }
            },
            dismissButton = { TextButton(onClick = { deleting = null }) { Text("キャンセル") } },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BudgetEntryEditorView(
    model: BudgetSettlementFeatureModel,
    report: BudgetSettlementReport,
    editing: BudgetEntry?,
    onClose: () -> Unit,
) {
    var dateText by rememberSaveable { mutableStateOf(editing?.date?.toString() ?: LocalDate.now().toString()) }
    var type by rememberSaveable { mutableStateOf(editing?.entryType ?: BudgetEntryType.Expense) }
    var accountItem by rememberSaveable { mutableStateOf(editing?.accountItem.orEmpty()) }
    var detail by rememberSaveable { mutableStateOf(editing?.detail.orEmpty()) }
    var amountText by rememberSaveable { mutableStateOf(editing?.amount?.toPlainString().orEmpty()) }
    var receiptType by rememberSaveable { mutableStateOf(editing?.receiptType.orEmpty()) }
    var receiptBytes by remember { mutableStateOf<ByteArray?>(null) }
    var dateError by remember { mutableStateOf<String?>(null) }
    var accountError by remember { mutableStateOf<String?>(null) }
    var amountError by remember { mutableStateOf<String?>(null) }
    var saveError by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val receiptPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        receiptBytes = uri?.let { context.contentResolver.openInputStream(it)?.use { stream -> stream.readBytes() } }
    }
    fun validate(): Triple<LocalDate?, BigDecimal?, Boolean> {
        val date = runCatching { LocalDate.parse(dateText) }.getOrNull()
        val amount = amountText.toBigDecimalOrNull()
        dateError = if (date == null) "日付をYYYY-MM-DD形式で入力してください。" else null
        accountError = if (accountItem.trim().isEmpty()) "科目を入力してください。" else null
        amountError = when {
            amount == null -> "金額を入力してください。"
            amount <= BigDecimal.ZERO -> "金額は0より大きい値を入力してください。"
            else -> null
        }
        return Triple(date, amount, dateError == null && accountError == null && amountError == null)
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (editing == null) "明細の登録" else "明細の編集") },
                navigationIcon = { TextButton(onClick = onClose) { Text("閉じる") } },
            )
        },
    ) { padding ->
        LazyColumn(
            Modifier.padding(padding).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                OutlinedTextField(
                    value = dateText,
                    onValueChange = { dateText = it; dateError = null },
                    label = { Text("日付（YYYY-MM-DD）") },
                    isError = dateError != null,
                    supportingText = { dateError?.let { Text(it) } },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                Text("種別")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    BudgetEntryType.entries.forEach { option ->
                        FilterChip(
                            selected = type == option,
                            onClick = { type = option },
                            label = { Text(entryTypeLabel(option)) },
                        )
                    }
                }
            }
            item {
                OutlinedTextField(
                    value = accountItem,
                    onValueChange = { accountItem = it; accountError = null },
                    label = { Text("科目（必須）") },
                    isError = accountError != null,
                    supportingText = { accountError?.let { Text(it) } },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = detail,
                    onValueChange = { detail = it },
                    label = { Text("詳細") },
                    minLines = 2,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = amountText,
                    onValueChange = { amountText = it; amountError = null },
                    label = { Text("金額（必須）") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    isError = amountError != null,
                    supportingText = { amountError?.let { Text(it) } },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = receiptType,
                    onValueChange = { receiptType = it },
                    label = { Text("証憑種別") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                Button(onClick = { receiptPicker.launch("image/jpeg") }) {
                    Text(if (receiptBytes != null || editing?.receiptImageUrl != null) "領収書画像を変更" else "領収書画像を添付")
                }
            }
            saveError?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
            item {
                Button(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        val (date, amount, valid) = validate()
                        if (!valid || date == null || amount == null) return@Button
                        val now = Instant.now()
                        val entry = BudgetEntry(
                            id = editing?.id ?: java.util.UUID.randomUUID(),
                            reportId = report.id,
                            date = date,
                            entryType = type,
                            accountItem = accountItem,
                            detail = detail,
                            amount = amount,
                            receiptType = receiptType,
                            receiptImageUrl = editing?.receiptImageUrl,
                            createdAt = editing?.createdAt ?: now,
                            updatedAt = now,
                        )
                        model.saveEntry(entry, receiptBytes) { result ->
                            if (result.isSuccess) onClose()
                            else saveError = result.exceptionOrNull()?.message ?: "保存に失敗しました。"
                        }
                    },
                ) { Text("保存") }
            }
        }
    }
}

@Composable
private fun BudgetReportEditorDialog(
    editing: BudgetSettlementReport?,
    onDismiss: () -> Unit,
    onSave: (BudgetSettlementReport) -> Unit,
) {
    var name by rememberSaveable { mutableStateOf(editing?.bookName.orEmpty()) }
    var start by rememberSaveable { mutableStateOf(editing?.fiscalYearStart?.toString() ?: "${LocalDate.now().year}-04-01") }
    var end by rememberSaveable { mutableStateOf(editing?.fiscalYearEnd?.toString() ?: "${LocalDate.now().year + 1}-03-31") }
    var nameError by remember { mutableStateOf<String?>(null) }
    var dateError by remember { mutableStateOf<String?>(null) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (editing == null) "帳簿の登録" else "帳簿の編集") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it; nameError = null },
                    label = { Text("帳簿名（必須）") },
                    isError = nameError != null,
                    supportingText = { nameError?.let { Text(it) } },
                )
                OutlinedTextField(value = start, onValueChange = { start = it; dateError = null }, label = { Text("年度開始日") })
                OutlinedTextField(value = end, onValueChange = { end = it; dateError = null }, label = { Text("年度終了日") })
                dateError?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val startDate = runCatching { LocalDate.parse(start) }.getOrNull()
                val endDate = runCatching { LocalDate.parse(end) }.getOrNull()
                nameError = if (name.trim().isEmpty()) "帳簿名を入力してください。" else null
                dateError = when {
                    startDate == null || endDate == null -> "日付をYYYY-MM-DD形式で入力してください。"
                    endDate.isBefore(startDate) -> "終了日は開始日以降にしてください。"
                    else -> null
                }
                if (nameError == null && dateError == null && startDate != null && endDate != null) {
                    val now = Instant.now()
                    onSave(
                        BudgetSettlementReport(
                            id = editing?.id ?: java.util.UUID.randomUUID(),
                            userId = editing?.userId ?: "guest",
                            fiscalYearStart = startDate,
                            fiscalYearEnd = endDate,
                            bookName = name,
                            incomeTotal = editing?.incomeTotal ?: BigDecimal.ZERO,
                            expenseTotal = editing?.expenseTotal ?: BigDecimal.ZERO,
                            balance = editing?.balance ?: BigDecimal.ZERO,
                            createdAt = editing?.createdAt ?: now,
                            updatedAt = now,
                        ),
                    )
                }
            }) { Text("保存") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("キャンセル") } },
    )
}

@Composable
private fun SummaryCard(label: String, amount: BigDecimal) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(label, style = MaterialTheme.typography.labelLarge)
            Text(money(amount), style = MaterialTheme.typography.headlineSmall)
        }
    }
}

private fun money(value: BigDecimal): String =
    NumberFormat.getCurrencyInstance(Locale.JAPAN).format(value)

private fun entryTypeLabel(type: BudgetEntryType) = when (type) {
    BudgetEntryType.Income -> "収入"
    BudgetEntryType.Expense -> "支出"
}

private fun shareBudgetCsv(
    context: Context,
    report: BudgetSettlementReport,
    entries: List<BudgetEntry>,
) {
    val directory = File(context.cacheDir, "shared").apply { mkdirs() }
    val safeName = report.bookName.replace(Regex("""[/:\\?%*|\"<>]"""), "_")
        .ifBlank { "予算・決算" }
    val file = File(directory, "$safeName.csv").apply {
        writeBytes(BudgetSettlementCsvExporter.export(report, entries))
    }
    val uri = FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        file,
    )
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/csv"
        putExtra(Intent.EXTRA_SUBJECT, "${report.bookName}.csv")
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(intent, "CSVを共有"))
}
