package jp.komehyappyo.member.next.feature.tools

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.provider.CalendarContract
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.IosShare
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.rememberScrollState
import jp.komehyappyo.member.next.core.designsystem.EmptyState
import jp.komehyappyo.member.next.core.designsystem.ErrorState
import jp.komehyappyo.member.next.core.designsystem.FeatureCard
import jp.komehyappyo.member.next.core.designsystem.LoadingState
import jp.komehyappyo.member.next.core.designsystem.PrimaryActionButton
import jp.komehyappyo.member.next.core.model.RecurrenceFrequency
import jp.komehyappyo.member.next.core.model.RecurrenceRule
import jp.komehyappyo.member.next.core.model.ReminderSetting
import jp.komehyappyo.member.next.core.model.Schedule
import jp.komehyappyo.member.next.core.model.ScheduleCategory
import jp.komehyappyo.member.next.core.model.ScheduleTimeOfDay
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

private sealed interface ScheduleScreen {
    data object List : ScheduleScreen
    data class Detail(val schedule: Schedule) : ScheduleScreen
    data class Editor(val schedule: Schedule?) : ScheduleScreen
}

@Composable
fun ScheduleRoot(model: ScheduleFeatureModel) {
    var screen: ScheduleScreen by remember { mutableStateOf(ScheduleScreen.List) }
    when (val current = screen) {
        ScheduleScreen.List -> ScheduleListView(
            model = model,
            onOpen = { screen = ScheduleScreen.Detail(it) },
            onAdd = { screen = ScheduleScreen.Editor(null) },
        )
        is ScheduleScreen.Detail -> ScheduleDetailView(
            model = model,
            schedule = current.schedule,
            onBack = { screen = ScheduleScreen.List },
            onEdit = { screen = ScheduleScreen.Editor(current.schedule) },
        )
        is ScheduleScreen.Editor -> ScheduleEditorView(
            model = model,
            editing = current.schedule,
            onClose = { screen = ScheduleScreen.List },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScheduleListView(
    model: ScheduleFeatureModel,
    onOpen: (Schedule) -> Unit,
    onAdd: () -> Unit,
) {
    val state by model.state.collectAsState()
    val context = LocalContext.current
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("予定") },
                actions = {
                    IconButton(
                        enabled = state.schedules.isNotEmpty(),
                        onClick = { shareCsv(context, state.schedules) },
                    ) {
                        Icon(Icons.Outlined.IosShare, contentDescription = "CSV共有")
                    }
                },
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onAdd,
                icon = { Icon(Icons.Outlined.Add, contentDescription = null) },
                text = { Text("予定を追加") },
            )
        },
    ) { padding ->
        Column(Modifier.padding(padding)) {
            when {
                state.isLoading -> LoadingState()
                state.errorMessage != null -> ErrorState(
                    message = state.errorMessage.orEmpty(),
                    onRetry = model::reload,
                )
                state.schedules.isEmpty() -> EmptyState(
                    title = "予定はまだありません",
                    message = "「予定を追加」から最初の予定を登録できます。",
                )
                else -> LazyColumn {
                    items(state.schedules, key = { it.id }) { schedule ->
                        ScheduleRow(schedule, onClick = { onOpen(schedule) })
                    }
                }
            }
        }
    }
}

@Composable
fun TodayScheduleView(model: ScheduleFeatureModel, onOpenAll: (() -> Unit)? = null) {
    val state by model.state.collectAsState()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("今日の予定", style = MaterialTheme.typography.headlineSmall)
        when {
            state.isLoading -> LoadingState()
            state.errorMessage != null -> ErrorState(
                message = state.errorMessage.orEmpty(),
                onRetry = model::reload,
            )
            state.todaySchedules.isEmpty() -> EmptyState(
                title = "今日の予定はありません",
                message = "便利タブから予定を登録できます。",
            )
            else -> state.todaySchedules.forEach { schedule ->
                FeatureCard(
                    title = schedule.title,
                    description = scheduleDateText(schedule),
                )
            }
        }
        if (onOpenAll != null) {
            TextButton(onClick = onOpenAll) { Text("すべての予定を見る") }
        }
    }
}

@Composable
private fun ScheduleRow(schedule: Schedule, onClick: () -> Unit) {
    ListItem(
        headlineContent = { Text(schedule.title) },
        supportingContent = {
            Column {
                Text(scheduleDateText(schedule))
                if (schedule.location.isNotBlank()) Text(schedule.location)
            }
        },
        modifier = Modifier.clickable(onClick = onClick),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScheduleDetailView(
    model: ScheduleFeatureModel,
    schedule: Schedule,
    onBack: () -> Unit,
    onEdit: () -> Unit,
) {
    val context = LocalContext.current
    var confirmDelete by remember { mutableStateOf(false) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("予定の詳細") },
                navigationIcon = {
                    TextButton(onClick = onBack) { Text("戻る") }
                },
                actions = {
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
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(schedule.title, style = MaterialTheme.typography.headlineSmall)
            DetailRow("開始", formatInstant(schedule.startDateTime))
            DetailRow("終了", formatInstant(schedule.endDateTime))
            DetailRow("時間帯", timeOfDayLabel(schedule.timeOfDay))
            if (schedule.location.isNotBlank()) DetailRow("場所", schedule.location)
            if (schedule.memo.isNotBlank()) DetailRow("メモ", schedule.memo)
            schedule.category?.let { DetailRow("カテゴリ", it.name) }
            schedule.recurrenceRule?.let {
                DetailRow("繰り返し", "${recurrenceLabel(it.frequency)}・${it.interval}回ごと")
            }
            schedule.reminderSetting?.takeIf { it.isEnabled }?.let {
                DetailRow("リマインダー", "${it.notifyBeforeMinutes}分前")
            }
            Button(onClick = { addToDeviceCalendar(context, schedule) }) {
                Text("端末カレンダーへ追加")
            }
        }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("この予定を削除しますか？") },
            confirmButton = {
                TextButton(
                    onClick = {
                        model.delete(schedule.id) { result ->
                            if (result.isSuccess) onBack()
                        }
                        confirmDelete = false
                    },
                ) { Text("削除") }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("キャンセル") }
            },
        )
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
    Column {
        Text(label, style = MaterialTheme.typography.labelMedium)
        Text(value)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScheduleEditorView(
    model: ScheduleFeatureModel,
    editing: Schedule?,
    onClose: () -> Unit,
) {
    var title by rememberSaveable { mutableStateOf(editing?.title.orEmpty()) }
    var location by rememberSaveable { mutableStateOf(editing?.location.orEmpty()) }
    var memo by rememberSaveable { mutableStateOf(editing?.memo.orEmpty()) }
    var categoryName by rememberSaveable { mutableStateOf(editing?.category?.name.orEmpty()) }
    var startMillis by rememberSaveable {
        mutableLongStateOf(editing?.startDateTime?.toEpochMilli() ?: Instant.now().toEpochMilli())
    }
    var endMillis by rememberSaveable {
        mutableLongStateOf(
            editing?.endDateTime?.toEpochMilli() ?: Instant.now().plusSeconds(3600).toEpochMilli(),
        )
    }
    var timeOfDay by rememberSaveable {
        mutableStateOf(editing?.timeOfDay ?: ScheduleTimeOfDay.AllDay)
    }
    var recurrenceEnabled by rememberSaveable {
        mutableStateOf(editing?.recurrenceRule != null)
    }
    var recurrenceFrequency by rememberSaveable {
        mutableStateOf(editing?.recurrenceRule?.frequency ?: RecurrenceFrequency.Weekly)
    }
    var recurrenceInterval by rememberSaveable {
        mutableIntStateOf(editing?.recurrenceRule?.interval ?: 1)
    }
    var reminderEnabled by rememberSaveable {
        mutableStateOf(editing?.reminderSetting?.isEnabled ?: false)
    }
    var reminderMinutes by rememberSaveable {
        mutableIntStateOf(editing?.reminderSetting?.notifyBeforeMinutes ?: 10)
    }
    var isCompleted by rememberSaveable { mutableStateOf(editing?.isCompleted ?: false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (editing == null) "予定の登録" else "予定の編集") },
                navigationIcon = { TextButton(onClick = onClose) { Text("閉じる") } },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("タイトル（必須）") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                DateTimePickerButton("開始日時", startMillis) { startMillis = it }
            }
            item {
                DateTimePickerButton("終了日時", endMillis) { endMillis = it }
            }
            item {
                Text("時間帯")
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    ScheduleTimeOfDay.entries.forEach { option ->
                        FilterChip(
                            selected = timeOfDay == option,
                            onClick = { timeOfDay = option },
                            label = { Text(timeOfDayShortLabel(option)) },
                        )
                    }
                }
            }
            item {
                OutlinedTextField(
                    value = location,
                    onValueChange = { location = it },
                    label = { Text("場所") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = memo,
                    onValueChange = { memo = it },
                    label = { Text("メモ") },
                    minLines = 3,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = categoryName,
                    onValueChange = { categoryName = it },
                    label = { Text("カテゴリ") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                LabeledSwitch("繰り返す", recurrenceEnabled) { recurrenceEnabled = it }
                if (recurrenceEnabled) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        RecurrenceFrequency.entries.forEach { frequency ->
                            FilterChip(
                                selected = recurrenceFrequency == frequency,
                                onClick = { recurrenceFrequency = frequency },
                                label = { Text(recurrenceShortLabel(frequency)) },
                            )
                        }
                    }
                    NumberField(
                        label = "繰り返し間隔",
                        value = recurrenceInterval,
                        onValueChange = { recurrenceInterval = it.coerceAtLeast(1) },
                    )
                }
            }
            item {
                LabeledSwitch("リマインダー", reminderEnabled) { reminderEnabled = it }
                if (reminderEnabled) {
                    NumberField(
                        label = "何分前に通知するか",
                        value = reminderMinutes,
                        onValueChange = { reminderMinutes = it.coerceAtLeast(0) },
                    )
                }
            }
            item {
                Row {
                    Checkbox(checked = isCompleted, onCheckedChange = { isCompleted = it })
                    Text("完了済み", modifier = Modifier.padding(top = 12.dp))
                }
            }
            errorMessage?.let { message ->
                item { Text(message, color = MaterialTheme.colorScheme.error) }
            }
            item {
                PrimaryActionButton(
                    label = "保存",
                    enabled = title.isNotBlank(),
                    onClick = {
                        val now = Instant.now()
                        val schedule = Schedule(
                            id = editing?.id ?: UUID.randomUUID(),
                            userId = editing?.userId ?: "guest",
                            title = title,
                            startDateTime = Instant.ofEpochMilli(startMillis),
                            endDateTime = Instant.ofEpochMilli(endMillis),
                            location = location,
                            timeOfDay = timeOfDay,
                            memo = memo,
                            isCompleted = isCompleted,
                            recurrenceRule = if (recurrenceEnabled) {
                                RecurrenceRule(recurrenceFrequency, recurrenceInterval)
                            } else {
                                null
                            },
                            reminderSetting = if (reminderEnabled) {
                                ReminderSetting(reminderMinutes, true)
                            } else {
                                null
                            },
                            category = categoryName.trim().takeIf(String::isNotEmpty)?.let {
                                ScheduleCategory(
                                    id = editing?.category?.id ?: UUID.randomUUID(),
                                    userId = editing?.userId ?: "guest",
                                    name = it,
                                )
                            },
                            createdAt = editing?.createdAt ?: now,
                            updatedAt = now,
                        )
                        model.save(schedule) { result ->
                            result.fold(
                                onSuccess = { onClose() },
                                onFailure = { errorMessage = it.message },
                            )
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun DateTimePickerButton(label: String, epochMillis: Long, onChange: (Long) -> Unit) {
    val context = LocalContext.current
    Button(
        onClick = {
            val current = Instant.ofEpochMilli(epochMillis).atZone(ZoneId.systemDefault())
            DatePickerDialog(
                context,
                { _, year, month, day ->
                    TimePickerDialog(
                        context,
                        { _, hour, minute ->
                            val updated = current
                                .withYear(year)
                                .withMonth(month + 1)
                                .withDayOfMonth(day)
                                .withHour(hour)
                                .withMinute(minute)
                            onChange(updated.toInstant().toEpochMilli())
                        },
                        current.hour,
                        current.minute,
                        true,
                    ).show()
                },
                current.year,
                current.monthValue - 1,
                current.dayOfMonth,
            ).show()
        },
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text("$label：${formatInstant(Instant.ofEpochMilli(epochMillis))}")
    }
}

@Composable
private fun NumberField(label: String, value: Int, onValueChange: (Int) -> Unit) {
    OutlinedTextField(
        value = value.toString(),
        onValueChange = { text -> text.toIntOrNull()?.let(onValueChange) },
        label = { Text(label) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun LabeledSwitch(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, modifier = Modifier.padding(top = 12.dp))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

private fun shareCsv(context: Context, schedules: List<Schedule>) {
    val sendIntent = Intent(Intent.ACTION_SEND).apply {
        type = "text/csv"
        putExtra(Intent.EXTRA_SUBJECT, "予定一覧.csv")
        putExtra(Intent.EXTRA_TEXT, "\uFEFF${ScheduleCsvExporter.export(schedules)}")
    }
    context.startActivity(Intent.createChooser(sendIntent, "CSVを共有"))
}

private fun addToDeviceCalendar(context: Context, schedule: Schedule) {
    val intent = Intent(Intent.ACTION_INSERT).apply {
        data = CalendarContract.Events.CONTENT_URI
        putExtra(CalendarContract.Events.TITLE, schedule.title)
        putExtra(CalendarContract.Events.DESCRIPTION, schedule.memo)
        putExtra(CalendarContract.Events.EVENT_LOCATION, schedule.location)
        putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, schedule.startDateTime.toEpochMilli())
        putExtra(CalendarContract.EXTRA_EVENT_END_TIME, schedule.endDateTime.toEpochMilli())
    }
    context.startActivity(intent)
}

private val dateTimeFormatter = DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm")

private fun formatInstant(value: Instant): String =
    dateTimeFormatter.format(value.atZone(ZoneId.systemDefault()))

private fun scheduleDateText(schedule: Schedule): String =
    "${formatInstant(schedule.startDateTime)}・${timeOfDayLabel(schedule.timeOfDay)}"

private fun timeOfDayLabel(value: ScheduleTimeOfDay): String = when (value) {
    ScheduleTimeOfDay.AllDay -> "終日"
    ScheduleTimeOfDay.Morning -> "午前"
    ScheduleTimeOfDay.Afternoon -> "午後"
    ScheduleTimeOfDay.Evening -> "夕方"
    ScheduleTimeOfDay.Specified -> "時間指定"
}

private fun timeOfDayShortLabel(value: ScheduleTimeOfDay): String = when (value) {
    ScheduleTimeOfDay.AllDay -> "終日"
    ScheduleTimeOfDay.Morning -> "午前"
    ScheduleTimeOfDay.Afternoon -> "午後"
    ScheduleTimeOfDay.Evening -> "夕方"
    ScheduleTimeOfDay.Specified -> "指定"
}

private fun recurrenceLabel(value: RecurrenceFrequency): String = when (value) {
    RecurrenceFrequency.Daily -> "毎日"
    RecurrenceFrequency.Weekly -> "毎週"
    RecurrenceFrequency.Monthly -> "毎月"
    RecurrenceFrequency.Yearly -> "毎年"
}

private fun recurrenceShortLabel(value: RecurrenceFrequency): String = when (value) {
    RecurrenceFrequency.Daily -> "日"
    RecurrenceFrequency.Weekly -> "週"
    RecurrenceFrequency.Monthly -> "月"
    RecurrenceFrequency.Yearly -> "年"
}
