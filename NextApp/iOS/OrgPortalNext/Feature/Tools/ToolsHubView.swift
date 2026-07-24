import DesignSystem
import SwiftUI

public struct ToolsHubView: View {
    private enum Destination: Identifiable {
        case schedule
        case diary

        var id: String {
            switch self {
            case .schedule: "schedule"
            case .diary: "diary"
            }
        }
    }

    @ObservedObject private var scheduleModel: ScheduleFeatureModel
    @ObservedObject private var diaryModel: DiaryFeatureModel
    @State private var destination: Destination?

    public init(
        scheduleModel: ScheduleFeatureModel,
        diaryModel: DiaryFeatureModel
    ) {
        self.scheduleModel = scheduleModel
        self.diaryModel = diaryModel
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
                    destination = .diary
                } label: {
                    FeatureCard(
                        "screen.diary.list",
                        subtitle: "home.diary.subtitle",
                        systemImage: "book.closed"
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
