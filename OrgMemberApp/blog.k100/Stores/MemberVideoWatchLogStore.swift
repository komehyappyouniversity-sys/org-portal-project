import Foundation
import FirebaseAuth
import FirebaseFirestore

final class MemberVideoWatchLogStore: ObservableObject {

    private let db = Firestore.firestore()

    // MARK: - 動画画面を開いた

    func recordVideoOpened(
        organizationId: String,
        videoId: String,
        videoTitle: String,
        memberName: String = ""
    ) {
        updateWatchLog(
            organizationId: organizationId,
            videoId: videoId,
            videoTitle: videoTitle,
            memberName: memberName,
            currentPositionSeconds: 0,
            durationSeconds: 0,
            isCompleted: false,
            addWatchCount: false
        )
    }

    // MARK: - 再生開始

    func recordVideoPlayStarted(
        organizationId: String,
        videoId: String,
        videoTitle: String,
        memberName: String = ""
    ) {
        updateWatchLog(
            organizationId: organizationId,
            videoId: videoId,
            videoTitle: videoTitle,
            memberName: memberName,
            currentPositionSeconds: 0,
            durationSeconds: 0,
            isCompleted: false,
            addWatchCount: true
        )
    }

    // MARK: - 再生途中保存

    func updatePlaybackProgress(
        organizationId: String,
        videoId: String,
        videoTitle: String,
        memberName: String = "",
        currentPositionSeconds: Double,
        durationSeconds: Double
    ) {
        updateWatchLog(
            organizationId: organizationId,
            videoId: videoId,
            videoTitle: videoTitle,
            memberName: memberName,
            currentPositionSeconds: currentPositionSeconds,
            durationSeconds: durationSeconds,
            isCompleted: false,
            addWatchCount: false
        )
    }

    // MARK: - 視聴完了

    func recordCompleted(
        organizationId: String,
        videoId: String,
        videoTitle: String,
        memberName: String = "",
        durationSeconds: Double
    ) {
        updateWatchLog(
            organizationId: organizationId,
            videoId: videoId,
            videoTitle: videoTitle,
            memberName: memberName,
            currentPositionSeconds: durationSeconds,
            durationSeconds: durationSeconds,
            isCompleted: true,
            addWatchCount: false
        )
    }

    // MARK: - 共通更新処理

    private func updateWatchLog(
        organizationId: String,
        videoId: String,
        videoTitle: String,
        memberName: String,
        currentPositionSeconds: Double,
        durationSeconds: Double,
        isCompleted: Bool,
        addWatchCount: Bool
    ) {

        guard let uid = Auth.auth().currentUser?.uid else {
            print("動画視聴ログ保存スキップ: ログインユーザーなし")
            return
        }

        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            print("動画視聴ログ保存スキップ: organizationId が空")
            return
        }

        guard !videoId.isEmpty else {
            print("動画視聴ログ保存スキップ: videoId が空")
            return
        }

        let logId = "\(uid)_\(videoId)"

        let ref = db
            .collection("organizations")
            .document(orgId)
            .collection("videoWatchLogs")
            .document(logId)

        db.runTransaction({ transaction, errorPointer in

            let snapshot: DocumentSnapshot

            do {
                snapshot = try transaction.getDocument(ref)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            let existingData = snapshot.data() ?? [:]

            let currentWatchCount = existingData["watchCount"] as? Int ?? 0
            let existingPlayHistory = existingData["playHistory"] as? [[String: Any]] ?? []
            let existingCompletionHistory = existingData["completionHistory"] as? [[String: Any]] ?? []

            var newWatchCount = currentWatchCount

            if addWatchCount {
                newWatchCount += 1
            }

            var playHistory = existingPlayHistory
            var completionHistory = existingCompletionHistory

            let now = Timestamp(date: Date())

            // 再生履歴追加
            if addWatchCount {
                playHistory.append([
                    "playedAt": now,
                    "positionSeconds": currentPositionSeconds
                ])
            }

            // 視聴完了履歴追加
            if isCompleted {
                completionHistory.append([
                    "completedAt": now,
                    "durationSeconds": durationSeconds
                ])
            }

            let data: [String: Any] = [
                "organizationId": orgId,

                "memberUid": uid,
                "memberName": memberName,

                "videoId": videoId,
                "videoTitle": videoTitle,

                "watchCount": newWatchCount,

                "lastPositionSeconds": currentPositionSeconds,
                "durationSeconds": durationSeconds,

                "totalWatchSeconds": currentPositionSeconds,

                "isCompleted": isCompleted,

                "completedAt": isCompleted
                    ? now
                    : existingData["completedAt"] as Any,

                "completionHistory": completionHistory,

                "playHistory": playHistory,

                "lastWatchedAt": now,
                "updatedAt": FieldValue.serverTimestamp(),

                "createdAt":
                    existingData["createdAt"]
                    ?? FieldValue.serverTimestamp()
            ]

            transaction.setData(
                data,
                forDocument: ref,
                merge: true
            )

            return nil

        }) { _, error in

            if let error {
                print("動画視聴ログ保存失敗:", error.localizedDescription)
            } else {
                print("動画視聴ログ保存成功:", videoTitle)
            }
        }
    }
}
