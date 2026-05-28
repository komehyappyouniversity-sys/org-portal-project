import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MemberRegistrationView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var organizationStore: OrganizationStore

    @StateObject private var registrationSettingsStore =
    MemberRegistrationSettingsStore()

    @State private var name = ""
    @State private var furigana = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""

    @State private var selectedYear = Calendar.current.component(.year, from: Date()) - 60
    @State private var selectedMonth = 1
    @State private var selectedDay = 1

    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showCompleteAlert = false

    @FocusState private var focusedField: Field?

    private let db = Firestore.firestore()

    enum Field {
        case name
        case furigana
        case email
        case phone
        case password
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var years: [Int] {
        Array((1900...currentYear).reversed())
    }

    private var months: [Int] {
        Array(1...12)
    }

    private var days: [Int] {
        let calendar = Calendar.current

        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth

        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return Array(1...31)
        }

        return Array(range)
    }

    private var selectedBirthDate: Date {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = selectedDay

        return Calendar.current.date(from: components) ?? Date()
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

                Button("パスワードを忘れた方はこちら") {
                    sendPasswordReset()
                }
                .font(.headline)
                .foregroundColor(.blue)
                .disabled(isLoading)

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
        .onAppear {
            registrationSettingsStore.startListening(
                organizationId: resolvedOrganizationId()
            )
        }
        .onChange(of: organizationStore.organizationId) { _, newValue in
            registrationSettingsStore.startListening(
                organizationId: newValue
            )
        }
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

            TextField("", text: $name)
                .placeholder(when: name.isEmpty) {
                    Text("例：山田太郎").foregroundColor(.gray)
                }
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)
                .tint(.blue)

            fieldTitle("ふりがな")

            TextField("", text: $furigana)
                .placeholder(when: furigana.isEmpty) {
                    Text("例：やまだたろう").foregroundColor(.gray)
                }
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .furigana)
                .tint(.blue)

            if registrationSettingsStore.birthDateRequired {
                fieldTitle("生年月日")
                birthDatePicker
            }

            ZStack(alignment: .leading) {

                TextField("", text: $email)
                    .foregroundColor(.primary)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .tint(.blue)

                if email.isEmpty {
                    Text(verbatim: "例：example@gmail.com")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 14)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            )

            fieldTitle("電話番号")

            TextField("", text: $phone)
                .placeholder(when: phone.isEmpty) {
                    Text("例：09012345678").foregroundColor(.gray)
                }
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .phone)
                .tint(.blue)

            fieldTitle("パスワード")

            SecureField("", text: $password)
                .placeholder(when: password.isEmpty) {
                    Text("6文字以上").foregroundColor(.gray)
                }
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .password)
                .tint(.blue)
        }
    }

    private var birthDatePicker: some View {
        HStack(spacing: 10) {

            Picker("年", selection: $selectedYear) {
                ForEach(years, id: \.self) { year in
                    Text(String(year) + "年")
                        .foregroundColor(.primary)
                        .tag(year)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .frame(minWidth: 110)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onChange(of: selectedYear) { _, _ in
                normalizeSelectedDay()
            }

            Picker("月", selection: $selectedMonth) {
                ForEach(months, id: \.self) { month in
                    Text("\(month)月")
                        .foregroundColor(.primary)
                        .tag(month)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onChange(of: selectedMonth) { _, _ in
                normalizeSelectedDay()
            }

            Picker("日", selection: $selectedDay) {
                ForEach(days, id: \.self) { day in
                    Text("\(day)日")
                        .foregroundColor(.primary)
                        .tag(day)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
    }

    private func normalizeSelectedDay() {
        if let maxDay = days.last,
           selectedDay > maxDay {
            selectedDay = maxDay
        }
    }

    private func register() {
        errorMessage = ""

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFurigana = furigana.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let organizationId = resolvedOrganizationId()

        guard !trimmedName.isEmpty else {
            errorMessage = "お名前を入力してください。"
            return
        }

        guard !trimmedFurigana.isEmpty else {
            errorMessage = "ふりがなを入力してください。"
            return
        }

        guard isHiragana(trimmedFurigana) else {
            errorMessage = "ふりがなは、ひらがなで入力してください。"
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

        guard trimmedPassword.count >= 6 else {
            errorMessage = "パスワードは6文字以上で入力してください。"
            return
        }

        guard !organizationId.isEmpty else {
            errorMessage = "コミュニティ情報が取得できません。"
            return
        }

        isLoading = true

        Auth.auth().createUser(
            withEmail: trimmedEmail,
            password: trimmedPassword
        ) { result, error in

            if let nsError = error as NSError? {

                if nsError.code == AuthErrorCode.emailAlreadyInUse.rawValue {

                    Auth.auth().signIn(
                        withEmail: trimmedEmail,
                        password: trimmedPassword
                    ) { result, error in

                        if let error {
                            let nsError = error as NSError

                            DispatchQueue.main.async {
                                self.isLoading = false
                                self.errorMessage =
                                """
                                既存アカウントのログインに失敗しました。
                                code: \(nsError.code)
                                \(nsError.localizedDescription)
                                """
                            }
                            return
                        }

                        guard let uid = result?.user.uid else {
                            DispatchQueue.main.async {
                                self.isLoading = false
                                self.errorMessage = "UID取得失敗"
                            }
                            return
                        }

                        saveRegistration(
                            organizationId: organizationId,
                            uid: uid,
                            name: trimmedName,
                            furigana: trimmedFurigana,
                            email: trimmedEmail,
                            phone: trimmedPhone
                        )
                    }

                    return
                }

                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = nsError.localizedDescription
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
                furigana: trimmedFurigana,
                email: trimmedEmail,
                phone: trimmedPhone
            )
        }
    }

    private func saveRegistration(
        organizationId: String,
        uid: String,
        name: String,
        furigana: String,
        email: String,
        phone: String
    ) {
        var data: [String: Any] = [
            "uid": uid,
            "organizationId": organizationId,
            "name": name,
            "furigana": furigana,
            "email": email,
            "phone": phone,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if registrationSettingsStore.birthDateRequired {
            data["birthDate"] = Timestamp(date: selectedBirthDate)
        }

        db.collection("organizations")
            .document(organizationId)
            .collection("memberRegistrations")
            .document(uid)
            .setData(data, merge: true) { error in

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error {
                        self.errorMessage =
                        "登録保存に失敗しました：\(error.localizedDescription)"
                    } else {
                        self.showCompleteAlert = true
                    }
                }
            }
    }

    private func sendPasswordReset() {
        errorMessage = ""

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            errorMessage = "パスワードリセットにはメールアドレスを入力してください。"
            return
        }

        isLoading = true

        Auth.auth().sendPasswordReset(withEmail: trimmedEmail) { error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error {
                    self.errorMessage =
                    "パスワードリセットメールの送信に失敗しました：\(error.localizedDescription)"
                } else {
                    self.errorMessage =
                    "パスワードリセットメールを送信しました。メールを確認してください。"
                }
            }
        }
    }

    private func isHiragana(_ text: String) -> Bool {
        let pattern = #"^[ぁ-んー　\s]+$"#
        return text.range(
            of: pattern,
            options: .regularExpression
        ) != nil
    }

    private func resolvedOrganizationId() -> String {
        organizationStore.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            self

            placeholder()
                .opacity(shouldShow ? 1 : 0)
                .padding(.leading, 8)
                .allowsHitTesting(false)
        }
    }
}
