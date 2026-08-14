import Foundation
import Model

public final class VimeoMemoStore {
    private let userDefaults: UserDefaults
    private let storageKey = "memo_values"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func entries(communityId: String, videoId: String) -> [VimeoVideoMemo] {
        let raw = read().entries[key(for: communityId, videoId: videoId), default: ""]
        guard !raw.isEmpty else { return [] }
        guard
            let data = raw.data(using: .utf8),
            let payload = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [[String: Any]]
        else {
            return [
                VimeoVideoMemo(
                    id: "legacy",
                    text: raw,
                    playbackSeconds: 0,
                    createdAtMillis: 0,
                    updatedAtMillis: 0,
                    syncStatus: .synced,
                )
            ]
        }

        return payload.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return VimeoVideoMemo(
                id: id,
                text: item["text"] as? String ?? "",
                playbackSeconds: numberFromJSON(item["playbackSeconds"]) ?? 0,
                createdAtMillis: int64FromJSON(item["createdAtMillis"]),
                updatedAtMillis: int64FromJSON(item["updatedAtMillis"]),
                syncStatus: syncStatusFromJSON(item["syncStatus"])
            )
        }.sorted { $0.createdAtMillis > $1.createdAtMillis }
    }

    public func allEntries() -> [String: [VimeoVideoMemo]] {
        read().entries.reduce(into: [String: [VimeoVideoMemo]]()) { result, item in
            result[item.key] = entries(fromRaw: item.value)
        }
    }

    public func pendingEntries() -> [String: [VimeoVideoMemo]] {
        allEntries().mapValues { memos in
            memos.filter { $0.syncStatus == .pendingSync }
        }.filter { !$0.value.isEmpty }
    }

    public func serialized(entries: [VimeoVideoMemo]) -> String {
        guard !entries.isEmpty else { return "" }
        let payload = entries.map { memo in
            [
                "id": memo.id,
                "text": memo.text,
                "playbackSeconds": memo.playbackSeconds,
                "createdAtMillis": memo.createdAtMillis,
                "updatedAtMillis": memo.updatedAtMillis,
                "syncStatus": memo.syncStatus.rawValue,
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    public func saveAllEntries(_ entries: [String: [VimeoVideoMemo]]) {
        let values = Dictionary(uniqueKeysWithValues: entries.map { (key, memoEntries) in
            (key, serialized(entries: memoEntries))
        })
        let jsonData = try? JSONSerialization.data(withJSONObject: values, options: [])
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        userDefaults.setValue(jsonString, forKey: storageKey)
    }

    public func save(communityId: String, videoId: String, entries: [VimeoVideoMemo]) {
        var values = read()
        let key = key(for: communityId, videoId: videoId)
        let text = serialized(entries: entries)
        if text.isEmpty {
            values.entries.removeValue(forKey: key)
        } else {
            values.entries[key] = text
        }
        let jsonData = try? JSONSerialization.data(withJSONObject: values.entries, options: [])
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? values.json
        userDefaults.setValue(jsonString, forKey: storageKey)
    }

    public func saveAll(_ memos: [String: String]) {
        userDefaults.setValue(memos, forKey: storageKey)
    }

    public func entries(fromRaw raw: String) -> [VimeoVideoMemo] {
        guard
            let data = raw.data(using: .utf8),
            let payload = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [[String: Any]]
        else {
            return [
                VimeoVideoMemo(
                    id: "legacy",
                    text: raw,
                    playbackSeconds: 0,
                    createdAtMillis: 0,
                    updatedAtMillis: 0,
                    syncStatus: .synced,
                )
            ]
        }

        return payload.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return VimeoVideoMemo(
                id: id,
                text: item["text"] as? String ?? "",
                playbackSeconds: numberFromJSON(item["playbackSeconds"]) ?? 0,
                createdAtMillis: int64FromJSON(item["createdAtMillis"]),
                updatedAtMillis: int64FromJSON(item["updatedAtMillis"]),
                syncStatus: syncStatusFromJSON(item["syncStatus"]),
            )
        }
    }

    private func read() -> (entries: [String: String], json: String) {
        guard let raw = userDefaults.string(forKey: storageKey),
              let data = raw.data(using: .utf8),
              let values = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: String] else {
            return ([:], "{}")
        }
        return (values, raw)
    }

    private func key(for communityId: String, videoId: String) -> String {
        "\(communityId):\(videoId)"
    }

    private func syncStatusFromJSON(_ value: Any?) -> VimeoVideoMemoSyncStatus {
        if let status = value as? String, let parsed = VimeoVideoMemoSyncStatus(rawValue: status) {
            return parsed
        }
        return .synced
    }

    private func numberFromJSON(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let number = value as? Int64 { return Double(number) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private func int64FromJSON(_ value: Any?) -> Int64 {
        if let number = value as? Double { return Int64(number) }
        if let number = value as? Int { return Int64(number) }
        if let number = value as? Int64 { return number }
        if let number = value as? NSNumber { return number.int64Value }
        return 0
    }
}

public final class VideoQuestionDraftStore {
    private let userDefaults: UserDefaults
    private let storageKey = "video_question_drafts"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func questions(communityId: String, memberUid: String) -> [VideoQuestion] {
        allQuestions()
            .filter { $0.communityId == communityId && $0.memberUid == memberUid }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    public func pendingQuestions(communityId: String, memberUid: String) -> [VideoQuestion] {
        questions(communityId: communityId, memberUid: memberUid)
            .filter { $0.syncStatus.requiresSync }
    }

    public func allQuestions() -> [VideoQuestion] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([VideoQuestion].self, from: data)) ?? []
    }

    public func save(_ question: VideoQuestion) {
        var values = allQuestions()
        let identity = questionIdentity(question)
        if let index = values.firstIndex(where: { questionIdentity($0) == identity }) {
            values[index] = question
        } else {
            values.append(question)
        }
        write(values)
    }

    public func replaceQuestions(
        communityId: String,
        memberUid: String,
        with questions: [VideoQuestion]
    ) {
        let retained = allQuestions().filter {
            $0.communityId != communityId || $0.memberUid != memberUid
        }
        write(retained + questions)
    }

    private func write(_ questions: [VideoQuestion]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(questions) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func questionIdentity(_ question: VideoQuestion) -> String {
        question.clientRequestId.isEmpty ? question.id : question.clientRequestId
    }
}
