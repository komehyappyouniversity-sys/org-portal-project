package jp.komehyappyo.member.next.feature.tools

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Row
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import jp.komehyappyo.member.next.core.designsystem.FeatureCard

data class ManualItem(
    val id: String,
    val title: String,
    val description: String,
    val detail: String,
    val externalURL: String? = null,
)

@Composable
fun ManualListRoot() {
    var selectedManual by remember { mutableStateOf<ManualItem?>(null) }

    if (selectedManual != null) {
        ManualDetailRoot(
            manual = selectedManual!!,
            onBack = { selectedManual = null },
        )
        return
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(bottom = 24.dp),
    ) {
        item {
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text("使い方マニュアル", style = MaterialTheme.typography.headlineSmall)
                Text(
                    "ログイン、コミュニティ参加、主要機能の使い方をまとめています。",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
        items(availableManuals, key = { it.id }) { manual ->
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = { selectedManual = manual },
            ) {
                FeatureCard(
                    title = manual.title,
                    description = manual.description,
                    icon = Icons.AutoMirrored.Outlined.MenuBook,
                    modifier = Modifier,
                )
            }
        }
        if (availableManuals.isEmpty()) {
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text("表示可能なマニュアルがありません。")
                    }
                }
            }
        }
    }
}

@Composable
private fun ManualDetailRoot(
    manual: ManualItem,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
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
                Text(
                    manual.title,
                    style = MaterialTheme.typography.titleLarge,
                )
                TextButton(onClick = onBack) {
                    Text("閉じる")
                }
            }
        }
        item {
            Card {
                Text(
                    manual.detail,
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        }
        manual.externalURL?.let { externalURL ->
            item {
                Button(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        openUrl(context, externalURL)
                    },
                ) {
                    Text("外部参照を開く")
                }
            }
        }
        item {
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = onBack,
            ) {
                Text("一覧に戻る")
            }
        }
    }
}

private fun openUrl(context: Context, url: String) {
    context.startActivity(
        Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
    )
}

val availableManuals: List<ManualItem> = listOf(
    ManualItem(
        id = "quick-start",
        title = "1. アカウントと開始の流れ",
        description = "Guestで始めて、会員登録するまで。",
        detail =
        """
        1) アプリを開くとホームと便利機能が表示されます。
        2) 会員登録はマイページからメールアドレスで行います。
        3) コミュニティへ参加するには、コミュニティコードまたはQRコードを使います。
        4) 承認後、コミュニティ機能（投稿・お知らせなど）が利用できます。
        """.trimIndent(),
    ),
    ManualItem(
        id = "tools-start",
        title = "2. 便利機能の使い方",
        description = "予定、日記、金種計算、会議録音など。",
        detail =
        """
        ホーム・便利タブから各機能画面を開けます。
        - 予定: 今日の予定を入力し、繰り返しやリマインダーを設定します。
        - 日記・写真日記: 写真付きで自分用の記録を残します。
        - 金種計算: 配布金額を入力して、必要な紙幣・硬貨を整理できます。
        - 会議録音: 文章化は端末内で保存し、後で確認できるようにします。
        """.trimIndent(),
    ),
    ManualItem(
        id = "sns-favorites",
        title = "3. SNS補助・お気に入りの使い方",
        description = "投稿補助やリンク保存の流れを確認。",
        detail =
        """
        SNS投稿補助では、文章を1タップで外部SNSへコピーできます。
        お気に入りは、タイトル・URL・メモを保存し、アプリ削除前にバックアップも可能です。
        共有URLは同じ機能内でワンタップで開けるため、後から見返しやすいです。
        """.trimIndent(),
    ),
    ManualItem(
        id = "troubleshoot",
        title = "4. よくあるトラブル",
        description = "音声・写真・同期で困ったときの確認ポイント。",
        detail =
        """
        - 録音が再生されない: 権限（マイク）と保存先の空き容量を確認します。
        - カメラや写真が保存されない: 端末内保存の許可、またはアプリ更新後の再起動で解消する場合があります。
        - ログインできない: メールアドレスとパスワード、再度パスワードリセットを確認します。
        - コミュニティ参加できない: 正しいコミュニティコードか、承認待ち状態かを確認します。
        """.trimIndent(),
        externalURL = null,
    ),
)
