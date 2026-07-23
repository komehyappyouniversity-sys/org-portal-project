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
        self == .schedule
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
    @ObservedObject private var model: ScheduleFeatureModel
    @State private var isShowingTodaySchedule = false

    public init(model: ScheduleFeatureModel) {
        self.model = model
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
            TodayScheduleView(model: model)
        }
    }
}
