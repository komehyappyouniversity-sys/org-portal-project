import Foundation
import SwiftUI
import DesignSystem
import Model

public struct ScheduleListView: View {
    @ObservedObject private var model: ScheduleFeatureModel
    @State private var editorMode: ScheduleEditorMode?
    @State private var csvURL: URL?

    public init(model: ScheduleFeatureModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    LoadingState()
                } else if let error = model.errorMessage {
                    ErrorState(message: error) {
                        Task { await model.load() }
                    }
                } else if model.schedules.isEmpty {
                    EmptyState("schedule.empty", systemImage: "calendar.badge.plus")
                } else {
                    List(model.schedules) { schedule in
                        NavigationLink {
                            ScheduleDetailView(model: model, schedule: schedule)
                        } label: {
                            ScheduleRow(schedule: schedule)
                        }
                    }
                }
            }
            .navigationTitle("screen.schedule.list")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("action.share_csv", systemImage: "square.and.arrow.up") {
                        csvURL = makeCsvFile()
                    }
                    .disabled(model.schedules.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("action.add", systemImage: "plus") {
                        editorMode = .new
                    }
                }
            }
            .sheet(item: $editorMode) { mode in
                ScheduleEditorView(model: model, mode: mode)
            }
            .sheet(
                isPresented: Binding(
                    get: { csvURL != nil },
                    set: { if !$0 { csvURL = nil } }
                )
            ) {
                if let csvURL {
                    ActivityShareSheet(activityItems: [csvURL])
                }
            }
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }

    private func makeCsvFile() -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedules.csv")
        do {
            try ScheduleCsvExporter.data(for: model.schedules).write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

public struct TodayScheduleView: View {
    @ObservedObject private var model: ScheduleFeatureModel

    public init(model: ScheduleFeatureModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    LoadingState()
                } else if let error = model.errorMessage {
                    ErrorState(message: error) {
                        Task { await model.load() }
                    }
                } else if model.todaysSchedules.isEmpty {
                    EmptyState("schedule.today.empty", systemImage: "calendar")
                } else {
                    List(model.todaysSchedules) { schedule in
                        NavigationLink {
                            ScheduleDetailView(model: model, schedule: schedule)
                        } label: {
                            ScheduleRow(schedule: schedule)
                        }
                    }
                }
            }
            .navigationTitle("screen.schedule.today")
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }
}

private struct ScheduleRow: View {
    let schedule: Schedule

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: schedule.isCompleted ? "checkmark.circle.fill" : "calendar")
                .foregroundStyle(
                    schedule.isCompleted ? .secondary : DesignTokens.brandGreen
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.title)
                    .font(.headline)
                    .strikethrough(schedule.isCompleted)
                Text(
                    schedule.startDateTime,
                    format: schedule.timeOfDay == .specified
                        ? .dateTime.month().day().hour().minute()
                        : .dateTime.month().day()
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if !schedule.location.isEmpty {
                    Label(schedule.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                }
            }
        }
        .frame(minHeight: DesignTokens.minimumTapHeight)
    }
}

public struct ScheduleDetailView: View {
    @ObservedObject private var model: ScheduleFeatureModel
    @Environment(\.dismiss) private var dismiss
    @State private var editorMode: ScheduleEditorMode?
    @State private var showDeleteConfirmation = false
    @State private var calendarMessage: LocalizedStringKey?
    private let schedule: Schedule
    private let calendarClient = DeviceCalendarClient()

    public init(model: ScheduleFeatureModel, schedule: Schedule) {
        self.model = model
        self.schedule = schedule
    }

    public var body: some View {
        List {
            LabeledContent("schedule.start") {
                Text(schedule.startDateTime.formatted())
            }
            LabeledContent("schedule.end") {
                Text(schedule.endDateTime.formatted())
            }
            LabeledContent("schedule.time_of_day") {
                Text(LocalizedStringKey(schedule.timeOfDay.localizationKey))
            }
            if !schedule.location.isEmpty {
                LabeledContent("schedule.location", value: schedule.location)
            }
            if !schedule.memo.isEmpty {
                Section("schedule.memo") {
                    Text(schedule.memo)
                }
            }
            if let recurrence = schedule.recurrenceRule {
                LabeledContent("schedule.recurrence") {
                    Text("\(recurrence.frequency.rawValue) × \(recurrence.interval)")
                }
            }
            if let reminder = schedule.reminderSetting, reminder.isEnabled {
                LabeledContent("schedule.reminder") {
                    Text("\(reminder.notifyBeforeMinutes)分前")
                }
            }
            if let category = schedule.category {
                LabeledContent("schedule.category", value: category.name)
            }
            Button("action.add_to_calendar", systemImage: "calendar.badge.plus") {
                Task {
                    do {
                        try await calendarClient.add(schedule)
                        calendarMessage = "alert.calendar_added"
                    } catch {
                        calendarMessage = "error.calendar"
                    }
                }
            }
            Button(
                "action.delete",
                systemImage: "trash",
                role: .destructive
            ) {
                showDeleteConfirmation = true
            }
        }
        .navigationTitle("screen.schedule.detail")
        .toolbar {
            Button("action.edit") {
                editorMode = .edit(schedule)
            }
        }
        .sheet(item: $editorMode) { mode in
            ScheduleEditorView(model: model, mode: mode)
        }
        .alert(
            "alert.delete_title",
            isPresented: $showDeleteConfirmation
        ) {
            Button("action.cancel", role: .cancel) {}
            Button("action.delete", role: .destructive) {
                Task {
                    await model.delete(schedule)
                    dismiss()
                }
            }
        } message: {
            Text("alert.delete_message")
        }
        .alert(
            calendarMessage ?? "",
            isPresented: Binding(
                get: { calendarMessage != nil },
                set: { if !$0 { calendarMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
    }
}

public enum ScheduleEditorMode: Identifiable {
    case new
    case edit(Schedule)

    public var id: String {
        switch self {
        case .new: "new"
        case .edit(let schedule): schedule.id.uuidString
        }
    }
}

public struct ScheduleEditorView: View {
    @ObservedObject private var model: ScheduleFeatureModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Schedule
    @State private var recurrenceEnabled: Bool
    @State private var recurrenceFrequency: RecurrenceFrequency
    @State private var recurrenceInterval: Int
    @State private var reminderEnabled: Bool
    @State private var reminderMinutes: Int
    @State private var categoryName: String
    @State private var validationMessage: LocalizedStringKey?
    private let titleKey: LocalizedStringKey

    public init(model: ScheduleFeatureModel, mode: ScheduleEditorMode) {
        self.model = model
        let schedule: Schedule
        switch mode {
        case .new:
            let start = Date.now
            schedule = Schedule(
                userId: "guest",
                title: "",
                startDateTime: start,
                endDateTime: start.addingTimeInterval(3600),
                timeOfDay: .specified
            )
            titleKey = "screen.schedule.new"
        case .edit(let existing):
            schedule = existing
            titleKey = "screen.schedule.edit"
        }
        _draft = State(initialValue: schedule)
        _recurrenceEnabled = State(initialValue: schedule.recurrenceRule != nil)
        _recurrenceFrequency = State(
            initialValue: schedule.recurrenceRule?.frequency ?? .weekly
        )
        _recurrenceInterval = State(
            initialValue: schedule.recurrenceRule?.interval ?? 1
        )
        _reminderEnabled = State(
            initialValue: schedule.reminderSetting?.isEnabled ?? false
        )
        _reminderMinutes = State(
            initialValue: schedule.reminderSetting?.notifyBeforeMinutes ?? 10
        )
        _categoryName = State(initialValue: schedule.category?.name ?? "")
    }

    public var body: some View {
        NavigationStack {
            Form {
                TextField("schedule.title", text: $draft.title)
                Picker("schedule.time_of_day", selection: $draft.timeOfDay) {
                    ForEach(ScheduleTimeOfDay.allCases, id: \.self) { value in
                        Text(LocalizedStringKey(value.localizationKey)).tag(value)
                    }
                }
                DatePicker(
                    "schedule.start",
                    selection: $draft.startDateTime,
                    displayedComponents: draft.timeOfDay == .specified
                        ? [.date, .hourAndMinute] : [.date]
                )
                DatePicker(
                    "schedule.end",
                    selection: $draft.endDateTime,
                    in: draft.startDateTime...,
                    displayedComponents: draft.timeOfDay == .specified
                        ? [.date, .hourAndMinute] : [.date]
                )
                TextField("schedule.location", text: $draft.location)
                TextField("schedule.memo", text: $draft.memo, axis: .vertical)
                    .lineLimit(3...8)
                Toggle("schedule.completed", isOn: $draft.isCompleted)

                Section("schedule.recurrence") {
                    Toggle("schedule.recurrence", isOn: $recurrenceEnabled)
                    if recurrenceEnabled {
                        Picker("schedule.recurrence", selection: $recurrenceFrequency) {
                            ForEach(RecurrenceFrequency.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        Stepper(
                            value: $recurrenceInterval,
                            in: 1...99
                        ) {
                            Text("間隔: \(recurrenceInterval)")
                        }
                    }
                }

                Section("schedule.reminder") {
                    Toggle("schedule.reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        Stepper(value: $reminderMinutes, in: 0...10_080) {
                            Text("\(reminderMinutes)分前")
                        }
                    }
                }

                Section("schedule.category") {
                    TextField("schedule.category", text: $categoryName)
                }

                if let validationMessage {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                        .accessibilityLabel(validationMessage)
                }
            }
            .navigationTitle(titleKey)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        Task { await save() }
                    }
                }
            }
        }
    }

    private func save() async {
        var value = draft
        value.recurrenceRule = recurrenceEnabled
            ? RecurrenceRule(
                frequency: recurrenceFrequency,
                interval: recurrenceInterval
            )
            : nil
        value.reminderSetting = ReminderSetting(
            notifyBeforeMinutes: reminderMinutes,
            isEnabled: reminderEnabled
        )
        let trimmedCategory = categoryName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        value.category = trimmedCategory.isEmpty
            ? nil
            : ScheduleCategory(
                id: draft.category?.id ?? UUID(),
                userId: draft.userId,
                name: trimmedCategory
            )
        do {
            try await model.save(value)
            dismiss()
        } catch let validation as ScheduleValidationError {
            validationMessage = LocalizedStringKey(validation.localizationKey)
        } catch {
            validationMessage = LocalizedStringKey("state.error")
        }
    }
}
