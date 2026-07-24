package jp.komehyappyo.member.next.feature.tools

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddCircle
import androidx.compose.material.icons.outlined.RemoveCircle
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import jp.komehyappyo.member.next.core.model.Denomination
import jp.komehyappyo.member.next.core.model.DenominationCalculator
import java.text.NumberFormat
import java.util.Locale

@Composable
fun DenominationCalculatorView() {
    var countTexts by rememberSaveable {
        mutableStateOf(List(Denomination.entries.size) { "" })
    }
    val parsedCounts = parseCounts(countTexts)
    val total = parsedCounts?.let { runCatching { DenominationCalculator.total(it) }.getOrNull() }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Text("金種計算", style = MaterialTheme.typography.headlineSmall)
        }
        item {
            TotalCard(total = total)
        }
        denominationGroup(
            title = "硬貨",
            denominations = Denomination.entries.filter(Denomination::isCoin),
            countTexts = countTexts,
            onCountChanged = { denomination, value ->
                countTexts = countTexts.updated(denomination, value)
            },
        )
        denominationGroup(
            title = "紙幣",
            denominations = Denomination.entries.filter { !it.isCoin },
            countTexts = countTexts,
            onCountChanged = { denomination, value ->
                countTexts = countTexts.updated(denomination, value)
            },
        )
        item {
            OutlinedButton(
                modifier = Modifier.fillMaxWidth(),
                enabled = countTexts.any(String::isNotEmpty),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = MaterialTheme.colorScheme.error,
                ),
                onClick = {
                    countTexts = List(Denomination.entries.size) { "" }
                },
            ) {
                Text("すべてクリア")
            }
        }
    }
}

@Composable
private fun TotalCard(total: Long?) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
        ),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                "合計金額",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
            )
            if (total != null) {
                Text(
                    yenFormatter.format(total),
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                )
            } else {
                Text(
                    "枚数が大きすぎます。入力を減らしてください。",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.denominationGroup(
    title: String,
    denominations: List<Denomination>,
    countTexts: List<String>,
    onCountChanged: (Denomination, String) -> Unit,
) {
    item {
        Text(title, style = MaterialTheme.typography.titleMedium)
    }
    items(denominations, key = { it.name }) { denomination ->
        DenominationRow(
            denomination = denomination,
            countText = countTexts[denomination.ordinal],
            onCountChanged = { onCountChanged(denomination, it) },
        )
    }
}

@Composable
private fun DenominationRow(
    denomination: Denomination,
    countText: String,
    onCountChanged: (String) -> Unit,
) {
    val current = countText.toLongOrNull() ?: 0
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            "${numberFormatter.format(denomination.yenValue)}円",
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold,
        )
        IconButton(
            enabled = current > 0,
            onClick = {
                val updated = (current - 1).coerceAtLeast(0)
                onCountChanged(if (updated == 0L) "" else updated.toString())
            },
        ) {
            Icon(
                Icons.Outlined.RemoveCircle,
                contentDescription = "${denomination.yenValue}円を1枚減らす",
            )
        }
        OutlinedTextField(
            modifier = Modifier.width(96.dp),
            value = countText,
            onValueChange = { value ->
                onCountChanged(value.filter { it in '0'..'9' }.take(18))
            },
            placeholder = { Text("0") },
            suffix = { Text("枚") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            label = { Text("${denomination.yenValue}円") },
        )
        IconButton(
            onClick = {
                if (current < Long.MAX_VALUE) {
                    onCountChanged((current + 1).toString())
                }
            },
        ) {
            Icon(
                Icons.Outlined.AddCircle,
                contentDescription = "${denomination.yenValue}円を1枚増やす",
            )
        }
    }
}

private fun parseCounts(countTexts: List<String>): Map<Denomination, Long>? {
    val result = mutableMapOf<Denomination, Long>()
    Denomination.entries.forEach { denomination ->
        val text = countTexts[denomination.ordinal]
        val count = if (text.isEmpty()) 0 else text.toLongOrNull() ?: return null
        result[denomination] = count
    }
    return result
}

private fun List<String>.updated(
    denomination: Denomination,
    value: String,
): List<String> = toMutableList().also {
    it[denomination.ordinal] = value
}

private val numberFormatter = NumberFormat.getIntegerInstance(Locale.JAPAN)
private val yenFormatter = NumberFormat.getCurrencyInstance(Locale.JAPAN).apply {
    maximumFractionDigits = 0
}
