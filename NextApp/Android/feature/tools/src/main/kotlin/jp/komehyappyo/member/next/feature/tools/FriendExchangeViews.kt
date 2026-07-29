package jp.komehyappyo.member.next.feature.tools

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.model.FriendContact
import jp.komehyappyo.member.next.core.model.FriendInteractionHistory
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

private sealed interface FriendExchangeDestination {
    data object List : FriendExchangeDestination
    data class ContactEditor(val contact: FriendContact?) : FriendExchangeDestination
    data class Detail(val contact: FriendContact) : FriendExchangeDestination
    data class HistoryEditor(
        val contact: FriendContact,
        val history: FriendInteractionHistory?,
    ) : FriendExchangeDestination
}

@Composable
fun FriendExchangeRoot(model: FriendExchangeFeatureModel) {
    val state by model.state.collectAsStateWithLifecycle()
    var destination: FriendExchangeDestination by remember {
        mutableStateOf(FriendExchangeDestination.List)
    }

    state.errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = model::clearError,
            confirmButton = { TextButton(onClick = model::clearError) { Text("閉じる") } },
            title = { Text("処理できませんでした") },
            text = { Text(message) },
        )
    }
    state.notice?.let { message ->
        AlertDialog(
            onDismissRequest = model::clearNotice,
            confirmButton = { TextButton(onClick = model::clearNotice) { Text("確認") } },
            text = { Text(message) },
        )
    }

    when (val current = destination) {
        FriendExchangeDestination.List -> FriendContactList(
            contacts = state.contacts,
            isLoading = state.isLoading,
            onAdd = { destination = FriendExchangeDestination.ContactEditor(null) },
            onOpen = { destination = FriendExchangeDestination.Detail(it) },
        )
        is FriendExchangeDestination.ContactEditor -> FriendContactEditor(
            contact = current.contact,
            onCancel = {
                destination = current.contact?.let(FriendExchangeDestination::Detail)
                    ?: FriendExchangeDestination.List
            },
            onSave = { values ->
                model.saveContact(
                    existing = current.contact,
                    name = values.name,
                    postalCode = values.postalCode,
                    prefecture = values.prefecture,
                    city = values.city,
                    addressLine = values.addressLine,
                    birthDate = values.birthDate,
                    phoneNumber = values.phoneNumber,
                    email = values.email,
                ) { saved ->
                    if (saved) destination = FriendExchangeDestination.List
                }
            },
        )
        is FriendExchangeDestination.Detail -> FriendContactDetail(
            contact = current.contact,
            histories = state.histories[current.contact.id].orEmpty(),
            onLoad = { model.observeHistories(current.contact.id) },
            onBack = { destination = FriendExchangeDestination.List },
            onEdit = { destination = FriendExchangeDestination.ContactEditor(current.contact) },
            onAddHistory = {
                destination = FriendExchangeDestination.HistoryEditor(current.contact, null)
            },
            onEditHistory = {
                destination = FriendExchangeDestination.HistoryEditor(current.contact, it)
            },
            onDeleteContact = {
                model.deleteContact(current.contact)
                destination = FriendExchangeDestination.List
            },
            onDeleteHistory = model::deleteHistory,
        )
        is FriendExchangeDestination.HistoryEditor -> FriendHistoryEditor(
            contact = current.contact,
            history = current.history,
            onCancel = { destination = FriendExchangeDestination.Detail(current.contact) },
            onSave = { values ->
                model.saveHistory(
                    existing = current.history,
                    friendId = current.contact.id,
                    interactionDate = values.interactionDate,
                    memo = values.memo,
                    photoUrls = values.photoUrls,
                    isPhoneCall = values.isPhoneCall,
                    phoneNumber = values.phoneNumber,
                ) { saved ->
                    if (saved) destination = FriendExchangeDestination.Detail(current.contact)
                }
            },
        )
    }
}

@Composable
private fun FriendContactList(
    contacts: List<FriendContact>,
    isLoading: Boolean,
    onAdd: () -> Unit,
    onOpen: (FriendContact) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("友達情報・交流履歴帳", style = MaterialTheme.typography.headlineSmall)
        Text("本人だけが利用できる非公開の記録です。")
        Button(onClick = onAdd) { Text("友達を追加") }
        when {
            isLoading -> LoadingState()
            contacts.isEmpty() -> EmptyState(
                title = "友達情報はまだありません",
                message = "「友達を追加」から登録できます。",
            )
            else -> contacts.forEach { contact ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpen(contact) },
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(contact.name, style = MaterialTheme.typography.titleMedium)
                        if (contact.phoneNumber.isNotBlank()) Text(contact.phoneNumber)
                        if (contact.email.isNotBlank()) Text(contact.email)
                    }
                }
            }
        }
    }
}

private data class ContactEditorValues(
    val name: String,
    val postalCode: String,
    val prefecture: String,
    val city: String,
    val addressLine: String,
    val birthDate: LocalDate?,
    val phoneNumber: String,
    val email: String,
)

@Composable
private fun FriendContactEditor(
    contact: FriendContact?,
    onCancel: () -> Unit,
    onSave: (ContactEditorValues) -> Unit,
) {
    var name by rememberSaveable { mutableStateOf(contact?.name.orEmpty()) }
    var postalCode by rememberSaveable { mutableStateOf(contact?.postalCode.orEmpty()) }
    var prefecture by rememberSaveable { mutableStateOf(contact?.prefecture.orEmpty()) }
    var city by rememberSaveable { mutableStateOf(contact?.city.orEmpty()) }
    var addressLine by rememberSaveable { mutableStateOf(contact?.addressLine.orEmpty()) }
    var birthDate by rememberSaveable { mutableStateOf(contact?.birthDate?.toString().orEmpty()) }
    var phoneNumber by rememberSaveable { mutableStateOf(contact?.phoneNumber.orEmpty()) }
    var email by rememberSaveable { mutableStateOf(contact?.email.orEmpty()) }
    var dateError by rememberSaveable { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(if (contact == null) "友達を追加" else "友達情報を編集", style = MaterialTheme.typography.headlineSmall)
        OutlinedTextField(name, { name = it }, label = { Text("名前（必須）") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(postalCode, { postalCode = it }, label = { Text("郵便番号") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(prefecture, { prefecture = it }, label = { Text("都道府県") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(city, { city = it }, label = { Text("市区町村") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(addressLine, { addressLine = it }, label = { Text("番地・建物名") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(
            birthDate,
            { birthDate = it; dateError = false },
            label = { Text("生年月日（YYYY-MM-DD）") },
            isError = dateError,
            supportingText = if (dateError) ({ Text("日付をYYYY-MM-DD形式で入力してください。") }) else null,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(phoneNumber, { phoneNumber = it }, label = { Text("電話番号") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(email, { email = it }, label = { Text("メールアドレス") }, modifier = Modifier.fillMaxWidth())
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onCancel) { Text("キャンセル") }
            Button(onClick = {
                val parsedDate = birthDate.takeIf(String::isNotBlank)?.let {
                    runCatching { LocalDate.parse(it) }.getOrNull()
                }
                dateError = birthDate.isNotBlank() && parsedDate == null
                if (!dateError) {
                    onSave(
                        ContactEditorValues(
                            name, postalCode, prefecture, city, addressLine,
                            parsedDate, phoneNumber, email,
                        ),
                    )
                }
            }) { Text("保存") }
        }
    }
}

@Composable
private fun FriendContactDetail(
    contact: FriendContact,
    histories: List<FriendInteractionHistory>,
    onLoad: () -> Unit,
    onBack: () -> Unit,
    onEdit: () -> Unit,
    onAddHistory: () -> Unit,
    onEditHistory: (FriendInteractionHistory) -> Unit,
    onDeleteContact: () -> Unit,
    onDeleteHistory: (FriendInteractionHistory) -> Unit,
) {
    val context = LocalContext.current
    var confirmCall by remember { mutableStateOf(false) }
    var confirmDeleteContact by remember { mutableStateOf(false) }
    var pendingHistoryDelete by remember { mutableStateOf<FriendInteractionHistory?>(null) }
    LaunchedEffect(contact.id) { onLoad() }

    if (confirmCall) {
        AlertDialog(
            onDismissRequest = { confirmCall = false },
            title = { Text("電話をかけますか？") },
            text = { Text(contact.phoneNumber) },
            dismissButton = { TextButton(onClick = { confirmCall = false }) { Text("キャンセル") } },
            confirmButton = {
                TextButton(onClick = {
                    confirmCall = false
                    context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:${contact.phoneNumber}")))
                }) { Text("電話画面を開く") }
            },
        )
    }
    if (confirmDeleteContact) {
        ConfirmDeleteDialog(
            message = "この友達情報と交流履歴を削除します。よろしいですか？",
            onDismiss = { confirmDeleteContact = false },
            onConfirm = { confirmDeleteContact = false; onDeleteContact() },
        )
    }
    pendingHistoryDelete?.let { history ->
        ConfirmDeleteDialog(
            message = "この交流履歴を削除しますか？",
            onDismiss = { pendingHistoryDelete = null },
            onConfirm = { pendingHistoryDelete = null; onDeleteHistory(history) },
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(contact.name, style = MaterialTheme.typography.headlineSmall)
        Text(contactAddress(contact).ifBlank { "住所未登録" })
        contact.birthDate?.let { Text("生年月日: $it") }
        if (contact.phoneNumber.isNotBlank()) Text("電話: ${contact.phoneNumber}")
        if (contact.email.isNotBlank()) Text("メール: ${contact.email}")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onBack) { Text("一覧へ") }
            Button(onClick = onEdit) { Text("編集") }
        }
        if (contact.phoneNumber.isNotBlank()) {
            OutlinedButton(onClick = { confirmCall = true }) { Text("電話をかける") }
        }
        TextButton(onClick = { confirmDeleteContact = true }) { Text("友達情報を削除") }
        HorizontalDivider()
        Text("交流履歴", style = MaterialTheme.typography.titleLarge)
        Button(onClick = onAddHistory) { Text("交流履歴を追加") }
        if (histories.isEmpty()) {
            Text("交流履歴はまだありません。")
        } else {
            histories.forEach { history ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onEditHistory(history) },
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(history.interactionDate.atZone(ZoneId.systemDefault()).toLocalDate().toString())
                        if (history.isPhoneCall) Text("電話で交流")
                        if (history.memo.isNotBlank()) Text(history.memo)
                        if (history.photoUrls.isNotEmpty()) Text("写真 ${history.photoUrls.size}枚")
                        TextButton(onClick = { pendingHistoryDelete = history }) { Text("削除") }
                    }
                }
            }
        }
    }
}

private data class HistoryEditorValues(
    val interactionDate: Instant,
    val memo: String,
    val photoUrls: List<String>,
    val isPhoneCall: Boolean,
    val phoneNumber: String,
)

@Composable
private fun FriendHistoryEditor(
    contact: FriendContact,
    history: FriendInteractionHistory?,
    onCancel: () -> Unit,
    onSave: (HistoryEditorValues) -> Unit,
) {
    val initialDate = history?.interactionDate
        ?.atZone(ZoneId.systemDefault())
        ?.toLocalDate()
        ?: LocalDate.now()
    var date by rememberSaveable { mutableStateOf(initialDate.toString()) }
    var memo by rememberSaveable { mutableStateOf(history?.memo.orEmpty()) }
    var photo1 by rememberSaveable { mutableStateOf(history?.photoUrls?.getOrNull(0).orEmpty()) }
    var photo2 by rememberSaveable { mutableStateOf(history?.photoUrls?.getOrNull(1).orEmpty()) }
    var isPhoneCall by rememberSaveable { mutableStateOf(history?.isPhoneCall ?: false) }
    var phoneNumber by rememberSaveable {
        mutableStateOf(history?.phoneNumber?.ifBlank { contact.phoneNumber } ?: contact.phoneNumber)
    }
    var dateError by rememberSaveable { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(if (history == null) "交流履歴を追加" else "交流履歴を編集", style = MaterialTheme.typography.headlineSmall)
        OutlinedTextField(
            date,
            { date = it; dateError = false },
            label = { Text("交流日（YYYY-MM-DD）") },
            isError = dateError,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(memo, { memo = it }, label = { Text("メモ") }, minLines = 4, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(photo1, { photo1 = it }, label = { Text("写真URL 1") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(photo2, { photo2 = it }, label = { Text("写真URL 2") }, modifier = Modifier.fillMaxWidth())
        Row {
            Checkbox(isPhoneCall, { isPhoneCall = it })
            Text("電話での交流として記録", modifier = Modifier.padding(top = 12.dp))
        }
        if (isPhoneCall) {
            OutlinedTextField(phoneNumber, { phoneNumber = it }, label = { Text("電話番号") }, modifier = Modifier.fillMaxWidth())
        }
        Text("メモ・写真・電話記録のいずれかを入力してください。")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onCancel) { Text("キャンセル") }
            Button(onClick = {
                val parsed = runCatching { LocalDate.parse(date) }.getOrNull()
                dateError = parsed == null
                parsed?.let {
                    onSave(
                        HistoryEditorValues(
                            interactionDate = it.atStartOfDay(ZoneId.systemDefault()).toInstant(),
                            memo = memo,
                            photoUrls = listOf(photo1, photo2).filter(String::isNotBlank),
                            isPhoneCall = isPhoneCall,
                            phoneNumber = phoneNumber,
                        ),
                    )
                }
            }) { Text("保存") }
        }
    }
}

@Composable
private fun ConfirmDeleteDialog(
    message: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("削除の確認") },
        text = { Text(message) },
        dismissButton = { TextButton(onClick = onDismiss) { Text("キャンセル") } },
        confirmButton = { TextButton(onClick = onConfirm) { Text("削除") } },
    )
}

private fun contactAddress(contact: FriendContact): String =
    listOf(contact.postalCode, contact.prefecture, contact.city, contact.addressLine)
        .filter(String::isNotBlank)
        .joinToString(" ")
