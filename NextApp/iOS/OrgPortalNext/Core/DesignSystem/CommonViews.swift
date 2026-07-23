import SwiftUI

public struct FeatureCard: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let systemImage: String
    private let status: LocalizedStringKey?

    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        systemImage: String,
        status: LocalizedStringKey? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.status = status
    }

    public var body: some View {
        HStack(spacing: DesignTokens.contentSpacing) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(DesignTokens.brandGreen)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let status {
                StatusBadge(status, systemImage: "clock")
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadius))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .contentShape(Rectangle())
        .frame(minHeight: DesignTokens.minimumTapHeight)
    }
}

public struct CommunitySwitcher: View {
    @Binding private var selection: String?
    private let communities: [(id: String, name: String)]

    public init(
        selection: Binding<String?>,
        communities: [(id: String, name: String)]
    ) {
        _selection = selection
        self.communities = communities
    }

    public var body: some View {
        Picker("community.switcher", selection: $selection) {
            ForEach(communities, id: \.id) { community in
                Text(community.name).tag(Optional(community.id))
            }
        }
        .pickerStyle(.menu)
        .frame(minHeight: DesignTokens.minimumTapHeight)
    }
}

public struct PrimaryActionButton: View {
    private let title: LocalizedStringKey
    private let action: () -> Void

    public init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.minimumTapHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(DesignTokens.brandGreen)
    }
}

public struct StatusBadge: View {
    private let text: LocalizedStringKey
    private let systemImage: String
    private let color: Color

    public init(
        _ text: LocalizedStringKey,
        systemImage: String,
        color: Color = DesignTokens.brandGreen
    ) {
        self.text = text
        self.systemImage = systemImage
        self.color = color
    }

    public var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

public struct EmptyState: View {
    private let message: LocalizedStringKey
    private let systemImage: String

    public init(_ message: LocalizedStringKey, systemImage: String = "tray") {
        self.message = message
        self.systemImage = systemImage
    }

    public var body: some View {
        ContentUnavailableView(message, systemImage: systemImage)
    }
}

public struct ErrorState: View {
    private let message: String
    private let retry: () -> Void

    public init(message: String, retry: @escaping () -> Void) {
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        ContentUnavailableView {
            Label(message, systemImage: "exclamationmark.triangle")
        } actions: {
            Button("action.retry", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.brandGreen)
        }
    }
}

public struct LoadingState: View {
    public init() {}

    public var body: some View {
        ProgressView()
            .controlSize(.large)
            .accessibilityLabel("state.loading")
    }
}

public struct PermissionRequiredState: View {
    private let message: LocalizedStringKey

    public init(_ message: LocalizedStringKey) {
        self.message = message
    }

    public var body: some View {
        ContentUnavailableView(message, systemImage: "lock.shield")
    }
}

public struct OfflineBanner: View {
    public init() {}

    public var body: some View {
        Label("state.offline", systemImage: "wifi.slash")
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(.orange)
    }
}
