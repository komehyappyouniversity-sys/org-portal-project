import Foundation
import FirebaseAuth
import FirebaseFirestore

protocol MemberServiceProtocol {
    func ensureSignedIn() async throws -> String
    func fetchMember(uid: String) async throws -> MemberProfile?
    func listenMember(
        uid: String,
        onChange: @escaping (Result<MemberProfile?, Error>) -> Void
    ) -> ListenerRegistration
}

final class MemberService: MemberServiceProtocol {
    private let db = Firestore.firestore()

    func ensureSignedIn() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }

        return try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signInAnonymously { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let uid = result?.user.uid else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "MemberService",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "匿名サインインに失敗しました。"]
                        )
                    )
                    return
                }

                continuation.resume(returning: uid)
            }
        }
    }

    func fetchMember(uid: String) async throws -> MemberProfile? {
        let snapshot = try await db.collection("members").document(uid).getDocument()
        guard snapshot.exists else { return nil }
        return MemberProfile.from(document: snapshot)
    }

    func listenMember(
        uid: String,
        onChange: @escaping (Result<MemberProfile?, Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("members")
            .document(uid)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                guard let snapshot, snapshot.exists else {
                    onChange(.success(nil))
                    return
                }

                onChange(.success(MemberProfile.from(document: snapshot)))
            }
    }
}
