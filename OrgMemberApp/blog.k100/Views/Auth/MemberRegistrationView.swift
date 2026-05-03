import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MemberRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var organizationStore: OrganizationStore

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var birthDate = Date()

    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showCompleteAlert = false

    private let db = Firestore.firestore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("会員登録")
                    .font(.largeTitle.bold())

                inputSection

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.headline)
                }

                Button {
                    register()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("会員登録を申請する")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading)
            }
            .padding(24)
        }
        .navigationTitle("会員登録")
        .navigationBarTitleDisplayMode(.inline)
        .alert("申請が完了しました", isPresented: $showCompleteAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("管理者の承認後、会員ページを利用できます。")
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            fieldTitle("お名前")
            TextField("例：根津孝誠", text: $name)
                .textFieldStyle(.roundedBorder)

            fieldTitle("生年月日")
            DatePicker(
                "生年月日を選択",
                selection: $birthDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)

            fieldTitle("メールアドレス")
            TextField("例：example@gmail.com", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            fieldTitle("電話番号")
            TextField("例：09012345678", text: $phone)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)

            fieldTitle("パスワード")
            SecureField("6文字以上", text: $password)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func fieldTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
    }

    private func register() {
        errorMessage = ""

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let organizationId = resolvedOrganizationId()

        guard !trimmedName.isEmpty else {
            errorMessage = "お名前を入力してください。"
            return
        }

        guard !trimmedEmail.isEmpty else {
            errorMessage = "メールアドレスを入力してください。"
            return
        }

        guard !trimmedPhone.isEmpty else {
            errorMessage = "電話番号を入力してください。"
            return
        }

        guard password.count >= 6 else {
            errorMessage = "パスワードは6文字以上で入力してください。"
            return
        }

        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が取得できません。"
            return
        }

        isLoading = true

        Auth.auth().createUser(withEmail: trimmedEmail, password: password) { result, error in
            if let error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
                return
            }

            guard let uid = result?.user.uid else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "UIDが取得できません。"
                }
                return
            }

            saveRegistration(
                organizationId: organizationId,
                uid: uid,
                name: trimmedName,
                email: trimmedEmail,
                phone: trimmedPhone
            )
        }
    }

    private func saveRegistration(
        organizationId: String,
        uid: String,
        name: String,
        email: String,
        phone: String
    ) {
        let data: [String: Any] = [
            "uid": uid,
            "organizationId": organizationId,
            "name": name,
            "email": email,
            "phone": phone,
            "birthDate": Timestamp(date: birthDate),
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let registrationRef = db
            .collection("organizations")
            .document(organizationId)
            .collection("memberRegistrations")
            .document(uid)

        let memberRef = db
            .collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)

        let batch = db.batch()
        batch.setData(data, forDocument: registrationRef)
        batch.setData(data, forDocument: memberRef)

        batch.commit { error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                self.showCompleteAlert = true
            }
        }
    }

    private func resolvedOrganizationId() -> String {
        let fromStore = organizationStore.organization.id
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !fromStore.isEmpty {
            return fromStore
        }

        return OrganizationConfig.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
