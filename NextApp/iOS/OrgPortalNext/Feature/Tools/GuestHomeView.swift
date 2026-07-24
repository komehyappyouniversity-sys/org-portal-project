import DesignSystem
import SwiftUI

public enum GuestHomeTool: String, CaseIterable, Identifiable, Sendable {
    case schedule
    case diary
    case denomination
    case meetingMinutes

    public var id: String { rawValue }

    public static let ordered: [GuestHomeTool] = [
        .schedule,
        .diary,
        .denomination,
        .meetingMinutes
    ]

    public var isAvailable: Bool {
        self == .schedule || self == .diary || self == .denomination
    }

    var title: LocalizedStringKey {
        switch self {
        case .schedule: "home.schedule.title"
        case .diary: "home.diary.title"
        case .denomination: "home.denomination.title"
        case .meetingMinutes: "home.meeting_minutes.title"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .schedule: "home.schedule.subtitle"
        case .diary: "home.diary.subtitle"
        case .denomination: "home.denomination.subtitle"
        case .meetingMinutes: "home.meeting_minutes.subtitle"
        }
    }

    var systemImage: String {
        switch self {
        case .schedule: "calendar"
        case .diary: "book.closed"
        case .denomination: "yensign.circle"
        case .meetingMinutes: "mic"
        }
    }
}

public struct GuestHomeView: View {
    @ObservedObject private var scheduleModel: ScheduleFeatureModel
    @ObservedObject private var diaryModel: DiaryFeatureModel
    @State private var isShowingTodaySchedule = false
    @State private var isShowingDiary = false
    @State private var isShowingDenomination = false

    public init(
        scheduleModel: ScheduleFeatureModel,
        diaryModel: DiaryFeatureModel
    ) {
        self.scheduleModel = scheduleModel
        self.diaryModel = diaryModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.contentSpacing) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("home.guest.title")
                            .font(.title2.bold())
                        Spacer()
                        StatusBadge("home.guest.badge", systemImage: "person.crop.circle")
                    }
                    Text("home.guest.message")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(GuestHomeTool.ordered) { tool in
                        if tool == .schedule {
                            Button {
                                isShowingTodaySchedule = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("home.schedule.accessibility_hint")
                        } else if tool == .diary {
                            Button {
                                isShowingDiary = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("home.diary.accessibility_hint")
                        } else if tool == .denomination {
                            Button {
                                isShowingDenomination = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("home.denomination.accessibility_hint")
                        } else {
                            FeatureCard(
                                tool.title,
                                subtitle: tool.subtitle,
                                systemImage: tool.systemImage,
                                status: "home.status.coming_soon"
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("tab.home")
        }
        .sheet(isPresented: $isShowingTodaySchedule) {
            TodayScheduleView(model: scheduleModel)
        }
        .sheet(isPresented: $isShowingDiary) {
            DiaryRootView(model: diaryModel)
        }
        .sheet(isPresented: $isShowingDenomination) {
            DenominationCalculatorView()
        }
    }
}
