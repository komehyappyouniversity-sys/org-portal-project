import Foundation
import Model

public enum ScheduleCsvExporter {
    public static func data(for schedules: [Schedule]) -> Data {
        let formatter = ISO8601DateFormatter()
        let header = [
            "schema_version=1",
            "id,title,start_at,end_at,time_of_day,location,memo,is_completed"
        ]
        let rows = schedules.map { schedule in
            [
                schedule.id.uuidString,
                schedule.title,
                formatter.string(from: schedule.startDateTime),
                formatter.string(from: schedule.endDateTime),
                schedule.timeOfDay.rawValue,
                schedule.location,
                schedule.memo,
                schedule.isCompleted.description
            ]
            .map(escape)
            .joined(separator: ",")
        }
        let csv = (header + rows).joined(separator: "\r\n") + "\r\n"
        return Data([0xEF, 0xBB, 0xBF]) + Data(csv.utf8)
    }

    private static func escape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
