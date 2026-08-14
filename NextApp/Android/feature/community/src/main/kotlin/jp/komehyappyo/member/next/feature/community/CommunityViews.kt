package jp.komehyappyo.member.next.feature.community

import android.app.Activity
import android.content.res.Configuration
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import jp.komehyappyo.member.next.core.designsystem.OfflineBanner
import jp.komehyappyo.member.next.core.model.RadioPlaybackRecord
import jp.komehyappyo.member.next.core.model.RadioProgram
import jp.komehyappyo.member.next.core.model.BookingEvent
import jp.komehyappyo.member.next.core.model.BookingSlot
import jp.komehyappyo.member.next.core.model.CommunityAuditLog
import jp.komehyappyo.member.next.core.model.CommunityMembershipStatus
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun CommunityRoot(
    model: CommunityFeatureModel,
    onRefreshManagementPosts: () -> Unit,
    memberPostReplyContent: @Composable () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val sessionState by model.session.state.collectAsStateWithLifecycle()
    val activity = LocalContext.current as Activity
    val uriHandler = LocalUriHandler.current
    var selectedVideoId by rememberSaveable { mutableStateOf<String?>(null) }
    val selectedVideo = state.distributedVideos.firstOrNull { it.id == selectedVideoId }
    var bookingEventId by rememberSaveable { mutableStateOf("") }
    var bookingEventTitle by rememberSaveable { mutableStateOf("") }
    var bookingEventDescription by rememberSaveable { mutableStateOf("") }
    var bookingEventDate by rememberSaveable { mutableStateOf("") }
    var bookingEventFee by rememberSaveable { mutableStateOf("0") }
    var bookingEventZoomUrl by rememberSaveable { mutableStateOf("") }
    var bookingSlotId by rememberSaveable { mutableStateOf("") }
    var bookingSlotStartAt by rememberSaveable { mutableStateOf("") }
    var bookingSlotEndAt by rememberSaveable { mutableStateOf("") }
    var bookingSlotCapacity by rememberSaveable { mutableStateOf("1") }
    var bookingSlotOpen by rememberSaveable { mutableStateOf(true) }
    var bookingCancellationTarget by remember { mutableStateOf<Pair<BookingEvent, BookingSlot>?>(null) }
    val adminVideoQuestionAnswers = remember { mutableStateMapOf<String, String>() }

    LaunchedEffect(sessionState.authenticationToken) {
        model.refreshPublicCommunities()
        if (sessionState.authenticationToken != null) model.refresh()
        model.refreshRadioPrograms()
        onRefreshManagementPosts()
    }
    LaunchedEffect(sessionState.selectedCommunityId) {
        if (sessionState.authenticationToken != null) {
            onRefreshManagementPosts()
        }
        model.refreshRadioPrograms()
    }

    if (selectedVideo != null) {
        VimeoVideoDetailScreen(
            model = model,
            video = selectedVideo,
            onBack = { selectedVideoId = null },
        )
        return
    }

    bookingCancellationTarget?.let { (event, slot) ->
        AlertDialog(
            onDismissRequest = { bookingCancellationTarget = null },
            title = { Text("予約をキャンセルしますか？") },
            text = { Text("この操作を取り消すことはできません。") },
            confirmButton = {
                Button(onClick = {
                    model.cancelBooking(event, slot)
                    bookingCancellationTarget = null
                }) { Text("予約をキャンセル") }
            },
            dismissButton = {
                TextButton(onClick = { bookingCancellationTarget = null }) { Text("戻る") }
            },
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("つながる")
        if (state.isLoading) CircularProgressIndicator()
        if (state.hasPendingVideoMemoSync) {
            OfflineBanner()
        }
        state.message?.let { Text(it) }

        if (model.canAccessRadio()) {
            Text("インターネットラジオ")
            if (state.radioIsLoading) {
                CircularProgressIndicator()
            } else if (state.radioPrograms.isEmpty()) {
                Text("ラジオ番組はありません。")
            } else {
                RadioSection(
                    programs = state.radioPrograms,
                    records = state.radioPlaybackRecords,
                    playingProgramId = state.radioPlayingProgramId,
                    currentUserId = sessionState.userId,
                    formatter = radioDateTimeFormatter(),
                    isLoading = state.radioIsLoading,
                    onToggle = model::toggleRadioPlayback,
                    isPlayable = model::isRadioPlayable,
                )
                HorizontalDivider()
            }
        }

        Text("コミュニティを探す")
        Text("公開中のコミュニティを見て回れます。")
        OutlinedTextField(
            value = state.publicQuery,
            onValueChange = model::updatePublicQuery,
            label = { Text("名前・コード・紹介文で検索") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedButton(onClick = model::refreshPublicCommunities) {
            Text("検索")
        }
        if (state.publicCommunities.isEmpty() && !state.isLoading) {
            Text("公開中のコミュニティは見つかりませんでした。")
        }
        state.publicCommunities.forEach { community ->
            val membership = state.memberships.firstOrNull {
                it.second.id == community.id
            }?.first
            Column(
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                community.logoUrl?.takeIf(String::isNotBlank)?.let { logoUrl ->
                    AsyncImage(
                        model = logoUrl,
                        contentDescription = "${community.name}のロゴ",
                        modifier = Modifier.fillMaxWidth().height(96.dp),
                    )
                }
                Text(community.name)
                Text("コード: ${community.code}")
                if (community.description.isNotEmpty()) {
                    Text(community.description)
                }
                community.homepageUrl?.let { homepage ->
                    TextButton(onClick = { uriHandler.openUri(homepage) }) {
                        Text("ホームページを見る")
                    }
                }
                Text(
                    when (membership?.status) {
                        CommunityMembershipStatus.Pending -> "承認待ち"
                        CommunityMembershipStatus.Approved -> "参加中"
                        CommunityMembershipStatus.Rejected -> "承認されませんでした"
                        null -> if (community.joinEnabled) {
                            "参加申請受付中"
                        } else {
                            "現在は参加申請受付外"
                        }
                    },
                )
                when (membership?.status) {
                    CommunityMembershipStatus.Approved -> {
                        Button(
                            onClick = { model.selectCommunity(community.id) },
                            enabled = sessionState.selectedCommunityId != community.id,
                        ) {
                            Text(
                                if (sessionState.selectedCommunityId == community.id) {
                                    "選択中のコミュニティ"
                                } else {
                                    "このコミュニティへ切替"
                                },
                            )
                        }
                    }
                    null -> {
                        Button(
                            onClick = { model.applyTo(community) },
                            enabled = community.joinEnabled && !state.isLoading,
                        ) {
                            Text("このコミュニティへ参加申請")
                        }
                    }
                    else -> Unit
                }
            }
            HorizontalDivider()
        }

            if (sessionState.authenticationToken == null) {
                Text("マイページで会員登録またはログイン後に参加申請できます。")
            } else {
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
                            onClick = { model.selectCommunity(community.id) },
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

            if (state.adminAccess?.canReviewMembers == true) {
                memberPostReplyContent()

                Text("参加申請の承認")
                if (state.pendingApplications.isEmpty()) {
                    Text("承認待ちの申請はありません。")
                }
                state.pendingApplications.forEach { application ->
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Text(application.applicantName ?: "申請者")
                        application.applicantFurigana?.let { Text(it) }
                        Text(application.applicantEmail ?: "利用者ID: ${application.userId}")
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(
                                onClick = {
                                    model.review(
                                        application,
                                        CommunityMembershipStatus.Approved,
                                    )
                                },
                                enabled = state.reviewingUserId == null,
                            ) {
                                Text("承認")
                            }
                            OutlinedButton(
                                onClick = {
                                    model.review(
                                        application,
                                        CommunityMembershipStatus.Rejected,
                                    )
                                },
                                enabled = state.reviewingUserId == null,
                            ) {
                                Text("却下")
                            }
                        }
                        if (state.reviewingUserId == application.userId) {
                            CircularProgressIndicator()
                        }
                    }
                    HorizontalDivider()
                }

                Text("管理者コンソール")
                Text("イベント予約の管理")
                Text("イベントを保存")
                OutlinedTextField(
                    value = bookingEventTitle,
                    onValueChange = { bookingEventTitle = it },
                    label = { Text("イベント名") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = bookingEventDescription,
                    onValueChange = { bookingEventDescription = it },
                    label = { Text("説明") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                )
                OutlinedTextField(
                    value = bookingEventDate,
                    onValueChange = { bookingEventDate = it },
                    label = { Text("開催日時（例: 2026-08-12T13:00:00Z）") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = bookingEventFee,
                    onValueChange = { bookingEventFee = it },
                    label = { Text("料金（円）") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = bookingEventZoomUrl,
                    onValueChange = { bookingEventZoomUrl = it },
                    label = { Text("Zoom URL（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = {
                        model.saveBookingEvent(
                            bookingEventId,
                            bookingEventTitle,
                            bookingEventDescription,
                            bookingEventDate.ifBlank { null },
                            bookingEventFee.toIntOrNull() ?: 0,
                            paymentRequired = (bookingEventFee.toIntOrNull() ?: 0) > 0,
                            zoomUrl = bookingEventZoomUrl,
                            isPublished = false,
                        )
                    }) { Text("下書き保存") }
                    Button(onClick = {
                        model.saveBookingEvent(
                            bookingEventId,
                            bookingEventTitle,
                            bookingEventDescription,
                            bookingEventDate.ifBlank { null },
                            bookingEventFee.toIntOrNull() ?: 0,
                            paymentRequired = (bookingEventFee.toIntOrNull() ?: 0) > 0,
                            zoomUrl = bookingEventZoomUrl,
                            isPublished = true,
                        )
                    }) { Text("公開して保存") }
                }
                state.managedBookingEvents.forEach { event ->
                    TextButton(onClick = {
                        model.selectManagedBookingEvent(event.id)
                        bookingEventId = event.id
                        bookingEventTitle = event.title
                        bookingEventDescription = event.description
                        bookingEventDate = event.eventDate.orEmpty()
                        bookingEventFee = event.feeAmount.toString()
                        bookingEventZoomUrl = event.zoomUrl.orEmpty()
                    }) {
                        Text("${event.title}（${if (event.isPublished) "公開" else "下書き"}）")
                    }
                }
                state.selectedManagedBookingEventId?.let {
                    Text("予約状況")
                    TextButton(onClick = model::refreshBookingStatus) {
                        Text("予約情報を更新")
                    }
                    if (state.managedBookingSlots.isEmpty()) {
                        Text("予約枠はまだありません。")
                    }
                    state.managedBookingSlots.forEach { slot ->
                        val reservations = state.managedBookingReservations.filter { reservation ->
                            reservation.slotId == slot.id
                        }
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Text("${slot.startAt ?: "開始時刻未定"} - ${slot.endAt ?: "終了時刻未定"}")
                            Text("定員 ${slot.capacity}名 / 予約 ${slot.reservedCount}名 / 残席 ${slot.remainingCount}名")
                            Text(if (slot.isOpen) "受付中" else "受付停止中")
                            reservations.forEach { reservation ->
                                val memberName = state.communityMembers
                                    .firstOrNull { it.userId == reservation.userId }
                                    ?.applicantName
                                    ?.takeIf(String::isNotBlank)
                                    ?: reservation.userId
                                Text("$memberName / ${reservation.status} / ${reservation.purchaseStatus}")
                            }
                        }
                    }
                }
                Text("予約枠を保存")
                OutlinedTextField(
                    value = bookingEventId,
                    onValueChange = { bookingEventId = it },
                    label = { Text("イベントID（上のイベントを選択）") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = bookingSlotStartAt,
                    onValueChange = { bookingSlotStartAt = it },
                    label = { Text("開始日時（例: 2026-08-12T13:00:00Z）") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = bookingSlotEndAt,
                    onValueChange = { bookingSlotEndAt = it },
                    label = { Text("終了日時（例: 2026-08-12T14:00:00Z）") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = bookingSlotCapacity,
                    onValueChange = { bookingSlotCapacity = it },
                    label = { Text("定員") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                TextButton(onClick = { bookingSlotOpen = !bookingSlotOpen }) {
                    Text(if (bookingSlotOpen) "受付中（タップで停止）" else "受付停止中（タップで再開）")
                }
                Button(onClick = {
                    model.saveBookingSlot(
                        bookingEventId,
                        bookingSlotId,
                        bookingSlotStartAt.ifBlank { null },
                        bookingSlotEndAt.ifBlank { null },
                        bookingSlotCapacity.toIntOrNull() ?: 0,
                        bookingSlotOpen,
                    )
                }) { Text("予約枠を保存") }
                if (state.adminAccess?.role == "owner") {
                    Text("複数管理者の設定")
                    OutlinedTextField(
                        value = state.adminQuery,
                        onValueChange = model::updateAdminQuery,
                        label = { Text("氏名・メールアドレス・UIDで検索") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    if (model.administratorCandidates().isEmpty()) {
                        Text("追加できる承認済み会員が見つかりません。")
                    }
                    model.administratorCandidates().forEach { member ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Column {
                                Text(member.applicantName ?: "氏名未登録")
                                Text(member.applicantEmail ?: member.userId)
                            }
                            Button(
                                onClick = { model.saveAdministrator(member.userId) },
                                enabled = !state.isLoading,
                            ) { Text("管理者に追加") }
                        }
                    }
                    state.administrators.forEach { admin ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text("${admin.userId} (${admin.role})")
                            if (admin.isActive) {
                                TextButton(onClick = { model.deactivateAdministrator(admin) }) {
                                    Text("無効化")
                                }
                            } else {
                                Text("無効")
                            }
                        }
                    }
                }

                Text("会員管理")
                state.communityMembers.forEach { member ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(member.applicantName ?: member.userId)
                        if (member.status == CommunityMembershipStatus.Approved) {
                            TextButton(onClick = { model.suspendMember(member) }) {
                                Text("利用停止")
                            }
                        } else {
                            Text(when (member.status) {
                                CommunityMembershipStatus.Pending -> "承認待ち"
                                CommunityMembershipStatus.Rejected -> "停止中"
                                CommunityMembershipStatus.Approved -> "参加中"
                            })
                        }
                    }
                }
                HorizontalDivider()

                Text("動画質問対応")
                if (state.adminVideoQuestions.isEmpty()) {
                    Text("対応する質問はありません。")
                }
                val unansweredQuestions = state.adminVideoQuestions.filter { it.answerText.isBlank() }
                if (unansweredQuestions.isNotEmpty()) {
                    Text("未回答")
                    unansweredQuestions.forEach { question ->
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text("動画: ${question.videoTitle}")
                            Text("質問: ${question.questionText}")
                            if (question.memoText.isNotBlank()) {
                                Text("メモ: ${question.memoText}")
                            }
                            OutlinedTextField(
                                value = adminVideoQuestionAnswers[question.id] ?: "",
                                onValueChange = {
                                    adminVideoQuestionAnswers[question.id] = it
                                },
                                label = { Text("回答を入力") },
                                modifier = Modifier.fillMaxWidth(),
                            )
                            Button(
                                onClick = {
                                    model.answerVideoQuestion(
                                        question.id,
                                        adminVideoQuestionAnswers[question.id] ?: "",
                                    )
                                    adminVideoQuestionAnswers.remove(question.id)
                                },
                            ) { Text("回答を保存") }
                        }
                        HorizontalDivider()
                    }
                }
                val answeredQuestions = state.adminVideoQuestions.filter { it.answerText.isNotBlank() }
                if (answeredQuestions.isNotEmpty()) {
                    Text("回答済み")
                    answeredQuestions.forEach { question ->
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Text("動画: ${question.videoTitle}")
                            Text("質問: ${question.questionText}")
                            Text("回答: ${question.answerText}")
                        }
                        HorizontalDivider()
                    }
                }

                Text("監査ログ")
                if (state.auditLogs.isEmpty()) {
                    Text("監査ログはまだありません。")
                }
                state.auditLogs.forEach { log ->
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(auditActionText(log.action))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            log.actorUserId?.takeIf { it.isNotBlank() }?.let {
                                Text("操作: $it")
                            }
                            log.targetUserId?.takeIf { it.isNotBlank() }?.let {
                                Text("対象: $it")
                            }
                        }
                        log.createdAt?.let { createdAt ->
                            Text(auditCreatedAtText(createdAt))
                        }
                    }
                    HorizontalDivider()
                }

                Text("Vimeo動画管理")
                var managedVideoId by remember { mutableStateOf("") }
                var managedVideoTitle by remember { mutableStateOf("") }
                var managedVideoDescription by remember { mutableStateOf("") }
                var managedVimeoId by remember { mutableStateOf("") }
                var managedVimeoUrl by remember { mutableStateOf("") }
                var managedThumbnailUrl by remember { mutableStateOf("") }
                var vimeoAccessToken by remember { mutableStateOf("") }
                var selectedVimeoVideoIds by remember { mutableStateOf(setOf<String>()) }
                var vimeoUserId by remember(state.vimeoConfiguration.userId) {
                    mutableStateOf(state.vimeoConfiguration.userId)
                }
                var vimeoQuery by remember(state.vimeoConfiguration.query) {
                    mutableStateOf(state.vimeoConfiguration.query)
                }
                Text("Vimeo接続設定")
                Text(if (state.vimeoConfiguration.hasAccessToken) "接続設定済み" else "未設定")
                OutlinedTextField(
                    value = vimeoAccessToken,
                    onValueChange = { vimeoAccessToken = it },
                    label = { Text("Vimeoアクセストークン") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = vimeoUserId,
                    onValueChange = { vimeoUserId = it },
                    label = { Text("VimeoユーザーID") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = vimeoQuery,
                    onValueChange = { vimeoQuery = it },
                    label = { Text("動画検索キーワード（任意）") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(onClick = {
                    model.saveVimeoConfiguration(vimeoAccessToken, vimeoUserId, vimeoQuery)
                    vimeoAccessToken = ""
                }) { Text("Vimeo接続設定を保存") }
                HorizontalDivider()
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text("Vimeoフォルダ")
                    TextButton(onClick = model::refreshVimeoFolders) { Text("フォルダを取得") }
                }
                if (state.vimeoFolders.isNotEmpty()) {
                    TextButton(onClick = model::refreshVimeoLibrary) { Text("すべての動画を取得") }
                    state.vimeoFolders.forEach { folder ->
                        TextButton(onClick = { model.refreshVimeoFolderVideos(folder) }) {
                            Text(folder.name)
                        }
                    }
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text("Vimeo動画一覧")
                    TextButton(onClick = model::refreshVimeoLibrary) { Text("Vimeoから取得") }
                }
                if (state.vimeoLibraryVideos.isEmpty()) {
                    Text("Vimeoから取得すると、動画を選択して登録できます。")
                }
                if (state.vimeoLibraryVideos.isNotEmpty()) {
                    Text("複数選択して一括公開")
                    state.vimeoLibraryVideos.forEach { video ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text(video.title, modifier = Modifier.weight(1f))
                            TextButton(onClick = {
                                selectedVimeoVideoIds = if (video.vimeoVideoId in selectedVimeoVideoIds) {
                                    selectedVimeoVideoIds - video.vimeoVideoId
                                } else {
                                    selectedVimeoVideoIds + video.vimeoVideoId
                                }
                            }) {
                                Text(if (video.vimeoVideoId in selectedVimeoVideoIds) "選択済み" else "選択")
                            }
                        }
                    }
                    Button(
                        onClick = {
                            model.saveCommunityVideos(
                                state.vimeoLibraryVideos.filter {
                                    it.vimeoVideoId in selectedVimeoVideoIds
                                },
                                isPublished = true,
                            )
                            selectedVimeoVideoIds = emptySet()
                            model.clearVimeoLibrary()
                        },
                        enabled = selectedVimeoVideoIds.isNotEmpty(),
                    ) {
                        Text("選択した動画をまとめて公開")
                    }
                    Text("個別にタイトルや説明を編集する場合は、下の動画を選択してください。")
                }
                state.vimeoLibraryVideos.forEach { video ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        TextButton(onClick = {
                            managedVideoId = video.vimeoVideoId
                            managedVideoTitle = video.title
                            managedVideoDescription = video.description
                            managedVimeoId = video.vimeoVideoId
                            managedVimeoUrl = video.videoUrl.orEmpty()
                            managedThumbnailUrl = video.thumbnailUrl.orEmpty()
                            model.clearVimeoLibrary()
                        }) {
                            Column {
                                Text(video.title)
                                Text(video.vimeoVideoId)
                            }
                        }
                        Text(
                            if (state.managedVideos.any { it.vimeoVideoId == video.vimeoVideoId }) {
                                "登録済み"
                            } else {
                                "選択"
                            },
                        )
                    }
                }
                HorizontalDivider()
                Text("登録済み動画")
                OutlinedTextField(
                    value = managedVideoId,
                    onValueChange = { managedVideoId = it },
                    label = { Text("動画ID（編集時のみ）") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = managedVideoTitle,
                    onValueChange = { managedVideoTitle = it },
                    label = { Text("動画タイトル") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = managedVimeoId,
                    onValueChange = { managedVimeoId = it },
                    label = { Text("Vimeo動画ID") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = managedVimeoUrl,
                    onValueChange = { managedVimeoUrl = it },
                    label = { Text("Vimeo URL（任意）") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = managedVideoDescription,
                    onValueChange = { managedVideoDescription = it },
                    label = { Text("説明") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                )
                OutlinedTextField(
                    value = managedThumbnailUrl,
                    onValueChange = { managedThumbnailUrl = it },
                    label = { Text("サムネイルURL（任意）") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = {
                        model.saveCommunityVideo(
                            managedVideoId,
                            managedVideoTitle,
                            managedVideoDescription,
                            managedVimeoId,
                            managedVimeoUrl,
                            managedThumbnailUrl,
                            false,
                        )
                    }) { Text("下書き保存") }
                    Button(onClick = {
                        model.saveCommunityVideo(
                            managedVideoId,
                            managedVideoTitle,
                            managedVideoDescription,
                            managedVimeoId,
                            managedVimeoUrl,
                            managedThumbnailUrl,
                            true,
                        )
                    }) { Text("公開して保存") }
                }
                state.managedVideos.forEach { video ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        TextButton(onClick = {
                            managedVideoId = video.id
                            managedVideoTitle = video.title
                            managedVideoDescription = video.description
                            managedVimeoId = video.vimeoVideoId
                            managedVimeoUrl = video.videoUrl.orEmpty()
                            managedThumbnailUrl = video.thumbnailUrl.orEmpty()
                        }) { Text(video.title) }
                        Text("${if (video.isPublished) "公開" else "下書き"}")
                        TextButton(onClick = {
                            model.saveCommunityVideo(
                                video.id,
                                video.title,
                                video.description,
                                video.vimeoVideoId,
                                video.videoUrl.orEmpty(),
                                video.thumbnailUrl.orEmpty(),
                                !video.isPublished,
                            )
                        }) { Text(if (video.isPublished) "非公開" else "公開") }
                    }
                }
            }

            if (state.bookingEvents.isNotEmpty()) {
                Text("イベント予約")
                TextButton(onClick = model::refreshBookingStatus) {
                    Text("予約情報を更新")
                }
                if (state.myBookingReservations.isNotEmpty()) {
                    Text("自分の予約")
                    state.myBookingReservations.forEach { reservation ->
                        val event = state.bookingEvents.firstOrNull { it.id == reservation.eventId }
                        val slot = state.myBookingSlots["${reservation.eventId}:${reservation.slotId}"]
                        Text(
                            "${event?.title ?: "イベント"} / " +
                                (slot?.startAt ?: "予約枠: ${reservation.slotId}"),
                        )
                        TextButton(onClick = { model.selectBookingEvent(reservation.eventId) }) {
                            Text("予約内容を確認")
                        }
                        if (event != null && slot != null) {
                            OutlinedButton(
                                onClick = { bookingCancellationTarget = event to slot },
                                enabled = state.bookingProcessingSlotId == null,
                            ) {
                                Text("予約をキャンセル")
                            }
                        }
                    }
                }
                state.bookingEvents.forEach { event ->
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Text(event.title)
                        event.eventDate?.let { Text("開催日: $it") }
                        if (event.description.isNotBlank()) Text(event.description)
                        if (state.myBookingReservations.any { it.eventId == event.id }) {
                            Text("このイベントは予約済みです。")
                        }
                        Text(
                            if (event.paymentRequired || event.feeAmount > 0) {
                                "料金: ${event.feeAmount}円（決済準備中のため予約できません）"
                            } else {
                                "無料イベント"
                            },
                        )
                        event.zoomUrl?.takeIf(String::isNotBlank)?.let { zoomUrl ->
                            if (state.myBookingReservations.any { it.eventId == event.id }) {
                                TextButton(onClick = { uriHandler.openUri(zoomUrl) }) {
                                    Text("Zoom参加リンクを開く")
                                }
                            }
                        }
                        OutlinedButton(
                            onClick = { model.selectBookingEvent(event.id) },
                            enabled = state.selectedBookingEventId != event.id,
                        ) {
                            Text(if (state.selectedBookingEventId == event.id) "予約枠を表示中" else "予約枠を見る")
                        }
                        if (state.selectedBookingEventId == event.id) {
                            if (state.bookingSlots.isEmpty()) {
                                Text("予約枠はまだありません。")
                            }
                            state.bookingSlots.forEach { slot ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text("${slot.startAt ?: "開始時刻未定"} - ${slot.endAt ?: "終了時刻未定"}")
                                        Text("残席: ${slot.remainingCount} / ${slot.capacity}")
                                    }
                                    val isBooked = slot.id in state.bookedSlotIds
                                    val canReserve = !event.paymentRequired && event.feeAmount <= 0 &&
                                        slot.isOpen && !slot.isFull &&
                                        state.bookingProcessingSlotId == null
                                    val bookingLabel = when {
                                        event.paymentRequired || event.feeAmount > 0 -> "決済準備中"
                                        !slot.isOpen -> "受付停止中"
                                        slot.isFull -> "満席"
                                        else -> "予約"
                                    }
                                    if (isBooked) {
                                        OutlinedButton(
                                            onClick = { bookingCancellationTarget = event to slot },
                                            enabled = state.bookingProcessingSlotId == null,
                                        ) { Text("予約をキャンセル") }
                                    } else {
                                        Button(
                                            onClick = { model.reserveBooking(event, slot) },
                                            enabled = canReserve,
                                        ) { Text(bookingLabel) }
                                    }
                                }
                            }
                        }
                    }
                    HorizontalDivider()
                }
            }

            if (state.distributedVideos.isNotEmpty()) {
                Text("Vimeo配信動画")
                state.distributedVideos.forEach { video ->
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { selectedVideoId = video.id }
                            .padding(vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        video.thumbnailUrl?.takeIf(String::isNotBlank)?.let { thumbnail ->
                            AsyncImage(
                                model = thumbnail,
                                contentDescription = "${video.title}のサムネイル",
                                modifier = Modifier.fillMaxWidth().height(140.dp),
                            )
                        }
                        Text(video.title)
                        Text("視聴・メモ")
                    }
                    HorizontalDivider()
                }
            }
            if (false && state.distributedVideos.isNotEmpty()) {
                Text("Vimeo配信動画")
                    state.distributedVideos.forEach { video ->
                    var memo by remember(video.id) {
                        mutableStateOf("")
                    }
                    var editingMemoId by remember("${video.id}:editingMemo") { mutableStateOf<String?>(null) }
                    var editingMemoText by remember("${video.id}:editingMemoText") { mutableStateOf("") }
                    var question by remember("${video.id}:question") {
                        mutableStateOf("")
                    }
                    var playbackSeconds by remember("${video.id}:position") {
                        mutableStateOf(0.0)
                    }
                    var playbackCommandId by remember("${video.id}:playbackCommand") {
                        mutableStateOf(0)
                    }
                    var playbackCommand by remember("${video.id}:playbackAction") {
                        mutableStateOf<VimeoPlaybackCommand?>(null)
                    }
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        VimeoPlayerView(
                            videoId = video.vimeoVideoId,
                            playbackCommand = playbackCommand,
                            initialPlaybackSeconds = playbackSeconds,
                            isLandscape = false,
                            modifier = Modifier.fillMaxWidth().height(210.dp),
                            onTimeChanged = { playbackSeconds = it },
                        )
                        androidx.compose.foundation.layout.Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Button(onClick = {
                                playbackCommandId += 1
                                playbackCommand = VimeoPlaybackCommand(
                                    action = VimeoPlaybackAction.Play,
                                    requestId = playbackCommandId,
                                )
                            }) { Text("再生") }
                            Button(onClick = {
                                playbackCommandId += 1
                                playbackCommand = VimeoPlaybackCommand(
                                    action = VimeoPlaybackAction.Pause,
                                    requestId = playbackCommandId,
                                )
                            }) { Text("一時停止") }
                            Button(onClick = {
                                playbackCommandId += 1
                                playbackCommand = VimeoPlaybackCommand(
                                    action = VimeoPlaybackAction.Stop,
                                    requestId = playbackCommandId,
                                )
                            }) { Text("停止") }
                        }
                        Text("再生位置: ${playbackSeconds.toInt() / 60}:${(playbackSeconds.toInt() % 60).toString().padStart(2, '0')}")
                        video.thumbnailUrl?.takeIf(String::isNotBlank)?.let { thumbnail ->
                            AsyncImage(
                                model = thumbnail,
                                contentDescription = "${video.title}のサムネイル",
                                modifier = Modifier.fillMaxWidth().height(120.dp),
                            )
                        }
                        Text(video.title)
                        if (video.description.isNotBlank()) Text(video.description)
                        val url = "https://player.vimeo.com/video/${video.vimeoVideoId}"
                        TextButton(onClick = { uriHandler.openUri(url) }) {
                            Text("Vimeoで再生")
                        }
                        Text("メモを追加")
                        OutlinedTextField(
                            value = memo,
                            onValueChange = { memo = it },
                            label = { Text("動画メモ") },
                            modifier = Modifier.fillMaxWidth(),
                            minLines = 3,
                        )
                        Button(onClick = {
                            model.addVideoMemo(video, memo, playbackSeconds)
                            memo = ""
                        }) {
                            Text("メモを追加")
                        }
                        model.videoMemosFor(video).forEach { entry ->
                            Column(
                                modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                                verticalArrangement = Arrangement.spacedBy(4.dp),
                            ) {
                                Text(
                                    if (entry.createdAtMillis == 0L) "以前のメモ" else
                                        "${Instant.ofEpochMilli(entry.createdAtMillis).atZone(ZoneId.systemDefault()).format(DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm"))} / 再生位置 ${entry.playbackSeconds.toInt() / 60}:${(entry.playbackSeconds.toInt() % 60).toString().padStart(2, '0')}",
                                )
                                if (editingMemoId == entry.id) {
                                    OutlinedTextField(
                                        value = editingMemoText,
                                        onValueChange = { editingMemoText = it },
                                        modifier = Modifier.fillMaxWidth(),
                                        minLines = 3,
                                    )
                                    Row {
                                        Button(onClick = {
                                            model.updateVideoMemo(video, entry, editingMemoText)
                                            editingMemoId = null
                                        }) { Text("更新") }
                                        TextButton(onClick = { editingMemoId = null }) { Text("取消") }
                                    }
                                } else {
                                    Text(entry.text)
                                    Row {
                                        TextButton(onClick = {
                                            editingMemoId = entry.id
                                            editingMemoText = entry.text
                                        }) { Text("編集") }
                                        TextButton(onClick = { model.deleteVideoMemo(video, entry) }) { Text("削除") }
                                    }
                                }
                            }
                        }
                        OutlinedTextField(
                            value = question,
                            onValueChange = { question = it },
                            label = { Text("動画について質問") },
                            modifier = Modifier.fillMaxWidth(),
                            minLines = 3,
                        )
                        Button(
                            onClick = {
                                model.submitVideoQuestion(video, memo, question, playbackSeconds)
                                question = ""
                            },
                            enabled = question.trim().isNotEmpty(),
                        ) {
                            Text("質問を送信")
                        }
                        model.questionsFor(video).forEach { item ->
                            Text("質問: ${item.questionText}")
                            if (item.answerText.isNotBlank()) {
                                Text("回答: ${item.answerText}")
                            } else {
                                Text("回答待ち")
                            }
                        }
                    }
                    HorizontalDivider()
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
        }
    }
}

@Composable
private fun VimeoVideoDetailScreen(
    model: CommunityFeatureModel,
    video: jp.komehyappyo.member.next.core.model.DistributedVideo,
    onBack: () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    var memo by rememberSaveable(video.id) { mutableStateOf("") }
    var editingMemoId by rememberSaveable("${video.id}:editingMemo") { mutableStateOf<String?>(null) }
    var editingMemoText by rememberSaveable("${video.id}:editingMemoText") { mutableStateOf("") }
    var playbackSeconds by rememberSaveable("${video.id}:position") { mutableStateOf(0.0) }
    var playbackCommandId by rememberSaveable("${video.id}:playbackCommand") { mutableStateOf(0) }
    var playbackCommand by remember { mutableStateOf<VimeoPlaybackCommand?>(null) }

    fun sendCommand(action: VimeoPlaybackAction, positionSeconds: Double? = null) {
        playbackCommandId += 1
        playbackCommand = VimeoPlaybackCommand(action, playbackCommandId, positionSeconds)
    }

    if (isLandscape) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
            VimeoPlayerView(
                videoId = video.vimeoVideoId,
                playbackCommand = playbackCommand,
                initialPlaybackSeconds = playbackSeconds,
                isLandscape = isLandscape,
                onTimeChanged = { playbackSeconds = it },
                modifier = Modifier.fillMaxHeight().aspectRatio(16f / 9f),
            )
        }
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        TextButton(onClick = onBack) { Text("動画一覧へ戻る") }
        if (state.hasPendingVideoMemoSync) {
            OfflineBanner()
        }
        VimeoPlayerView(
            videoId = video.vimeoVideoId,
            playbackCommand = playbackCommand,
            initialPlaybackSeconds = playbackSeconds,
            isLandscape = isLandscape,
            onTimeChanged = { playbackSeconds = it },
            modifier = Modifier.fillMaxWidth().height(210.dp),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { sendCommand(VimeoPlaybackAction.Play) }) { Text("再生") }
            Button(onClick = { sendCommand(VimeoPlaybackAction.Pause) }) { Text("一時停止") }
            Button(onClick = { sendCommand(VimeoPlaybackAction.Stop) }) { Text("停止") }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = {
                sendCommand(VimeoPlaybackAction.Seek, (playbackSeconds - 1).coerceAtLeast(0.0))
            }) { Text("-1秒") }
            OutlinedButton(onClick = {
                sendCommand(VimeoPlaybackAction.Seek, playbackSeconds + 1)
            }) { Text("+1秒") }
        }
        Text("再生位置: ${playbackSeconds.toInt() / 60}:${(playbackSeconds.toInt() % 60).toString().padStart(2, '0')}")
        Text(video.title)
        Text("メモを追加")
        OutlinedTextField(
            value = memo,
            onValueChange = { memo = it },
            label = { Text("動画メモ") },
            modifier = Modifier.fillMaxWidth(),
            minLines = 3,
        )
        Button(
            onClick = {
                model.addVideoMemo(video, memo, playbackSeconds)
                memo = ""
            },
            enabled = memo.trim().isNotEmpty(),
        ) { Text("メモを追加") }
        model.videoMemosFor(video).forEach { entry ->
            Column(
                modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    if (entry.createdAtMillis == 0L) "以前のメモ" else
                        "${Instant.ofEpochMilli(entry.createdAtMillis).atZone(ZoneId.systemDefault()).format(DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm"))} / 再生位置 ${entry.playbackSeconds.toInt() / 60}:${(entry.playbackSeconds.toInt() % 60).toString().padStart(2, '0')}",
                )
                if (editingMemoId == entry.id) {
                    OutlinedTextField(
                        value = editingMemoText,
                        onValueChange = { editingMemoText = it },
                        modifier = Modifier.fillMaxWidth(),
                        minLines = 3,
                    )
                    Row {
                        Button(onClick = {
                            model.updateVideoMemo(video, entry, editingMemoText)
                            editingMemoId = null
                        }) { Text("更新") }
                        TextButton(onClick = { editingMemoId = null }) { Text("取消") }
                    }
                } else {
                    Text(entry.text)
                    Row {
                        TextButton(onClick = {
                            sendCommand(VimeoPlaybackAction.SeekAndPlay, entry.playbackSeconds)
                        }, enabled = entry.createdAtMillis != 0L) { Text("この位置から再生") }
                        TextButton(onClick = {
                            editingMemoId = entry.id
                            editingMemoText = entry.text
                        }) { Text("編集") }
                        TextButton(onClick = { model.deleteVideoMemo(video, entry) }) { Text("削除") }
                    }
                }
            }
        }
    }
}

@Composable
private fun RadioSection(
    programs: List<RadioProgram>,
    records: List<RadioPlaybackRecord>,
    currentUserId: String,
    playingProgramId: String?,
    isLoading: Boolean,
    formatter: DateTimeFormatter,
    onToggle: (RadioProgram) -> Unit,
    isPlayable: (RadioProgram) -> Boolean,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        programs.forEach { program ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(program.title, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(program.description)
                Text("配信開始: ${formatter.format(program.broadcastStartAt.atZone(ZoneId.systemDefault()))}")
                val record = records.firstOrNull {
                    it.userId == currentUserId && it.programId == program.id
                }
                record?.let {
                    Text(
                        "再生回数: ${it.playCount} 回 / 最終再生: " +
                            (it.lastPlayedAt?.let { time ->
                                formatter.format(time.atZone(ZoneId.systemDefault()))
                            } ?: "未再生")
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = { onToggle(program) },
                        enabled = !isLoading,
                    ) {
                        Text(
                            when {
                                !isPlayable(program) -> "配信前"
                                playingProgramId == program.id -> "停止"
                                else -> "再生"
                            },
                        )
                    }
                    if (playingProgramId == program.id) {
                        Text("再生中")
                    }
                }
            }
            HorizontalDivider()
        }
    }
}

private fun radioDateTimeFormatter(): DateTimeFormatter =
    DateTimeFormatter.ofPattern("M月d日 HH:mm", Locale.JAPAN)

private fun auditActionText(action: String): String = when (action) {
    "membership.approved" -> "参加申請承認"
    "membership.rejected" -> "参加申請却下"
    "membership.suspended" -> "会員を利用停止"
    "administrator.added" -> "管理者を追加"
    "administrator.deactivated" -> "管理者を無効化"
    else -> action
}

private fun auditCreatedAtText(createdAt: String): String = runCatching {
    Instant.parse(createdAt).atZone(ZoneId.systemDefault()).format(
        DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm"),
    )
}.getOrNull() ?: createdAt
