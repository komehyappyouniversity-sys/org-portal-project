import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            // ブランドカラー（例: 青色） を背景に
            Color(red: 0.13, green: 0.50, blue: 0.98)
                .ignoresSafeArea()
            
            // ロゴが後で追加できるようアプリ名を中央に太字で
            Text("会員アプリ")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
        }
    }
}

#Preview {
    LaunchScreen()
}
