//
//  ContentView.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<ContainerMaster> { !$0.isArchived }) private var containers: [ContainerMaster]
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    // 共有用ID
    @AppStorage("householdID") private var householdID: String = ""
    @State private var showWhatsNew = false
    @State private var showUpdateAlert = false
    // App Storeアップデートがあるかどうかを一旦保持するフラグ（シートとの競合防止用）
    @State private var pendingUpdateAlert = false

    var body: some View {
        // スプラッシュ画面を削除し、直接メイン画面へ遷移
        if !hasSeenOnboarding {
            // オンボーディング画面
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                .transition(.opacity)
        } else {
            // メインタブView
            mainTabView
                .transition(.opacity)
                .task {
                    // UpdateCheckerによるApp Storeの最新バージョン確認
                    do {
                        let hasUpdate = try await UpdateChecker.checkUpdate()
                        if hasUpdate {
                            // WhatsNewシートが表示中ならアラートを保留する
                            // （アラートがシートを閉じてしまうのを防ぐため）
                            if showWhatsNew {
                                pendingUpdateAlert = true
                            } else {
                                showUpdateAlert = true
                            }
                        }
                    } catch {
                        print("App Store update check failed: \(error)")
                    }
                }
                .onAppear {
                    // アプリ起動時にIDがあれば同期開始
                    if !householdID.isEmpty {
                        DataSyncService.shared.startSync(householdID: householdID, modelContext: modelContext)
                    }
                    // WhatsNewチェックを即時実行（App Storeチェックより先にshowWhatsNewをセットするため遅延なし）
                    checkForUpdates()
                }
                .onChange(of: householdID) { oldValue, newValue in
                    if newValue.isEmpty {
                        // ログアウト時
                        DataSyncService.shared.stopSync()
                    } else {
                        // ログイン/参加時
                        DataSyncService.shared.startSync(householdID: newValue, modelContext: modelContext)
                    }
                }
                .sheet(isPresented: $showWhatsNew, onDismiss: {
                    // WhatsNewシートが閉じた後、保留中のアップデートアラートがあれば表示
                    if pendingUpdateAlert {
                        pendingUpdateAlert = false
                        showUpdateAlert = true
                    }
                }) {
                    WhatsNewView {
                        updateSavedVersion()
                    }
                    .interactiveDismissDisabled(true)
                }
                .alert("アップデートのお知らせ", isPresented: $showUpdateAlert) {
                    Button("アップデートする") {
                        // プライマリボタン押下時に、AppConfigで指定した正しいIDを使用したストア画面へ遷移
                        UIApplication.shared.open(AppConfig.storeURL)
                    }
                    Button("後で", role: .cancel) { }
                } message: {
                    Text("新しいバージョンのURUOIが利用可能です。ストアからアップデートをお願いします。")
                }
        }
    }
    
    // MARK: - メインタブView
    
    private var mainTabView: some View {
        TabView {
            RecordView()
                .tabItem {
                    Label("記録", systemImage: "drop.fill")
                }
            
            AnalysisView()
                .tabItem {
                    Label("分析", systemImage: "chart.bar.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "list.bullet")
                }
            
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
        .preferredColorScheme(.light) // アプリ全体をライトモードに固定
        .onAppear {
            configureTabBarAppearance()
            // injectInitialDataIfNeeded() // 初回データ生成を無効化
        }
    }
    
    // MARK: - タブバー設定
    
    /// タブバーを透過なしの白背景に設定
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground() // 透過なしの不透明設定
        appearance.backgroundColor = .white // 背景色を白に
        
        // アイコン選択色の設定（メインカラー）
        let itemAppearance = UITabBarItemAppearance()
        let mainColor = UIColor(red: 0x15/255.0, green: 0x6E/255.0, blue: 0xBA/255.0, alpha: 1.0) // #156EBA
        itemAppearance.selected.iconColor = mainColor
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: mainColor]
        appearance.stackedLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // MARK: - 初期データ注入 (無効化中)
    
    /*
    /// 初回起動時にContainerMasterの初期データを注入
    private func injectInitialDataIfNeeded() {
        // アーカイブされていないコンテナが存在するかチェック
        let descriptor = FetchDescriptor<ContainerMaster>(
            predicate: #Predicate { !$0.isArchived }
        )
        
        do {
            let existingContainers = try modelContext.fetch(descriptor)
            guard existingContainers.isEmpty else { return }
            
            print("📦 初期データを注入します")
            
            // 初期データを注入
            let initialContainers: [(name: String, emptyWeight: Double)] = [
                ("白の大きい器", 1185.0),
                ("緑の大きい器", 1166.0),
                ("Mサイズ", 902.0),
                ("Sサイズ", 494.0),
                ("ボトル", 0.0)
            ]
            
            for container in initialContainers {
                let newContainer = ContainerMaster(
                    name: container.name,
                    emptyWeight: container.emptyWeight
                )
                modelContext.insert(newContainer)
            }
            // try modelContext.save() は自動保存されるため明示的に呼ばなくても良い場合が多いが念のため
            try? modelContext.save()
            print("✅ 初期データの注入が完了しました")
        } catch {
            print("❌ 初期データ注入エラー: \(error)")
        }
    }
    */
    // MARK: - App Version
    
    private func checkForUpdates() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let savedVersion = UserDefaults.standard.string(forKey: "savedAppVersion")
        
        if savedVersion != currentVersion {
            showWhatsNew = true
        }
    }
    
    private func updateSavedVersion() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        UserDefaults.standard.set(currentVersion, forKey: "savedAppVersion")
    }
}

// MARK: - SplashView

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // 背景色
            Color.appMain
                .ignoresSafeArea()
            
            // ロゴ
            VStack(spacing: 20) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text("URUOI")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
            .onAppear {
                // ロゴのフェードイン・スケールアニメーション
                withAnimation(.easeOut(duration: 0.8)) {
                    logoScale = 1.0
                    logoOpacity = 1.0
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("メイン画面") {
    ContentView()
        .modelContainer(for: [ContainerMaster.self, WaterRecord.self], inMemory: true)
}

#Preview("スプラッシュ画面") {
    SplashView()
}
