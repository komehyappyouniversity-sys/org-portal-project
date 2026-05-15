import SwiftUI

struct AdminOrganizationSwitcherView: View {
    @EnvironmentObject var organizationStore: AdminOrganizationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("現在の組織") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(organizationStore.currentOrganizationName.isEmpty
                         ? "未選択"
                         : organizationStore.currentOrganizationName)
                        .font(.headline)

                    Text(organizationStore.currentOrganizationId.isEmpty
                         ? "organizationId なし"
                         : organizationStore.currentOrganizationId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("切り替え可能な組織") {
                ForEach(organizationStore.availableOrganizations) { organization in
                    Button {
                        organizationStore.selectOrganization(organization)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(organization.name)
                                    .foregroundColor(.primary)

                                Text(organization.id)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if organization.id == organizationStore.currentOrganizationId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }

            if !organizationStore.errorMessage.isEmpty {
                Section {
                    Text(organizationStore.errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("組織切替")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("更新") {
                    Task {
                        await organizationStore.reload()
                    }
                }
            }
        }
    }
}
