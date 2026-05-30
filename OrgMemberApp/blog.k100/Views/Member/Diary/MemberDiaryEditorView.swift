import SwiftUI
import PhotosUI

struct MemberDiaryEditorView: View {

    let organizationId: String
    let uid: String
    let existingDiary: MemberDiary?

    @ObservedObject var store: MemberDiaryStore

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var bodyText: String
    @State private var mood: String
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    @FocusState private var isTitleFocused: Bool
    @FocusState private var isBodyFocused: Bool

    private let moods = ["とても良い", "良い", "普通", "少し不調", "不調"]

    init(
        organizationId: String,
        uid: String,
        existingDiary: MemberDiary?,
        store: MemberDiaryStore
    ) {
        self.organizationId = organizationId
        self.uid = uid
        self.existingDiary = existingDiary
        self.store = store

        _title = State(initialValue: existingDiary?.title ?? "")
        _bodyText = State(initialValue: existingDiary?.body ?? "")
        _mood = State(initialValue: existingDiary?.mood ?? "普通")
    }

    private var currentImageCount: Int {
        (existingDiary?.imageURLs.count ?? 0) + selectedImages.count
    }

    var body: some View {
        Form {
            Section("タイトル") {
                DiaryTextField(
                    text: $title,
                    placeholder: "例：今日の体調",
                    isFocused: $isTitleFocused
                )
                .frame(height: 44)
                .padding(.horizontal, 8)
                .background(Color.white)
                .cornerRadius(14)
            }

            Section("本文") {
                DiaryTextView(
                    text: $bodyText,
                    isFocused: $isBodyFocused
                )
                .frame(minHeight: 260)
                .padding(8)
                .background(Color.white)
                .cornerRadius(18)
            }

            Section("気分") {
                Picker("気分", selection: $mood) {
                    ForEach(moods, id: \.self) { mood in
                        Text(mood).tag(mood)
                    }
                }
            }

            Section("写真（最大3枚）") {
                if let existingDiary,
                   !existingDiary.imageURLs.isEmpty {

                    Text("保存済み写真：\(existingDiary.imageURLs.count)枚")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: max(
                        0,
                        3 - (existingDiary?.imageURLs.count ?? 0)
                    ),
                    matching: .images
                ) {
                    Label("写真を選択", systemImage: "photo")
                }
                .disabled(currentImageCount >= 3)

                if currentImageCount >= 3 {
                    Text("写真は1件の日記につき最大3枚までです。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(selectedImages.indices, id: \.self) { index in
                    Image(uiImage: selectedImages[index])
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if !store.errorMessage.isEmpty {
                Section {
                    Text(store.errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTitleFocused = true
            }
        }
        .navigationTitle(existingDiary == nil ? "日記を書く" : "日記を編集")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("キャンセル") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    Task {
                        await store.saveDiary(
                            organizationId: organizationId,
                            uid: uid,
                            existingDiary: existingDiary,
                            title: title,
                            body: bodyText,
                            mood: mood,
                            newImages: selectedImages
                        )

                        if store.errorMessage.isEmpty {
                            dismiss()
                        }
                    }
                }
                .disabled(store.isLoading)
            }
        }
        .onChange(of: selectedItems) {
            Task {
                await loadSelectedImages()
            }
        }
    }

    private func loadSelectedImages() async {
        selectedImages = []

        for item in selectedItems.prefix(3) {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {

                    selectedImages.append(image)
                }

            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }
}

struct DiaryTextField: UIViewRepresentable {

    @Binding var text: String

    let placeholder: String
    let isFocused: FocusState<Bool>.Binding

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()

        textField.font = .systemFont(ofSize: 17)
        textField.textColor = .label
        textField.tintColor = .systemBlue
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.returnKeyType = .next
        textField.backgroundColor = .clear

        return textField
    }

    func updateUIView(
        _ uiView: UITextField,
        context: Context
    ) {
        if uiView.text != text {
            uiView.text = text
        }

        if isFocused.wrappedValue,
           !uiView.isFirstResponder {

            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {

        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }
    }
}

struct DiaryTextView: UIViewRepresentable {

    @Binding var text: String

    let isFocused: FocusState<Bool>.Binding

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        textView.font = .systemFont(ofSize: 17)
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.tintColor = .systemBlue
        textView.delegate = context.coordinator
        textView.isScrollEnabled = true

        return textView
    }

    func updateUIView(
        _ uiView: UITextView,
        context: Context
    ) {
        if uiView.text != text {
            uiView.text = text
        }

        if isFocused.wrappedValue,
           !uiView.isFirstResponder {

            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {

        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
    }
}
