import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AdminFCMTokenSaver {
    static func save(token: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("管理者UIDなし。FCM保存スキップ")
            return
        }

        let db = Firestore.firestore()

        db.collection("admins")
            .document(uid)
            .setData([
                "fcmToken": token,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

        print("管理者FCMトークン保存完了:", token)
    }
}
