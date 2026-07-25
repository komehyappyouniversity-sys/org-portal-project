package jp.komehyappyo.member.next.feature.community

import android.app.Activity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import jp.komehyappyo.member.next.core.model.CommunityMembershipStatus

@Composable
fun CommunityRoot(model: CommunityFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    val sessionState by model.session.state.collectAsStateWithLifecycle()
    val activity = LocalContext.current as Activity

    LaunchedEffect(sessionState.authenticationToken) {
        if (sessionState.authenticationToken != null) model.refresh()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("つながる")
        if (sessionState.authenticationToken == null) {
            Text("マイページで会員登録またはログイン後に参加申請できます。")
            return@Column
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("参加コミュニティ")
            TextButton(onClick = model::refresh) { Text("更新") }
        }
        if (state.memberships.isEmpty()) {
            Text("参加申請はまだありません。")
        }
        state.memberships.forEach { (membership, community) ->
            Column(
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(community.name)
                Text(
                    when (membership.status) {
                        CommunityMembershipStatus.Pending -> "承認待ち"
                        CommunityMembershipStatus.Approved -> "参加中"
                        CommunityMembershipStatus.Rejected -> "承認されませんでした"
                    },
                )
                if (membership.status == CommunityMembershipStatus.Approved) {
                    OutlinedButton(
                        onClick = { model.session.selectCommunity(community.id) },
                        enabled = sessionState.selectedCommunityId != community.id,
                    ) {
                        Text(
                            if (sessionState.selectedCommunityId == community.id) {
                                "選択中"
                            } else {
                                "このコミュニティへ切替"
                            },
                        )
                    }
                }
            }
            HorizontalDivider()
        }
        if (sessionState.previousCommunityId != null) {
            TextButton(onClick = model.session::returnToPreviousCommunity) {
                Text("前のコミュニティへ戻る")
            }
        }

        Text("コミュニティへ参加")
        OutlinedTextField(
            value = state.code,
            onValueChange = model::updateCode,
            label = { Text("コミュニティコード") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = model::search) { Text("コードを確認") }
            OutlinedButton(
                onClick = {
                    GmsBarcodeScanning.getClient(activity).startScan()
                        .addOnSuccessListener { barcode ->
                            barcode.rawValue?.let(model::receiveScan)
                        }
                        .addOnFailureListener {
                            model.updateCode("")
                        }
                },
            ) {
                Text("QRコードを読む")
            }
        }
        state.candidate?.let { community ->
            Column(
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(community.name)
                if (community.description.isNotEmpty()) Text(community.description)
                Button(onClick = model::apply) {
                    Text("このコミュニティへ参加申請")
                }
            }
        }
        if (state.isLoading) CircularProgressIndicator()
        state.message?.let { Text(it) }
    }
}
