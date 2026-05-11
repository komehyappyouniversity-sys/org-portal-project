import SwiftUI

struct OrganizationDetailView: View {
    let organization: OrganizationItem

    var body: some View {
        List {

            Section("組織情報") {

                HStack {
                    Text("組織名")
                    Spacer()

                    Text(organization.name)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("organizationId")
                    Spacer()

                    Text(organization.id)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("状態")
                    Spacer()

                    Text(organization.isActive ? "有効" : "停止中")
                        .foregroundColor(
                            organization.isActive ? .green : .red
                        )
                }
            }

            Section("管理アプリ設定") {

                NavigationLink {
                    SuperAdminFeatureSettingsView(
                        organizationId: organization.id
                    )
                } label: {
                    Label(
                        "管理アプリ機能設定",
                        systemImage: "switch.2"
                    )
                }

                NavigationLink {
                    OrganizationAdminListView(
                        organization: organization
                    )
                } label: {
                    Label(
                        "管理者一覧",
                        systemImage: "person.2"
                    )
                }

                NavigationLink {
                    OrganizationVimeoSettingsView(
                        organization: organization
                    )
                } label: {
                    Label(
                        "Vimeo設定",
                        systemImage: "play.rectangle"
                    )
                }
            }
        }
        .navigationTitle(organization.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
