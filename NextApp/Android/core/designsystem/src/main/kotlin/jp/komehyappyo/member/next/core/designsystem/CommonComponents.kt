package jp.komehyappyo.member.next.core.designsystem

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun FeatureCard(
    title: String,
    description: String,
    modifier: Modifier = Modifier,
    content: @Composable (() -> Unit)? = null,
) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(description, style = MaterialTheme.typography.bodyMedium)
            content?.invoke()
        }
    }
}

@Composable
fun CommunitySwitcher(
    communities: List<Pair<String, String>>,
    selectedId: String?,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        TextButton(onClick = { expanded = true }) {
            Text(communities.firstOrNull { it.first == selectedId }?.second ?: "コミュニティを選択")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            communities.forEach { community ->
                DropdownMenuItem(
                    text = { Text(community.second) },
                    onClick = {
                        expanded = false
                        onSelect(community.first)
                    },
                )
            }
        }
    }
}

@Composable
fun PrimaryActionButton(label: String, onClick: () -> Unit, enabled: Boolean = true) {
    Button(onClick = onClick, enabled = enabled, modifier = Modifier.fillMaxWidth()) {
        Text(label)
    }
}

@Composable
fun StatusBadge(label: String) {
    AssistChip(onClick = {}, label = { Text(label) })
}

@Composable
fun EmptyState(title: String, message: String, action: (@Composable () -> Unit)? = null) {
    StateContainer {
        Text(title, style = MaterialTheme.typography.titleMedium)
        Text(message)
        action?.invoke()
    }
}

@Composable
fun ErrorState(message: String, onRetry: () -> Unit) {
    StateContainer {
        Text("読み込みに失敗しました", style = MaterialTheme.typography.titleMedium)
        Text(message, color = MaterialTheme.colorScheme.error)
        Button(onClick = onRetry) { Text("再試行") }
    }
}

@Composable
fun LoadingState() {
    StateContainer {
        CircularProgressIndicator()
        Text("読み込み中")
    }
}

@Composable
fun PermissionRequiredState(message: String, onOpenSettings: () -> Unit) {
    StateContainer {
        Text("権限が必要です", style = MaterialTheme.typography.titleMedium)
        Text(message)
        Button(onClick = onOpenSettings) { Text("設定を開く") }
    }
}

@Composable
fun OfflineBanner() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        horizontalArrangement = Arrangement.Center,
    ) {
        Text("オフラインです。端末内のデータを表示しています。")
    }
}

@Composable
private fun StateContainer(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        content()
    }
}
