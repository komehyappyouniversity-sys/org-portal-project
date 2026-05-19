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

    @FocusState private var focusedField: Field?

    private let db = Firestore.firestore()

    enum Field {
        case name
        case email
        case phone
        case password
    }

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

                    focusedField = nil
                    register()

                } label: {

                    if isLoading {

                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()

                    } else {

                        Text("会員登録を申請する")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(isLoading)
            }
            .padding(24)
        }
        .navigationTitle("会員登録")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "申請が完了しました",
            isPresented: $showCompleteAlert
        ) {

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
                .focused($focusedField, equals: .name)
                .tint(.blue)

            fieldTitle("生年月日")

            DatePicker(
                "生年月日を選択",
                selection: $birthDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)

            fieldTitle("メールアドレス")

            TextField(
                "例：example@gmail.com",
                text: $email
            )
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
            .focused($focusedField, equals: .email)
            .tint(.blue)

            fieldTitle("電話番号")

            TextField(
                "例：09012345678",
                text: $phone
            )
            .keyboardType(.phonePad)
            .textFieldStyle(.roundedBorder)
            .focused($focusedField, equals: .phone)
            .tint(.blue)

            fieldTitle("パスワード")

            SecureField("6文字以上", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .password)
                .tint(.blue)
        }
    }

    private func fieldTitle(
        _ text: String
    ) -> some View {

        Text(text)
            .font(.title3.bold())
    }

    private func register() {

        errorMessage = ""

        let trimmedName = name
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let trimmedEmail = email
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let trimmedPhone = phone
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

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

            errorMessage =
            "パスワードは6文字以上で入力してください。"

            return
        }

        guard !organizationId.isEmpty else {

            errorMessage =
            "コミュニティ情報が取得できません。"

            return
        }

        isLoading = true

        Auth.auth().createUser(
            withEmail: trimmedEmail,
            password: password
        ) { result, error in

            if let nsError = error as NSError? {

                if nsError.code == AuthErrorCode.emailAlreadyInUse.rawValue {

                    Auth.auth().signIn(
                        withEmail: trimmedEmail,
                        password: password
                    ) { result, error in

                        if let error {

                            DispatchQueue.main.async {

                                self.isLoading = false
                                self.errorMessage =
                                "既存アカウントです。正しいパスワードでログインしてください。"
                            }

                            return
                        }

                        guard let uid = result?.user.uid else {

                            DispatchQueue.main.async {

                                self.isLoading = false
                                self.errorMessage =
                                "UID取得失敗"
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

                    return
                }

                DispatchQueue.main.async {

                    self.isLoading = false
                    self.errorMessage =
                    nsError.localizedDescription
                }

                return
            }

            guard let uid = result?.user.uid else {

                DispatchQueue.main.async {

                    self.isLoading = false
                    self.errorMessage =
                    "UIDが取得できません。"
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

        registrationRef.setData(data, merge: true) { error in

            DispatchQueue.main.async {

                self.isLoading = false

                if error != nil {

                    self.errorMessage =
                    "登録保存に失敗しました"

                } else {

                    self.showCompleteAlert = true
                }
            }
        }
    }

    private func resolvedOrganizationId() -> String {

        organizationStore.organizationId
            .trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines
            )
    }
}
