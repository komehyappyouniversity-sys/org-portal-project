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

            Section("登録用QRコード") {

                NavigationLink {
                    OrganizationQRCodeView(
                        title: "管理アプリ登録用QRコード",
                        organizationName: organization.name,
                        organizationCode: organization.organizationCode
                    )
                } label: {
                    Label(
                        "管理アプリ用QRコードを発行",
                        systemImage: "qrcode"
                    )
                }

                NavigationLink {
                    OrganizationQRCodeView(
                        title: "会員アプリ登録用QRコード",
                        organizationName: organization.name,
                        organizationCode: organization.organizationCode
                    )
                } label: {
                    Label(
                        "会員アプリ用QRコードを発行",
                        systemImage: "person.crop.circle.badge.plus"
                    )
                }
            }

            Section("組織表示設定") {
                NavigationLink {
                    OrganizationLogoSettingsView(
                        organization: organization
                    )
                } label: {
                    Label(
                        "組織ロゴ設定",
                        systemImage: "photo"
                    )
                }

                NavigationLink {
                    OrganizationHomepageSettingsView(
                        organization: organization
                    )
                } label: {
                    Label(
                        "ホームページURL設定",
                        systemImage: "globe"
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
