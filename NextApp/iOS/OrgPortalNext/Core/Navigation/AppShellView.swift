import SwiftUI
import DesignSystem

public enum AppTab: Hashable {
    case home
    case tools
    case community
    case profile
}

public struct AppShellView<
    Home: View,
    Tools: View,
    Community: View,
    Profile: View
>: View {
    @State private var selection: AppTab = .home
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let home: Home
    private let tools: Tools
    private let community: Community
    private let profile: Profile

    public init(
        home: Home,
        tools: Tools,
        community: Community,
        profile: Profile
    ) {
        self.home = home
        self.tools = tools
        self.community = community
        self.profile = profile
    }

    public var body: some View {
        TabView(selection: $selection) {
            home
                .tabItem { Label("tab.home", systemImage: "house") }
                .tag(AppTab.home)
            tools
                .tabItem { Label("tab.tools", systemImage: "wrench.and.screwdriver") }
                .tag(AppTab.tools)
            community
                .tabItem { Label("tab.community", systemImage: "person.3") }
                .tag(AppTab.community)
            profile
                .tabItem { Label("tab.profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .tint(DesignTokens.brandGreen)
        .toolbar(verticalSizeClass == .compact ? .hidden : .visible, for: .tabBar)
    }
}

public struct PlaceholderTabView: View {
    private let titleKey: LocalizedStringKey
    private let messageKey: LocalizedStringKey

    public init(titleKey: LocalizedStringKey, messageKey: LocalizedStringKey) {
        self.titleKey = titleKey
        self.messageKey = messageKey
    }

    public var body: some View {
        NavigationStack {
            EmptyState(messageKey, systemImage: "shippingbox")
                .navigationTitle(titleKey)
        }
    }
}
