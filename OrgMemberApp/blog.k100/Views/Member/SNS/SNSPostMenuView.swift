import SwiftUI
import UIKit

struct SNSPostMenuView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                snsOpenButton(
                    title: "Facebook",
                    icon: "f.circle.fill",
                    urlString: "https://www.facebook.com/"
                )

                snsOpenButton(
                    title: "Instagram",
                    icon: "camera.circle.fill",
                    urlString: "https://www.instagram.com/"
                )

                snsOpenButton(
                    title: "X",
                    icon: "xmark.circle.fill",
                    urlString: "https://x.com/"
                )

                snsOpenButton(
                    title: "LINE",
                    icon: "message.circle.fill",
                    urlString: "line://"
                )

                snsOpenButton(
                    title: "アメブロ",
                    icon: "pencil.circle.fill",
                    urlString: "https://ameblo.jp/"
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("SNSに投稿")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func snsOpenButton(
        title: String,
        icon: String,
        urlString: String
    ) -> some View {

        Button {
            openURL(urlString)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .bold))

                Text(title)
                    .font(.title3.bold())

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline.bold())
            }
            .foregroundColor(.white)
            .padding(.vertical, 18)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}
