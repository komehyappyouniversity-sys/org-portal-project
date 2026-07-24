package jp.komehyappyo.member.next.feature.tools

import android.app.DatePickerDialog
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Calculate
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.ErrorState
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.model.CashDistribution
import jp.komehyappyo.member.next.core.model.CashDistributionCalculator
import jp.komehyappyo.member.next.core.model.CashDistributionEntry
import jp.komehyappyo.member.next.core.model.CashDistributionValidationException
import jp.komehyappyo.member.next.core.model.Denomination
import java.io.File
import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private enum class DenominationToolDestination { Distribution, CashTotal }

@Composable
fun DenominationToolRoot(model: CashDistributionFeatureModel) {
    var destination by rememberSaveable {
        mutableStateOf<DenominationToolDestination?>(null)
    }
    when (destination) {
        DenominationToolDestination.Distribution -> CashToolDestinationContainer(
            onBack = { destination = null },
        ) {
            CashDistributionRoot(model)
        }
        DenominationToolDestination.CashTotal -> CashToolDestinationContainer(
            onBack = { destination = null },
        ) {
            DenominationCalculatorView()
        }
        null -> LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item { Text("金種計算", style = MaterialTheme.typography.headlineSmall) }
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { destination = DenominationToolDestination.Distribution },
                ) {
                    ListItem(
                        leadingContent = { Icon(Icons.Outlined.Groups, contentDescription = null) },
                        headlineContent = { Text("金種分配計算") },
                        supportingContent = {
                            Text("配布する金額から必要な紙幣・硬貨の枚数を計算")
                        },
                    )
                }
            }
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { destination = DenominationToolDestination.CashTotal },
                ) {
                    ListItem(
                        leadingContent = {
                            Icon(Icons.Outlined.Calculate, contentDescription = null)
                        },
                        headlineContent = { Text("現金集計") },
                        supportingContent = {
                            Text("手元の紙幣・硬貨の枚数から合計金額を計算")
                        },
                    )
                }
            }
        }
    }
}

private sealed interface CashDistributionScreen {
    data object List : CashDistributionScreen
    data class Detail(val value: CashDistribution) : CashDistributionScreen
    data class Editor(val value: CashDistribution?) : CashDistributionScreen
}

@Composable
fun CashDistributionRoot(model: CashDistributionFeatureModel) {
    var screen: CashDistributionScreen by remember {
        mutableStateOf(CashDistributionScreen.List)
    }
    when (val current = screen) {
        CashDistributionScreen.List -> CashDistributionList(
            model = model,
            onOpen = { screen = CashDistributionScreen.Detail(it) },
            onAdd = { screen = CashDistributionScreen.Editor(null) },
        )
        is CashDistributionScreen.Detail -> CashDistributionDetail(
            model = model,
            distribution = current.value,
            onBack = { screen = CashDistributionScreen.List },
            onEdit = { screen = CashDistributionScreen.Editor(current.value) },
        )
        is CashDistributionScreen.Editor -> CashDistributionEditor(
            model = model,
            editing = current.value,
            onClose = { screen = CashDistributionScreen.List },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CashDistributionList(
    model: CashDistributionFeatureModel,
    onOpen: (CashDistribution) -> Unit,
    onAdd: () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var message by remember { mutableStateOf<String?>(null) }
    val createBackup = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri ->
        if (uri != null) {
            model.exportBackup { result ->
                result.fold(
                    onSuccess = { bytes ->
                        runCatching {
                            context.contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                                ?: error("保存先を開けません。")
                        }.fold(
                            onSuccess = { message = "バックアップを書き出しました。" },
                            onFailure = { message = "バックアップを書き出せませんでした。" },
                        )
                    },
                    onFailure = { message = "バックアップを書き出せませんでした。" },
                )
            }
        }
    }
    val openBackup = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) {
            runCatching {
                context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: error("ファイルを開けません。")
            }.fold(
                onSuccess = { data ->
                    model.importBackup(data) { result ->
                        result.fold(
                            onSuccess = { message = "${it}件の分配記録を復元しました。" },
                            onFailure = { message = "バックアップを読み込めませんでした。" },
                        )
                    }
                },
                onFailure = { message = "バックアップを読み込めませんでした。" },
            )
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("金種分配計算") },
                actions = {
                    IconButton(
                        enabled = state.distributions.isNotEmpty(),
                        onClick = { createBackup.launch("金種分配バックアップ.json") },
                    ) {
                        Icon(Icons.Outlined.FileUpload, contentDescription = "バックアップを書き出す")
                    }
                    IconButton(onClick = { openBackup.launch(arrayOf("application/json")) }) {
                        Icon(Icons.Outlined.FileDownload, contentDescription = "バックアップを読み込む")
                    }
                    IconButton(onClick = onAdd) {
                        Icon(Icons.Outlined.Add, contentDescription = "分配記録を追加")
                    }
                },
            )
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when {
                state.isLoading -> LoadingState()
                state.errorMessage != null -> ErrorState(
                    message = state.errorMessage.orEmpty(),
                    onRetry = model::reload,
                )
                state.distributions.isEmpty() -> EmptyState(
                    title = "分配記録はまだありません",
                    message = "追加ボタンから最初の分配記録を登録できます。",
                )
                else -> LazyColumn {
                    items(state.distributions, key = { it.id }) { distribution ->
                        ListItem(
                            headlineContent = { Text(distribution.title) },
                            supportingContent = {
                                Text(
                                    "${formatDate(distribution.distributionDate)} ・ " +
                                        cashYenFormatter.format(distribution.totalAmount),
                                )
                            },
                            modifier = Modifier.clickable { onOpen(distribution) },
                        )
                    }
                }
            }
        }
    }
    message?.let {
        AlertDialog(
            onDismissRequest = { message = null },
            text = { Text(it) },
            confirmButton = { TextButton(onClick = { message = null }) { Text("OK") } },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CashDistributionEditor(
    model: CashDistributionFeatureModel,
    editing: CashDistribution?,
    onClose: () -> Unit,
) {
    var value by remember { mutableStateOf(editing ?: CashDistribution()) }
    var title by remember { mutableStateOf(value.title) }
    var entries by remember { mutableStateOf(value.entries) }
    var date by remember {
        mutableStateOf(value.distributionDate.atZone(ZoneId.systemDefault()).toLocalDate())
    }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (editing == null) "分配記録を追加" else "分配記録を編集") },
                navigationIcon = { TextButton(onClick = onClose) { Text("キャンセル") } },
                actions = {
                    TextButton(
                        onClick = {
                            value = value.copy(
                                title = title,
                                distributionDate = date.atStartOfDay(ZoneId.systemDefault()).toInstant(),
                                entries = entries,
                            )
                            runCatching { value.validated() }.fold(
                                onSuccess = { validated ->
                                    model.save(validated) { result ->
                                        result.fold(
                                            onSuccess = { onClose() },
                                            onFailure = { errorMessage = "保存できませんでした。" },
                                        )
                                    }
                                },
                                onFailure = { errorMessage = validationMessage(it) },
                            )
                        },
                    ) { Text("保存") }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                OutlinedTextField(
                    modifier = Modifier.fillMaxWidth(),
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("タイトル（必須）") },
                    singleLine = true,
                )
            }
            item {
                OutlinedButton(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        DatePickerDialog(
                            context,
                            { _, year, month, day -> date = LocalDate.of(year, month + 1, day) },
                            date.year,
                            date.monthValue - 1,
                            date.dayOfMonth,
                        ).show()
                    },
                ) { Text("配布日 ${date.format(DateTimeFormatter.ISO_LOCAL_DATE)}") }
            }
            items(entries, key = { it.id }) { entry ->
                val index = entries.indexOfFirst { it.id == entry.id }
                Card(Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text("配布先 ${index + 1}", style = MaterialTheme.typography.titleMedium)
                        RecipientAmountEditor(1, entry.recipientName1, entry.amount1) { name, amount ->
                            entries = entries.updated(index, entry.copy(recipientName1 = name, amount1 = amount))
                        }
                        RecipientAmountEditor(2, entry.recipientName2, entry.amount2) { name, amount ->
                            entries = entries.updated(index, entry.copy(recipientName2 = name, amount2 = amount))
                        }
                        RecipientAmountEditor(3, entry.recipientName3, entry.amount3) { name, amount ->
                            entries = entries.updated(index, entry.copy(recipientName3 = name, amount3 = amount))
                        }
                        OutlinedTextField(
                            modifier = Modifier.fillMaxWidth(),
                            value = entry.receiverName,
                            onValueChange = {
                                entries = entries.updated(index, entry.copy(receiverName = it))
                            },
                            label = { Text("受取確認者") },
                        )
                        Row {
                            Checkbox(
                                checked = entry.receivedDate != null,
                                onCheckedChange = { checked ->
                                    entries = entries.updated(
                                        index,
                                        entry.copy(
                                            receivedDate = if (checked) {
                                                entry.receivedDate ?: Instant.now()
                                            } else {
                                                null
                                            },
                                        ),
                                    )
                                },
                            )
                            Text(
                                "受取日を記録",
                                modifier = Modifier.padding(top = 12.dp),
                            )
                        }
                        entry.receivedDate?.let { receivedDate ->
                            val receivedLocalDate = receivedDate
                                .atZone(ZoneId.systemDefault())
                                .toLocalDate()
                            OutlinedButton(
                                modifier = Modifier.fillMaxWidth(),
                                onClick = {
                                    DatePickerDialog(
                                        context,
                                        { _, year, month, day ->
                                            entries = entries.updated(
                                                index,
                                                entry.copy(
                                                    receivedDate = LocalDate
                                                        .of(year, month + 1, day)
                                                        .atStartOfDay(ZoneId.systemDefault())
                                                        .toInstant(),
                                                ),
                                            )
                                        },
                                        receivedLocalDate.year,
                                        receivedLocalDate.monthValue - 1,
                                        receivedLocalDate.dayOfMonth,
                                    ).show()
                                },
                            ) {
                                Text(
                                    "受取日 ${
                                        receivedLocalDate.format(
                                            DateTimeFormatter.ISO_LOCAL_DATE,
                                        )
                                    }",
                                )
                            }
                        }
                        TextButton(
                            onClick = {
                                entries = entries.filterNot { it.id == entry.id }
                                    .ifEmpty { listOf(CashDistributionEntry()) }
                            },
                        ) {
                            Icon(Icons.Outlined.Delete, contentDescription = null)
                            Text("この行を削除")
                        }
                    }
                }
            }
            item {
                OutlinedButton(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { entries = entries + CashDistributionEntry() },
                ) { Text("配布先の行を追加") }
            }
        }
    }
    errorMessage?.let {
        AlertDialog(
            onDismissRequest = { errorMessage = null },
            title = { Text("入力内容を確認してください") },
            text = { Text(it) },
            confirmButton = { TextButton(onClick = { errorMessage = null }) { Text("OK") } },
        )
    }
}

@Composable
private fun RecipientAmountEditor(
    number: Int,
    name: String,
    amount: Long,
    onChange: (String, Long) -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            modifier = Modifier.weight(1f),
            value = name,
            onValueChange = { onChange(it, amount) },
            label = { Text("受取人$number") },
            singleLine = true,
        )
        OutlinedTextField(
            modifier = Modifier.weight(1f),
            value = if (amount == 0L) "" else amount.toString(),
            onValueChange = { text ->
                val filtered = text.filter(Char::isDigit).take(18)
                onChange(name, filtered.toLongOrNull() ?: 0)
            },
            label = { Text("配布額") },
            suffix = { Text("円") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CashDistributionDetail(
    model: CashDistributionFeatureModel,
    distribution: CashDistribution,
    onBack: () -> Unit,
    onEdit: () -> Unit,
) {
    val context = LocalContext.current
    var confirmDelete by remember { mutableStateOf(false) }
    val counts = remember(distribution) {
        runCatching { CashDistributionCalculator.requiredCounts(distribution.entries) }
            .getOrDefault(emptyMap())
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(distribution.title) },
                navigationIcon = { TextButton(onClick = onBack) { Text("戻る") } },
                actions = {
                    IconButton(onClick = {
                        shareFile(
                            context,
                            CashDistributionExporter.csvFile(context, distribution),
                            "text/csv",
                        )
                    }) { Icon(Icons.Outlined.Share, contentDescription = "CSVを共有") }
                    IconButton(onClick = {
                        shareFile(
                            context,
                            CashDistributionExporter.pdfFile(context, distribution),
                            "application/pdf",
                        )
                    }) { Icon(Icons.Outlined.FileUpload, contentDescription = "PDFを共有") }
                    IconButton(onClick = onEdit) {
                        Icon(Icons.Outlined.Edit, contentDescription = "編集")
                    }
                    IconButton(onClick = { confirmDelete = true }) {
                        Icon(Icons.Outlined.Delete, contentDescription = "削除")
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item { Text("配布日 ${formatDate(distribution.distributionDate)}") }
            item {
                Text(
                    "合計 ${cashYenFormatter.format(distribution.totalAmount)}",
                    style = MaterialTheme.typography.headlineSmall,
                )
            }
            item { Text("必要な金種", style = MaterialTheme.typography.titleMedium) }
            items(Denomination.entries.sortedByDescending { it.yenValue }) { denomination ->
                val count = counts[denomination] ?: 0
                if (count > 0) {
                    ListItem(
                        headlineContent = { Text("${denomination.yenValue}円") },
                        trailingContent = { Text("${count}枚") },
                    )
                }
            }
            distribution.entries.forEachIndexed { index, entry ->
                item { Text("配布先 ${index + 1}", style = MaterialTheme.typography.titleMedium) }
                entry.recipientAmounts.filter { it.second > 0 }.forEach { pair ->
                    item {
                        ListItem(
                            headlineContent = { Text(pair.first) },
                            trailingContent = { Text(cashYenFormatter.format(pair.second)) },
                        )
                    }
                }
                entry.receivedDate?.let {
                    item { Text("受取日 ${formatDate(it)}") }
                }
                if (entry.receiverName.isNotBlank()) {
                    item { Text("受取確認者 ${entry.receiverName}") }
                }
            }
        }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("この分配記録を削除しますか？") },
            text = { Text("削除した記録は元に戻せません。") },
            confirmButton = {
                TextButton(onClick = {
                    model.delete(distribution) { if (it.isSuccess) onBack() }
                    confirmDelete = false
                }) { Text("削除") }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("キャンセル") }
            },
        )
    }
}

object CashDistributionExporter {
    fun csvFile(context: Context, distribution: CashDistribution): File {
        return shareFile(context, distribution.title, "csv").apply {
            writeBytes(csvData(distribution))
        }
    }

    fun csvData(distribution: CashDistribution): ByteArray {
        val rows = mutableListOf(
            listOf("配布日", "タイトル", "受取人", "配布額", "受取日", "受取確認者"),
        )
        distribution.entries.forEach { entry ->
            entry.recipientAmounts.filter { it.second > 0 }.forEach { pair ->
                rows += listOf(
                    formatDate(distribution.distributionDate),
                    distribution.title,
                    pair.first,
                    pair.second.toString(),
                    entry.receivedDate?.let(::formatDate).orEmpty(),
                    entry.receiverName,
                )
            }
        }
        val csv = rows.joinToString("\r\n") { row ->
            row.joinToString(",") { "\"${it.replace("\"", "\"\"")}\"" }
        } + "\r\n"
        return byteArrayOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte()) + csv.toByteArray()
    }

    fun pdfFile(context: Context, distribution: CashDistribution): File {
        val file = shareFile(context, distribution.title, "pdf")
        val document = PdfDocument()
        var pageNumber = 1
        var page = document.startPage(PdfDocument.PageInfo.Builder(595, 842, pageNumber).create())
        var y = 48f
        val paint = Paint().apply { textSize = 14f }
        fun line(text: String, bold: Boolean = false) {
            if (y > 800) {
                document.finishPage(page)
                pageNumber += 1
                page = document.startPage(
                    PdfDocument.PageInfo.Builder(595, 842, pageNumber).create(),
                )
                y = 48f
            }
            paint.isFakeBoldText = bold
            page.canvas.drawText(text, 44f, y, paint)
            y += 24f
        }
        paint.textSize = 22f
        line(distribution.title, true)
        paint.textSize = 14f
        line("配布日: ${formatDate(distribution.distributionDate)}")
        line("合計: ${cashYenFormatter.format(distribution.totalAmount)}", true)
        line("必要な金種", true)
        CashDistributionCalculator.requiredCounts(distribution.entries)
            .filterValues { it > 0 }
            .toList()
            .sortedByDescending { it.first.yenValue }
            .forEach { (denomination, count) ->
                line("${denomination.yenValue}円: ${count}枚")
            }
        line("配布先", true)
        distribution.entries.forEach { entry ->
            entry.recipientAmounts.filter { it.second > 0 }.forEach { pair ->
                line("${pair.first}: ${cashYenFormatter.format(pair.second)}")
            }
            entry.receivedDate?.let { line("受取日: ${formatDate(it)}") }
            if (entry.receiverName.isNotBlank()) {
                line("受取確認者: ${entry.receiverName}")
            }
        }
        document.finishPage(page)
        file.outputStream().use(document::writeTo)
        document.close()
        return file
    }

    private fun shareFile(context: Context, name: String, extension: String): File {
        val directory = File(context.cacheDir, "shared").apply { mkdirs() }
        val safeName = name.replace(Regex("""[/:\\?%*|"<>]"""), "_").ifBlank { "金種分配" }
        return File(directory, "$safeName.$extension")
    }
}

private fun shareFile(context: Context, file: File, mimeType: String) {
    val uri = FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        file,
    )
    context.startActivity(
        Intent.createChooser(
            Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
            "共有",
        ),
    )
}

private fun List<CashDistributionEntry>.updated(
    index: Int,
    value: CashDistributionEntry,
): List<CashDistributionEntry> = toMutableList().also { it[index] = value }

private fun validationMessage(error: Throwable): String = when (error) {
    CashDistributionValidationException.TitleRequired -> "タイトルを入力してください。"
    CashDistributionValidationException.AmountRequired -> "1件以上の配布額を入力してください。"
    CashDistributionValidationException.RecipientNameRequired ->
        "配布額を入力した受取人の名前を入力してください。"
    CashDistributionValidationException.NegativeAmount -> "配布額は0円以上で入力してください。"
    CashDistributionValidationException.Overflow -> "金額が大きすぎます。"
    else -> "保存できませんでした。"
}

private fun formatDate(instant: Instant): String =
    DateTimeFormatter.ofPattern("yyyy年M月d日", Locale.JAPAN)
        .withZone(ZoneId.systemDefault())
        .format(instant)

private val cashYenFormatter = NumberFormat.getCurrencyInstance(Locale.JAPAN).apply {
    maximumFractionDigits = 0
}

@Composable
private fun CashToolDestinationContainer(
    onBack: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.fillMaxSize()) {
        TextButton(onClick = onBack) { Text("金種計算に戻る") }
        Box(modifier = Modifier.weight(1f)) { content() }
    }
}
