import SwiftUI

struct SettingsView: View {
    // dismissは不要になるので削除しても良いですが、念のため残しておいても問題ありません
    @Environment(\.dismiss) private var dismiss
    
    // アプリ共通の課金状態フラグ
    @AppStorage("isProMember") private var isProMember: Bool = false
    
    // アラート設定
    @AppStorage("isWaterAlertEnabled") private var isWaterAlertEnabled: Bool = true
    @AppStorage("waterReminderDays") private var waterReminderDays: Int = 1 // キーを修正: waterAlertInterval -> waterReminderDays
    @AppStorage("isHealthAlertEnabled") private var isHealthAlertEnabled: Bool = true
    @AppStorage("healthAlertThreshold") private var healthAlertThreshold: Int = 200
    
    @State private var showingPremiumIntro = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - プレミアムプラン案内（未加入時のみ）
                if !isProMember {
                    Section {
                        Button {
                            showingPremiumIntro = true
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow)
                                Text("もっと！URUOIプランを見る")
                                    .fontWeight(.bold)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // MARK: - 家族共有設定
                Section(header: Text("データ共有"), footer: Text("記録を家族と共有することができます。")) {
                    if isProMember {
                        NavigationLink(destination: FamilySharingView()) {
                            HStack {
                                Image(systemName: "house.fill")
                                    .foregroundStyle(.blue)
                                Text("家族共有（ベータ版）")
                            }
                        }
                    } else {
                        Button {
                            showingPremiumIntro = true
                        } label: {
                            HStack {
                                Image(systemName: "house.fill")
                                    .foregroundStyle(.blue)
                                Text("家族共有（ベータ版）")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // MARK: - 水換えアラート
                Section(header: Text("水換えアラート"), footer: Text("水を換えてから指定した日数が経過すると通知が届きます。")) {
                    if isProMember {
                        Toggle("有効にする", isOn: $isWaterAlertEnabled)
                            .tint(.blue)
                        
                        if isWaterAlertEnabled {
                            Stepper("通知間隔: \(waterReminderDays) 日", value: $waterReminderDays, in: 1...30)
                        }
                    } else {
                        Button {
                            showingPremiumIntro = true
                        } label: {
                            HStack {
                                Text("有効にする")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // MARK: - 健康アラート
                Section(header: Text("健康アラート"), footer: Text("1日の飲水量が基準を下回った場合に通知します。")) {
                    Toggle("有効にする", isOn: $isHealthAlertEnabled)
                        .tint(.blue)
                    
                    if isHealthAlertEnabled {
                        Stepper("基準量: \(healthAlertThreshold) ml", value: $healthAlertThreshold, step: 50)
                    }
                }
                
                // MARK: - サポート
                Section("サポート") {
                    Link("よくある質問", destination: URL(string: "https://alive-galliform-e53.notion.site/URUOI-2decf0f2e6aa80859cb6d4dcb00c6738?source=copy_link")!)
                    Link("プライバシーポリシー", destination: URL(string: "https://alive-galliform-e53.notion.site/2e0cf0f2e6aa807a91cae7e207684724?source=copy_link")!)
                    Link("お問い合わせ・フィードバック", destination: URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSe0Xdk_P7sMJupxluDGtE-YrroVIKzi3DHetZ65MTQ8KzWS6A/viewform?usp=dialog")!)
                }
                
                // MARK: - アプリ情報
                Section("アプリについて") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - 🧪 テスト用メニュー
                Section(header: Text("🧪 テスト用メニュー")) {
                    Toggle("【デバッグ】プレミアムプラン有効化", isOn: $isProMember)
                        .tint(.orange)
                    Text("※このスイッチはテスト版でのみ表示されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            // 以前ここにあった .toolbar ブロックを削除しました
            .sheet(isPresented: $showingPremiumIntro) {
                PremiumIntroductionView()
            }
        }
    }
}
