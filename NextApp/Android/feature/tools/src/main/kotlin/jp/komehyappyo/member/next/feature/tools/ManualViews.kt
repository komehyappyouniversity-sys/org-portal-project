package jp.komehyappyo.member.next.feature.tools

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.ErrorState
import jp.komehyappyo.member.next.core.designsystem.FeatureCard
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.model.Manual

@Composable
fun ManualListRoot(model: ManualFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    var selectedManual by remember { mutableStateOf<Manual?>(null) }
    LaunchedEffect(state.manuals) {
        val selected = selectedManual ?: return@LaunchedEffect
        if (state.manuals.none { it.listIdentity == selected.listIdentity }) {
            selectedManual = null
        }
    }

    selectedManual?.let { manual ->
        ManualDetailRoot(
            manual = manual,
            onBack = { selectedManual = null },
        )
        return
    }

    when {
        state.isLoading && !state.hasLoaded -> LoadingState()
        state.errorMessage != null -> ErrorState(
            message = state.errorMessage!!,
            onRetry = model::load,
        )
        state.manuals.isEmpty() -> EmptyState(
            title = "表示可能なマニュアルがありません。",
            message = "公開中のマニュアルが追加されると、ここに表示されます。",
        )
        else -> ManualList(
            manuals = state.manuals,
            onSelect = { selectedManual = it },
        )
    }
}

@Composable
private fun ManualList(
    manuals: List<Manual>,
    onSelect: (Manual) -> Unit,
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(bottom = 24.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("使い方マニュアル", style = MaterialTheme.typography.headlineSmall)
                Text(
                    "アプリ共通と、選択中のコミュニティ専用マニュアルを表示します。",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
        items(manuals, key = { it.listIdentity }) { manual ->
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = { onSelect(manual) },
            ) {
                FeatureCard(
                    title = manual.title,
                    description = if (manual.communityId == null) {
                        "アプリ共通マニュアル"
                    } else {
                        "コミュニティ専用マニュアル"
                    },
                    icon = Icons.AutoMirrored.Outlined.MenuBook,
                    modifier = Modifier,
                )
            }
        }
    }
}

@Composable
private fun ManualDetailRoot(
    manual: Manual,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    var enlargedImageUrl by remember { mutableStateOf<String?>(null) }
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(manual.title, style = MaterialTheme.typography.titleLarge)
                TextButton(onClick = onBack) { Text("閉じる") }
            }
        }
        item {
            Card {
                Text(
                    manual.body,
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        }
        items(manual.imageUrls) { imageUrl ->
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = { enlargedImageUrl = imageUrl },
            ) {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = "画像を拡大",
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 120.dp),
                    contentScale = ContentScale.FillWidth,
                )
            }
        }
        validWebUrl(manual.pdfUrl)?.let { pdfUrl ->
            item {
                Button(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { openUrl(context, pdfUrl) },
                ) { Text("PDFを開く") }
            }
        }
        validWebUrl(manual.externalUrl)?.let { externalUrl ->
            item {
                Button(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { openUrl(context, externalUrl) },
                ) { Text("外部リンクを開く") }
            }
        }
        item {
            Button(modifier = Modifier.fillMaxWidth(), onClick = onBack) {
                Text("一覧に戻る")
            }
        }
    }

    enlargedImageUrl?.let { imageUrl ->
        Dialog(
            onDismissRequest = { enlargedImageUrl = null },
            properties = DialogProperties(usePlatformDefaultWidth = false),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black)
                    .padding(16.dp),
            ) {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = "拡大画像",
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Fit,
                )
                TextButton(
                    modifier = Modifier.align(Alignment.TopEnd),
                    onClick = { enlargedImageUrl = null },
                ) {
                    Text("閉じる", color = Color.White)
                }
            }
        }
    }
}

private fun validWebUrl(value: String?): String? {
    val normalized = value?.trim()?.takeIf(String::isNotEmpty) ?: return null
    val uri = Uri.parse(normalized)
    return normalized.takeIf {
        uri.scheme.equals("https", true) || uri.scheme.equals("http", true)
    }
}

private fun openUrl(context: Context, url: String) {
    context.startActivity(
        Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
    )
}
