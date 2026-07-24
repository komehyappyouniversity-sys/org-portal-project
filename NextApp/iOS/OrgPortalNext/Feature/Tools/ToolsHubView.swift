import DesignSystem
import SwiftUI

public struct ToolsHubView: View {
    private enum Destination: Identifiable {
        case schedule
        case diary
        case denomination
        case meetingMinutes
        case snsPostingAssistant

        var id: String {
            switch self {
            case .schedule: "schedule"
            case .diary: "diary"
            case .denomination: "denomination"
            case .meetingMinutes: "meetingMinutes"
            case .snsPostingAssistant: "snsPostingAssistant"
            }
        }
    }

    @ObservedObject private var scheduleModel: ScheduleFeatureModel
    @ObservedObject private var diaryModel: DiaryFeatureModel
    @ObservedObject private var cashDistributionModel: CashDistributionFeatureModel
    @ObservedObject private var meetingMinutesModel: MeetingMinutesFeatureModel
    @ObservedObject private var snsPostingAssistantModel: SnsPostingAssistantFeatureModel
    @State private var destination: Destination?

    public init(
        scheduleModel: ScheduleFeatureModel,
        diaryModel: DiaryFeatureModel,
        cashDistributionModel: CashDistributionFeatureModel,
        meetingMinutesModel: MeetingMinutesFeatureModel,
        snsPostingAssistantModel: SnsPostingAssistantFeatureModel
    ) {
        self.scheduleModel = scheduleModel
        self.diaryModel = diaryModel
        self.cashDistributionModel = cashDistributionModel
        self.meetingMinutesModel = meetingMinutesModel
        self.snsPostingAssistantModel = snsPostingAssistantModel
    }

    public var body: some View {
        NavigationStack {
            List {
                Button {
                    destination = .schedule
                } label: {
                    FeatureCard(
                        "screen.schedule.list",
                        subtitle: "home.schedule.subtitle",
                        systemImage: "calendar"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .meetingMinutes
                } label: {
                    FeatureCard(
                        "home.meeting_minutes.title",
                        subtitle: "home.meeting_minutes.subtitle",
                        systemImage: "mic"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .diary
                } label: {
                    FeatureCard(
                        "screen.diary.list",
                        subtitle: "home.diary.subtitle",
                        systemImage: "book.closed"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .denomination
                } label: {
                    FeatureCard(
                        "home.denomination.title",
                        subtitle: "home.denomination.subtitle",
                        systemImage: "yensign.circle"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .snsPostingAssistant
                } label: {
                    FeatureCard(
                        "SNS投稿補助",
                        subtitle: "文章をコピーして外部SNSを開きます。",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("tab.tools")
        }
        .sheet(item: $destination) { destination in
            ZStack(alignment: .topTrailing) {
                switch destination {
                case .schedule:
                    ScheduleListView(model: scheduleModel)
                case .diary:
                    DiaryRootView(model: diaryModel)
                case .denomination:
                    DenominationToolView(model: cashDistributionModel)
                case .meetingMinutes:
                    MeetingMinutesRootView(model: meetingMinutesModel)
                case .snsPostingAssistant:
                    SnsPostingAssistantView(model: snsPostingAssistantModel)
                }
                Button {
                    self.destination = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                }
                .padding()
                .accessibilityLabel("action.close")
            }
        }
    }
}
