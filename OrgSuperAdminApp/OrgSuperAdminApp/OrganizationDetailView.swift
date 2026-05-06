import SwiftUI

struct OrganizationDetailView: View {
    let organization: OrganizationItem

    var body: some View {
        List {
            Section("組織情報") {
                row(title: "組織名", value: organization.name)
                row(title: "organizationId", value: organization.id)
                row(title: "状態", value: organization.isActive ? "有効" : "停止中")
            }

            Section("管理メニュー") {
                NavigationLink("管理者一覧") {
                    OrganizationAdminListView(organization: organization)
                }

                NavigationLink("Vimeo設定") {
                    OrganizationVimeoSettingsView(organization: organization)
                }

                NavigationLink("課金設定") {
                    Text("課金設定は次のステップで作成します")
                }
            }
        }
        .navigationTitle(organization.name)
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
}
