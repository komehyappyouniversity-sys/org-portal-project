import Foundation
import Model

public enum SampleData {
    public static func schedule(
        title: String = "サンプル予定",
        start: Date = .now
    ) -> Schedule {
        Schedule(
            userId: "guest_example",
            title: title,
            startDateTime: start,
            endDateTime: start.addingTimeInterval(3600),
            timeOfDay: .specified
        )
    }
}
