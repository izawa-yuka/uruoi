import SwiftUI
import UIKit

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
    @AppStorage("numberOfPets") private var numberOfPets: Int = 1
    
    @State private var showingPremiumIntro = false
    @Environment(\.modelContext) private var modelContext
    #if DEBUG
    @State private var showingDebugAlert = false
    @State private var showingPermissionAlert = false
    #endif
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 会員ステータス
                Section {
                    HStack {
                        switch StoreManager.shared.currentPlan {
                        case .lifetime:
                            Label {
                                Text("ずっと！URUOIプラン（買い切り）")
                                    .foregroundStyle(.primary)
                                    .fontWeight(.bold)
                            } icon: {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                            }
                        case .monthly:
                            Label {
                                Text("もっと！URUOIプラン（月額）")
                                    .foregroundStyle(.primary)
                                    .fontWeight(.bold)
                            } icon: {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                            }
                        case .yearly:
                            Label {
                                Text("もっと！URUOIプラン（年額）")
                                    .foregroundStyle(.primary)
                                    .fontWeight(.bold)
                            } icon: {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                            }
                        case .free:
                            Text("現在のプラン: 無料プラン")
                        }
                    }
                }
                
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
                                Text("家族共有")
                            }
                        }
                    } else {
                        Button {
                            showingPremiumIntro = true
                        } label: {
                            HStack {
                                Image(systemName: "house.fill")
                                    .foregroundStyle(.blue)
                                Text("家族共有")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // MARK: - 猫の設定
                Section(header: Text("猫の設定")) {
                    Stepper(value: $numberOfPets, in: 1...20) {
                        Text(String(localized: "猫の頭数: \(numberOfPets)匹"))
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
                
                // MARK: - 言語設定
                Section {
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        HStack {
                            Label {
                                Text("言語設定", tableName: "Localizable")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "globe")
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            if let languageCode = Bundle.main.preferredLocalizations.first,
                               let languageName = Locale.current.localizedString(forIdentifier: languageCode) {
                                Text(languageName)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // MARK: - サポート
                Section("サポート") {
                    Link("よくある質問", destination: AppConfig.faqURL)
                    Link("利用規約", destination: AppConfig.termsURL)
                    Link("プライバシーポリシー", destination: AppConfig.privacyPolicyURL)
                    Link("お問い合わせ・フィードバック", destination: AppConfig.supportURL)
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
                
                // MARK: - 📸 スクリーンショット用 (DEBUGのみ)
                #if DEBUG
                Section(header: Text("📸 スクリーンショット用")) {
                    Button("スクショ用データを生成") {
                        showingDebugAlert = true
                    }
                    .foregroundColor(.blue)
                }
                
                Section(header: Text("🔔 通知デバッグ")) {
                    Button("権限ステータス確認") {
                        NotificationManager.shared.debugCheckPermission()
                    }
                    
                    Button("待機中の通知リストを出力") {
                        NotificationManager.shared.debugListPendingNotifications()
                    }
                    
                    // 確実に動くようにタスクとログを明示的に書く
                    Button("5秒後にテスト通知") {
                        Task {
                            print("🟢 [Debug] ボタンがタップされました")
                            let center = UNUserNotificationCenter.current()
                            
                            // 1. 権限確認
                            var settings = await center.notificationSettings()
                            print("🟢 [Debug] 権限状態(初期): \(settings.authorizationStatus.rawValue)")
                            
                            // 未決定の場合はリクエストする
                            if settings.authorizationStatus == .notDetermined {
                                print("🟡 [Debug] 権限をリクエストします...")
                                do {
                                    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                                    print("🟢 [Debug] 権限リクエスト結果: \(granted)")
                                    // 設定を再取得
                                    settings = await center.notificationSettings()
                                } catch {
                                    print("🔴 [Debug] 権限リクエストエラー: \(error)")
                                }
                            }
                            
                            // 許可されていない場合
                            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                                print("🔴 [Debug] 権限がありません (Status: \(settings.authorizationStatus.rawValue))")
                                await MainActor.run {
                                    showingPermissionAlert = true
                                }
                                return
                            }
                            
                            // 2. コンテンツ作成
                            let content = UNMutableNotificationContent()
                            content.title = "🔔 デバッグ通知"
                            content.body = "これは5秒後のテスト通知です"
                            content.sound = .default
                            
                            // 3. トリガー作成
                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                            
                            // 4. 登録
                            do {
                                try await center.add(request)
                                print("🟢 [Debug] 通知リクエストを登録しました（5秒後）")
                            } catch {
                                print("🔴 [Debug] 通知登録エラー: \(error)")
                            }
                        }
                    }
                    .foregroundColor(.green)
                }
                #endif
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPremiumIntro) {
                PremiumIntroductionView()
            }
            .task {
                await StoreManager.shared.updatePurchasedStatus()
            }
            #if DEBUG
            .alert("データの生成", isPresented: $showingDebugAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("生成する", role: .destructive) {
                    DebugDataManager.injectSampleData(context: modelContext)
                }
            } message: {
                Text("既存のデータはすべて削除され、ダミーデータに置き換わります。よろしいですか？")
            }
            .alert("通知が無効です", isPresented: $showingPermissionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("設定アプリから通知を許可してください。")
            }
            #endif
        }
    }
}
